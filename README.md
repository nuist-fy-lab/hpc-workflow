# HPC Workflow

User-space workflows for scientific computing on traditional Slurm clusters.
The toolkit **does not** replace Slurm or require elevated privileges.

Includes:

- `hpc/bin/hpc-submit`: explicit partition, node, CPU, RAM, GPU and wall-time requests.
- `hpc/slurm/container.sbatch`: SingularityCE/SIF workloads with read-only
  ext3 overlays and SquashFS data mounts.
- `hpc/slurm/ray.sbatch`: Ray symmetric-run within an exclusive multi-node
  allocation. Use only where full-node allocation is appropriate.
- `hpc/sky/`: SkyPilot Slurm task examples, without assuming Pyxis/Enroot.
- `hpc/bin/hpc-doctor`: read-only login node compatibility report.

See [hpc/README.md](hpc/README.md) for configuration and examples.

## Security and scope

No credentials, site-specific SSH configuration, cluster login details,
Slurm accounts, or network routes are checked in. Jobs require explicit
resources and are subject to the cluster's ordinary permissions and queueing.
This repository never submits a job in CI.

For safety on a **public** repository, the self-hosted CI workflow runs only
on trusted pushes to the protected default branch or explicit manual dispatch.
It does not execute third-party pull request code on HPC runners.
