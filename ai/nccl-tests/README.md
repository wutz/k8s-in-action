# NCCL Tests

## 运行

```sh
# 根据集群实际硬件配置进行修改
kubectl apply -f nccl-tests-h100.yml

# 查询测试结果
kubectl logs -f nccl-test-h100-launcher-xxx

kubectl delete -f nccl-tests-h100.yml
```

16 卡 H100 NVLink + 8x 400Gbps IB 测试结果

```
#
#                                                              out-of-place                       in-place          
#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
536870912     134217728     float     sum      -1   2622.9  204.69  383.79      0   2622.4  204.72  383.86      0
1073741824     268435456     float     sum      -1   5200.4  206.47  387.14      0   5199.4  206.51  387.21      0
2147483648     536870912     float     sum      -1    10308  208.32  390.61      0    10389  206.70  387.57      0
4294967296    1073741824     float     sum      -1    20528  209.22  392.29      0    20530  209.21  392.27      0
8589934592    2147483648     float     sum      -1    41145  208.77  391.45      0    41008  209.47  392.76      0
# Out of bounds values : 0 OK
# Avg bus bandwidth    : 388.893 
#
```

## 参考

* [coreweave/nccl-tests](https://github.com/CoreWeave/nccl-tests)