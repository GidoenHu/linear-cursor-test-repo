# Cloud Agent base image: Python 3.12+ and Node.js 22
# Referenced by .cursor/environment.json

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    sudo \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Default `python3` -> 3.12
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Node.js 22 (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Common CLIs used by Cloud Agents
RUN corepack enable \
    && npm install -g pnpm@latest

# Non-root user expected by Cloud Agents
RUN id -u ubuntu &>/dev/null || useradd -m -s /bin/bash ubuntu \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu

WORKDIR /workspace
