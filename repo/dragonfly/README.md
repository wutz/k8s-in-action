# Drangonfly Install

## add helm repo

```
helm repo add dragonfly https://dragonflyoss.github.io/helm-charts/
```
## Configuration
- 配置详情参考 `values.yaml`

### 创建 seed client secret (如果使用)

```bash
kubectl create secret generic seed-client-secret \
  --from-file=cr.example.com.pem=./cr.example.com.pem \
  -n dragonfly-system
```

### 创建 client secret （如果使用）

```bash
kubectl create secret generic client-secret \
  --from-file=cr.example.com.pem=./cr.example.com.pem \
  -n dragonfly-system
```

```bash
helm upgrade --install dragonfly dragonfly/dragonfly --version=1.2.19 -f values.yaml --namespace dragonfly-system --create-namespace
```

## Check that Dragonfly is deployed successfully:

```
$ kubectl get po -n dragonfly-system
NAME                                 READY   STATUS    RESTARTS      AGE
dragonfly-client-gvspg               1/1     Running   0             34m
dragonfly-client-kxrhh               1/1     Running   0             34m
dragonfly-manager-864774f54d-6t79l   1/1     Running   0             34m
dragonfly-mysql-0                    1/1     Running   0             34m
dragonfly-redis-master-0             1/1     Running   0             34m
dragonfly-redis-replicas-0           1/1     Running   0             34m
dragonfly-redis-replicas-1           1/1     Running   0             32m
dragonfly-redis-replicas-2           1/1     Running   0             32m
dragonfly-scheduler-0                1/1     Running   0             34m
dragonfly-seed-client-0              1/1     Running   5 (21m ago)   34m
```

## 访问 dragonfly web 控制台

```
kubectl port-forward svc/dragonfly-manager -n dragonfly-system 8080:8080
```
-  浏览器访问： http://localhost:8080

默认： root/dragonfly

## 登录 dragonfly-client 所在的宿主机节点 执行以下命令测试

`注意：` 前提是harbor仓库已经存储了 `library/nginx:latest`, 如果没有，请自行 `push` 一个测试镜像

```
critcl pull cr.example.com/library/nginx:latest
```

- 查看 `dragonfly-client` pod的日志如下所示：

```
  2024-10-21T02:03:02.899178248+00:00  INFO  download task started: Download { url: "http://cr.example.com/libray/nginx/blobs/sha256:55c7e777947803f80ca493164a5d16fd53fceca71c02caf9dcd1bedeaa1440bb", digest: None, range: None, r#type: Standard, tag: None, application: None, priority: Level6, filtered_query_params: ["X-Obs-Date", "X-Amz-User-Agent", "x-cos-security-token", "X-Amz-Algorithm", "X-Goog-Date", "OSSAccessKeyId", "X-Goog-Credential", "X-Amz-Credential", "SecurityToken", "X-Obs-Security-Token", "X-Amz-Expires", "X-Goog-Expires", "q-ak", "X-Goog-Algorithm", "X-Amz-Security-Token", "q-sign-time", "q-sign-algorithm", "q-url-param-list", "X-Goog-Signature", "q-header-list", "X-Goog-SignedHeaders", "Expires", "AccessKeyId", "X-Amz-SignedHeaders", "X-Amz-Signature", "X-Amz-Date", "Signature", "q-signature", "q-key-time"], request_header: {"user-agent": "containerd/v1.7.21-k3s2", "x-dragonfly-registry": "http://cr.example.com", "accept-encoding": "gzip", "accept": "application/vnd.docker.container.image.v1+json, */*"}, piece_length: None, output_path: None, timeout: None, disable_back_to_source: false, need_back_to_source: false, certificate_chain: [], prefetch: false, object_storage: None }
    at dragonfly-client/src/grpc/dfdaemon_download.rs:227
    in download_task with host_id: "10.192.0.22-gn016.hs5h.local", task_id: "2b1c2e3985ba1acc0c6b28007148985a03e4bb7973748ba9123ac17f56b17423", peer_id: "10.192.0.22-gn016.hs5h.local-80113ae5-f14f-44bf-b33f-1611e77748ac"
```