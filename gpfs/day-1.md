# 部署 GPFS

## 准备

1. 访问 [https://www.ibm.com/docs/en/storage-scale?topic=STXKQY/gpfsclustersfaq.html](https://www.ibm.com/docs/en/storage-scale?topic=STXKQY/gpfsclustersfaq.html) 检查使用的 GPFS 版本支持 OS 和 MOFED (如果环境配置 IB/RoCE) 版本
2. 配置 `/etc/hosts` 其中每个节点使用格式 `<ip> <fqdn> <alias>`

    ```bash
    cat << 'EOF' >> /etc/hosts
    192.168.1.101 bj1sn001.example.local bj1sn001
    192.168.1.102 bj1sn002.example.local bj1sn002
    192.168.1.103 bj1sn003.example.local bj1sn003
    192.168.1.104 bj1sn004.example.local bj1sn004
    EOF
    ```

3. 配置节点间 SSH 免密

    ```bash
    ssh-keygen
    ssh-copy-id bj1sn001
    ssh-copy-id bj1sn002
    ssh-copy-id bj1sn003
    ssh-copy-id bj1sn004
    ```

4. 安装 pdsh

    ```bash
    apt install -y pdsh
    cat << 'EOF' >> /etc/profile.d/pdsh.sh
    export PDSH_RCMD_TYPE=ssh
    EOF
    source /etc/profile.d/pdsh.sh

    cat << 'EOF' > all
    bj1sn[001-004]
    EOF
    ```

5. 关闭 selinux & firewalld

    ```bash
    # RHEL/RockyLinux
    pdsh -w ^all 'systemctl disable firewalld --now'
    pdsh -w ^all 'sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config'
    ```

6. 配置 ntp 和时区

    ```bash
    # RHEL/RockyLinux
    pdsh -w ^all 'timedatectl set-timezone Asia/Shanghai'
    pdsh -w ^all 'yum install -y chrony'
    pdsh -w ^all 'sed -i 's/^pool.*/pool ntp.aliyun.com iburst/' /etc/chrony.conf'
    pdsh -w ^all 'systemctl enable --now chronyd'
    pdsh -w ^all 'chronyc sources'
    ```

7. 更新 kernel 到最新版本

    ```bash
    # RHEL/RockyLinux
    pdsh -w ^all 'yum update -y'
    # Ubuntu
    pdsh -w ^all 'apt update && apt upgrade -y'

    # 重启使用新 kernel
    pdsh -w ^all reboot
    ```

8. 安装 MOFED 驱动并重启

## [安装软件包](https://www.ibm.com/docs/en/storage-scale/5.2.2?topic=isslndp-manually-installing-storage-scale-software-packages-linux-nodes)

1. `./Spectrum_Scale_Data_Management-5.1.5.1-x86_64-Linux-install` 输出 `1` 接受即可

2. 安装包

    * RHEL/RockyLinux

        ```bash
        cd /usr/lpp/mmfs/5.*/gpfs_rpms

        # Data Access 版本
        yum -y install gpfs.base*.rpm gpfs.gpl*.rpm gpfs.license.da*.rpm gpfs.gskit*.rpm gpfs.msg*.rpm gpfs.docs*.rpm

        # Data Management 版本
        yum -y install gpfs.base*.rpm gpfs.gpl*.rpm gpfs.license.dm*.rpm gpfs.gskit*.rpm gpfs.docs*.rpm gpfs.msg*.rpm gpfs.adv*.rpm gpfs.crypto*.rpm
        ```

    * Ubuntu

        ```bash
        cd /usr/lpp/mmfs/5.*/gpfs_debs

        # Data Access 版本
        apt -y install ./gpfs.base*.deb ./gpfs.gpl*.deb ./gpfs.license.da*.deb ./gpfs.gskit*.deb ./gpfs.msg*.deb ./gpfs.docs*.deb

        # Data Management 版本
        apt -y install ./gpfs.base*.deb ./gpfs.gpl*.deb ./gpfs.license.dm*.deb ./gpfs.gskit*.deb ./gpfs.msg*.deb ./gpfs.docs*.deb ./gpfs.adv*.deb ./gpfs.crypto*.deb
        ```
    
3. 构建 **GPFS portability layer** 
    
    ```bash
    /usr/lpp/mmfs/bin/mmbuildgpl --build-package
    ```

    * RHEL/RockyLinux   

        ```bash
        rpm -ivh /root/rpmbuild/RPMS/x86_64/gpfs.gplbin*rpm
        ```

    * Ubuntu

        ```bash
        dpkg -i /tmp/deb/gpfs.gplbin*deb
        ```

4. 设置环境变量

    ```bash
    cat << 'EOF' >> /etc/profile.d/gpfs.sh
    export PATH=/usr/lpp/mmfs/bin:$PATH
    EOF
    source /etc/profile.d/gpfs.sh
    ```

5. 软件包拷贝到其他节点重复 2-4 步骤

    * RHEL/RockyLinux

        ```bash
        pdcp -w ^all -r /usr/lpp/mmfs/5.*/gpfs_rpms /tmp
        pdcp -w ^all /root/rpmbuild/RPMS/x86_64/gpfs.gplbin*rpm /tmp/gpfs_rpms

        # Data Access 版本
        pdsh -w ^all 'cd /tmp/gpfs_rpms && yum -y install gpfs.base*.rpm gpfs.gpl*.rpm gpfs.license.da*.rpm gpfs.gskit*.rpm gpfs.docs*.rpm gpfs.msg*.rpm'
        # Data Management 版本
        pdsh -w ^all 'cd /tmp/gpfs_rpms && yum -y install gpfs.base*.rpm gpfs.gpl*.rpm gpfs.license.dm*.rpm gpfs.gskit*.rpm gpfs.docs*.rpm gpfs.msg*.rpm gpfs.adv*.rpm gpfs.crypto*.rpm'
        ```

    * Ubuntu

        ```bash
        pdcp -w ^all -r /usr/lpp/mmfs/5.*/gpfs_debs /tmp
        pdcp -w ^all /tmp/deb/gpfs.gplbin*deb /tmp/gpfs_debs

        # Data Access 版本
        pdsh -w ^all 'cd /tmp/gpfs_debs && apt -y install ./gpfs.base*.deb ./gpfs.gpl*.deb ./gpfs.license.da*.deb ./gpfs.gskit*.deb ./gpfs.msg*.deb ./gpfs.docs*.deb'

        # Data Management 版本
        pdsh -w ^all 'cd /tmp/gpfs_debs && apt -y install ./gpfs.base*.deb ./gpfs.gpl*.deb ./gpfs.license.dm*.deb ./gpfs.gskit*.deb ./gpfs.msg*.deb ./gpfs.docs*.deb ./gpfs.adv*.deb ./gpfs.crypto*.deb'
        ```

    ```bash
    pdcp -w ^all /etc/profile.d/gpfs.sh /etc/profile.d/
    ```

## 创建集群并启动
    
```bash
cat << 'EOF' > NodeList
bj1sn001:quorum-manager
bj1sn002:quorum-manager
bj1sn003:quorum
bj1sn004
bj1gn001
EOF

mmcrcluster -N NodeList --ccr-enable -r /usr/bin/ssh -R /usr/bin/scp -C cluster1.bj1

mmchlicense server --accept -N bj1sn001,bj1sn002,bj1sn003,bj1sn004
mmchlicense client --accept -N bj1gn001,bj1gn002

# 查看集群配置
mmlscluster

# 启动集群
mmstartup -a

# 查看集群状态
mmgetstate -a
```
    
## 创建 NSD
    
```bash
cat << 'EOF' > gen_nsd.sh
for node in bj1sn00{1..4}; do
    for dev in nvme{0..7}n1; do

cat << IN
%nsd:
    device=/dev/$dev
    nsd=nsd_${node}_${dev}
    servers=$node
    usage=dataAndMetadata
    failureGroup=${node#bj1sn}
    thinDiskType=nvme
IN

    done
done
EOF
sh gen_nsd.sh > NSD

# 创建 NSD
mmcrnsd -F NSD

# 查看 NSD
mmlsnsd
```

- 在较小存储集群中通常按照节点设置 failureGroup

## 创建 GPFS
    
```bash
# 创建 GPFS
mmcrfs bj1fs1 -F NSD -m 2 -r 2 -M 3 -R 3 -A yes -Q yes

# 修改挂载点为 /share
mmchfs bj1fs1 -T /share

# 挂载 GPFS
mmmount bj1fs1 -a

# 查看磁盘
mmlsdisk bj1fs1 -L

# 查看 NSD
mmlsnsd

# 查看 GPFS
mmlsfs bj1fs1

# 设置 GPFS 元数据副本为 3, 并且均衡数据
mmchfs bj1fs1 -m 3 && mmrestripefs bj1fs1 -R
```
    
## 启用 RoCE/IB 通信
    
```bash
# 启用 IB 通信
mmchconfig verbsRdma=enable,verbsRdmaSend=yes,verbsPorts="mlx5_0 mlx5_1"
# 启用 RoCE 通信, 网络配置必须开启 IPv6 且必须设置 `verbsRdmaCm=enable`
mmchconfig verbsRdma=enable,verbsRdmaSend=yes,verbsPorts="mlx5_0 mlx5_1",verbsRdmaCm=enable

# 关闭集群
mmshutdown -a

# 启动集群
mmstartup -a

# 查看 RDMA 是否开启
mmfsadm test verbs status
# 测试 RDMA 连接状态
mmfsadm test verbs conn
# 查看网络状态
mmdiag --network
```

## 删除 GPFS 集群

```bash
# 卸载 GPFS
mmumount all a

# 删除 GPFS
mmdelfs bj1fs1

# 删除 NSD
mmdelsnsd -F NSD

# 关闭集群
mmshutdown -a

# 卸载软件包
# RHEL/RockyLinux
pdsh -w ^all 'rpm -e `rpm -qa | grep gpfs`'
# Ubuntu
pdsh -w ^all 'dpkg -P `dpkg-query -W -f='\''${Package}\n'\'' | grep gpfs`'

pdsh -w ^all rm -rf /var/mmfs /usr/lpp/mmfs
```