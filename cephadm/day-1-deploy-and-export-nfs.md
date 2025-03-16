# 部署与导出 NFS

为了避免 nfs server 成为瓶颈，每个导出需要使用独立的 nfs server 集群。

```bash
# 创建 nfs 集群，这将创建 2 个服务 `nfs.bj1nfs01` 和 `ingress.nfs.bj1nfs01`
ceph nfs cluster create bj1nfs01 "1 label:nfs" --ingress --ingress-mode keepalive-only --virtual_ip 100.68.17.1/20 
# 设置 .nfs 池 crush 规则, 解决 ceph osd pool autoscale-status 输出为空以及 PG Autoscale 不工作问题
ceph osd pool set .nfs crush_rule rep_ssd

# 创建 cephfs 导出, --client_addr 指定允许的 nfs 客户端 ip 或者 ip 段, 初始允许 ceph 集群所有节点访问
ceph nfs export create cephfs --cluster-id bj1nfs01 --pseudo-path /bj1cfs01 --fsname bj1cfs01 --client_addr 100.68.17.0/20

# 导出配置
ceph nfs export info bj1nfs01 /bj1cfs01 -o bj1cfs01nfs.json
# 在 clients.addresses 中添加允许的 nfs 客户端 ip 或者 ip 段
# 然后应用配置
ceph nfs export apply bj1nfs01 -i bj1cfs01nfs.json
```

