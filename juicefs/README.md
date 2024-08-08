# [部署 JuiceFS](https://juicefs.com/docs/zh/community/introduction/)

JuiceFS 是一个开源的分布式文件系统，支持多种对象存储后端。

使用 JuiceFS 的原因是可以在机械盘构建的对象存储上，再配合客户端缓存盘，实现高性能、低成本的存储解决方案。

JuiceFS 主要包含 3 种版本，分别是：

* JuiceFS 社区版: 开源版本免费使用，支持客户端缓存盘, 需要自己分别提供元数据和对象存储
* JuiceFS 云版本: 相比开源版本，在各个云厂商上有部署好的元数据存储提供，需要自己提供对象存储, 相比社区版支持分布式缓存（用于解决单节点缓存空间有限，以及缓存在其它计算节点上问题）
* JuiceFS 企业版: 可以部署在私有集群上，元数据服务由原厂提供, 对象存储需要自己提供, 相比社区版本支持分布式缓存

以下所有部署方式均是基于 JuiceFS 社区版本：

* 云上：元数据可以选择云厂商提供的 RDS 版本的 Redis，对象存储直接使用云厂商提供的版本即可
* 云下：
    * 元数据
        * 对于开发用途的使用[单机实例 Redis](../redis/README.md)，或者对数据一致性要求没有那么高使用 HA Redis
        * 对于数据一致性要求很高，元数据数量超过 2 亿以上使用 [TiKV](https://tikv.org/)
    * 对象存储
        * 社区上有小规模使用 MinIO, 规模稍大使用 SeaweedFS 案例
        * 在大规模成熟方案还有 Ceph, Ceph 提供 2 种方式
            * Ceph RGW 支持 S3 接口
            * Ceph RADOS 提供原生 Ceph 接口，相比 Ceph RGW 减少中间协议转发层开销以及负载均衡开销

以下部署方式使用方案：

* 元数据 (选择一个）：
    * Redis
        * [单机版本 Redis](../redis/README.md)
        * Redis HA (待补充)
    * TiKV (待补充)
* 对象存储
    * [Ceph RADOS](../cephadm/2-ceph-rados.md)

## 安装

1. 安装 JuiceFS CSI

    ```bash
    helmwave up --build
    ```

2. 创建名字为 `juicefs` 的 JuiceFS (可以创建多个不同的 JuiceFS)

    * 修改元数据连接信息: 修改文件 [juicefs/secret.yaml](juicefs/secret.yaml) 中的 `metaurl` 为实际值
    * 修改对象存储连接信息
        * 放置 ceph 配置文件到 [juicefs/ceph](juicefs/ceph) 中
        * 如果提供的 ceph 配置不是 `ceph.client.juicefs.keyring` 则需要修改 [kustomization.yaml](juicefs/kustomization.yaml) 中的实际文件名称，以及 [juicefs/secret.yaml](juicefs/secret.yaml) 中的 `secret-key` 为实际值
        * 最后修改 [juicefs/secret.yaml](juicefs/secret.yaml) 中的 `bucket` 值，其值为 ceph pool 名称

    部署执行

    ```bash
    kubectl apply -k juicefs
    ```

3. 验证

    ```bash
    kubectl apply -f tests.yaml
    ```


