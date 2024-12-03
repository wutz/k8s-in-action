# 部署 Ceph RGW 对象存储

## 创建 Pool

```bash
ceph osd pool create .rgw.root crush_rule rep_ssd
ceph osd pool create default.rgw.log crush_rule rep_ssd
ceph osd pool create default.rgw.control crush_rule rep_ssd
ceph osd pool create default.rgw.meta crush_rule rep_ssd
ceph osd pool create default.rgw.buckets.index crush_rule rep_ssd
ceph osd_pool create default.rgw.buckets.no_ec crush_rule rep_hdd

# 可以根据实际硬件配置调整数据池的 crush rule
ceph osd pool create default.rgw.buckets.data erasure ec42_hdd
```

## 部署 RGW

```yaml
# 创建文件 rgw.yaml
service_type: rgw
service_id: default
placement:
  host_pattern: ceph*
  count_per_host: 2
networks:
  - 172.19.12.0/24
spec:
  rgw_frontend_port: 8000
```

* 由于设置实例数为 2， 这将占用系统端口 8000-8001

```bash
# 部署 RGW 服务 
ceph orch apply -i rgw.yaml

ceph orch ls
# 查询 RGW 进程
ceph orch ps --daemon_type rgw
```

## 部署 Ingress

缺省 RGW 服务只监听在每个节点上，不提供负载均衡服务，故而需要部署 Ingress 服务

```yaml
# 创建文件 ingress.yaml
service_type: ingress
service_id: rgw.default
placement:
  host_pattern: ceph*
spec:
  backend_service: rgw.default
  virtual_ips_list:
  - 172.19.12.101/24
  - 172.19.12.102/24
  - 172.19.12.103/24
  frontend_port: 80
  monitor_port: 1967
```

* 其中 vip 列表从管理员获取 

```bash
# 部署 Ingress 服务
ceph orch apply -i ingress.yaml

ceph orch ls
# 查询 Ingress 进程
ceph orch ps --daemon_type ingress
```

配置 DNS 解析（可选）：
* 配置 s3.example.com 节点到 172.19.12.[101-103] 的 A 记录

## 创建用户

```bash
radosgw-admin user create --uid=wutz --display-name="Taizeng Wu"
radosgw-admin user info --uid=wutz
radosgw-admin user rm --uid=wutz
```

## 性能测试

### warp

访问 [minio/warp](https://github.com/minio/warp/releases) 下载 warp 命令

```bash
warp mixed \
        --host=s3.example.com \
        --access-key=xxx \
        --secret-key=xxxxxx \
        --bucket=benchmark \
        --concurrent 100 \
        --objects 100000 \
        --obj.size 1MiB \
        --get-distrib 50 \
        --stat-distrib 0 \
        --put-distrib 50 \
        --delete-distrib 0 \
        --duration 1m 
```

* 如果使用 https 则加上参数 `--tls`

### elbencho

访问 [elbencho](https://github.com/breuner/elbencho/releases) 下载工具

```bash
#!/usr/bin/env bash

S3SERVER=http://s3.example.com
S3KEY=xxx
S3SECRET=xxxxxx
S3BUCKET=benchmark
ELBENCHO=/usr/local/bin/elbencho
FILES=4096
RESFILE=s3.log

HOSTS=$(echo ceph01 |tr ' ' ,)
#HOSTS=$(echo ceph0{1..2} |tr ' ' ,)
#HOSTS=$(echo ceph0{1..3} |tr ' ' ,)

echo $HOSTS |tr , '\n' |xargs -I{} ssh {} $ELBENCHO --service
sleep 3

set -x

for T in {1,4,16,64}; do
#for T in 64; do

        N=$(($FILES/$T))

        # Create bucket "S3BUCKET" for big object size
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -d $S3BUCKET

        # Test T threads, each creating 1 directories with N 4MiB objects inside
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -w -t $T -n 1 -N $N -s 4m -b 4m --resfile $RESFILE $S3BUCKET

        # Test T threads, each reading 1 directories with N 4MiB objects inside
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -r -t $T -n 1 -N $N -s 4m -b 4m --resfile $RESFILE $S3BUCKET

        # Delete objects and bucket created by above
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -D -F -t $T -n 1 -N $N $S3BUCKET

        #-------

        # Create bucket "S3BUCKET" for small object size
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -d $S3BUCKET

        # Test T threads, each creating 4 directories with N 4KiB objects inside
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -w -t $T -n 4 -N $N -s 4k -b 4k --resfile $RESFILE $S3BUCKET

        # Test T threads, each reading 4 directories with N 4KiB objects inside
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -r -t $T -n 4 -N $N -s 4k -b 4k --resfile $RESFILE $S3BUCKET

        # Delete objects and bucket created by above
        $ELBENCHO --hosts $HOSTS --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                -D -F -t $T -n 4 -N $N $S3BUCKET

done

$ELBENCHO --hosts $HOSTS --quit
```