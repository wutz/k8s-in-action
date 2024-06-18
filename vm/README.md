# Victoria Metrics

提供兼容 Prometheus 的 Metrics 监控栈

- 修改 `values.yml` 中的值以符合实际情况

  - `grafana.adminPassword`
  - `grafana.ingress.hosts` 和 `grafana.ingress.tls.hosts`

- 部署

  ```sh
  helmwave up --build
  ```

- 访问 https://g.play.example.com (使用上述修改后的域名地址)

- 卸载

  ```sh
  helmwave down
  ```
