# Rook 日常维护

## 节点与 OSD 管理

* 新增节点按照 k8s 新增节点操作即可，如果新节点有空盘则可以自动加入集群

* 新增 OSD 插入空盘会自动加入集群

* 移除节点和 OSD

    ```sh
    # 立即排干节点上的 pod 
    kubectl drain bj1sn001 --ignore-daemonsets --delete-emptydir-data

    # 如果需要撤销 drain 节点，则执行 uncordon 命令
    #kubectl uncordon bj1sn001

    # 删除节点
    kubectl delete node bj1sn001
    ```

    ```sh
    # 查看 OSD 列表, 找到移除节点下的 osd ids
    kubectl rook-ceph ceph osd tree

    # 删除 OSD, osd 必须处于 down 状态才允许移除
    kubectl rook-ceph rook purge-osd 1,2,3 --force
    ```

* 更换故障 OSD 磁盘

    ```sh
    # 查看 OSD 列表, 找到故障 OSD 的 id
    kubectl rook-ceph ceph osd tree

    # 更换故障 OSD 磁盘
    kubectl rook-ceph rook purge-osd 1 --force

    # 新增空盘自动加入集群
    ```

* 节点离线缺省 `30m` 后开始 recovery 自动恢复满足数据冗余数量
