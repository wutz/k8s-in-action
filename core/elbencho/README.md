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



