# GPFS 日常维护

## 使用 Fileset 进行逻辑隔离

* 第一级 fileset 用于租户隔离
* 第二级 fileset 用于租户下的用户隔离
* 在 fileset 上施加 quota 和 qos 限制

```bash
# 创建 fileset
mmcrfileset bj1fs1 ifset1
# 链接 fileset 到文件系统上位置
mmlinkfileset bj1fs1 ifset1 -J /share/ifset1
# 查看 fileset 信息
mmlsfileset bj1fs1

# 启用对 root 用户施加 quota 限制
mmchconfig enforceFilesetQuotaOnRoot=yes -i
# 设置大小软限制 95G，硬限制 100G；文件软限制 95K，硬限制 100K
mmsetquota bj1fs1:ifset1 --block 95G:100G --files 95K:100K
# 查看 quota 信息
mmlsquota -j ifset1 bj1fs1
```