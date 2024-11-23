# 部署单机 Redis

适用于只有一台机器需要部署 Redis 的情况。

对于 Redis HA 支持以及在 K8S 部署可以使用 [Kubeblocks](https://cn.kubeblocks.io/docs/preview/user-docs/overview/introduction)

对于数据一致性更高的场景，可以考虑使用 [TiKV](https://tikv.org/) 等分布式 KV 存储。

## 安装 Redis

```bash
mkdir redis
cd redis
mkdir data

cat << 'EOF' > start.sh
#!/bin/bash
set -x

docker rm -f redis
docker run \
	-d \
	--name redis \
	-e REDIS_PASSWORD=<Custom Password> \
	-p 6379:6379 \
	-v $PWD/data:/data \
	redis:7.4 \
		/bin/sh -c 'redis-server --save 60 1 --appendonly yes --requirepass ${REDIS_PASSWORD}'
EOF

chmod +x start.sh
./start.sh
```

> 修改 `<Custom Password>` 为自定义密码

## 连接 Redis

```bash
docker exec -it redis bash

redis-cli -h 127.0.0.1 -a <Custom Password>

ping
set hello world
get hello
keys *
```
