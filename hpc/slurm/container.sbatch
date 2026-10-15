#!/usr/bin/env bash
# Resource requests are supplied by hpc-submit rather than hardcoded in this file.
set -euo pipefail
image=$1; overlay=$2; dataset=$3; gpu=$4; unused_ray_gpus=$5; shift 5
[[ $1 == -- ]] || { echo 'missing command separator' >&2; exit 2; }
shift
(( $# > 0 )) || { echo 'missing command' >&2; exit 2; }
args=(exec --cleanenv)
if [[ $gpu == 1 ]]; then args+=(--nv); fi
if [[ -n $overlay ]]; then args+=(--overlay "${overlay}:ro"); fi
if [[ -n $dataset ]]; then args+=(--bind "${dataset}:/datasets:image-src=/"); fi
printf 'job=%s partition=%s hosts=%s cpus=%s\n' "${SLURM_JOB_ID:-?}" "${SLURM_JOB_PARTITION:-?}" "${SLURM_JOB_NODELIST:-?}" "${SLURM_CPUS_PER_TASK:-?}"
exec srun --ntasks=1 singularity "${args[@]}" "$image" "$@"
