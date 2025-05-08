##

loki + promtail

## 部署

### loki

loki 的部署具有多个模式：
- single-binary：单进程模式，所有的功能模块均部署到单一进程中，可以多实例部署（需要对象存储支持）
- simple-scalable：简易扩展模式，功能分为三类：read，write，backend，可以单独扩展，需要对象存储支持
- distributed：全分布式模式，每个功能模块均以独立的进程部署，可以单独扩展，需要对象存储支持

> 注意：只有 single-binary 模式且 replica 为 1 时，支持使用 filesystem 作为存储后端，其它的模式均需要使用对象存储(如 s3, gcs, azure 等)

```shell


# 单独编译 loki manifests
KUBECONFIG=~/.kube/... ENV=prod helmwave build --tags loki --yml

# 单独编译 promtail manifests
KUBECONFIG=~/.kube/... ENV=prod helmwave build --tags promtail --yml

# 编译 所有 manifests
KUBECONFIG=~/.kube/... ENV=prod helmwave build --yml


# 单独提交 loki manifests
KUBECONFIG=~/.kube/... ENV=prod helmwave up --tags loki

# 单独提交 promtail manifests
KUBECONFIG=~/.kube/... ENV=prod helmwave up --tags promtail

# 提交 所有已编译的 manifests
KUBECONFIG=~/.kube/... ENV=prod helmwave up
```
