# HPC Workflow

**English** | [简体中文](README.zh-CN.md)

Reproducible user-space workflows for scientific computing on Slurm clusters using **SingularityCE**, **SquashFS/ext3 overlays**, **Ray**, and **SkyPilot**.

## Overview

`hpc-workflow` provides lightweight, rootless submission wrappers and templates for running containerized scientific and machine-learning workloads on traditional multi-tenant Slurm clusters—without requiring root privileges, system daemons, or Pyxis/Enroot plugins.

### Components

| Path | Purpose |
| :--- | :--- |
| `hpc/bin/hpc-submit` | Unified Slurm job launcher with explicit partition, CPU, RAM, GPU, wall-time, container, and overlay flags |
| `hpc/bin/hpc-doctor` | Read-only login-node environment and container runtime compatibility checker |
| `hpc/slurm/container.sbatch` | SingularityCE (`.sif`) template supporting read-only `ext3` environment overlays and `.sqsh` dataset mounts |
| `hpc/slurm/ray.sbatch` | Multi-node symmetric Ray cluster template inside an exclusive Slurm allocation |
| `hpc/sky/` | SkyPilot task templates (`task.cpu.yaml`, `task.gpu.yaml`) for native Slurm backends |
| `hpc/bin/sky-container` | Single-file SquashFS SkyPilot launcher (`singularity exec` without login-node Python venv sprawl) |

## Quick Start

### 1. Deployment & Environment Check

Install the scripts to a user-writable directory on the login node (e.g., `~/.local/opt/hpc-workflow/current` with symlinks in `~/.local/bin`) and run a read-only compatibility check:

```bash
hpc-doctor
```

### 2. Single-Node CPU & GPU Container Jobs

```bash
# Single-node CPU job
hpc-submit --partition cpu-short --cpus 4 --mem 8G --time 00:30:00 \
  --image /shared/images/python.sif \
  --job-name demo -- python -c 'print("hello")'

# Single-node GPU job
hpc-submit --partition gpu-v100 --cpus 8 --mem 32G --time 02:00:00 \
  --gres gpu:v100:1 --image /shared/images/pytorch.sif \
  -- python train.py
```

### 3. Immutable SquashFS Datasets & Read-Only Overlays

Package Python environments as `.ext3` overlays and large training datasets (such as satellite image tiles) as `.sqsh` SquashFS archives to avoid metadata bottlenecks on shared parallel filesystems (GPFS/Lustre):

```bash
hpc-submit --partition cpu-short --cpus 8 --mem 32G --time 04:00:00 \
  --image /shared/python.sif \
  --overlay /shared/python-env.ext3 \
  --dataset /shared/training-tiles.sqsh \
  -- python /shared/project/train.py --data /datasets
```

> **Note**: Overlays are mounted read-only so multiple concurrent jobs can safely share the same environment file. Write checkpoints to a separate writable directory on shared storage.

### 4. Multi-Node Ray Workloads

For distributed workloads where Ray (`>= 2.49`) is installed inside the `.sif` image, `--ray` launches a temporary Ray cluster scoped to an exclusive multi-node Slurm allocation:

```bash
hpc-submit --ray --nodes 2 --partition gpu-v100 --cpus 8 --mem 32G \
  --time 02:00:00 --gres gpu:v100:1 --ray-gpus 1 \
  --image /shared/ray-pytorch.sif \
  -- python -u /shared/train_ray.py
```

### 5. Optional SkyPilot Integration

Configure SSH access in `~/.slurm/config` (never committed to Git) to submit jobs from a client via SkyPilot's native Slurm backend:

```bash
sky check
sky launch --infra slurm/my-cluster/cpu-short hpc/sky/task.cpu.yaml
sky launch --infra slurm/my-cluster/gpu-v100 hpc/sky/task.gpu.yaml
```

For login nodes where unpacking large Python virtual environments is undesirable, the `.github/workflows/skypilot-squashfs.yml` workflow builds SkyPilot and its dependencies into a single read-only `.sqsh` image invoked directly via `hpc/bin/sky-container`.

## Security & Scope

- **Zero Checked-In Secrets**: No SSH configurations, cluster hostnames, Slurm account names, or credentials are stored in this repository.
- **Explicit Resource Requests**: Every job requires explicit partition, CPU, memory, and wall-time bounds subject to standard Slurm scheduler policies.
- **Isolated Public CI**: Static validation and SquashFS packaging run strictly on GitHub-hosted runners; this repository never submits jobs to private Slurm clusters during CI.
