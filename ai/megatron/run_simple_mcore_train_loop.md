# 1. 训练脚本run_simple_mcore_train_loop.py执行过程

本向导描述如何快速的运行Megatron Core示例训练脚本。


# 2. 环境准备

## 2.1. 硬件环境

本次使用2卡4090资源进行

## 2.2. 软件环境

### 2.2.1. 基础容器运行时环境

经过测试，如下容器镜像满足本次测试的要求

|镜像名称 | Ubuntu系统版本 | CUDA版本| Pytorch版本| Python版本| 特殊说明 |
|:---:|:---:|:---:| :---:|:---:|:---:|
|nvcr.io/nvidia/pytorch:24.02-py3| 22.04 | NVIDIA CUDA 12.3.2 | 2.3.0a0+ebedce2 | Python 3.10.12| 无|
|nvcr.io/nvidia/pytorch:24.03-py3| 22.04 | NVIDIA CUDA 12.4.0.41 | 2.3.0a0+40ec155e58 | Python 3.10.12 | 无|
|nvcr.io/nvidia/pytorch:24.04-py3| 22.04 | NVIDIA CUDA 12.4.1 | 2.3.0a0+6ddf5cf85e | Python 3.10.12 | 无|
|nvcr.io/nvidia/pytorch:24.05-py3| 22.04 | NVIDIA CUDA 12.4.1 | 2.4.0a0+07cecf4168 | Python 3.10.12 | 无|
|nvcr.io/nvidia/pytorch:24.06-py3| 22.04 | NVIDIA CUDA 12.5.0.23 | 2.4.0a0+f70bd71a48 | Python 3.10.12 | 无|
|nvcr.io/nvidia/pytorch:24.07-py3| 22.04 | NVIDIA CUDA 12.5.1 | 2.4.0a0+3bcc3cddb5 | Python 3.10.12 | 无|
|nvcr.io/nvidia/pytorch:24.08-py3| 22.04 | NVIDIA CUDA 12.6 | 2.5.0a0+872d972e41 | Python 3.10.12 | 可运行，但有警告|
|nvcr.io/nvidia/pytorch:24.09-py3| 22.04 | NVIDIA CUDA 12.6.1 | 2.5.0a0+b465a5843b | Python 3.10.12 | 可运行，但有警告|
|nvcr.io/nvidia/pytorch:24.10-py3| 22.04 | NVIDIA CUDA 12.6.2 | 2.5.0a0+e000cf0ad9 | Python 3.10.12 | 可运行，但有警告|

如上镜像软件版本信息全部从NVIDIA官网获取，文档位置如下

```html
https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/rel-24-10.html
```

### 2.2.2. Docker版本

本次使用Docker版本24.0.7

### 2.2.3. Megatron版本

本次使用的Megatron版本为0.9.0

以下内容以nvcr.io/nvidia/pytorch:24.10-py3为例

# 3. 环境准备

## 3.1. 运行容器并安装必要依赖

```bash
$ docker run --ipc=host --shm-size=512m --gpus all -it nvcr.io/nvidia/pytorch:24.10-py3

以下在容器内执行
# pip install megatron_core
# pip install tensorstore
# pip install zarr
```

## 3.2. 准备Megatron环境

本文档以Megatron-LM源码仓库为基准准备Megatron环境，步骤如下所示

```bash
# git clone https://github.com/NVIDIA/Megatron-LM.git
# cd Megatron-LM
# git checkout core_r0.9.0
```

修改代码仓库的setup.py文件，修改如下信息

```py
原始文件内容
    packages=setuptools.find_namespace_packages(include=["megatron.core", "megatron.core.*"]),
    ext_modules=[
        Extension(
            "megatron.core.datasets.helpers",
            sources=["megatron/core/datasets/helpers.cpp"],
            language="c++",
            extra_compile_args=extra_compile_args,
        )
    ],
修改后的内容
    packages=setuptools.find_namespace_packages(include=["megatron.*"]),
    ext_modules=[
        Extension(
            "megatron.core.datasets.helpers",
            sources=["megatron/core/datasets/helpers.cpp"],
            language="c++",
            extra_compile_args=extra_compile_args,
        )
    ],
```

修改megatron/core/datasets/utils.py，把编译部分去掉

```bash
# vim megatron/core/datasets/utils.py
原始文件内容
def compile_helpers():
    """Compile C++ helper functions at runtime. Make sure this is invoked on a single process."""
    import os
    import subprocess

    command = ["make", "-C", os.path.abspath(os.path.dirname(__file__))]
    if subprocess.run(command).returncode != 0:
        import sys

        log_single_rank(logger, logging.ERROR, "Failed to compile the C++ dataset helper functions")
        sys.exit(1)
修改为
def compile_helpers():
    """Compile C++ helper functions at runtime. Make sure this is invoked on a single process."""
    import os
    import subprocess

#    command = ["make", "-C", os.path.abspath(os.path.dirname(__file__))]
#    if subprocess.run(command).returncode != 0:
#        import sys

#        log_single_rank(logger, logging.ERROR, "Failed to compile the C++ dataset helper functions")
#        sys.exit(1)
```

手工编译megatron.core.datasets中的c文件

```bash
# cd megatron/core/datasets
# make
编译完成后生成helpers.cpython-310-x86_64-linux-gnu.so这个动态链接库文件
```

编译Megatron_Core的whl包

首先切换到Megatron-LM软件仓库根目录,然后执行如下命令

```bash
# pip install build

# python -m build
```

以上命令执行完成会生成megaton_core的whl文件。位置如下

```bash
# ls dist/
megatron_core-0.9.0-cp310-cp310-linux_x86_64.whl  megatron_core-0.9.0.tar.gz
手工安装whl文件
# pip install ./dist/megatron_core-0.9.0-cp310-cp310-linux_x86_64.whl
```

运行简单训练脚本run_simple_mcore_train_loop.py

```bash
# NUM_GPUS=2
NUM_GPUS根据当前机器的卡数而定，我测试的结果是如果NUM_GPUS值不等于真实卡数会出现以下脚本执行后无响应的问题。
# torchrun --nproc-per-node $NUM_GPUS  examples/run_simple_mcore_train_loop.py
```
