# 使用常用客户端工具

## kubectl

阅读文章 https://kubernetes.io/zh-cn/docs/reference/kubectl/

常用技巧：

1. 安装 kubectl 插件管理器

   https://krew.sigs.k8s.io/docs/user-guide/quickstart/

2. 安装 namespace 切换插件

   https://github.com/ahmetb/kubectx

   ```sh
   kubectl krew install ns
   ```

3. 设置常用环境变量

   ```sh
   cat << 'EOF' > /etc/profile.d/k8s.sh
   export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
   export KUBECONFIG=~/.kube/config

   source <(kubectl completion bash)
   alias k=kubectl
   complete -o default -F __start_kubectl k
   EOF

   source /etc/profile.d/k8s.sh
   ```

4. 常用使用方法

   ```sh
   k get nodes
   k get po

   k ns kube-system
   k get po

   k apply -f test.yaml
   ```

5. 多集群管理

   可以使用插件 kubectx 进行切换，但是容易忘记所在集群, 下面使用为每个集群设置别名方式降低误操作

   ```sh
   alias d1='export KUBECONFIG=~/.kube/ctx/dev1.yaml; kubectl'

   d1 get po
   ```

## kustomize

阅读文章 https://kubectl.docs.kubernetes.io/

```sh
# 创建目录存放 yaml 文件
mkdir ollama && cd ollama

# 初始化
kustomize init

# 创建各种 yaml 文件
# 然后使用 kustomize 添加
kustomize edit add resource service.yaml

# 部署
kustomize build | k apply -f -
# 或者
k apply -k .
```

## Helm

阅读 https://helm.sh/ 了解常用使用方法

> 作为临时使用, 持久化使用 Helmwave

## Helmwave

阅读 https://docs.helmwave.app/

使用案例参考 CertManager

1. 使用搜索引擎搜索对应项目 helm charts, 然后执行 `helm repo add <name> <url>` 添加
2. 使用 `helm search repo <name>/` 仓库下使用的具体版本
3. 使用 `helm show values <name>/<chart>` 缺省值，一边后面自定义修改
4. 创建需要自定义的 `vaules.yml` 文件
5. 创建 `helmwave.yml` 描述文件
6. 执行 `helmwave up --build` 部署服务
7. 执行 `helmwave down` 卸载服务
