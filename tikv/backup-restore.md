# 1. 元数据备份和恢复

本文档介绍如何备份和恢复tikv的元数据,也就是pd中保存的元数据。

## 1.1. 备份元数据

执行如下命令备份元数据

```bash
# tiup cluster meta backup tikv01 --file meta.gz
```

## 1.2. 恢复元数据

执行如下命令恢复备份的元数据

```bash
# tiup cluster meta restore tikv ./meta.gz

  ██     ██  █████  ██████  ███    ██ ██ ███    ██  ██████
  ██     ██ ██   ██ ██   ██ ████   ██ ██ ████   ██ ██
  ██  █  ██ ███████ ██████  ██ ██  ██ ██ ██ ██  ██ ██   ███
  ██ ███ ██ ██   ██ ██   ██ ██  ██ ██ ██ ██  ██ ██ ██    ██
   ███ ███  ██   ██ ██   ██ ██   ████ ██ ██   ████  ██████

the exist meta.yaml of cluster tikv was last modified at 2024-11-13T18:50:14+08:00
the given tarball was last modified at 2024-11-13T19:28:17+08:00
This operation will override topology file and other meta file of tidb cluster tikv .
Are you sure to continue?
(Type "Yes, I know my cluster meta will be be overridden." to continue)
: Yes, I know my cluster meta will be be overridden.
Restoring cluster meta files...
restore meta of cluster tikv successfully.
```