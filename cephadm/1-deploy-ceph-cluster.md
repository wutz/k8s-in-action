# 部署 Ceph 集群

> 避免为操作系统提前创建用户 `ceph` 否则会引起安装包时不能正常执行 post-install 脚本

* 依赖: 参见 [环境准备](../docs/0-prepare.md)

  对于扩容现有Ceph集群操作，需要在执行本文档之前验证新加存储节点与现有客户端的连通性。
  在现有Ceph集群执行如下命令确认客户端的IP
  ```bash
   # ceph fs status
   找到指定文件系统处于active状态的mds服务
   # ceph tell mds.bjcfs01.mn01.zxhhrq client ls |grep addr
    {
        "id": 205000,
        "entity": {
            "name": {
                "type": "client",
                "num": 205000
            },
            "addr": {
                "type": "v1",
                "addr": "10.251.10.17:0",
                "nonce": 1156683885
            }
        }
      ...
    }
   上面得到的信息中addr就是客户端的IP地址，使用ping命令确认当前新加节点与现有客户端的网络连通性。
  ```

* 环境示例 

    | 节点 | Public Network IP | Cluster Network IP |
    | --- | --- | --- |
    | bj1dn01 | 100.68.16.1/20 | N/A |
    | bj1dn02 | 100.68.16.2/20 | N/A |
    | bj1dn03 | 100.68.16.3/20 | N/A |
    | bj1sn001 | 100.68.20.1/20 | 10.68.20.1/20 |
    | bj1sn002 | 100.68.20.2/20 | 10.68.20.2/20 |
    | bj1sn003 | 100.68.20.3/20 | 10.68.20.3/20 |
    | bj1sn004 | 100.68.20.4/20 | 10.68.20.4/20 |

* 配置 hosts 文件

    ```bash
    # 使用前 3 个节点作为管理角色
    cat > admin <<EOF
    root@100.68.20.[1-3]
    EOF

    cat > hosts <<EOF
    # dn
    100.68.16.1    bj1dn01
    100.68.16.2    bj1dn02
    100.68.16.3    bj1dn03

    # sn
    100.68.20.1    bj1sn001
    100.68.20.2    bj1sn002
    100.68.20.3    bj1sn003
    100.68.20.4    bj1sn004
    EOF

    pdcp -w ^admin hosts /tmp/hosts
    pdsh -w ^admin "cat /tmp/hosts >> /etc/hosts"
    ```

* 配置 docker

    ```bash
    pdsh -w ^all apt install docker.io -y

    cat > daemon.json <<EOF
    {
        "log-driver": "json-file",
        "log-opts": {
            "max-size": "250m",
            "max-file": "3"
        },
        "proxies": {
            "http-proxy": "http://100.68.3.1:3128",
            "https-proxy": "http://100.68.3.1:3128",
            "no-proxy": "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,localhost,*.example.com"
        }
    }
    EOF

    pdcp -w ^all daemon.json /etc/docker
    pdsh -w ^all systemctl restart docker
    ```

* 安装 Cephadm 用于部署集群

    ```bash
    pdsh -w ^all apt install -y cephadm
    # 如果机器无法访问外网，则需要临时设置代理
    # export https_proxy=http://100.68.3.1:3128
    pdsh -w ^all cephadm add-repo --release squid --repo-url http://mirrors.ustc.edu.cn/ceph --gpg-url http://mirrors.ustc.edu.cn/ceph/keys/release.gpg
    # 如果临时设置代理，则需要取消
    # unset https_proxy
    pdsh -w ^all cephadm install
    pdsh -w ^all cephadm version
    ```

* 安装 Ceph CLI 用于管理集群

    ```bash
    pdsh -w ^all cephadm install ceph-common 
    pdsh -w ^all ceph -v
    ```

* 引导新集群

    在 bootstrap 节点(sn01)执行

    ```bash
    cephadm bootstrap --mon-ip 100.68.20.1 --cluster-network 10.68.20.0/20 
    ceph -s
    ```

    - 创建一个 mon 和 mgr 守护进程
    - 生成新的 SSH key 并添加到 `/root/.ssh/authorized_keys`
    - 复制一份公钥到 `/etc/ceph/ceph.pub`
    - 生成最小配置文件到 `/etc/ceph/ceph.conf`
    - 复制一份用户 `client.admin` secret 到 `/etc/ceph/ceph.client.admin.keyring`
    - 增加 label `_admin` 到引导节点

    如果节点数量小于 5 个，则把 mon 服务设置为 3 个
    
    ```bash
    ceph orch apply mon --placement="3"
    ```

* 添加节点

    * 添加集群 ssh public key 到其它新的节点
        - 从 bootstrap 节点的文件 `/etc/ceph/ceph.pub` 获取 ssh public key
        - 然后此 key 追加到所有新节点文件 `/root/.ssh/authorized_keys` 中

    * 访问 ceph dashboard 并修改配置

        ```bash
        ceph dashboard set-grafana-api-url https://100.68.20.1:3000/
        ```

    * 添加新节点到集群中 (在 bootstrap 节点执行)
        
        ```bash
        ceph orch host add bj1sn001 --labels _admin
        ceph orch host add bj1sn002 --labels _admin
        ceph orch host add bj1sn003 --labels _admin
        ceph orch host add bj1sn004 
        ceph orch host add bj1dn01 --labels mds
        ceph orch host add bj1dn02 --labels mds
        ceph orch host add bj1dn03 --labels mds
        ceph orch host ls
        ```
        
    * 其它配置
        - 如果上游的 container image 被移除，可以执行 `ceph config set global container_image xxx`  
        - 如果添加节点属于不同的网络，需要指定 `public_network` 和 `cluster_network` 参数

            ```bash
            ceph config set mon public_network "100.68.20.0/20,100.68.32.0/20"
            ceph config set global cluster_network "100.68.20.0/20,100.68.32.0/20"
            ```

* [添加存储](https://docs.ceph.com/en/reef/cephadm/services/osd/#cephadm-deploy-osds)

    - 注意检查磁盘上存在分区。
      如果存在分区，需要尝试执行如下命令清除分区表

      ```bash
      以下三个命令根据自己的环境可以任选其一进行尝试，dd和sgdisk抹除的最彻底
      # dd if=/dev/zero of=/dev/xxx bs=1M count=1
      # wipefs -fa /dev/sda
      # sgdisk --zap-all /dev/sda
      ```
      上述抹除分区表命令执行完成后一定要执行一遍下面的 ceph orch device ls --refresh命令。

    - 查看可用磁盘
        
        ```bash
        ceph orch device ls --refresh 
        ```
        
        - 通过加上参数 `--refresh` 可以刷新识别磁盘列表。
        - 检查磁盘是否支持 libstoragemgmt `cephadm shell lsmcli ldl`
        - 如果支持则执行开启 `ceph config set mgr mgr/cephadm/device_enhanced_scan true`
        - 不支持 NVMe 设备

    - 可以执行清除磁盘以使其可用 (可选)
        
        ```bash
        ceph orch device zap ceph1 /dev/sdb
        ```
        
    - 创建 service spec 描述添加那些磁盘
        
        ```bash
        # 查看磁盘属性
        $ cephadm shell
        > ceph-volume inventory </path/to/disk>
            ====== Device report /dev/xxxxxx ======
    
         path                      /dev/xxxxxx
         ceph device               False
         being replaced            False
         lsm data                  {}
         available                 True      #该值为True表示可被Ceph使用
         rejected reasons                    #该值为一个字符数组，表示不能被Ceph使用的原因，可根据原因做出相应处理。
         device id
         removable                 0
         ro                        0
         vendor
         model                     xxxxxx
         sas address
         rotational                0
         actuators                 None
         scheduler mode            none
         human readable size       7.28 TB   #这个大小作为下面osd-ssd.yaml中指定的size大小
        ```
        
        
        ```yaml
        # osd-hdd.yaml
        service_type: osd
        service_id: hdd
        placement:
            host_pattern: bj1osd*
        spec:
            data_devices:
                rotational: 1
                size: '7.28T'
        ```

        ```yaml
        # osd-ssd.yaml
        service_type: osd
        service_id: ssd
        placement:
            host_pattern: bj1osd*
        spec:
            data_devices:
                rotational: 0
                size: '6.99T'
        ```

        * 如果 size 值不明确，也可以指定范围，例如 `size: '6T:7T'`
        
        ```bash
        # 部署 hdd
        # --dry-run 不实际部署，用于检查配置是否正确, 执行 --dry-run 等待一段时间后再重复执行
        ceph orch apply osd -i osd-hdd.yaml --dry-run
        ceph orch apply osd -i osd-hdd.yaml 

        # 部署 ssd
        ceph orch apply osd -i osd-ssd.yaml --dry-run
        ceph orch apply osd -i osd-ssd.yaml 

        # 查看 cephadm 部署日志
        ceph -W cephadm
        ceph log last cephadm
        ceph osd tree
        ceph -s
        ```

* 创建 crush rule
    
    ```bash
    # ceph osd crush rule create-replicated <name> <root> <failure-domain> <class>
    ceph osd crush rule create-replicated rep_hdd default host hdd
    ceph osd crush rule create-replicated rep_ssd default host ssd

    # ceph osd crush rule create-replicated <name> <root> <failure-domain> <class>
    # 创建 EC 2+2 纠删码，存储集群推荐 5 个节点
    ceph osd erasure-code-profile set ec22_ssd k=2 m=2 crush-root=default crush-failure-domain=host crush-device-class=ssd
    # 创建 EC 4+2 纠删码，存储集群推荐 7 个节点
    ceph osd erasure-code-profile set ec42_ssd k=4 m=2 crush-root=default crush-failure-domain=host crush-device-class=ssd
    # 创建 EC 8+3 纠删码，存储集群推荐 12 个节点
    ceph osd erasure-code-profile set ec83_ssd k=8 m=3 crush-root=default crush-failure-domain=host crush-device-class=ssd
    # 如果需要创建 HDD EC 纠删码，修改 `crush-device-class=hdd` 即可
    ```

    > * 缺省自带副本类 crush rule `replicated_rule`，如果系统中存在 HDD 和 SSD 两类设备这将混用在一起，这会带来不稳定性能。
    > * 一般显示创建副本类 crush rule 指定设备类型（例如上面明确 ssd 设备）

* 使 PG Autoscale 工作

    每个 Pool 中的 PG 数量会影响到性能，Ceph 提供自动调整 PG 数量功能。

    ```bash
    # 解决 ceph osd pool autoscale-status 输出为空以及 PG Autoscale 不工作问题
    ceph osd pool set .mgr crush_rule rep_ssd
    ```


* 部署完 Ceph 集群后并不能提供对外服务，需要根据应用场景部署对应服务

    * [提供 Ceph RADOS 原生服务](2-ceph-rados.md)
    * [部署 CephFS](3-deploy-cephfs.md)
    * [部署 Ceph RBD 块存储](4-deploy-rbd.md)
    * [部署 Ceph RGW 对象存储](5-deploy-rgw.md)

* 其它

    * 使用多路径设备，重启节点 lvm 别名设备丢失问题

        这是因为重启节点时 lvm 先处理 /dev/sd* 设备导致被锁定，无法处理对应 /dev/mapper/mpath* 设备
        
        ```bash
        # 打开文件
        /etc/lvm/lvm.conf
        # 添加一行, 让 lvm 只处理 /dev/mapper/mpath* 设备
        filter = [ "a|/dev/mapper/mpath.*|", "r|.*|" ]
        
        # 然后执行 
        update-initramfs -u
        # 重启节点
        reboot
        ```
