#!/usr/bin/env bash
# Ray >=2.49, installed inside SIF. Exclusive nodes requested by hpc-submit.
set -euo pipefail
image=$1; overlay=$2; dataset=$3; gpu=$4; ray_gpus=$5; shift 5
[[ $1 == -- ]] || { echo 'missing command separator' >&2; exit 2; }
shift
(( $# > 0 )) || { echo 'missing Ray entrypoint' >&2; exit 2; }
[[ ${SLURM_JOB_NUM_NODES:-0} -ge 2 ]] || { echo 'Ray needs >=2 allocated nodes' >&2; exit 2; }
nodes=$SLURM_JOB_NUM_NODES
head=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
[[ -n $head ]] || { echo 'empty Slurm nodelist' >&2; exit 2; }
# Exclusive node allocations avoid Ray port collisions with other tenants.
# This job owns allocated node resources and nothing outside its allocation.
port=$(( 12000 + SLURM_JOB_ID % 28000 ))
args=(exec --cleanenv)
if [[ $gpu == 1 ]]; then args+=(--nv); fi
if [[ -n $overlay ]]; then args+=(--overlay "${overlay}:ro"); fi
if [[ -n $dataset ]]; then args+=(--bind "${dataset}:/datasets:image-src=/"); fi
printf 'ray job=%s nodes=%s head=%s port=%s cpus/node=%s gpus/node=%s\n' "$SLURM_JOB_ID" "$nodes" "$head" "$port" "$SLURM_CPUS_PER_TASK" "$ray_gpus"
exec srun --nodes="$nodes" --ntasks="$nodes" --ntasks-per-node=1 \
  singularity "${args[@]}" "$image" ray symmetric-run \
    --address "${head}:${port}" --min-nodes "$nodes" \
    --num-cpus "$SLURM_CPUS_PER_TASK" --num-gpus "$ray_gpus" \
    -- "$@"
