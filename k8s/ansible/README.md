# 使用 ansible 部署 k8s 集群

## 部署 k3s 发行版集群

> Alpha

- 修改配置

    修改 [inventory/k3s.yml](inventory/k3s.yml) 文件:
    * server 和 agent: 安装目标节点列表
    * k3s_version: 指定 k3s 版本
    * token: 指定 k3s 集群的 token
    * iface: 用于通信网卡
    * proxy_env: 指定代理环境变量
    * tls_san: apiserver 从外面访问 LB 的 IP, 用于签发证书

- 部署集群

    ```bash
    ansible-playbook -i inventory/k3s.yml playbooks/k3s/cluster.yml
    ```

- 卸载集群

    ```bash
    ansible-playbook -i inventory/k3s.yml playbooks/k3s/reset.yml
    ```

## 部署 k8s 发行版集群

> 待实现

基于 kubeadm 自动部署 k8s 发行版

## 节点准备

> 待实现

适于准备节点，但是需要手动安装 k3s/k8s, 或者用于其它用途场景
