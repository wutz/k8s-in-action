# 部署 PyPI Mirror

基于 [devpi](https://devpi.net/docs/devpi/devpi/stable/%2Bd/index.html) 提供私有仓库和按需缓存 Mirror 功能。

## 部署

1. 修改 `prod/deployment.yaml` 中的 `DEVPI_PASSWORD`
2. 修改 `prod/ingress.yaml` 中的 `pypi.example.com`
3. 修改 `prod/pvc.yaml` 中的 `storage` 大小 (只存储被拉取过的 PyPI 数据，全量在 20Ti 左右，按需调整)

```bash
kubectl apply -k prod/
```

## 配置

部署完成后，需要修改 Mirror 服务器以加快拉取速度。

```sh
pip install devpi-client
devpi login root --password xxx
# 使用实际域名
devpi use https://pypi.example.com
devpi index root/pypi volatile=True
devpi index --delete root/pypi
devpi index -c root/pypi type=mirror mirror_url=https://mirrors.163.com/pypi/simple/
devpi index root/pypi volatile=False
```

## 使用

```bash
# 使用实际域名
pip config set global.index-url https://pypi.example.com/root/pypi/+simple/
```