# 部署 Ceph 集群

> 避免为操作系统提前创建用户 `ceph` 否则会引起安装包时不能正常执行 post-install 脚本

* 依赖: 参见 [环境准备](../docs/0-prepare.md)

* 配置 docker

    ```bash
    pdsh -w ^all apt install docker.io -y

    cat > daemon.json <<EOF
    {
        "proxies": {
            "http-proxy": "http://172.19.1.100:3128",
            "https-proxy": "http://172.19.1.100:3128",
            "no-proxy": "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,localhost,.example.com"
        }
    }
    EOF

    pdcp -w ^all daemon.json /etc/docker
    pdsh -w ^all systemctl restart docker
    ```

* 安装 Cephadm 用于部署集群

    ```bash
    pdsh -w ^all apt install -y cephadm
    pdsh -w ^all cephadm add-repo --release reef --repo-url http://mirrors.ustc.edu.cn/ceph
    pdsh -w ^all cephadm install
    pdsh -w ^all cephadm version
    ```

* 安装 Ceph CLI 用于管理集群

    ```bash
    pdsh -w ^all cephadm install ceph-common 
    pdsh -w ^all ceph -v
    ```

* 引导新集群

    在 Bootstrap Node 执行

    ```bash
    cephadm bootstrap --allow-fqdn-hostname --mon-ip 172.19.12.1 --cluster-network 172.20.12.0/24 
    ceph -s
    ```

    - 创建一个 mon 和 mgr 守护进程
    - 生成新的 SSH key 并添加到 `/root/.ssh/authorized_keys`
    - 复制一份公钥到 `/etc/ceph/ceph.pub`
    - 生成最小配置文件到 `/etc/ceph/ceph.conf`
    - 复制一份用户 `client.admin` secret 到 `/etc/ceph/ceph.client.admin.keyring`
    - 增加 label `_admin` 到引导节点

* 添加节点

    * 添加集群 ssh public key 到其它新的节点
        - 从 bootstrap 节点的文件 `/etc/ceph/ceph.pub` 获取 ssh public key
        - 然后此 key 追加到所有新节点文件 `/root/.ssh/authorized_keys` 中

    * 访问 ceph dashboard 并修改配置

        ```bash
        ceph dashboard set-grafana-api-url https://172.19.12.1:3000/
        ```

    * 添加新节点到集群中 (在 bootstrap 节点执行)
        
        ```bash
        ceph orch host add sn002.play.local --labels _admin
        ceph orch host add sn003.play.local --labels _admin
        ceph orch host ls
        ```
        
    * 其它配置
        - 如果上游的 container image 被移除，可以执行 `ceph config set global container_image xxx`  
        - 如果添加节点属于不同的网络，需要指定 `public_network` 和 `cluster_network` 参数

            ```bash
            ceph config set mon public_network "172.19.12.0/24,172.29.12.0/24"
            ceph config set global cluster_network "172.20.12.0/24,172.30.12.0/24"
            ```

* [添加存储](https://docs.ceph.com/en/reef/cephadm/services/osd/#cephadm-deploy-osds)


    - 注意检查磁盘上存在分区

    - 查看可用磁盘
        
        ```bash
        ceph orch device ls [--wide]
        ```
        
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
        > ceph-volume inventory </path/to/disk>
        ```
        
        ```yaml
        # 根据磁盘属性和规划创建描述文件 osd_spec.yml
        service_type: osd
        service_id: default_drive_group
        placement:
            host_pattern: '*'
        spec:
            data_devices:
                rotational: 1
                model: 'ST4000NM0033-9ZM'
                size: '3.64T'
            db_devices:
                rotational: 0
                model: 'INTEL SSDPEDMX400G4'
                size: '372.61G'
        ```
        
        ```yaml
        service_type: osd
        service_id: hdd
        placement:
            host_pattern: sn*
        spec:
            data_devices:
                rotational: 1
                size: '7.28T'
        ```

        ```yaml
        service_type: osd
        service_id: ssd
        placement:
            host_pattern: sn*
        spec:
            data_devices:
                rotational: 0
                size: '6.99T'
        ```
        
        ```bash
        # 应用描述文件
        > ceph orch apply osd -i ./osd_spec.yml [--dry-run]
        ```

* 创建 crush rule
    
    ```bash
    # ceph osd crush rule create-replicated <name> <root> <failure-domain> <class>
    ceph osd crush rule create-replicated rep_ssd default host ssd
    ceph osd crush rule create-replicated rep_hdd default host hdd

    # ceph osd crush rule create-replicated <name> <root> <failure-domain> <class>
    # 创建 EC 4+2 纠删码，存储集群至少有 7 个节点
    ceph osd erasure-code-profile set ec42_hdd k=4 m=2 crush-root=default crush-failure-domain=host crush-device-class=hdd
    # 创建 EC 8+3 纠删码，存储集群至少有 12 个节点
    ceph osd erasure-code-profile set ec83_hdd k=8 m=3 crush-root=default crush-failure-domain=host crush-device-class=hdd
    # 如果需要创建 SSD EC 纠删码，修改 `crush-device-class=ssd` 即可
    ```

    > * 缺省自带副本类 crush rule `replicated_rule`，如果系统中存在 HDD 和 SSD 两类设备这将混用在一起，这会带来不稳定性能。
    > * 一般显示创建副本类 crush rule 指定设备类型（例如上面明确 ssd 设备）

    ```bash
    # 解决 ceph osd pool autoscale-status 输出为空的问题
    ceph osd pool set .mgr crush_rule rep_ssd
    ```

* 部署完 Ceph 集群后并不能提供对外服务，需要根据应用场景部署对应服务

    * [提供 Ceph RADOS 原生服务](2-ceph-rados.md)
    * [部署 CephFS](3-deploy-cephfs.md)