# 0 准备

## 软件与硬件

![k8s-arch](images/k8s-arch.png)

### 集群命名

* 格式：`<2位字母城市缩写><1位数字序号>`
  * 数字序号：
    * 总是跳过数字 4
    * 数字 1-9 用于内部生产集群
    * 数字 10-89 用于外部生产集群
    * 数字 90-99 用于内部测试集群
* 示例：
  * bj1: 北京一个内部生产集群
  * sh10: 上海一个外部生产集群
  * gz90: 广州一个内部测试集群

### 节点命名

* 格式：`<集群名称><2位字母节点角色缩写><2-3数字序号>`
  * 数字序号：功能节点使用 2 位数字，计算节点使用 3 位数字
* 控制节点 mn
  * 生产集群至少 3 节点满足 HA 需要，最大 7 节点
  * 示例：`bj1mn01`, `bj1mn02`, `bj1mn03`
* 网络负载均衡节点 ln
  * 生产集群至少 2 节点满足 HA 需要, 可复用管理节点
  * 示例：`bj1ln01`, `bj1ln02`
* 存储节点 sn
  * 生产集群至少 3 节点满足 HA 需要, 推荐配置独立节点 (酌情复用管理节点)
  * 示例：`bj1sn001`, `bj1sn002`, `bj1sn003`
* 数据库节点 dn
  * 生产集群至少 3 节点满足 HA 需要, 推荐配置独立节点 (酌情复用管理节点)
  * 示例：`bj1dn01`, `bj1dn02`, `bj1dn03`
* CPU 计算节点 cn
  * 示例：`bj1cn001`, `bj1cn002`, `bj1cn003`
* GPU 计算节点 gn
  * 示例：`bj1gn001`, `bj1gn002`, `bj1gn003`

### DNS 命名

* 内网：`*.<CLUSTER>i.example.com`, 例如 `*.bj1i.example.com`
* 外网：`*.<CLUSTER>.example.com`, 例如 `*.bj1.example.com`

> * example.com 为示例域名，根据实际情况进行替换
> * i 是 internal 的缩写，表示内部服务

### 网络

- 所有节点至少 10Gb 以太内网互联
- 存储节点额外提供至少 10Gb 以太网互联进行数据复制，配置此网络可以极大提供存储性能
- 提供网络负载均衡节点至少 1Gb 接入互联网，如果不面向外部提供服务此网络可选。

> 可以根据具体业务和用户需求调整网络配置。

### 软件

- OS: ubuntu 22.04
- K8S: [k3s](https://k3s.io/) v1.31
- Ceph: [ceph](https://docs.ceph.com/en/latest/releases/) v19.2

> 更多需求可以参考 [k3s requirements](https://docs.k3s.io/zh/installation/requirements)

## 所有节点初始化

| 节点 | IP |
| --- | --- |
| bj1mn01 | 10.128.0.1/16 |
| bj1mn02 | 10.128.0.2/16 |
| bj1mn03 | 10.128.0.3/16 |
| bj1gn001 | 10.128.1.1/16 |
| bj1gn002 | 10.128.1.2/16 |
| bj1gn003 | 10.128.1.3/16 |
| bj1dn01 | 100.68.16.1/20 |
| bj1dn02 | 100.68.16.2/20 |
| bj1dn03 | 100.68.16.3/20 |
| bj1sn001 | 100.68.20.1/20 |
| bj1sn002 | 100.68.20.2/20 |
| bj1sn003 | 100.68.20.3/20 |
| bj1sn004 | 100.68.20.4/20 |

### 管理工具 pdsh

> * 为了安全性，后续所有 ssh 访问均从本地发起

```sh
# Ubuntu
apt install pdsh -y
# macOS
brew install pdsh

# 生成 hosts 用于后续执行 pdsh / pdcp
cat << 'EOF' > all
root@10.128.0.[1-3]
root@10.128.1.[1-3]
root@100.68.16.[1-3]
root@100.68.20.[1-4]
EOF

# 设置 pdsh 使用 ssh 而非缺省的 rsh
cat << 'EOF' > /etc/profile.d/pdsh.sh
export PDSH_RCMD_TYPE=ssh
export PDSH_REMOTE_PDCP_PATH=pdcp
EOF
source /etc/profile.d/pdsh.sh

# 所有节点安装 pdsh
pdsh -w ^all apt install -y pdsh
```

### 设置 ssh 无密码登录

> 为了安全性，后续关闭所有节点密码登录

```sh
# 如果本地没有 ssh 密钥，则生成
ssh-keygen -t ecdsa

# ssh-copy 设置无密码登录所有节点
pdsh -w ^all -R exec ssh-copy-id %h
```

### 设置节点统一 interface 名称

> * 后续一些服务依赖一致的 interface 名称
> * 某些环境 interface 名称已统一，可以跳过

一般物理机上 interface 名称需要根据实际情况进行修改统一名称，下面是一个示例

```sh
cat << 'EOF' /etc/netplan/00-installer-config.yaml
network:
  ethernets:
    eth0:
      addresses:
      - 10.128.0.1/16
      routes:
      - to: default
        via: 10.128.255.254
      nameservers:
        addresses:
        - 119.29.29.29
        - 223.5.5.5
        - 223.6.6.6
      match:
        macaddress: fa:16:3e:f1:c3:fd
      set-name: eth0
EOF

netplan apply
```

```bash
# 检查网络配置
pdsh -w ^all ip r
# 检查 dns 配置
pdsh -w ^all resolvectl dns
```

### 设置节点名称

```sh
# 设置节点名称
hostnamectl set-hostname bj1mn01
hostnamectl set-hostname bj1mn02
...
```

### 设置时间同步和时区

```sh
pdsh -w ^all sed -i 's/^#NTP=/NTP=ntp.aliyun.com/g' /etc/systemd/timesyncd.conf
pdsh -w ^all systemctl restart systemd-timesyncd
pdsh -w ^all timedatectl timesync-status

pdsh -w ^all timedatectl set-timezone Asia/Shanghai
```

> 也可以根据需要自行搭建 ntp server

### 设置 apt 镜像

```sh
pdsh -w ^all sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
pdsh -w ^all sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
pdsh -w ^all sed -i 's/http:/https:/g' /etc/apt/sources.list
pdsh -w ^all apt update
```

如果需要使用代理，可以设置 apt 代理：

```bash
cat << 'EOF' > 80proxy
Acquire::http::Proxy "http://100.68.3.1:3128";
Acquire::https::Proxy "http://10.68.3.1:3128";
EOF

pdcp -w ^all 80proxy /etc/apt/apt.conf.d/80proxy
pdsh -w ^all apt update
```

### 设置防火墙

```sh
pdsh -w ^all ufw disable
```

### 关闭 swap

```sh
pdsh -w ^all swapoff -a
pdsh -w ^all cp /etc/fstab /etc/fstab.bak
pdsh -w ^all "sed -i 's/^\/swap/#&/' /etc/fstab"
```

### 开启 CPU 超线程

在 BIOS 中修改后重启，在系统执行 `lscpu` 检查是否为 `Thread(s) per core: 2`

### 开启 CPU Performance Mode

```sh
cat << 'EOF' > cpufrequtils
GOVERNOR="performance"
EOF
pdsh -w ^all apt install cpufrequtils -y
pdcp -w ^all cpufrequtils /etc/default
pdsh -w ^all systemctl restart cpufrequtils

# 查看当前 CPU 频率 (执行任意命令即可)
pdsh -w ^all 'apt install linux-tools-common linux-tools-`uname -r` -y'
turbostat --interval 1
```

如果节点间 `ping` 延迟大于 `0.1ms`， 则需要在 BIOS 中禁用 `SpeedStep` 和 `C1E` 模式

### 锁定内核版本，避免驱动失效

确保所有节点使用一致的内核版本后，再进行锁定

```bash
pdsh -w ^all apt update
pdsh -w ^all apt upgrade -y
pdsh -w ^all uname -r
```

```sh
cat << 'EOF' > nolinuxupgrades
Package: linux-*
Pin: version *
Pin-Priority: -1
EOF

pdcp -w ^all nolinuxupgrades /etc/apt/preferences.d/nolinuxupgrades
```

## 安全

### 关闭密码登录增强安全性

```sh
pdsh -w ^all "sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config.d/50-cloud-init.conf"
pdsh -w ^all systemctl reload ssh
```

### 设置防火墙

不同角色节点防火墙设置不同，需要根据实际情况进行设置

#### 存储节点

考虑到存储节点需要对外提供服务，需要禁止计算节点访问存储节点 22 端口.

所有存储节点需要执行下面步骤, 假如：
* 存储节点在网段：`100.68.16.0/20`
* 外部 VPN 所在 IP：`100.68.3.100`

```bash
# 缺省允许进入和出去
ufw reset
ufw default allow incoming
ufw default allow outgoing
ufw enable

# 查看
ufw status verbose

# 允许特定网络和 IP 访问 22 端口
ufw allow from 100.68.16.0/20 to any port 22
ufw allow from 100.68.3.100 to any port 22
# 禁止所有其他来源访问 22 端口
ufw deny 22

# 查看
ufw status verbose
```

## 基础测试

### 网络连通测试

首先使用 ping 测试节点间延迟，值必须小于 `0.1ms`

注意： 该部分测试中如果ping的延迟大于0.1ms需要注意是不是CPU降频造成的。

通常情况下AMD CPU开启了性能模式后就可以让CPU超过基础频率运行，而INTEL CPU还有深度睡眠模式C1E主要注意。

INTEL CPU的C1E深度睡眠模式在服务器上需要显式的关闭才能有效让处理器运行在基础频率之上。该部分需要再BIOS中设定。

使用i7z查看C1E是否已关闭

```bash
# apt install i7z -y
# i7z
```
执行完i7z命令后可以得到如下截图

![i7z](images/c1e-2.png)

入上图所示，如果C3、C6有数字变动证明INTEL服务器的CPU未关闭C1E仍处于节点模式。需要进入到BIOS中进行设置。

![BIOS C1E 设置](images/c1e.jpeg)

入上图所示，需要做如下调整：

1. Pstates 置为禁用状态。
1. CPU C6 置为禁用状态。
1. CPU C1E 置为禁用状态。
1. Package C State 选择C0C1

编辑好以后保存退出重启服务器，再次使用i7z命令确认C1E已关闭，确认ping操作延迟问题是否已解决。

### 网络性能测试


```sh
pdsh -w ^all apt install -y iperf

# 启动 iperf 服务
pdsh -w ^all iperf -i1 -s

# 打开另外终端
# 测试上行
pdsh -w 10.128.0.1 iperf -i1 -c 10.128.0.2 -P8
# 测试下行
pdsh -w 10.128.0.1 iperf -i1 -c 10.128.0.2 -P8 -R

# 依次测试两两节点间网络性能
```

### 磁盘性能测试

访问 [elbencho](https://github.com/breuner/elbencho/releases) 下载 elbencho 二进制文件

```sh
tar zxvf elbencho-static-x86_64.tar.gz
# 解压后将 elbencho 文件拷贝到 /usr/local/bin
pdcp -w ^all elbencho /usr/local/bin
pdsh -w ^all apt install -y nvme-cli sysstat

# 依次测试每个节点裸盘性能
# 获取所有 nvme 设备
nvme list
# 假如查询到 12 个设备, 则指定设备列表 /dev/nvme{0..11}n1
# 测试写, -t 48 指定线程数, 取值为设备数乘以 4
elbencho -w -b 4M -t 48 --direct -s 100g /dev/nvme{0..11}n1
# 测试读, 修改 -w 为 -r
elbencho -r -b 4M -t 48 --direct -s 100g /dev/nvme{0..11}n1

# 同时监控 io 性能是否满足设备官方性能标称（通常写比官方高，读略低于官方）
iostat -xm 1
```

通常情况下NVME盘写入速率为5G/s，如果测得的数据与该值相差很大需要确认是否存在PCIE掉速的情况。

```bash

# lspci -vvv |grep 'Non-Volatile'
5a:00.0 Non-Volatile memory controller: xxx Microelectronics Co., Ltd NVMe SSD Controller xxx (prog-if 02 [NVM Express])
...
其中第一列5a:00.0是该设备的PCIE地址。

# lspci -s 5a:00.0 -vvvxxx |grep 'Speed'
		LnkCap:	Port #0, Speed 16GT/s, Width x4, ASPM not supported
		LnkSta:	Speed 16GT/s (ok), Width x1 (downgraded)
		LnkCap2: Supported Link Speeds: 2.5-16GT/s, Crosslink+ Retimer+ 2Retimers+ DRS+
		LnkCtl2: Target Link Speed: 16GT/s, EnterCompliance- SpeedDis-
如果输出中出现了downgraded字样表示存在PCIE掉速的情况，执行下面步骤
# lspci -s 5a:00.0 -vvvxxx |grep 'Physical'
	Physical Slot: 114
	Capabilities: [198 v1] Physical Layer 16.0 GT/s <?>
记住Physical Slot:后面的数字，这里是114，这是该设备的物理槽位号。执行如下命令通知操作系统对此设备下电
# echo 0 >/sys/bus/pci/slots/114/power
把设备拔掉30秒后再重新插回原来的槽位确认是否正常，一次不行重复执行几次。
```
