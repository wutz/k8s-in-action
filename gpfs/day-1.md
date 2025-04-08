# 部署 GPFS

## 准备

1. 访问 [https://www.ibm.com/docs/en/storage-scale?topic=STXKQY/gpfsclustersfaq.html](https://www.ibm.com/docs/en/storage-scale?topic=STXKQY/gpfsclustersfaq.html) 检查使用的 GPFS 版本支持 OS 和 MOFED (如果环境配置 IB/RoCE) 版本
2. [可选] 安装 MOFED 驱动并重启
3. 配置节点间 SSH 免密
4. 关闭 selinux & firewalld
5. 配置 ntp 和时区
6. 配置 `/etc/hosts` 其中每个节点使用格式 `<ip> <fqdn> <alias>`

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
    $ cat << 'EOF' > NodeList
    server1:quorum-manager
    server2:quorum-manager
    server3:quorum
    client1
    client2
    EOF
    $ sudo mmcrcluster -N NodeList --ccr-enable -r /usr/bin/ssh -R /usr/bin/scp -C cluster1
    
    $ sudo mmchlicense server --accept -N server1,server2,server3
    $ sudo mmchlicense client --accept -N client1,client2
    
    $ sudo mmlscluster
    $ sudo mmstartup -a
    ```
    
## 创建 NSD
    
    ```bash
    $ cat << 'EOF' > gen_nsd.sh
    for node in server{1..3}; do
    	for dev in nvme{0..7}n1; do
    
    cat << 'IN'
    %nsd:
    	device=/dev/$dev
    	nsd=nsd_${node}_${dev}
    	servers=$node
    	usage=dataAndMetadata
    	failureGroup=${node#server}
    	thinDiskType=nvme
    IN
    
    	done
    done
    EOF
    $ sh gen_nsd.sh > NSD
    $ sudo mmcrnsd -F NSD
    ```
    
    - 在较小存储集群中通常按照节点设置 failureGroup

## 创建 GPFS
    
    ```bash
    $ sudo mmcrfs fs1 -F NSD -m 2 -r 2 -M 3 -R 3 -A yes -Q yes
    $ sudo mmmount fs1 -a
    
    $ sudo mmlsdisk fs1 -L
    $ sudo mmlsnsd
    $ sudo mmlsfs fs1
    $ sudo mmchfs fs1 -m 3 && mmrestripefs fs1 -R
    ```
    
## 启用 RoCE/IB 通信
    
    ```bash
    $ sudo mmchconfig verbsRdma=enable,verbsRdmaSend=yes,verbsPorts="mlx5_bond_0",verbsRdmaCm=enable
    $ sudo mmshutdown -a
    $ sudo mmstartup -a
    ```
    
    - 如果使用 RoCE，网络配置必须开启 IPv6 且必须设置 `verbsRdmaCm=enable`