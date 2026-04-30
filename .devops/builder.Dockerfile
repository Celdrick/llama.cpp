# Offline build environment for llama.cpp
# This image contains all dependencies needed to compile llama.cpp in an offline environment

ARG UBUNTU_VERSION=22.04

FROM ubuntu:$UBUNTU_VERSION

ARG TARGETARCH

# Install all build dependencies for offline compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    git \
    libssl-dev \
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

# Set environment variables for BMI2 and SSE42
ENV CC=gcc CXX=g++

# Default command - start bash for interactive build
CMD ["bash"]