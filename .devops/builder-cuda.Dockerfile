# Offline build environment for llama.cpp with CUDA support
# This image contains all dependencies needed to compile llama.cpp with CUDA in an offline environment

ARG UBUNTU_VERSION=24.04
ARG CUDA_VERSION=12.8.1

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}

ARG TARGETARCH

# Install all build dependencies for offline CUDA compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc-14 \
    g++-14 \
    make \
    cmake \
    git \
    libssl-dev \
    libgomp1 \
    pkg-config \
    ca-certificates \
    curl \
    wget \
    python3 \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Create workspace directory
WORKDIR /workspace

# Set environment variables
ENV CC=gcc-14 CXX=g++-14 CUDAHOSTCXX=g++-14

# Default command - start bash for interactive build
CMD ["bash"]