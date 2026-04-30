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

# Create runtime image based on CANN base
FROM ascendai/cann:8.5.0-910b-openeuler24.03-py3.11 AS runtime

# Install runtime dependencies
RUN yum install -y --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
    libgomp \
    curl \
    && yum clean all \
    && rm -rf /var/cache/yum

# Set CANN environment variables for runtime
ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LD_LIBRARY_PATH=/app:${ASCEND_TOOLKIT_HOME}/lib64:${ASCEND_TOOLKIT_HOME}/aarch64-linux/devlib:${LD_LIBRARY_PATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${PATH}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp

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