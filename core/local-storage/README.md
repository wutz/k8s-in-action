# local-storage

节点本地盘 csi，常用于自身带数据冗余的数据库使用

## 部署

如果需要自定义使用本地路径位置，需要修改 [path.yaml](./path.yaml)

```bash
kubectl apply -k .
```

## 卸载

```bash
kubectl delete -k.
```