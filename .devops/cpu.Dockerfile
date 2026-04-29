## Build image
FROM openeuler/openeuler:22.03 AS build

ARG TARGETARCH

RUN dnf makecache && \
    dnf install -y gcc gcc-c++ make git cmake openssl-devel

WORKDIR /app

COPY . .

RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DLLAMA_BUILD_TESTS=OFF; \
    else \
        echo "Unsupported architecture"; \
        exit 1; \
    fi && \
    cmake --build build -j $(nproc)

RUN mkdir -p /app/full \
    && cp build/bin/* /app/full \
    && cp *.py /app/full \
    && cp -r gguf-py /app/full \
    && cp -r requirements /app/full \
    && cp requirements.txt /app/full \
    && cp .devops/tools.sh /app/full/tools.sh

## Base image
FROM openeuler/openeuler:22.03 AS base

RUN dnf makecache && \
    dnf install -y glibc curl \
    && dnf clean all \
    && rm -rf /tmp/* /var/tmp/*

### Full
FROM base AS full

COPY --from=build /app/full /app

WORKDIR /app

RUN dnf makecache && \
    dnf install -y \
    git \
    python3 \
    python3-pip \
    python3-wheel \
    && pip install --upgrade setuptools \
    && pip install -r requirements.txt \
    && dnf clean all \
    && rm -rf /tmp/* /var/tmp/*

ENTRYPOINT ["/app/tools.sh"]

### Light, CLI only
FROM base AS light

COPY --from=build /app/full/llama-cli /app/full/llama-completion /app

WORKDIR /app

ENTRYPOINT [ "/app/llama-cli" ]

### Server, Server only
FROM base AS server

ENV LLAMA_ARG_HOST=0.0.0.0

COPY --from=build /app/full/llama-server /app

WORKDIR /app

HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]

ENTRYPOINT [ "/app/llama-server" ]
