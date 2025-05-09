# Cert Manager

> GA

> https://cert-manager.io/docs/

- 修改 `certs/clusterissuer.yaml` 中的 email 为自己的邮箱地址

- 部署

  ```sh
  helmwave up --build
  ```

- 测试

  修改 `ingress.yaml` 中的 `hosts` 和 `host` 为实际 DNS 域名

  ```sh
  # 部署
  kubectl apply -k tests

  # 访问 https://kuard.play.example.com

  # 卸载
  kubectl delete -k tests
  ```

  可以通过查看签名过程

  ```sh
  kubectl get ing
  kubectl get cert
  kubectl get challenges
  ```
