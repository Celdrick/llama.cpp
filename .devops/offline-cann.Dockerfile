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
# Note: builder-cann image already contains all build dependencies
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

# Collect .so files for runtime
RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# Runtime stage - reuse the same builder-cann image as base
# This avoids needing to pull CANN base image in offline environment
FROM llama.cpp:builder-cann AS runtime

WORKDIR /app

# Copy .so files from build stage
COPY --from=build /app/lib/ /app/

# Copy built binaries from build stage
COPY --from=build /app/build/bin/llama-cli /app/
COPY --from=build /app/build/bin/llama-server /app/

# Set locale
ENV LC_ALL=C.utf8

# Set CANN environment variables (required for runtime)
ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${LIBRARY_PATH}
ENV LD_LIBRARY_PATH=/app:${ASCEND_TOOLKIT_HOME}/lib64:${ASCEND_TOOLKIT_HOME}/lib64/plugin/opskernel:${ASCEND_TOOLKIT_HOME}/lib64/plugin/nnengine:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe/op_tiling:${ASCEND_TOOLKIT_HOME}/runtime/lib64/stub:${LD_LIBRARY_PATH}
ENV PYTHONPATH=${ASCEND_TOOLKIT_HOME}/python/site-packages:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe:${PYTHONPATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${ASCEND_TOOLKIT_HOME}/compiler/ccec_compiler/bin:${PATH}
ENV ASCEND_AICPU_PATH=${ASCEND_TOOLKIT_HOME}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp
ENV TOOLCHAIN_HOME=${ASCEND_TOOLKIT_HOME}/toolkit
ENV ASCEND_HOME_PATH=${ASCEND_TOOLKIT_HOME}

# Create directory for models
RUN mkdir -p /models

# Server configuration
ENV LLAMA_ARG_HOST=0.0.0.0

HEALTHCHECK --interval=5m CMD [ "curl", "-f", "http://localhost:8080/health" ]

# Default entrypoint - llama-server
ENTRYPOINT ["/app/llama-server"]