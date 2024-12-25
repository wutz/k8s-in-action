# 0 准备

## 软件与硬件

![k8s-arch](images/k8s-arch.png)

### DC 数据中心命名

* 格式：<2位字母城市缩写><1位数字序号>
* 城市缩写：例如北京 bj, 上海 sh 和广州 gz 等
* 数字序号：同一城市下使用内网互联的数据中心，从数字 1 开始
* 示例：
  * bj1: 北京第一个机房内部生产集群
  * sh3: 上海第三个机房内部测试集群
  * gz2: 广州第二个机房用户集群

### DNS 命名

* 基础服务使用域名
  * 内网：`*.<DC>i.example.com`, 例如 `*.bj1i.example.com`
  * 外网：`*.<DC>.example.com`, 例如 `*.bj1.example.com`
* 计算集群中服务使用域名 
  * 内网：`*.<CLUSTER>.<DC>i.example.com`, 例如 `*.prod.bj1i.example.com`
  * 外网：`*.<CLUSTER>.<DC>.example.com`, 例如 `*.prod.bj1.example.com`

> * example.com 为示例域名，根据实际情况进行替换
> * i 是 internal 的缩写，表示内部服务

### 节点命名

* 格式：`<IP>.<DC>.local`
  * 短名称使用 IP 地址短横线分隔
  * 示例：`10-128-0-1.bj1.local`
* 节点角色
  * 控制节点 control-plane
    * 生产集群至少 3 节点满足 HA 需要，最大 7 节点
    * 测试集群至少 1 节点，可以与计算节点复用
  * 网络负载均衡节点 load-balancer
    * 生产集群至少 2 节点满足 HA 需要, 可复用管理节点
  * 存储节点 storage
    * 生产集群至少 3 节点满足 HA 需要, 推荐配置独立节点 (酌情复用管理节点)
    * 测试集群复用管理节点
  * 数据库节点 database
    * 生产集群至少 2 节点满足 HA 需要, 推荐配置独立节点 (酌情复用管理节点)
    * 测试集群复用管理节点
  * CPU 计算节点 cpu
  * GPU 计算节点 gpu

### 网络

- 所有节点至少 10Gb 以太内网互联
- 存储节点额外提供至少 10Gb 以太网互联进行数据复制，配置此网络可以极大提供存储性能
- 提供网络负载均衡节点至少 1Gb 接入互联网，如果不面向外部提供服务此网络可选。

> 可以根据具体业务和用户需求调整网络配置。

### 软件

- OS: ubuntu 22.04
- K8S: [k3s](https://k3s.io/) v1.31
- Ceph: [ceph](https://docs.ceph.com/en/latest/releases/) v18.2

> 更多需求可以参考 [k3s requirements](https://docs.k3s.io/zh/installation/requirements)

## 所有节点初始化

| 节点 | 角色 |
| --- | --- |
| 10-128-0-1.bj1.local | control-plane,load-balancer,database |
| 10-128-0-2.bj1.local | control-plane,load-balancer,database |
| 10-128-0-3.bj1.local | control-plane,load-balancer,database |
| 10-128-0-101.bj1.local | storage |
| 10-128-0-102.bj1.local | storage |
| 10-128-0-103.bj1.local | storage |
| 10-128-0-104.bj1.local | storage |
| 10-128-1-1.bj1.local | gpu |
| 10-128-1-2.bj1.local | gpu |
| 10-128-1-3.bj1.local | gpu |

### 管理工具 pdsh

> * 为了安全性，后续所有 ssh 访问均从本地发起

```sh
# Ubuntu
apt install pdsh -y
# macOS
brew install pdsh

# 生成 hosts 用于后续执行 pdsh / pdcp
cat << 'EOF' > all
root@10.128.0.[1-3,100-104]
root@10.128.1.[1-3]
EOF

# 设置 pdsh 远程 pdcp 路径
pdsh -w ^all apt install -y pdsh
export PDSH_REMOTE_PDCP_PATH=pdcp
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
pdsh -w ^all 'hostnamectl set-hostname $(ip -4 addr show eth0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}" | sed "s/\./-/g" | head -1).bj1.local'

# 设置登录显示长主机名
pdsh -w ^all sed -i 's/\\\\h/\\\\H/g' '~/.bashrc'
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
Acquire::http::Proxy "http://10.128.0.200:3128";
Acquire::https::Proxy "http://10.128.0.200:3128";
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

> 如果在 BIOS 中已经开启，可以跳过。开启此选项极大提升性能

```sh
cat << 'EOF' > cpufrequtils
GOVERNOR="performance"
EOF
pdsh -w ^all apt install cpufrequtils -y
pdcp -w ^all cpufrequtils /etc/default
pdsh -w ^all systemctl restart cpufrequtils

# 查看当前 CPU 频率 (执行任意命令即可)
pdsh -w ^all cpufreq-info
pdsh -w ^all grep MHz /proc/cpuinfo
pdsh -w ^all cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors
```

### 锁定内核版本，避免驱动失效

> 确保所有节点使用一致的内核版本后，再进行锁定

```sh
cat << 'EOF' > nolinuxupgrades
Package: linux-*
Pin: version *
Pin-Priority: -1
EOF
pdcp -w ^all nolinuxupgrades /etc/apt/preferences.d/nolinuxupgrades
```

### [必须]关闭密码登录增强安全性

```sh
pdsh -w ^all "sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config.d/50-cloud-init.conf"
pdsh -w ^all systemctl reload ssh
```

## 基础测试

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

