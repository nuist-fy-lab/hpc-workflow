# HPC Workflow（科学计算 Slurm 工作流工具集）

[English](README.md) | **简体中文**

面向传统 Slurm 高性能计算集群的用户态科学计算工作流工具集，集成 **SingularityCE 容器**、**SquashFS / ext3 只读挂载**、**Ray 多节点分布式计算**与 **SkyPilot**。

## 项目概览

`hpc-workflow` 提供一套轻量、免 root 权限的作业提交封装与模板，帮助科研人员在多租户 Slurm 集群上可复现地运行容器化科学计算与机器学习任务，无需系统级守护进程，也不依赖 Pyxis/Enroot 等特权插件。

### 核心组件

| 路径 | 用途说明 |
| :--- | :--- |
| `hpc/bin/hpc-submit` | 统一 Slurm 作业提交入口，支持显式指定分区、CPU、内存、GPU、时限、容器镜像与数据挂载 |
| `hpc/bin/hpc-doctor` | 登录节点只读环境自检工具（检查 Slurm、SingularityCE、SquashFS 挂载兼容性等） |
| `hpc/slurm/container.sbatch` | SingularityCE（`.sif`）作业模板，支持只读挂载 `ext3` 环境层与 `.sqsh` 数据集 |
| `hpc/slurm/ray.sbatch` | 在独占多节点 Slurm 资源分配内启动对称式 Ray 集群的作业模板 |
| `hpc/sky/` | 面向原生 Slurm 后端的 SkyPilot 任务配置示例（`task.cpu.yaml`、`task.gpu.yaml`） |
| `hpc/bin/sky-container` | 单文件 SquashFS 版 SkyPilot 启动器（通过 `singularity exec` 直接运行，避免在登录节点解压大量 Python 小文件） |

## 快速上手

### 1. 部署与环境自检

将脚本部署到集群登录节点的用户目录（如 `~/.local/opt/hpc-workflow/current`，并将可执行文件软链接至 `~/.local/bin`），首先运行只读环境检查：

```bash
hpc-doctor
```

### 2. 单节点 CPU 与 GPU 容器作业

```bash
# 提交单节点 CPU 容器作业
hpc-submit --partition cpu-short --cpus 4 --mem 8G --time 00:30:00 \
  --image /shared/images/python.sif \
  --job-name demo -- python -c 'print("hello")'

# 提交单节点 GPU 容器作业
hpc-submit --partition gpu-v100 --cpus 8 --mem 32G --time 02:00:00 \
  --gres gpu:v100:1 --image /shared/images/pytorch.sif \
  -- python train.py
```

### 3. SquashFS 数据集与只读 Overlay 环境挂载

将 Python 依赖环境打包为 `.ext3` overlay 镜像，将海量训练切片（如卫星遥感切片数据）打包为 `.sqsh`（SquashFS）单文件挂载，可显著降低共享并行文件系统（GPFS/Lustre）的元数据压力：

```bash
hpc-submit --partition cpu-short --cpus 8 --mem 32G --time 04:00:00 \
  --image /shared/python.sif \
  --overlay /shared/python-env.ext3 \
  --dataset /shared/training-tiles.sqsh \
  -- python /shared/project/train.py --data /datasets
```

> **说明**：Overlay 默认以**只读模式**挂载，允许多个并发作业安全共享同一环境镜像；训练 Checkpoint 等输出请写入独立的共享可写目录。

### 4. 多节点 Ray 分布式作业

当容器镜像（`.sif`）内已安装 Ray（`>= 2.49`）时，可通过 `--ray` 在独占多节点 Slurm 分配内自动拉起临时 Ray 集群（作业结束即自动销毁）：

```bash
hpc-submit --ray --nodes 2 --partition gpu-v100 --cpus 8 --mem 32G \
  --time 02:00:00 --gres gpu:v100:1 --ray-gpus 1 \
  --image /shared/ray-pytorch.sif \
  -- python -u /shared/train_ray.py
```

### 5. SkyPilot 集成（可选）

在本地客户端的 `~/.slurm/config` 中配置集群 SSH 连接信息（切勿提交至 Git），即可通过 SkyPilot 原生 Slurm 后端提交任务：

```bash
sky check
sky launch --infra slurm/my-cluster/cpu-short hpc/sky/task.cpu.yaml
sky launch --infra slurm/my-cluster/gpu-v100 hpc/sky/task.gpu.yaml
```

若不便在集群登录节点展开庞大的 Python 虚拟环境，可使用 `.github/workflows/skypilot-squashfs.yml` 在云端构建单文件 `.sqsh` 镜像，并通过 `hpc/bin/sky-container` 直接调用。

## 安全与边界原则

- **零敏感信息入库**：仓库不包含任何 SSH 密钥、集群内部地址、Slurm 账户名或网络路由配置。
- **显式资源申请**：所有作业必须显式声明分区、CPU、内存与运行时间上限，严格受限于集群 Slurm 调度与权限策略。
- **公共 CI 隔离**：本仓库的静态检查与镜像打包全部在 GitHub 官方托管 Runner 上执行，绝不在公共 CI 中触发私有集群作业。
