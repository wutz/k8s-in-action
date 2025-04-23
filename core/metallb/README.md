# [MetalLB](https://metallb.universe.tf/)

高可用的服务均衡器

## 部署

```sh
# 根据实际情况修改 default-pool.yaml
# 参考 https://metallb.universe.tf/configuration/

# 部署 
kubectl apply -k .
```

## 使用

```sh
# 使用示例
# 参考 https://metallb.universe.tf/usage/ 
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    # 指定 IP 地址池中的 IP 地址, 该 IP 地址必须在此 IPAddressPool 中
    # 设置此注解可以防止 Service 重建时 IP 地址发生变化
    metallb.universe.tf/loadBalancerIPs: 172.18.15.190
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
EOF
```

## 卸载

```sh 
kubectl delete -k .
```
