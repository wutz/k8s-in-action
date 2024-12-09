# 部署 Ceph RGW 对象存储

## 创建 Pool

```bash
# 创建索引池
ceph osd pool create default.rgw.buckets.index rep_ssd
ceph osd pool application enable default.rgw.buckets.index rgw

# 创建数据池
ceph osd pool create default.rgw.buckets.data erasure ec42_hdd --bulk
ceph osd pool application enable default.rgw.buckets.data rgw

# 创建用于存放分段上传的文件数据池
ceph osd pool create default.rgw.buckets.non-ec rep_hdd
ceph osd pool application enable default.rgw.buckets.non-ec rgw
```

## 部署 RGW

```yaml
# 创建文件 rgw.yaml
service_type: rgw
service_id: default
placement:
  host_pattern: sn*
  count_per_host: 2
networks:
  - 172.19.12.0/24
spec:
  rgw_frontend_port: 8000
```

* 由于设置实例数为 2， 这将占用系统端口 8000-8001
* networks 设置对外提供服务的网络，一般与 Public 网络一致

```bash
# 部署 RGW 服务 
ceph orch apply -i rgw.yaml

ceph orch ls
# 查询 RGW 进程
ceph orch ps --daemon_type rgw

# 将 RGW 的控制池设置为 SSD 副本
ceph osd pool set .rgw.root crush_rule rep_ssd
ceph osd pool set default.rgw.log crush_rule rep_ssd
ceph osd pool set default.rgw.control crush_rule rep_ssd
ceph osd pool set default.rgw.meta crush_rule rep_ssd
```

## 部署 Ingress

缺省 RGW 服务只监听在每个节点上，不提供负载均衡服务，故而需要部署 Ingress 服务

```yaml
# 创建文件 ingress.yaml
service_type: ingress
service_id: rgw.default
placement:
  host_pattern: sn*
spec:
  backend_service: rgw.default
  virtual_ips_list:
  - 172.19.12.101/24
  - 172.19.12.102/24
  - 172.19.12.103/24
  - 172.19.12.104/24
  frontend_port: 80
  monitor_port: 1967
```

* vip 与 networks 设置一致
* 其中 vip 列表从管理员获取, 为了最大化负载均衡效果，一般与节点数量一致

```bash
# 部署 Ingress 服务
ceph orch apply -i ingress.yaml

ceph orch ls
# 查询 Ingress 进程
ceph orch ps --daemon_type ingress
```

配置 DNS 解析（可选）：
* 配置 s3.example.com 节点到 172.19.12.[101-104] 的 A 记录

## 配置分层存储 (可选)

如果对象存储存放大量小对象，缺省数据池使用 HDD 纠删码，这会带来空间放大和性能下降问题。

可以通过为不同对象大小选择不同的存储池来解决这个问题。
* 小于 16K 对象，存放在副本池 SSD 上 (由于 SSD 空间可能有限，需根据可用 SSD 空间调整这个大小)
* 16K - 1M 对象，存放在副本池 HDD 上 
* 大于等于 1M 对象，存放在缺省纠删码 HDD 上

```bash
# 创建小对象类 StorageClass
radosgw-admin zonegroup placement add \
    --rgw-zonegroup default \
    --placement-id default-placement \
    --storage-class SMALL_OBJ
# 创建中等对象类 StorageClass
radosgw-admin zonegroup placement add \
    --rgw-zonegroup default \
    --placement-id default-placement \
    --storage-class MEDIUM_OBJ

# 将数据池分配给不同的 StorageClass
radosgw-admin zone placement add \
	--rgw-zone default \
	--placement-id default-placement \
	--storage-class SMALL_OBJ \
	--data-pool default.rgw.buckets.data-rep-ssd
radosgw-admin zone placement add \
	--rgw-zone default \
	--placement-id default-placement \
	--storage-class MEDIUM_OBJ \
	--data-pool default.rgw.buckets.data-rep-hdd

# 创建数据池
ceph osd pool create default.rgw.buckets.data-rep-ssd rep_ssd 
ceph osd pool create default.rgw.buckets.data-rep-hdd rep_hdd 

# 重启 RGW
ceph orch restart rgw.default
```

```bash
# 创建 Lua 脚本
cat << 'EOF' > s3.lua
-- Lua script to auto-tier S3 object PUT requests

-- exit script quickly if it is not a PUT request
if Request == nil or Request.RGWOp ~= "put_obj"
then
  return
end

-- apply StorageClass only if user hasn't already assigned a storage-class
if Request.HTTP.StorageClass == nil or Request.HTTP.StorageClass == '' then
  if Request.ContentLength < 16384 then
    Request.HTTP.StorageClass = "SMALL_OBJ"
  elseif Request.ContentLength < 1048576 then
    Request.HTTP.StorageClass = "MEDIUM_OBJ"
  else
    Request.HTTP.StorageClass = "STANDARD"
  end
  RGWDebugLog("applied '" .. Request.HTTP.StorageClass .. "' to object '" .. Request.Object.Name .. "'")
end
EOF

# 将脚本应用于 RGW
radosgw-admin script put --infile=./s3.lua --context=preRequest
```

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