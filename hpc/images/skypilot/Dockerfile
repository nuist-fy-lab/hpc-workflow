FROM python:3.11-slim-bookworm

ARG SKY_VERSION=0.14.0
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# SkyPilot's Slurm provider connects to clusters using SSH.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Source distributions are built in GitHub Actions only. No package is
# compiled or unpacked on the target Slurm login node.
COPY wheels/ /opt/wheels/
RUN python -m pip install --only-binary=:all: \
       --find-links=/opt/wheels "skypilot[slurm]==${SKY_VERSION}" \
    && rm -rf /opt/wheels \
    && python -m pip check
