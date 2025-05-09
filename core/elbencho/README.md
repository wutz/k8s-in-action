# elbencho

elbencho 是由 BeeGFS 创始人开发的一款用于测试存储系统性能的工具。

elbencho 涵盖 fio, mdtest, ior 等测试工具功能，支持文件系统，对象存储 S3 和块存储性能测试。

访问 [elbencho](https://github.com/breuner/elbencho/releases) 下载工具

## 文件系统

### 大文件

主要评估文件系统的吞吐和 IOPS 性能，以符合业内标准指标

使用 [large.sh](large.sh) 脚本, 自定义共享文件系统的路径和测试客户端节点

### 多文件

主要评估文件系统大量小文件的读写性能，以符合 AI 训练数据集使用场景

使用 [multi.sh](multi.sh) 脚本, 自定义共享文件系统的路径和测试客户端节点

## 对象存储

使用 [s3.sh](s3.sh) 脚本, 自定义对象存储的 endpoint, access_key, secret_key 和测试客户端节点

除了使用 elbencho 测试对象存储性能，还可以使用 warp 测试对象存储性能:
* 访问 [minio/warp](https://github.com/minio/warp/releases) 下载 warp 命令
* 使用 [warp.sh](warp.sh) 脚本, 自定义对象存储的 endpoint, access_key, secret_key 和测试客户端节点

## 块设备

```sh
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
