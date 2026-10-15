# c2ln1 scientific Slurm workflows

This is **not** the GitHub Actions Slurm runner. Its existing long-lived
`p1shr / 4 CPUs / 8 GiB` allocation is not modified by any tool here.
Research jobs specify their partition/resources individually; permitted
partitions and GPUs are enforced by Slurm, not by the launcher.

## Deploy

All source changes and CI checks occur in GitHub Actions / DevSpace.
Deploy the checked-in scripts to the user's writable HPC location,
e.g. `~/.local/opt/hpc-workflow/current` with an `~/.local/bin/hpc-submit`
symlink; this requires no root and no system daemon.

Run `hpc-doctor` for a read-only environment report.

## Single node CPU

```bash
hpc-submit --partition p1shr --cpus 4 --mem 8G --time 00:30:00 \
  --image /shared/images/python.sif \
  --job-name demo -- python -c 'print("hello")'
```

GPU example (change partition / accelerator name to actual permissions):

```bash
hpc-submit --partition v100 --cpus 8 --mem 32G --time 02:00:00 \
  --gres gpu:v100:1 --image /shared/images/pytorch.sif \
  -- python train.py
```

## SquashFS & overlay

Use GitHub Actions to package prepared ML environments as `.sif` and
training tiles as `.sqsh` (SquashFS). Store them on shared GPFS and
reference their absolute paths at job submission:

```bash
hpc-submit --partition p1shr --cpus 8 --mem 32G --time 04:00:00 \
  --image /shared/python.sif --overlay /shared/python-env.ext3 \
  --dataset /shared/shiptrack-tiles.sqsh -- \
  python /shared/shiptracks/train.py --data /datasets
```

The overlay is mounted **read-only**, to prevent concurrent writers to the
same ext3 file. Its packages should be installed offline/in CI and remain
immutable on the cluster. For training checkpoints, use a separate writable
GPFS directory. Container-internal paths and input paths must exist.

Image/overlay mount compatibility on each compute partition must be validated
before relying on it. SquashFS reduces external namespace lookups but does not
guarantee high throughput for every random-access workload.

## Multi-node Ray

Ray >=2.49 must be present **inside the SIF** on every worker node.
For multi-tenancy safety the launcher requests exclusive Slurm nodes:

```bash
hpc-submit --ray --nodes 2 --partition v100 --cpus 8 --mem 32G \
  --time 02:00:00 --gres gpu:v100:1 --ray-gpus 1 \
  --image /shared/ray-pytorch.sif -- python -u /shared/train_ray.py
```

This consumes a complete allocation even when `--cpus` is small.
The Ray cluster exists only for the lifetime of its Slurm job.
The cluster may restrict cross-node ports; verify this for each partition.
For small single-node workloads use normal Slurm, without Ray overhead.

## SkyPilot

SkyPilot is an **optional client**. Native Slurm backend reads `~/.slurm/config`
(SSH-config syntax), submits `sbatch` via login-node SSH, and accepts
`--infra slurm/CLUSTER/PARTITION`. Configure authentication only in the
client environment; do not commit SSH keys or account tokens.

```bash
sky check
sky launch --infra slurm/lab-cluster/p1shr hpc/sky/task.cpu.yaml
sky launch --infra slurm/lab-cluster/v100 hpc/sky/task.gpu.yaml
```

**Do not** set `resources.image_id` until administrators enable
Pyxis/Enroot. The two sample SkyPilot tasks run directly on the allocated host.
SkyPilot does not bypass queues, reservations, GPU permissions, or policies.

VS Code SSH/Tunnel is intentionally out of scope.
