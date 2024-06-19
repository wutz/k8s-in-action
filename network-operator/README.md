# Network Operator

当配置了 Infiniband 或者 RoCE 设备时，才需要安装 Network Operator。

- 修改 `values.yml` 中需要使用的设备

  ```sh
  lspci -nn |grep -i mellanox
  1a:00.0 Infiniband controller [0207]: Mellanox Technologies MT2910 Family [ConnectX-7] [15b3:1021]
  5d:00.0 Ethernet controller [0200]: Mellanox Technologies MT2892 Family [ConnectX-6 Dx] [15b3:101d]
  ```

  > 假如只使用 Infiniband 设备，则设置 Vendor ID 为 15b3, Device ID 为 1021

- 部署

  ```sh
  helmwave up --build
  ```

- 测试

  ```sh
  k apply -f test.yml
  k logs -f mofed-test-pod
  k delete -f test.yml
  ```

- 卸载

  ```sh
  helmwave down
  ```
