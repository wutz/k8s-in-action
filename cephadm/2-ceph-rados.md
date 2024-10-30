# 提供 Ceph RADOS 原生服务

依赖 [部署 Ceph 集群](1-deploy-ceph-cluster.md)

一般用于访问 Ceph RADOS 原生服务的客户端程序，下面以为 JuiceFS 提供 Ceph RADOS Pool 为例.

相比于 Ceph RGW (s3) 接口，Ceph RADOS 减少额外开销服务(RGW 实例)以及流量负载均衡问题。

* 创建 Pool `mypool`

    根据性能需求选择副本池或者纠删码池

    * 创建副本 Pool

        副本池适合高 IOPS 场景

        ```bash
        # 创建 pool
        ceph osd pool create mypool 32 32 rep_ssd --bulk
        # 设置 pool 用途
        ceph osd pool application enable mypool myapp

        # 查询 pool 信息
        ceph osd pool get mypool all
        # 设置此 pool 预估占用空间比例, 这将自带调整 PG 数量（上面初始值为 32), 更大 PG 有助于提高吞吐量
        ceph osd pool set mypool target_size_ratio 0.3
        # 查询各个 pool 实际分配 PG 数量
        ceph osd pool autoscale-status
        ```

    * 创建纠删码 Pool

        纠删码池适合吞吐型及高得盘率场景

        ```bash
        ceph osd erasure-code-profile set ec42_hdd k=4 m=2 crush-root=default crush-failure-domain=host crush-device-class=hdd
        ceph osd pool create mypool 32 32 erasure ec42_hdd --bulk
        ceph osd pool application enable mypool myapp
        ceph osd pool set mypool target_size_ratio 0.3
        ceph osd pool autoscale-status
        ```

* 创建 key 用于客户端访问此 pool

    ```bash
    ceph auth get-or-create client.mypool mon 'allow r' osd 'allow rw pool=mypool' |tee /etc/ceph/ceph.client.mypool.keyring
    chmod 0600 /etc/ceph/ceph.client.mypool.keyring
    ```

    最后提供 `/etc/ceph/ceph.conf` 和 `/etc/ceph/ceph.client.mypool.keyring` 给客户端使用
