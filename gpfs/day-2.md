# GPFS 日常维护

## 使用 Fileset 进行逻辑隔离

* 第一级 fileset 用于租户隔离
* 第二级 fileset 用于租户下的用户隔离
* 在 fileset 上施加 quota 和 qos 限制
* [每文件系统最大独立 fileset 数量为 3000, 每文件系统最大独立和非独立 fileset 数量为 10000](https://www.ibm.com/docs/en/STXKQY/gpfsclustersfaq.html#filesets)
    * 独立 fileset 使用独立 inode 空间 (`mmcrfileset --inode-space new`)
    * 非独立 fileset 使用共享 inode 空间 (缺省)

```bash
# 创建 fileset
mmcrfileset bj1fs1 fset1
# 链接 fileset 到文件系统上位置
mmlinkfileset bj1fs1 fset1 -J /share/fset1
# 查看 fileset 信息
mmlsfileset bj1fs1

# 启用对 root 用户施加 quota 限制
mmchconfig enforceFilesetQuotaOnRoot=yes -i
# 设置大小软限制 95G，硬限制 100G；文件软限制 95K，硬限制 100K
mmsetquota bj1fs1:fset1 --block 95G:100G --files 95K:100K
# 查看 quota 信息
mmlsquota -j fset1 bj1fs1
```