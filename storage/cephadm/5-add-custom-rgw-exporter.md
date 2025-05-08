# 增加定制化rgw-exporter服务

注意：本文档不是必做项，请根据需要执行。

当前Ceph版本18.2.4没有提供完整的桶性能数据信息，所以需要增加一个rgw-exporter服务补充桶相关信息。

经过调研最终选型https://github.com/galexrt/extended-ceph-exporter。

本文档只适用于Ceph 18及以下版本，Ceph 19版本已经开始提供更细粒度的客户端和桶性能数据。

# 一、操作步骤

## 1.1. 创建用户

本步骤说明创建一个专为rgw-exporter使用的监控用户，步骤如下

```bash
radosgw-admin user create --uid extended-ceph-exporter --display-name "extended-ceph-exporter admin user" --caps "buckets=read;users=read;usage=read;metadata=read;zone=read"
# Access key 
radosgw-admin user info --uid extended-ceph-exporter | jq '.keys[0].access_key'
# Secret key 
radosgw-admin user info --uid extended-ceph-exporter | jq '.keys[0].secret_key'
```

## 1.2. 编写定制化rgw-exporter服务配置文件

本章节所描述配置文件内容参考如下官方文档

```html
https://docs.ceph.com/en/latest/cephadm/services/custom-container/#custom-container-service
```

最终形成的配置文件内容为:

```yaml
service_type: container
service_id: rgw-exporter
placement:
  host_pattern: sn001.play.local
  count_per_host: 1
image: docker.io/galexrt/extended-ceph-exporter
entrypoint: /bin/extended-ceph-exporter
uid: 1000
gid: 1000
args:
  - "--net=host"
  - "--cpus=2"
ports:
    - 9138
extra_entrypoint_args:
  - argument: "--rgw-host=http://127.0.0.1:8000"   # 这里需要根据自己的环境配置rgw管理地址和端口
  - argument: "--rgw-access-key=xxxxxxx"		   # 这里填入上一步获取到的AccessKey值
  - argument: "--rgw-secret-key=xxxxxxx"		   # 这里填入上一步获取到的SecretKey值
```

## 1.3. 创建定制服务

将上面的内容保存到一个文件，这里约定文件名称为rgw-exporter.yaml。执行如下命令创建定制的rgw-exporter服务。

```bash
# ceph orch apply -i ./rgw-exporter.yaml
```

执行完成后查看服务部署状态

```bash
# ceph orch ls
```

当看到container.rgw-exporter状态为1/1的时候表示部署完成。执行如下命令确认性能数据是否可以被获取。

```bash
# curl localhost:9138/metrics
上面命令重点看是否存在ceph_rgw_bucket_size指标项，如果存在表示获取成功，否则失败。
```

## 1.4. 定制Ceph内嵌的prometheus配置模板

默认情况下，Ceph内嵌的Prometheus不支持获取用户自定义服务的性能数据，需要修改其模板使其支持该功能.

该部分参考如下官方文档

```bash
https://docs.ceph.com/en/latest/cephadm/services/monitoring/#option-names
```

所涉及的配置文件模板请从github上的Ceph仓库下载，位置如下

```bash
https://github.com/ceph/ceph/blob/main/src/pybind/mgr/cephadm/templates/services/prometheus/prometheus.yml.j2
```

将上面的文件prometheus.yml.j2下载到本地并编辑该文件，增加定制的rgw-exporter配置

```yaml
  - job_name: 'rgw-exporter'
    static_configs:
    - targets: ['127.0.0.1:9138']
```

## 1.5. 更新Prometheus

按照官方文档的讲解执行如下命令更新prometheus的配置

文档位置

```bash
https://docs.ceph.com/en/latest/cephadm/services/monitoring/#example
```

执行如下命令

```bash
# 更新配置模板
ceph config-key set mgr/cephadm/services/prometheus/prometheus.yml \
  -i $PWD/prometheus.yml.j2

# 应用新配置
ceph orch reconfig prometheus
```

## 1.6. 验证数据是否已经接入

通常Ceph内嵌的Prometheus默认端口为9095，通过Prometheus的Webui页面查看指标数据ceph_rgw_bucket_size是否已存在。有代表成功，否则失败。


