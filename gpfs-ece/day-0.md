# GPFS 纠删码版集群规划

## 简介

IBM Storage Scale Erasure Code Edition 以软件形式提供 IBM Storage Scale RAID。

IBM Storage Scale Erasure Code Edition 可以在一个集群中拥有一个或多个恢复组，并且每个存储服务器仅属于一个 RG。恢复组中的所有存储服务器必须具有匹配的配置，包括相同的 CPU、内存、网络和存储设备配置。存储设备 (pdisk) 直接连接到仅一个存储服务器。

IBM Storage Scale Erasure Code Edition 支持以下纠删码和复制级别：16+2P、16+3P、8+2p、8+3p、4+2p、4+3p、3WayReplication 和 4WayReplication。

一个 IBM Storage Scale 集群中最多可以有 256 个 IBM Storage Scale Erasure Code Edition 存储节点。

## 硬件需求

* 最低硬件需求和预检查
    * 单路或双路 Intel 或 AMD x86_64 位处理器，总共有 16 个或更多处理器内核
    * 对于每个节点最多 64 个驱动器的配置，需要 64 GB 或更多内存
    * 每个机柜放置一个服务器
    * [支持的操作系统和软件版本](https://www.ibm.com/docs/en/storage-scale?topic=STXKQY/gpfsclustersfaq.html#fsi)
    * 每个存储节点最多支持 64 个驱动器
    * 每个恢复组支持最少 3 个，最多 32 个节点
    * 每个集群最多支持 256 个 IBM Storage Scale Erasure Code Edition 存储节点
    * 每个服务器的系统磁盘都需要一个物理驱动器。存储应受到 RAID1 保护，容量应为 100GB 或更多
    * 每个服务器中至少需要一个 SSD 或 NVMe 驱动器用于 IBM Storage Scale Erasure Code Edition 日志记录
    * 存储节点之间 25 Gbps 或更高。 根据您的工作负载需求，可能需要更高的带宽
* 硬件清单
    * 所有由 IBM Storage Scale Erasure Code Edition 管理的驱动器都必须禁用其易失性写入缓存
* 网络需求和预检
* 磁盘需求和预检查
    * IBM Storage Scale 支持 NVMe、SSD 和 HDD 类型的磁盘

## 纠删码选择规划

* [数据保护和存储利用率](https://www.ibm.com/docs/en/storage-scale-ece/5.2.2?topic=selection-data-protection-storage-utilization)
* [RAID 重建和备用空间](https://www.ibm.com/docs/en/storage-scale-ece/5.2.2?topic=selection-raid-rebuild-spare-space)
* 恢复组中的节点
* [推荐](https://www.ibm.com/docs/en/storage-scale-ece/5.2.2?topic=selection-recommendations)
    * 3 节点：3WayReplication
    * 4-5 节点：4+3P / 3WayReplication
    * 6-9 节点：8+3P / 4+2P / 4+3P
    * 10+ 节点：8+2P / 8+3P / 4+2P / 4+3P

## 规划节点角色

* 恢复组主节点
* 仲裁节点
    * IBM Storage Scale 使用一种称为仲裁的集群机制，以便在节点发生故障时保持数据一致性。
    * 法定人数基于简单的多数规则运作
    * 如果未保持法定人数，那么 IBM Storage Scale 文件系统将在整个集群中卸载，直到重新建立法定人数为止，此时会发生文件系统恢复
    * IBM Storage Scale 可以使用以下两种方法之一来确定仲裁
        * 节点仲裁: 节点法定数是 IBM Storage Scale 的缺省法定数算法。通常使用 3、**5** 或 7 个节点
        * 使用仲裁盘的节点仲裁: 仲裁磁盘可用于共享存储配置，以保持仲裁
* 管理节点
    * 对于每个文件系统，都会指定一个管理器节点作为文件系统管理器。此节点负责提供某些任务，例如文件系统配置更改、配额管理和可用空间管理
    * 管理器节点还负责整个集群中的令牌管理。令牌用于在集群中打开文件时维护锁定和一致性。
* CES 节点：集群导出服务 (CES) 用于提供对 IBM Storage Scale 文件系统中数据的 SMB、NFS 或对象访问
    * 对于具有高性能要求的环境，需要单独的 CES 节点。在这些环境中，建议 CES 节点除了导出服务之外不运行其他工作负载。
    * 最后，用于通过 CES 协议访问节点的网络必须在与用于 IBM Storage Scale Erasure Code Edition 流量的网络不同的物理适配器和网络上运行。
    * NSD 服务器节点

## 规划恢复组空间和横向扩展

将新磁盘添加到恢复组的去集群化阵列 DA 时，请确保满足以下要求:
* 插入到服务器空插槽中以扩展分散阵列空间的新磁盘，必须与 DA 中现有磁盘的类型相同
* 恢复组中的所有节点必须具有相同数量的 DA 添加的新磁盘
* 可能会同时将新磁盘添加到多个 DA 
* 建议添加与 DA 中现有磁盘数量相同的磁盘，以使 DA 空间加倍