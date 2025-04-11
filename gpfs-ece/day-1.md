# GPFS 纠删码版集群部署

## 安装先决条件

* 必须使用 EL8 或 EL9 系统
* 安装了最新版本的 Mellanox OFED
* 在 `/etc/hosts` 添加 `<IP address> <Fully qualified domain name> <Short name>` 格式名称解析

    ```bash
    # /etc/hosts
    192.168.1.101 bj1sn001.example.local bj1sn001
    192.168.1.102 bj1sn002.example.local bj1sn002
    192.168.1.103 bj1sn003.example.local bj1sn003
    192.168.1.104 bj1sn004.example.local bj1sn004
    ```

* 关闭防火墙

    ```bash
    pdsh -w ^all systemctl disable firewalld --now
    ```

* 设置时间同步服务

    ```bash
    pdsh -w ^all dnf install -y chrony
    pdsh -w ^all 'sed -i "s/^pool.*/pool ntp.aliyun.com iburst/" /etc/chrony.conf'
    pdsh -w ^all systemctl enable chronyd --now
    pdsh -w ^all chronyc sources
    ```

## 安装概述

1. 网络和硬件预检查
2. 集群定义
3. 安装

仲裁或管理器节点规则:
* 对于单个恢复组，以下仲裁节点规则适用
    * 当 scale-out 节点数为 4 时，quorum 节点数设置为 3
    * 当横向扩展节点数为 5 或 6 时，仲裁节点数设置为 5
    * 当横向扩展节点数为 7 个或更多时，仲裁节点数设置为 7
* 如果恢复组的数量大于 1 且小于或等于 7，那么 7 个仲裁节点将以循环方式分布在各个恢复组中
* 如果恢复组的数量超过 7 个，则选择 7 个恢复组作为仲裁持有者
* 如果集群配置中未定义恢复组或仲裁节点, 那么仲裁节点将根据单个恢复组规则进行分布
* 如果您要在现有集群中添加新的恢复组，或者想要将新节点添加到现有节点类中，那么安装工具包不会修改现有的仲裁配置

## 安装

### 使用安装工具包安装

从 Fix Central 上的 IBM Storage Scale 页面下载补丁包

```bash
cat << 'EOF' >> /etc/profile.d/gpfs.sh
export PATH=/usr/lpp/mmfs/bin:$PATH
EOF
source /etc/profile.d/gpfs.sh

# 安装依赖 
dnf -y install ansible 
pdsh -w ^all dnf install -y python3 python3-dmidecode python3-distro python3-ethtool numactl cpp gcc gcc-c++ elfutils elfutils-devel make 

# 提取安装包 
./Spectrum_Scale_Erasure_Code-5.x.y.z-x86_64-Linux-install --textonly

cd /usr/lpp/mmfs/5.x.y.z/ansible-toolkit/

# 清除节点和配置
./spectrumscale node clear
./spectrumscale config clear gpfs --all

# 设置类型必须为 ece
./spectrumscale setup -s InstallerNodeIP -st ece

# 设置集群名称
./spectrumscale config gpfs -c bj1.example.local

# 在集群定义文件中添加节点
./spectrumscale node add bj1sn001 -so -m -q -a
./spectrumscale node add bj1sn002 -so -m -q 
./spectrumscale node add bj1sn003 -so -m -q 
./spectrumscale node add bj1sn004 -so -m

# 显示集群定义文件中指定的节点列表
./spectrumscale node list

# 执行环境预检查
./spectrumscale callhome disable
./spectrumscale install -pr
# pdsh -w ^all dnf install -y kernel-devel-4.18.0-553.el8_10.x86_64 kernel-headers-4.18.0-553.el8_10.x86_64

# 执行安装工具包安装
./spectrumscale install --skip no-ece-check

# 映射 nvme 插槽位置
pdsh -w ^all 'rm -f /usr/lpp/mmfs/data/gems/*.edf'
mmshutdown -a
ecedrivemapping --mode nvme --slotrange 1 4
ecedrivemapping --mode nvme -report
cp /usr/lpp/mmfs/data/gems/*.edf .
pdcp -w ^all *.edf /usr/lpp/mmfs/data/
mmstartup -a
# 查看 nvme 插槽位置
# tslsenclslot -ad| mmyfields -s slot SlotHandle LocationCode Devices| grep gems | awk '{print "location: "$2" device: "$3}'

# 集群定义文件中定义恢复组
./spectrumscale recoverygroup define -N bj1sn001,bj1sn002,bj1sn003,bj1sn004

./spectrumscale install --skip no-ece-check
# mmchconfig nsdRAIDBufferPoolSizePct=90,nsdRAIDTracks=16384 -N nc_1
# mmshutdown -a
# mmstartup -a

# 检查分散式阵列信息
./spectrumscale recoverygroup list
[ INFO  ] Name nodeclass Server                        DA_Name:FreeCapacity:Type
[ INFO  ] rg_1 nc_1      node1,ndoe2,node4,node5,node6 DA1:9757G:NVMe,DA2:8829G:HDD

# 定义 vdisk 集
./spectrumscale vdiskset define -vs nvme_meta -rg rg_1 -code 4WayReplication -bs 2M -ss 50% -da DA1 -nsd-usage metadataOnly -storage-pool system
./spectrumscale vdiskset define -vs hdd_data -rg rg_1 -code 4+3P -bs 8M -ss 80% -da DA2 -nsd-usage dataOnly -storage-pool datapool

# 列出 vdisk 集
./spectrumscale vdiskset list
[ INFO  ] name      recoverygroup blocksize setsize  RaidCode nsdUsage     poolName daName
[ INFO  ] hdd_data  rg_1            8M      80%      4+3P   dataOnly     datapool    DA2
[ INFO  ] nvme_meta rg_1            2M      50%    4WayReplication metadataOnly   system    DA1
```

```bash
# 定义文件系统
./spectrumscale filesystem define -fs gpfs1 -vs hdd_data,nvme_meta --mmcrfs '-T /gpfs1'

# 预检查
./spectrumscale install -pr

# 执行安装
./spectrumscale install
```