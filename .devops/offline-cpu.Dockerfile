# ==============================================================================
# Offline build Dockerfile for llama.cpp (CPU version)
# ==============================================================================
# This Dockerfile is designed to be used on offline machines with llama.cpp:builder
# image already loaded. It compiles llama.cpp and creates a runnable image.
#
# Usage on offline machine:
#   1. Load builder image: docker load -i builder.tar
#   2. Copy llama.cpp source to this directory
#   3. Build: docker build -t llama.cpp:cpu-runtime -f offline-cpu.Dockerfile .
#
# Prerequisites:
#   - llama.cpp:builder image must be loaded
#   - llama.cpp source code in the build context

FROM llama.cpp:builder AS build

WORKDIR /app

# Copy llama.cpp source
COPY . .

# Build llama.cpp with CPU support (native auto-detection)
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_FATAL_WARNINGS=ON \
    -DGGML_RPC=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_TOOLS=ON \
    -DLLAMA_BUILD_SERVER=ON \
    -DBUILD_SHARED_LIBS=OFF

RUN cmake --build build --config Release -j $(nproc)

# Create runtime image
FROM ubuntu:22.04 AS runtime

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgomp1 \
    ca-certificates \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

# Copy built binaries
COPY --from=build /app/build/bin/llama-cli /app/
COPY --from=build /app/build/bin/llama-server /app/

# Create directory for models
RUN mkdir -p /models

# Server configuration
ENV LLAMA_ARG_HOST=0.0.0.0

HEALTHCHECK --interval=5m CMD [ "curl", "-f", "http://localhost:8080/health" ]

# Default entrypoint - llama-server
ENTRYPOINT ["/app/llama-server"]