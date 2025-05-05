# Multi-stage build for creating a multi-architecture container image

# Global build arguments
ARG BASE_IMAGE=localhost:5002/golang:1.21-amd64
ARG TARGETARCH
ARG DISTROLESS_IMAGE=localhost:5002/distroless-static:nonroot-${TARGETARCH}

# Stage 1: Dependencies - Downloads Go module dependencies
FROM ${BASE_IMAGE} AS deps
WORKDIR /app

# Add host.docker.internal to hosts file for proxy access
RUN echo "$(getent hosts host.docker.internal | awk '{ print $1 }') host.docker.internal" >> /etc/hosts || true

# Force IPv4 for wget
RUN echo 'prefer-family = IPv4' > /etc/wgetrc

# Proxy debug
ARG http_proxy
ARG https_proxy
RUN echo "=== [deps] Proxy env ===" && env | grep -i proxy || true
RUN echo "=== [deps] Test outbound ===" && wget -O- https://auth.docker.io/token || true

COPY go.mod go.sum ./
RUN go mod download

# Stage 2: Builder - Compiles the Go binary
FROM ${BASE_IMAGE} AS builder
WORKDIR /app

# Add host.docker.internal to hosts file for proxy access
RUN echo "$(getent hosts host.docker.internal | awk '{ print $1 }') host.docker.internal" >> /etc/hosts || true

# Force IPv4 for wget
RUN echo 'prefer-family = IPv4' > /etc/wgetrc

# Proxy debug
ARG http_proxy
ARG https_proxy
RUN echo "=== [builder] Proxy env ===" && env | grep -i proxy || true
RUN echo "=== [builder] Test outbound ===" && wget -O- https://auth.docker.io/token || true

# Copy downloaded dependencies from the deps stage
COPY --from=deps /go/pkg/mod /go/pkg/mod
COPY . .

# Build arguments for cross-compilation
ARG TARGETOS=linux
ARG TARGETARCH

# Build the binary with CGO disabled for better compatibility
# GOOS and GOARCH are set based on the target platform
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o simpleapp-controller .

# Stage 3: Final - Creates the minimal production image
# Using distroless base image for security and minimal size
FROM ${DISTROLESS_IMAGE}
WORKDIR /

# (Optional) Proxy debug in final image, usually not needed
# RUN echo "=== [final] Proxy env ===" && env | grep -i proxy || true

# Copy the compiled binary from the builder stage
COPY --from=builder /app/simpleapp-controller .

# Run as non-root user for security
USER 65532:65532

ENTRYPOINT ["/simpleapp-controller"]