# kubernetes-event-exporter

## 介绍

kubernetes-event-exporter 是一个用于收集 Kubernetes 集群事件并导出到指定存储的组件。它通过监听 Kubernetes API Server 的事件，将事件数据导出到指定的存储系统中，如 Elasticsearch、InfluxDB 等。

## 功能

- 收集 Kubernetes 集群事件
- 将事件数据导出到指定的存储系统
- 支持多种存储系统，如 Elasticsearch、InfluxDB 等
- 支持自定义事件过滤和转换规则
- 支持多租户和集群管理

## 安装&更新
默认安装到 vm namespace
```
KUBECONFIG=... ./man upgrade
```

## 访问

目前不提供 ingress，请使用 forward 暴露端口访问

## 事件映射
```json
{
  "metadata": {
    "name": "apprepo-kubeapps-sync-bitnami-28746010-t9qnk.17ef94a0e4137bc0",
    "namespace": "kubeapps",
    "uid": "ef4bb79d-197d-4b64-b3d9-8ba089af8f46",
    "resourceVersion": "148287483",
    "creationTimestamp": "2024-08-27T12:10:01Z"
  },
  "reason": "Failed",
  "message": "Error: secret \"kubeapps-postgresql\" not found",
  "source": { "component": "kubelet", "host": "cn001.dev.local" },
  "firstTimestamp": "2024-08-27T12:10:01Z",
  "lastTimestamp": "2024-08-27T12:10:01Z",
  "count": 1,
  "type": "Warning",
  "eventTime": null,
  "reportingComponent": "kubelet",
  "reportingInstance": "cn001.dev.local",
  "clusterName": "",
  "involvedObject": {
    "kind": "Pod",
    "namespace": "kubeapps",
    "name": "apprepo-kubeapps-sync-bitnami-28746010-t9qnk",
    "uid": "76859768-535c-4bc8-b617-38250e7ece78",
    "apiVersion": "v1",
    "resourceVersion": "148287461",
    "fieldPath": "spec.containers{sync}",
    "labels": {
      "apprepositories.kubeapps.com/repo-name": "bitnami",
      "apprepositories.kubeapps.com/repo-namespace": "kubeapps",
      "batch.kubernetes.io/controller-uid": "92a3d524-d016-4c1f-827e-365adf4ae09d",
      "batch.kubernetes.io/job-name": "apprepo-kubeapps-sync-bitnami-28746010",
      "controller-uid": "92a3d524-d016-4c1f-827e-365adf4ae09d",
      "job-name": "apprepo-kubeapps-sync-bitnami-28746010"
    },
    "ownerReferences": [
      {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "name": "apprepo-kubeapps-sync-bitnami-28746010",
        "uid": "92a3d524-d016-4c1f-827e-365adf4ae09d",
        "controller": true,
        "blockOwnerDeletion": true
      }
    ],
    "deleted": false
  }
}
```
```text
    layout:

      cluster  : "{{ .ClusterName }}"
      classify : "k8s-event"

      time     : "{{ .Metadata.CreationTimestamp.Format \"2006-01-02T15:04:05Z\" }}"
      namespace: "{{ .InvolvedObject.Namespace }}"
      msg      : "{{ .Message }}"

      start    : "{{ .FirstTimestamp }}"
      end      : "{{ .LastTimestamp }}"
      host     : "{{ .Source.Host }}"
      component: "{{ .Source.Component }}"
        
      type     : "{{ .Type }}"
      reason   : "{{ .Reason }}"
      count    : "{{ .Count }}"
      kind     : "{{ .InvolvedObject.Kind }}"
      name     : "{{ .InvolvedObject.Name }}"
      uid      : "{{ .InvolvedObject.UID }}"
      apiVersion: "{{ .InvolvedObject.APIVersion }}"
      resourceVersion : "{{ .InvolvedObject.ResourceVersion }}"
      fieldPath: "{{ .InvolvedObject.FieldPath }}"

      labels: "{{ toJson .InvolvedObject.Labels}}"
      ownerReferences: "{{ toJson .InvolvedObject.OwnerReferences }}"
      deleted : "{{ .InvolvedObject.Deleted }}"
```

## vmui 查询 - LogsQL
https://docs.victoriametrics.com/victorialogs/logsql/
```bash
# 查询所有
*

# 查询 component 为 kubelet 的事件
component:"kubelet"

# 查询类型为 Normal 的事件
type:"Normal"

# 查询类型为 Normal 且 component 为 kubelet 的事件
type:"Normal" AND component:"kubelet"

# regexp 查询
component:~"kubelet|deployment-controller"
```