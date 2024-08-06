# 提供 Ceph RADOS 原生服务

一般用于访问 Ceph RADOS 原生服务的客户端程序，下面以为 JuiceFS 提供 Ceph RADOS Pool 为例.

相比于 Ceph RGW (s3) 接口，Ceph RADOS 减少额外开销服务(RGW 实例)以及流量负载均衡问题。

* 创建 Pool `juicefs`

    ```bash
    # 创建 pool
    ceph osd pool create juicefs 128 128 rep_ssd --bulk
    # 设置为 2 副本。通常 SSD 设置 2 副本，HDD 设置 3 副本
    ceph osd pool set juicefs size 2
    # 设置 pool 用途
    ceph osd pool application enable juicefs juicefs

    # 查询 pool 信息
    ceph osd pool get juicefs all
    # 设置此 pool 预估占用空间比例, 这将自带调整 PG 数量（上面初始值为 128), 更大 PG 有助于提高吞吐量
    ceph osd pool set juicefs target_size_ratio 0.3
    # 查询各个 pool 实际分配 PG 数量
    ceph osd pool autoscale-status
    ```

* 创建 key 用于客户端访问此 pool

    ```bash
    ceph auth get-or-create client.juicefs mon 'allow r' osd 'allow rw pool=juicefs' |tee /etc/ceph/ceph.client.juicefs.keyring
    chmod 0600 /etc/ceph/ceph.client.juicefs.keyring
    ```

    最后提供 `/etc/ceph/ceph.conf` 和 `/etc/ceph/ceph.client.juicefs.keyring` 给客户端使用
