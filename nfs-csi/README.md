# NFS CSI

## 前置准备

- 创建 RAID 设备。如果使用多块本地磁盘，可以创建软 RAID，参考 https://ruan.dev/blog/2022/06/29/create-a-raid5-array-with-mdadm-on-linux
- 创建 NFS Server。参考 https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nfs-mount-on-ubuntu-22-04

## 部署 NFS CSI

- 假设 NFS Server 在 10.0.3.158，共享目录为 /data, 把这些信息配置在 storageclass.yml 中

  ```sh
  # 把 k8s 使用目录放在独立的子目录 /data/volumes 下
  mkdir /data/volumes
  ```

- 部署 NFS CSI

  ```sh
  helmwave up --build
  ```

  上面操作完成以下步骤:

  - 创建 namespace `nfs-csi`
  - 部署 helm chart `csi-driver-nfs`
  - 安装 storageclass `nfs-csi`

- 验证 nfs-csi 工作正常

  ```sh
  # 部署测试用例
  k apply -f test.yml

  # 等待部署 pod 运行
  k get po

  # 进入 pod 观察 nfs 是否挂载以及正常读写
  k exec -it deployment-nfs-xxxxx-xxx -- bash

  # 清理测试用例
  k delete -f test.yml
  ```
