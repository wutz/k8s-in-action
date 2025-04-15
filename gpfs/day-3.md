# 开启 NFS 服务

GPFS 的 NFS 服务需要安装在 CES (Cluster Export Services)节点。

本文档假设NFS服务安装在bj1sn001节点

## 安装软件包

### 安装依赖

安装 CES 相关软件包需要提前安装如下依赖

```bash
# apt install daemon arping libasn1-8-heimdal libgssapi3-heimdal libhcrypto4-heimdal libheimbase1-heimdal libheimntlm0-heimdal libhx509-5-heimdal libkrb5-26-heimdal libroken18-heimdal libwind0-heimdal
```

### 安装软件包

NFS软件依赖SMB相关软件包，所以这里必须先安装SMB相关软件包

#### 安装 SMB 软件包

* RHEL/RockyLinux

```bash
cd /usr/lpp/mmfs/5.*/smb_rpms/rhel*

yum -y install gpfs.smb-*.rpm
```

* Ubuntu

```bash
cd /usr/lpp/mmfs/5.*/smb_debs/ubuntu/ubuntu2*

apt -y install ./gpfs.smb-*.deb

```

#### 安装 NFS 软件包

* RHEL/RockyLinux

```bash
cd /usr/lpp/mmfs/5.*/ganesha_rpms/rhel*

yum -y install gpfs.nfs-*.rpm
```

* Ubuntu

```bash
cd /usr/lpp/mmfs/5.*/ganesha_debs/ubuntu/ubuntu2*

apt -y install ./gpfs.nfs-*.deb

```

## 创建共享文件集

### 创建文件集

```bash
# 创建根fileset
mmcrfileset bj1fs1 nfsroot --inode-space=new
# 创建nfs导出fileset
mmcrfileset bj1fs1 nfs01 --inode-space=new

# 链接根 fileset 到文件系统上位置
mmlinkfileset bj1fs1 nfsroot -J /share/nfsroot
# 链接nfs文件集到文件系统上为止
mmlinkfileset bj1fs1 nfs01 -J /share/nfs01

```

## 配置 CES 节点

执行如下命令激活CES节点

设置共享root

```bash
mmchconfig cesSharedRoot=/share/nfsroot
```

```bash
mmchnode --ces-enable -N bj1sn001
```

## 开启 NFS

在所有CES节点上激活NFS服务

```bash
mmces service enable NFS 
```

在所有CES节点上启动NFS服务

```bash
mmces service start NFS -a
```

## 导出NFS

设定认证方法

```bash
mmuserauth service create --data-access-method file --type userdefined

```

导出文件集

```bash
mmnfs export add /share/nfs01 --client "*(Access_Type=RW)"
如果只允许某个节点10.23.23.21访问就
--nfsadd "10.23.23.21(Access_Type=RW)"
```

查看导出

```bash
mmnfs export list
```

执行如下命令确认NFS已配置和运行成功

```bash
mmces service list -a
mmuserauth service list
mmnfs export list
```

## 挂载NFS

在任意NFS客户端执行如下命令挂载

```bash
mount -t nfs4 sh90gn001:/share/nfs01 /mnt
```

## 关闭NFS

移除导出

```bash
mmnfs export remove /share/nfsroot/nfs01
```

关闭NFS服务和节点

```bash
mmces service stop NFS -a
mmuserauth service remove --data-access-method file
mmces service disable NFS
```

删除fileset

```bash
与文件系统解绑
mmunlinkfileset bj1fs1 nfs01 
mmunlinkfileset bj1fs1 nfsroot

删除file
mmdelfileset bj1fs1 nfs01
mmdelfileset bj1fs1 nfsroot
```

关闭节点的CES功能

```bash
mmchnode --ces-disable -N bj1sn001
```