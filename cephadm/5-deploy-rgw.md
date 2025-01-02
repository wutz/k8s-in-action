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
  - 10.128.0.0/16
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
ceph orch ps --service_name rgw.default

# 将 RGW 的控制池设置为 SSD 副本
ceph osd pool set .rgw.root crush_rule rep_ssd
ceph osd pool set default.rgw.log crush_rule rep_ssd
ceph osd pool set default.rgw.control crush_rule rep_ssd
ceph osd pool set default.rgw.meta crush_rule rep_ssd
```

## 部署 Ingress

缺省 RGW 服务只监听在每个节点上，不提供负载均衡服务，故而需要部署 Ingress 服务

以下方式二选一

* 仅支持 http 部署

  ```yaml
  # 创建文件 ingress.yaml
  service_type: ingress
  service_id: rgw.default
  placement:
    host_pattern: sn*
  spec:
    backend_service: rgw.default
    virtual_ips_list:
    - 10.128.0.151/16
    - 10.128.0.152/16
    - 10.128.0.153/16
    - 10.128.0.154/16
    first_virtual_router_id: 150
    frontend_port: 80
    monitor_port: 1967
  ```
  > 其中 vip 列表从管理员获取, 为了最大化负载均衡效果，一般与节点数量一致

* 仅支持 https 部署

  如果需要使用 https 则需要配置 ssl_cert 和 frontend_port 为 443

  ```yaml
  service_type: ingress
  service_id: rgw.default
  placement:
    host_pattern: sn*
  spec:
    backend_service: rgw.default
    virtual_ips_list:
    - 10.128.0.151/16
    - 10.128.0.152/16
    - 10.128.0.153/16
    - 10.128.0.154/16
    first_virtual_router_id: 150
    frontend_port: 443
    monitor_port: 1967
    ssl_cert: |                         
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
  ```

  如果证书即将过期，执行以下步骤更新证书：

  ```bash
  # 1. 更新 ingress.yaml 的 ssl_cert

  # 2. 应用 ingress.yaml
  ceph orch apply -i ingress.yaml

  # 3. 重新部署 ingress
  ceph orch redeploy ingress.rgw.default
  ```

```bash
# 部署 Ingress 服务
ceph orch apply -i ingress.yaml

ceph orch ls
# 查询 Ingress 进程
ceph orch ps --service_name ingress.rgw.default
```

配置 DNS 解析（可选）：
* 配置 s3.example.com 节点到 10.128.0.[151-154] 的 A 记录

## 配置分层存储 (可选)

如果对象存储存放大量小对象，缺省数据池使用 HDD 纠删码，这会带来空间放大和性能下降问题。

可以通过为不同对象大小选择不同的存储池来解决这个问题。
* 小于 16K 对象，存放在副本池 SSD 上 (由于 SSD 空间可能有限，需根据可用 SSD 空间调整这个大小)
* 16K - 1M 对象，存放在副本池 HDD 上 
* 大于等于 1M 对象，存放在缺省纠删码 HDD 上

```bash
# 创建大对象类 StorageClass
radosgw-admin zonegroup placement add \
    --rgw-zonegroup default \
    --placement-id default-placement \
    --storage-class LARGE_OBJ
# 创建中等对象类 StorageClass
radosgw-admin zonegroup placement add \
    --rgw-zonegroup default \
    --placement-id default-placement \
    --storage-class MEDIUM_OBJ

# 将数据池分配给不同的 StorageClass
radosgw-admin zone placement add \
	--rgw-zone default \
	--placement-id default-placement \
	--storage-class LARGE_OBJ \
	--data-pool default.rgw.buckets.data
radosgw-admin zone placement add \
	--rgw-zone default \
	--placement-id default-placement \
	--storage-class MEDIUM_OBJ \
	--data-pool default.rgw.buckets.mediumobj
radosgw-admin zone placement modify \
	--rgw-zone default \
	--placement-id default-placement \
	--storage-class STANDARD \
	--data-pool default.rgw.buckets.smallobj

# 创建小对象池使用 SSD 副本
ceph osd pool create default.rgw.buckets.smallobj rep_ssd 
ceph osd pool application enable default.rgw.buckets.smallobj rgw
ceph osd pool set default.rgw.buckets.smallobj target_size_ratio 0.7

# 创建中对象池使用 HDD 副本
ceph osd pool create default.rgw.buckets.mediumobj rep_hdd 
ceph osd pool application enable default.rgw.buckets.mediumobj rgw
ceph osd pool set default.rgw.buckets.mediumobj target_size_ratio 0.3
ceph osd pool set default.rgw.buckets.data target_size_ratio 0.7

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
  if Request.ContentLength < 8192 then
    Request.HTTP.StorageClass = "STANDARD"
  elseif Request.ContentLength < 1048576 then
    Request.HTTP.StorageClass = "MEDIUM_OBJ"
  else
    Request.HTTP.StorageClass = "LARGE_OBJ"
  end
  RGWDebugLog("applied '" .. Request.HTTP.StorageClass .. "' to object '" .. Request.Object.Name .. "'")
end
EOF

# 将脚本应用于 RGW
radosgw-admin script put --infile=./s3.lua --context=preRequest
```

## 使用

### 创建用户

```bash
# 创建用户
radosgw-admin user create --uid=wutz --display-name="Taizeng Wu"

# 查询用户
radosgw-admin user info --uid=wutz

# 删除用户
radosgw-admin user rm --uid=wutz
```

### 设置 quota

```bash
# 按照用户设置 quota
# --max-size 单位可以使用 B/K/M/G/T
radosgw-admin quota set --uid=wutz --quota-scope=user --max-size=10G --max-objects=10240
radosgw-admin quota enable --quota-scope=user --uid=wutz

# 查询 quota
radosgw-admin user info --uid=wutz
# 查询用户使用情况
radosgw-admin user stats --uid=wutz
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
RESFILE=s3.log
DIRS=1
FILES=128
THREADS_LIST="1 4 16 64"
SIZE_LIST="4k 128k 4m 1g"
HOSTS_LIST="gn001 gn[001-004] gn[001-016]"
USER=root

FIRST_HOST=$(echo $HOSTS_LIST | awk '{print $1}')
LAST_HOST=$(echo $HOSTS_LIST | awk '{print $NF}')
LAST_THREAD=$(echo $THREADS_LIST | awk '{print $NF}')
LAST_SIZE=$(echo $SIZE_LIST | awk '{print $NF}')

pdsh -w $USER@$LAST_HOST $ELBENCHO --service

for host in $HOSTS_LIST; do
    if [ "$host" == "$FIRST_HOST" ]; then
        thread_list=$THREADS_LIST
    else
        thread_list=$LAST_THREAD
    fi

    for threads in $thread_list; do
        for size in $SIZE_LIST; do
            if [[ "$size" == "$LAST_SIZE" ]]; then
                files=1
            else
                files=$FILES
            fi

            # Create bucket
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -d $S3BUCKET
            # Write
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -w -t $threads -n $DIRS -N $files -s $size -b $size --resfile $RESFILE $S3BUCKET
            # Read
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -r -t $threads -n $DIRS -N $files -s $size -b $size --resfile $RESFILE $S3BUCKET
            # Delete
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -D -F -t $threads -n $DIRS -N $files $S3BUCKET
        done
    done
done

$ELBENCHO --hosts $USER@$HOSTS --quit
```

# 其它

## 调整同时最大 backfills 数

主要用于提升恢复速度

调大 backfills 可能影响业务请求性能，通常只适合配置 NVMe SSD 的集群

```bash
# 设置 osd 的最大回填数
ceph config set osd osd_max_backfills 4
# v18 及以上版本
ceph config set osd osd_mclock_override_recovery_settings true
```