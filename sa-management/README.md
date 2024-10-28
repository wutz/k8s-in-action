# ServiceAccount + RBAC

以人员的角度，赋予人员集群的权限

## ServiceAccount

- 使用 `ServiceAccount` 和 `Secret` 认证
- 建议将控制人员权限相关的 `ServiceAccount` 和 `Secret` 统一放在一个 `namespace` 里管理，例如 `sa-management`

## RBAC

- 分为集群 RBAC 和命名空间 RBAC
- 通常建议赋予 `namespace` 的查看权限，便于使用插件 `kubectx`
- `Role` + `RoleBinding` 被创建在哪个 `namespace` ，则代表赋予在该 `namespace` 相关权限

## Role 和 ClusterRole 的使用

- 执行 `kubectl api-resources`

  ```
  NAME                               SHORTNAMES                          APIVERSION                                  NAMESPACED   KIND
  bindings                                                               v1                                          true         Binding
  configmaps                         cm                                  v1                                          true         ConfigMap
  events                             ev                                  v1                                          true         Event
  namespaces                         ns                                  v1                                          false        Namespace
  ```

- `namespaced` 资源通过 `Role` 控制权限，非 `namespaced` 资源使用 `ClusterRole` 控制权限
- `APIVERSION` 是 `v1` 时，配置 `Role` 和 `ClusterRole` 时 `apiGroups` 以 `""` 表示

## 示例

1. 准备配置文件 `harbor-developer`

   ```sh
   kubectl apply -k harbor-developer
   ```

1. 获取认证 `Token`

   ```sh
   kubectl get secret -n sa-management harbor-developer -o jsonpath="{.data.token}" | base64 -d
   ```

1. 创建 `kubeconfig`，并替换模板中的 `token` 为真实值

   ```sh
    apiVersion: v1
    clusters:
    - name: bj1a
      cluster:
        insecure-skip-tls-verify: true
        server: https://10.128.0.10:7443
    contexts:
    - name: bj1a
      context:
        cluster: bj1a
        namespace: harbor
        user: bj1a-harbor-developer
    current-context: bj1a
    kind: Config
    preferences: {}
    users:
    - name: bj1a-harbor-developer
      user:
        token: <token>
   ```
