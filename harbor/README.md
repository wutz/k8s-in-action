# Harbor Install

## Prerequisites
Kubernetes cluster 1.10+
Helm 2.8.0+
High available ingress controller (Harbor does not manage the external endpoint)
High available PostgreSQL (Harbor does not handle the deployment of HA of database)
High available Redis (Harbor does not handle the deployment of HA of Redis)
PVC that can be shared across nodes or external object storage

## add helm repo

```bash
helm repo add harbor https://helm.goharbor.io
```

## Configuration


### 网络

- 配置使用 ingress


```yaml
expose:
  type: ingress
  ingress:
    hosts:
      core: harbor.example.com  
```

- 配置 `externalURL`

```yaml
externalURL: https://harbor.example.com
```

- 配置 tls （如果使用）

```yaml
expose:
  tls:
  enabled: true
  secret:
      secretName: "harbor-tls-secret"
```

- 创建 `harbor-tls-secret` secret

```bash

```bash
kubectl create secret tls harbor-tls-secret \
  --cert=harbor.example.com.pem \
  --key=harbor.example.com.key \
  -n harbor-system
```

### 存储

- 配置存储类型 `shared-juice` 及 registry size `20Ti` jobservice size `100Gi`

```yaml
persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      existingClaim: ""
      storageClass: "shared-juice"
      subPath: ""
      accessMode: ReadWriteOnce
      size: 20Ti
      annotations: {}
    jobservice:
      jobLog:
        existingClaim: ""
        storageClass: "shared-juice"
        subPath: ""
        accessMode: ReadWriteOnce
        size: 100Gi
        annotations: {}
```

### 配置 harbor web `admin` 密码

- admin/xxxxxxxxxxxxxx

```yaml
harborAdminPassword: "xxxxxxxxxxxxxxx"
```


### 数据库

- 配置外部 postgres 连接信息 （如果使用）
```yaml
database:
  # if external database is used, set "type" to "external"
  # and fill the connection information in "external" section
  type: external
  external:
    host: "pgm-z87um9hgrsktkiev6.pg.rds.hs5b-int.paratera.com"
    port: "5432"
    username: "habor"
    password: "xxxxxxxxxxxxxxx"
    coreDatabase: "registry"
    # if using existing secret, the key must be "password"
    existingSecret: ""
    # "disable" - No SSL
    # "require" - Always SSL (skip verification)
    # "verify-ca" - Always SSL (verify that the certificate presented by the
    # server was signed by a trusted CA)
    # "verify-full" - Always SSL (verify that the certification presented by the
    # server was signed by a trusted CA and the server host name matches the one
    # in the certificate)
    sslmode: "disable"
  # The maximum number of connections in the idle connection pool per pod (core+exporter).
  # If it <=0, no idle connections are retained.
  maxIdleConns: 100
  # The maximum number of open connections to the database per pod (core+exporter).
  # If it <= 0, then there is no limit on the number of open connections.
  # Note: the default number of connections is 1024 for harbor's postgres.
  maxOpenConns: 900
  ## Additional deployment annotations
  podAnnotations: {}
  ## Additional deployment labels
  podLabels: {}  
```
  
- 配置外部 redis 连接信息 （如果使用）
```yaml
redis:
  # if external Redis is used, set "type" to "external"
  # and fill the connection information in "external" section
  type: external
  external:
    # support redis, redis+sentinel
    # addr for redis: <host_redis>:<port_redis>
    # addr for redis+sentinel: <host_sentinel1>:<port_sentinel1>,<host_sentinel2>:<port_sentinel2>,<host_sentinel3>:<port_sentinel3>
    addr: "r-uvnz4dxcdnmzwshc2.redis.rds.hs5b-int.paratera.com:6379"
    # The "coreDatabaseIndex" must be "0" as the library Harbor
    # used doesn't support configuring it
    # harborDatabaseIndex defaults to "0", but it can be configured to "6", this config is optional
    # cacheLayerDatabaseIndex defaults to "0", but it can be configured to "7", this config is optional
    coreDatabaseIndex: "1"
    jobserviceDatabaseIndex: "1"
    registryDatabaseIndex: "2"
    trivyAdapterIndex: "5"
    # harborDatabaseIndex: "6"
    # cacheLayerDatabaseIndex: "7"
    # username field can be an empty string, and it will be authenticated against the default user
    username: "harbor"
    password: "xxxxxxxxxxxxxxx"
```

## 部署

```bash
helm upgrade --install harbor harbor/harbor -f values.yaml --namespace harbor-system --create-namespace
```


## 卸载

```
helm uninstall harbor -n harbor-system
```
