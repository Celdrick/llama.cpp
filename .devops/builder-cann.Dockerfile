# ==============================================================================
# Offline build environment for llama.cpp with CANN (Ascend NPU) support
# ==============================================================================
# This image contains all dependencies needed to compile llama.cpp with CANN
# in an offline environment for Huawei Ascend NPU (910b)

ARG CHIP_TYPE=910b
ARG CANN_BASE_IMAGE=ascendai/cann:8.5.0-${CHIP_TYPE}-openeuler24.03-py3.11

FROM ${CANN_BASE_IMAGE}

# Install all build dependencies for offline compilation
RUN yum install -y --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
    gcc \
    gcc-c++ \
    cmake \
    make \
    git \
    openssl-devel \
    pkg-config \
    python3 \
    python3-pip \
    curl \
    wget \
    && yum clean all \
    && rm -rf /var/cache/yum

# Set CANN environment variables (required for compilation)
ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${LIBRARY_PATH}
ENV LD_LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${ASCEND_TOOLKIT_HOME}/lib64/plugin/opskernel:${ASCEND_TOOLKIT_HOME}/lib64/plugin/nnengine:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe/op_tiling:${ASCEND_TOOLKIT_HOME}/aarch64-linux/devlib:${ASCEND_TOOLKIT_HOME}/runtime/lib64/stub:${LD_LIBRARY_PATH}
ENV PYTHONPATH=${ASCEND_TOOLKIT_HOME}/python/site-packages:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe:${PYTHONPATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${ASCEND_TOOLKIT_HOME}/compiler/ccec_compiler/bin:${PATH}
ENV ASCEND_AICPU_PATH=${ASCEND_TOOLKIT_HOME}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp
ENV TOOLCHAIN_HOME=${ASCEND_TOOLKIT_HOME}/toolkit
ENV ASCEND_HOME_PATH=${ASCEND_TOOLKIT_HOME}

# Create workspace directory
WORKDIR /workspace

# Default command - start bash for interactive build
CMD ["bash"]