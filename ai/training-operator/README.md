# [部署 Training Operator](https://github.com/kubeflow/training-operator)

通常用于预训练或者微调 ML 模型，这些模型使用各种 ML 框架例如 Pytorch, TensorFlow, XGBoost, MPI 和 Paddle 等

本仓库 manifests 来自 [training-operator v1.7.0](https://github.com/kubeflow/training-operator/releases/tag/v1.7.0) 下目录 `manifests`

* 关闭 `mpijob/v1`

    前面安装 [mpi-operator](../mpi-operator/README.md) 提供的 `mpijob/v2beta1` 与 `training-operator` 提供的 `mpijob/v1` 不能同时存在。

    另外 `mpijob/v2beta1` 采用 ssh 互信方式，更接近裸金属环境适用范围更广

    * 注释 base/crds/kustomize.yaml 中的 `- kubeflow.org_mpijob.yaml`
    * base/deployment.yaml 中

        ```yaml
        - command:
            - /manager
        ```

        下面添加

        ```yaml
        args:
            - --enable-scheme=tfjob
            - --enable-scheme=pytorchjob
            - --enable-scheme=mxjob
            - --enable-scheme=xgboostjob
            - --enable-scheme=paddlejob
        ```

* 部署

    ```bash
    kubectl apply -k overlays/standalone
    ```