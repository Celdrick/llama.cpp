# ==============================================================================
# Offline build Dockerfile for llama.cpp (CUDA version)
# ==============================================================================
# This Dockerfile is designed to be used on offline machines with llama.cpp:builder-cuda
# image already loaded. It compiles llama.cpp with CUDA support and creates a runnable image.
#
# Usage on offline machine:
#   1. Load builder-cuda image: docker load -i builder-cuda.tar
#   2. Copy llama.cpp source to this directory
#   3. Build: docker build -t llama.cpp:cuda-runtime -f offline-cuda.Dockerfile .
#
# Prerequisites:
#   - llama.cpp:builder-cuda image must be loaded
#   - llama.cpp source code in the build context
#   - NVIDIA GPU with proper driver installed on host

ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04

# Use the builder-cuda image for build stage
FROM llama.cpp:builder-cuda AS build

WORKDIR /app

# Copy llama.cpp source
COPY . .

# CUDA architecture to build for (defaults to all supported archs)
ARG CUDA_DOCKER_ARCH=default

# Build llama.cpp with CUDA support
RUN if [ "${CUDA_DOCKER_ARCH}" != "default" ]; then \
    export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH}"; \
    fi && \
    cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_TOOLS=ON \
    -DLLAMA_BUILD_SERVER=ON \
    -DBUILD_SHARED_LIBS=OFF \
    ${CMAKE_ARGS} \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined . && \
    cmake --build build --config Release -j $(nproc)

# Collect shared libraries
RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# Runtime stage - use NVIDIA CUDA runtime image
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION} AS runtime

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgomp1 \
    libssl3 \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

# Copy shared libraries from build stage
COPY --from=build /app/lib/ /app

# Copy built binaries from build stage
COPY --from=build /app/build/bin/llama-cli /app/
COPY --from=build /app/build/bin/llama-server /app/

# Create directory for models
RUN mkdir -p /models

# Server configuration
ENV LLAMA_ARG_HOST=0.0.0.0

HEALTHCHECK --interval=5m CMD [ "curl", "-f", "http://localhost:8080/health" ]

# Default entrypoint - llama-server
ENTRYPOINT ["/app/llama-server"]