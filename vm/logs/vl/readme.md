## VictoriaLogs

本组件提供日志存储和查询功能

此外，后续在此组件集成 fluent-bit 作为日志收集器

官方文档：
https://docs.victoriametrics.com/victorialogs/quickstart/#helm-charts

配置参考：
https://github.com/VictoriaMetrics/helm-charts/blob/master/charts/victoria-logs-single/README.md

### 数据接入



promtail:  
https://docs.victoriametrics.com/victorialogs/data-ingestion/promtail/

promtail 是 loki 的默认收集组件，victorialogs 也实现了相关接口，注意参考下述 url
```
clients:
  - url: http://localhost:9428/insert/loki/api/v1/push?_stream_fields=instance,job,host,app
```

### 部署：
```shell
# 检查
ENV=prod helmwave build --yml

# 上线
ENV=prod helmwave up

# 卸载
ENV=prod helmwave down
```

