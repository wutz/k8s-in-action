# Dynamo

## 前置依赖

* 开发机：准备一个 x86_64 cpu 安装 docker 的 Linux 机器即可, 用于构建 Runtime 镜像和示例程序镜像
* 镜像仓库: 本示例使用 `cr.bj1.example.com` 作为镜像仓库
* K8S 集群: hello-world 示例不依赖 GPU
* 已解决开发机和 K8S 的科学上网问题

## 开发与构建镜像

* 准备 Runtime 镜像

    ```bash
    # 克隆 dynamo 仓库
    git clone https://github.com/ai-dynamo/dynamo.git

    # 构建 Runtime 镜像
    cd dynamo
    ./container/build.sh

    # 推送镜像到镜像仓库, 其中 <image-id> 执行 docker images 获取最近构建的镜像
    docker tag <image-id> cr.bj1.example.com/ai-dynamo/dynamo:v0.1.0-vllm
    docker push cr.bj1.example.com/ai-dynamo/dynamo:v0.1.0-vllm
    ```

* 构建程序

    > 为了不依赖 ubuntu 24.04 环境，本构建使用基础 Runtime 镜像启动一个容器用于构建 hello-world

    ```bash
    # 使用基础 Runtime 镜像启动一个容器用于构建 hello-world
    docker run --rm -it --net host -v /usr/libexec/docker:/usr/libexec/docker -v /root/.docker:/root/.docker -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker cr.bj1.example.com/ai-dynamo/dynamo:v0.1.0-vllm bash
    ```

    在下面示例选择一个构建：

    * 构建示例程序 hello-world

        ```bash
        # 在容器中构建示例程序
        cd /workspace/dynamo/examples/hello_world

        # 设置基础 Runtime 镜像
        export DYNAMO_IMAGE=cr.bj1.example.com/ai-dynamo/dynamo:v0.1.0-vllm

        # 构建示例程序
        dynamo build --containerize hello_world:Frontend

        # 获取示例程序运行配置, 用于后续部署到 K8S 集群
        dynamo get frontend > values.yml

        # 将示例程序镜像推送到镜像仓库, 其中 <image-id> 执行 docker images 获取最近构建的镜像
        docker tag <image-id> cr.bj1.example.com/ai-dynamo/dynamo-examples:hello-world
        docker push cr.bj1.example.com/ai-dynamo/dynamo-examples:hello-world
        ```

    * 构建示例程序 llm-agg

        ```bash
        # 在容器中构建示例程序
        cd /workspace/dynamo/examples/llm

        # 设置基础 Runtime 镜像
        export DYNAMO_IMAGE=cr.bj1.example.com/ai-dynamo/dynamo:v0.1.0-vllm

        # 构建示例程序
        dynamo build --containerize graphs.agg:Frontend

        # 获取示例程序运行配置, 用于后续部署到 K8S 集群
        dynamo get frontend > values.yml

        # 将示例程序镜像推送到镜像仓库, 其中 <image-id> 执行 docker images 获取最近构建的镜像
        docker tag <image-id> cr.bj1.example.com/ai-dynamo/dynamo-examples:llm-agg
        docker push cr.bj1.example.com/ai-dynamo/dynamo-examples:llm-agg
        ```

## 部署到 K8S 集群

> 安装 [helmwave](https://docs.helmwave.app/0.29.x/install/) 用于部署 helm 包

* 安装依赖 etcd 用于服务发现

    ```bash
    cd dynamo/etcd
    helmwave up --build
    ```

* 安装依赖 nats 用于 PD 消息传递

    ```bash
    cd dynamo/nats
    helmwave up --build
    ```

* 安装实例程序，选择一个对应的:

    * 安装 dynamo hello-world 示例程序

        * 替换 `dynamo/dynamo-hello-world/patch.yml` 中的 `image` 为示例程序镜像
        * 替换 `dynamo/dynamo-hello-world/values.yml` 来自开发机构建执行 `dynamo get frontend` 获取的配置

        部署：

        ```bash
        cd dynamo/hello-world
        helmwave up --build
        ```

        访问：
        ```bash
        # 查看服务部署情况
        kubectl -n dynamo get po 

        # 转发服务的端口到本地 3000 端口
        kubectl -n dynamo port-forward svc/dynamo-hello-world-frontend 3000:80

        # 访问服务
        curl -X 'POST' 'http://localhost:3000/generate' \
            -H 'accept: text/event-stream' \
            -H 'Content-Type: application/json' \
            -d '{"text": "test"}'
        ```

    * 安装 dynamo llm-agg 示例程序

        * 替换 `dynamo/dynamo-llm/patch.yml` 中的 `image` 为示例程序镜像
        * 替换 `dynamo/dynamo-llm/values.yml` 来自开发机构建执行 `dynamo get frontend` 获取的配置

        部署：

        ```bash
        # 部署 pvc 用于缓存模型文件
        kubectl apply -f dynamo/dynamo-llm/pvc.yaml

        cd dynamo/llm
        helmwave up --build
        ```

        访问：

        ```bash
        # 查看服务部署情况
        kubectl -n dynamo get po 

        # 转发服务的端口到本地 3000 端口
        kubectl -n dynamo port-forward svc/dynamo-llm-frontend 3000:80

        # 访问服务
        curl localhost:3000/v1/chat/completions   -H "Content-Type: application/json"   -d '{
            "model": "deepseek-ai/DeepSeek-R1-Distill-Llama-8B",
            "messages": [
            {
                "role": "user",
                "content": "In the heart of Eldoria, an ancient land of boundless magic and mysterious creatures, lies the long-forgotten city of Aeloria. Once a beacon of knowledge and power, Aeloria was buried beneath the shifting sands of time, lost to the world for centuries. You are an intrepid explorer, known for your unparalleled curiosity and courage, who has stumbled upon an ancient map hinting at ests that Aeloria holds a secret so profound that it has the potential to reshape the very fabric of reality. Your journey will take you through treacherous deserts, enchanted forests, and across perilous mountain ranges. Your Task: Character Background: Develop a detailed background for your character. Describe their motivations for seeking out Aeloria, their skills and weaknesses, and any personal connections to the ancient city or its legends. Are they driven by a quest for knowledge, a search for lost familt clue is hidden."
            }
            ],
            "stream":false,
            "max_tokens": 30
        }' 
        ```