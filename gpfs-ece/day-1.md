# GPFS 纠删码版集群部署

## 安装先决条件

* 安装了最新版本的 Mellanox OFED
* 在 `/etc/hosts` 添加 `<IP address> <Fully qualified domain name> <Short name>` 格式名称解析

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

## 使用安装工具包安装

从 Fix Central 上的 IBM Storage Scale 页面下载补丁包

```bash
# 安装 ansible
apt install ansible 
pdsh -w ^all apt install -y python3-dmidecode python3-ethtool

# 提取安装包 
./Spectrum_Scale_Erasure_Code-5.x.y.z-x86_64-Linux-install --textonly

cd /usr/lpp/mmfs/5.x.y.z/ansible-toolkit/

# 清除节点和配置
./spectrumscale node clear
./spectrumscale config clear gpfs --all
./spectrumscale callhome disable

# 设置类型必须为 ece
./spectrumscale setup -s InstallerNodeIP -st ece

# 设置集群名称
./spectrumscale config gpfs -c bj1cluster1

# 在集群定义文件中添加节点
./spectrumscale node add bj1sn001 -so -q -m -a
./spectrumscale node add bj1sn002 -so -q -m 
./spectrumscale node add bj1sn003 -so -q -m 
./spectrumscale node add bj1sn004 -so

# 显示集群定义文件中指定的节点列表
./spectrumscale node list

# 集群定义文件中定义恢复组
./spectrumscale recoverygroup define -N Node1,Node2,...,NodeN

# 执行环境预检查
./spectrumscale install -pr

# 执行安装工具包安装
./spectrumscale install
```

```bash
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