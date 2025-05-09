# 0 准备

### 管理工具 pdsh

> * 为了安全性，后续所有 ssh 访问均从本地发起

```sh
# Ubuntu
apt install pdsh -y
# macOS
brew install pdsh

# 生成 hosts 用于后续执行 pdsh / pdcp
cat << 'EOF' > all
bj1mn[01-03]
bj1gn[001-003]
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

如果节点间 `ping` 延迟大于 `0.1ms`， 则需要在 BIOS 中禁用 `SpeedStep` 和 `C1E` 模式

```sh
# 查看当前 CPU 频率 (执行任意命令即可)
pdsh -w ^all 'apt install linux-tools-common linux-tools-`uname -r` -y'
turbostat --interval 1
```

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

### 修复 `kubectl logs` 输出 `too many open files` 错误

```sh
cat << 'EOF' > 80-inotify.conf
fs.inotify.max_user_instances=1280
fs.inotify.max_user_watches=655360
EOF

pdcp -w ^all 80-inotify.conf /etc/sysctl.d
pdsh -w ^all sysctl --system
```

### 修复 `kubectl port-forward` 输出 `unable to do port forwarding: socat not found` 错误

```sh
pdsh -w ^all apt install -y socat


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

如果配置额外数据盘，访问 [elbencho](../core/elbencho/) 测试块存储性能