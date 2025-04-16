# 部署 Conda Mirror

基于 [quetz](https://quetz.readthedocs.io/en/latest/) 提供私有 channel 和按需缓存 Mirror 功能。

## 部署

1. 修改 `prod/ingress.yaml` 中的 `conda.example.com` 为实际域名
2. 修改 `prod/config.toml` 
   * 访问 https://github.com/settings/applications/new 注册填入 Authorization callback URL 值 https://conda.example.com/auth/github/authorize (注意替换 conda.example.com 为实际域名)
   * 从上述步骤获取 client_id 和 client_secret 后修改 `[github]` 对应字段
   * 修改 `[users]` 中的 `admins` 字段，填入 GitHub 用户名分配管理员权限
   * 执行 `openssl rand -hex 32` 生成 `session.secret` 填入 `config.toml`
3. 修改 `prod/pvc.yaml` 中的 `storage` 大小 (只存储被拉取过的 Conda 数据，按需调整)

```bash
kubectl apply -k prod/
```

## 配置

1. 访问 https://conda.example.com/ 使用 GitHub 账号登录, 点击按钮 `Get API Key` 获取 API Key
2. 创建 proxy 模式的 channel
    ```bash
    curl --request POST \
        --url https://conda.example.com/api/channels \
        --header 'Content-Type: application/json' \
        --header 'X-API-Key: <API Key>' \
        --data '{
            "name": "main",
            "private": false,
            "mirror_channel_url": "https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main",
            "mirror_mode": "proxy"
        }'
    
    curl --request POST \
        --url https://conda.example.com/api/channels \
        --header 'Content-Type: application/json' \
        --header 'X-API-Key: <API Key>' \
        --data '{
            "name": "r",
            "private": false,
            "mirror_channel_url": "https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r",
            "mirror_mode": "proxy"
        }'

    curl --request POST \
        --url https://conda.example.com/api/channels \
        --header 'Content-Type: application/json' \
        --header 'X-API-Key: <API Key>' \
        --data '{
            "name": "msys2",
            "private": false,
            "mirror_channel_url": "https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2",
            "mirror_mode": "proxy"
        }'
    ```


## 使用

```bash
# 使用实际域名
cat <<EOF >> ~/.condarc
channels:
  - defaults
show_channel_urls: true
default_channels:
  - https://conda.example.com/get/main
  - https://conda.example.com/get/r
  - https://conda.example.com/get/msys2
EOF
conda clean -i
```
