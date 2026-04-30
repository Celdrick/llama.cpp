# ==============================================================================
# Offline build Dockerfile for llama.cpp (CANN version for Ascend NPU 910b)
# ==============================================================================
# This Dockerfile is designed to be used on offline ARM machines with
# llama.cpp:builder-cann image already loaded. It compiles llama.cpp with CANN
# support and creates a runnable image.
#
# Usage on offline machine:
#   1. Load builder image: docker load -i builder-cann.tar
#   2. Copy llama.cpp source to this directory
#   3. Build: docker build -t llama.cpp:cann-runtime -f offline-cann.Dockerfile .
#
# Prerequisites:
#   - llama.cpp:builder-cann image must be loaded
#   - llama.cpp source code in the build context
#   - Huawei Ascend NPU (910b) hardware available

# Use the same builder image for build and runtime stages
FROM llama.cpp:builder-cann AS build

WORKDIR /app

# Copy llama.cpp source
COPY . .

# Build llama.cpp with CANN support for Ascend 910b
RUN source /usr/local/Ascend/ascend-toolkit/set_env.sh --force && \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_CANN=ON \
        -DSOC_TYPE=ascend910b \
        -DUSE_ACL_GRAPH=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_TOOLS=ON \
        -DLLAMA_BUILD_SERVER=ON && \
    cmake --build build --config Release -j $(nproc)

# Runtime stage - reuse the same builder-cann image as base
# This avoids needing to pull CANN base image in offline environment
FROM llama.cpp:builder-cann AS runtime

WORKDIR /app

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