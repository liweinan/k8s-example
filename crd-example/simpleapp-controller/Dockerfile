# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM localhost:5002/golang:1.21-${TARGETARCH} AS deps

ARG TARGETARCH
ARG CONTAINER_PROXY_URL
ENV http_proxy=${CONTAINER_PROXY_URL}
ENV https_proxy=${CONTAINER_PROXY_URL}
ENV HTTP_PROXY=${CONTAINER_PROXY_URL}
ENV HTTPS_PROXY=${CONTAINER_PROXY_URL}

# Configure wget to prefer IPv4 and add retry logic
RUN echo 'prefer-family = IPv4' > /etc/wgetrc && \
    echo 'tries = 3' >> /etc/wgetrc && \
    echo 'timeout = 10' >> /etc/wgetrc && \
    echo "use_proxy = yes" >> /etc/wgetrc && \
    echo "http_proxy = ${CONTAINER_PROXY_URL}" >> /etc/wgetrc && \
    echo "https_proxy = ${CONTAINER_PROXY_URL}" >> /etc/wgetrc && \
    echo "no_proxy = localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal" >> /etc/wgetrc

# Configure Go proxy settings for container environment
RUN go env -w GOPROXY="https://goproxy.cn,direct" && \
    go env -w GONOSUMDB="*" && \
    go env -w GONOPROXY="*" && \
    go env -w GOINSECURE="*" && \
    go env -w GOPRIVATE="*"

# Print proxy environment for debugging
RUN echo "=== [deps] Proxy env ===" && env | grep -i proxy
RUN echo "=== [deps] Go env ===" && go env | grep -i proxy

# Test outbound connectivity with retries
RUN echo "=== [deps] Test outbound ===" && \
    echo "Using proxy: ${CONTAINER_PROXY_URL}" && \
    echo "Testing proxy connection..." && \
    for i in $(seq 1 3); do \
        echo "Attempt $i: Testing connection to auth.docker.io..." && \
        if wget -O- https://auth.docker.io/token; then \
            echo "Connection successful" && \
            exit 0; \
        else \
            echo "Connection attempt $i failed, retrying in 2 seconds..." && \
            sleep 2; \
        fi; \
    done && \
    echo "All connection attempts failed" && \
    exit 1

WORKDIR /app

# Download Go modules
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Build the Go binary
FROM deps AS builder
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build -o /app/simpleapp-controller

# Create minimal runtime image
FROM --platform=$TARGETPLATFORM localhost:5002/distroless-static:nonroot-${TARGETARCH}
COPY --from=builder /app/simpleapp-controller /simpleapp-controller
ENTRYPOINT ["/simpleapp-controller"]