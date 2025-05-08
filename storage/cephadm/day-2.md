# 日常运维

## 在线扩容节点

首先需要检查新增节点网络是否与已有客户端节点网络互通

* cephfs 

  通过检查 mds 已经挂载的 client 获取正在使用的节点 ip 列表

  ```bash
  ceph fs get bj1cfs01
  ```
  获取最后一行 mds 服务名称，例如 `mds.bj1cfs01.zw1mds01.zfwrmx`

  然后查询 mds 中当前挂载的 client 列表
  ```bash
  ceph tell mds.bj1cfs01.zw1mds01.zfwrmx client ls |grep addr |grep -oP '\d{1,3}(\.\d{1,3}){3}'
  ```
  ceph 

最后在新增节点上执行 ping
* 上述获取的 client ip 列表
* 已有 ceph 集群的节点 ip 列表

