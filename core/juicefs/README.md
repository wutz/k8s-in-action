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
    * Redis 适合文件数量在 1 亿以下，数据一致性要求不高场景
        * [单机版本 Redis](../redis/README.md)
        * Redis HA (待补充)
    * TiKV 适合文件数量在 100 亿，数据一致性要求高场景生产环境
        * [部署 TiKV 集群](../tikv/README.md)
* 对象存储
    * [Ceph RADOS](../cephadm/2-ceph-rados.md)

## 安装

1. 安装 JuiceFS CSI

    ```bash
    helmwave up --build
    ```
2. 可以在一个集群中部署多个 JuiceFS，下面分别演示元数据是 Redis 和 TiKV 的场景

    * 创建名字为 `juicefs-dev` 的 JuiceFS 使用 Redis 作为元数据用于开发场景
        * 修改元数据连接信息: 修改文件 [juicefs-dev/secret.yaml](juicefs-dev/secret.yaml) 中的 `metaurl` 为实际值
        * 修改对象存储连接信息
        * 放置 ceph 配置文件到 [juicefs-dev/ceph](juicefs-dev/ceph) 中
        * 如果提供的 ceph 配置不是 `ceph.client.juicefs-dev.keyring` 则需要修改 [kustomization.yaml](juicefs-dev/kustomization.yaml) 中的实际文件名称，以及 [juicefs-dev/secret.yaml](juicefs-dev/secret.yaml) 中的 `secret-key` 为实际值
        * 最后修改 [juicefs-dev/secret.yaml](juicefs-dev/secret.yaml) 中的 `bucket` 值，其值为 ceph pool 名称

        ```bash
        部署执行
        kubectl apply -k juicefs-dev

        验证
        kubectl apply -f tests.yaml
        ```

    * 创建名字为 `juicefs-prd` 的 JuiceFS 使用 TiKV 作为元数据用于生产场景
        * 修改元数据连接信息: 修改文件 [juicefs-prd/secret.yaml](juicefs-prd/secret.yaml) 中的 `metaurl` 为实际值
        * 修改对象存储连接信息
        * 放置 ceph 配置文件到 [juicefs-prd/ceph](juicefs-prd/ceph) 中
        * 如果提供的 ceph 配置不是 `ceph.client.juicefs-prd.keyring` 则需要修改 [kustomization.yaml](juicefs-prd/kustomization.yaml) 中的实际文件名称，以及 [juicefs-prd/secret.yaml](juicefs-prd/secret.yaml) 中的 `secret-key` 为实际值
        * 最后修改 [juicefs-prd/secret.yaml](juicefs-prd/secret.yaml) 中的 `bucket` 值，其值为 ceph pool 名称
        * 使用 TiKV 场景 JuiceFS CSI 存在[问题](https://github.com/juicedata/juicefs-csi-driver/issues/443#issuecomment-2323272940), 请按照问题 workaround 进行操作

        ```bash
        # 部署执行
        kubectl apply -k juicefs-prd

        # 验证
        kubectl apply -f tests.yaml
        ``` 


# 性能测试

```bash
#!/usr/bin/env bash

TESTDIR=/jfs/testdir
ELBENCHO=/usr/local/bin/elbencho
RESFILE=fs.log
DIRS=1
FILES=128
THREADS_LIST="1 4 16 64"
SIZES_LIST="4k 128k 4m 1g"
HOSTS_LIST="gn001 gn[001-004] gn[001-016]"
USER=root

FIRST_HOST=$(echo $HOSTS_LIST | awk '{print $1}')
LAST_HOST=$(echo $HOSTS_LIST | awk '{print $NF}')
LAST_THREAD=$(echo $THREADS_LIST | awk '{print $NF}')
LAST_SIZE=$(echo $SIZES_LIST | awk '{print $NF}')

mkdir -p $TESTDIR
pdsh -w $USER@$LAST_HOST $ELBENCHO --service

for host in $HOSTS_LIST; do
    if [ "$host" == "$FIRST_HOST" ]; then
        thread_list=$THREADS_LIST
    else
        thread_list=$LAST_THREAD
    fi

    for threads in $thread_list; do
        for size in $SIZES_LIST; do
            if [[ "$size" == "$LAST_SIZE" ]]; then
                files=1
            else
                files=$FILES
            fi

            # write
            $ELBENCHO --hosts $host --direct -w -d -t $threads -n $DIRS -N $files -s $size --resfile $RESFILE $TESTDIR
            # read
            $ELBENCHO --hosts $host --direct -r -t $threads -n $DIRS -N $files -s $size --resfile $RESFILE $TESTDIR
            # re-read
            $ELBENCHO --hosts $host --direct -r -t $threads -n $DIRS -N $files -s $size --resfile $RESFILE $TESTDIR
            # delete
            $ELBENCHO --hosts $host -F -D -t $threads -n $DIRS -N $files $TESTDIR
        done
    done 
done

$ELBENCHO --hosts $USER@$LAST_HOST --quit
```