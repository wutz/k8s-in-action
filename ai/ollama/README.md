# Ollama + Open WebUI

提供一个类 ChatGPT 服务

- 修改 `ingress.yaml` 中的 `tls.hosts` 和 `rules.host` 为实际的域名

- 部署

  ```sh
  k apply -k .
  ```

- 访问 https://chat.play.example.com (使用上述修改域名访问)

- 卸载

  ```sh
  k delete -k .
  ```
