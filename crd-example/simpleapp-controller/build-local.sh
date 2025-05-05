#!/bin/bash

# Exit on error
set -e

# Configuration
USE_PROXY=true  # Set to false to disable proxy
PROXY_URL="http://host.docker.internal:7890"  # Use host.docker.internal instead of localhost
REGISTRY_PORT=5002
REGISTRY_HOST="localhost"
IMAGE_NAME="simpleapp-controller"
IMAGE_TAG="latest"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Configure proxy settings
if [ "$USE_PROXY" = true ]; then
    log "Setting up proxy at $PROXY_URL..."
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    # Don't proxy local registry access
    export no_proxy="localhost,127.0.0.1,registry,registry:5000"
    export NO_PROXY="localhost,127.0.0.1,registry,registry:5000"
else
    log "Removing proxy settings..."
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY
fi

# Clean up any existing containers and builders
log "Cleaning up..."
docker rm -f registry 2>/dev/null || true
docker buildx rm multiarch-builder 2>/dev/null || true

# Create Docker network
log "Creating Docker network..."
docker network create registry-net 2>/dev/null || true

# Create registry config
log "Creating registry config..."
cat > registry-config.json << 'EOF'
[registry."localhost:5002"]
  http = true
  insecure = true
EOF

# Start local registry with explicit HTTP configuration
log "Starting local registry..."
docker run -d --name registry \
    --network registry-net \
    -p 5002:5000 \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
    -e REGISTRY_HTTP_NET=tcp \
    registry:2

# Wait for registry to be ready
log "Waiting for registry to be ready..."
until curl -s --noproxy "*" http://localhost:5002/v2/_catalog > /dev/null; do
    sleep 1
done

# Test registry connection
log "Testing registry connection..."
if curl -v --noproxy "*" http://localhost:5002/v2/_catalog; then
    success "Registry is accessible"
else
    error "Registry is not accessible"
    exit 1
fi

# Create and use a new builder
log "Creating new builder..."
BUILDX_ARGS=(
    --name multiarch-builder
    --driver docker-container
    --driver-opt network=host
    --config registry-config.json
)

if [ "$USE_PROXY" = true ]; then
    docker buildx create "${BUILDX_ARGS[@]}" --bootstrap
    CONTAINER_NAME="buildx_buildkit_multiarch-builder0"
    
    # Get host IP (force IPv4)
    HOST_IP=$(docker run --rm alpine sh -c "getent ahostsv4 host.docker.internal | awk 'NR==1{print \$1}'" || echo "192.168.65.2")
    log "Using host IP: $HOST_IP"
    
    # Add host.docker.internal to the buildx container with IPv4
    docker exec "$CONTAINER_NAME" sh -c "echo '$HOST_IP host.docker.internal' >> /etc/hosts"
    
    # Set proxy settings with IPv4 preference
    docker exec "$CONTAINER_NAME" sh -c "
        export http_proxy='$PROXY_URL'
        export https_proxy='$PROXY_URL'
        export HTTP_PROXY='$PROXY_URL'
        export HTTPS_PROXY='$PROXY_URL'
        export no_proxy='localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal'
        export NO_PROXY='localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal'
        # Force IPv4 for wget
        echo 'prefer-family = IPv4' > /etc/wgetrc
    "
else
    BUILDX_ARGS+=(
        --driver-opt env.http_proxy=""
        --driver-opt env.https_proxy=""
        --driver-opt env.HTTP_PROXY=""
        --driver-opt env.HTTPS_PROXY=""
        --driver-opt env.no_proxy="*"
        --driver-opt env.NO_PROXY="*"
        --bootstrap
    )
    docker buildx create "${BUILDX_ARGS[@]}"
fi

docker buildx use multiarch-builder

# Network diagnostics
log "Running network diagnostics..."
log "Checking registry container network..."
docker inspect registry | grep -A 10 "NetworkSettings"
log "Checking buildx container network..."
docker inspect buildx_buildkit_multiarch-builder0 | grep -A 10 "NetworkSettings"
log "Testing network connectivity between containers..."
docker run --rm --network registry-net registry:2 ping -c 1 registry
log "Testing registry access from network..."
docker run --rm --network registry-net curlimages/curl -v http://registry:5000/v2/_catalog

# Set up base images in local registry
log "Setting up base images in local registry..."

# Handle AMD64 base image
log "Handling AMD64 base image..."
docker pull --platform linux/amd64 golang:1.21
docker tag golang:1.21 localhost:5002/golang:1.21-amd64
docker push localhost:5002/golang:1.21-amd64

# Handle ARM64 base image
log "Handling ARM64 base image..."
docker pull --platform linux/arm64 golang:1.21
docker tag golang:1.21 localhost:5002/golang:1.21-arm64
docker push localhost:5002/golang:1.21-arm64

# Handle distroless base image
log "Handling distroless base image..."
docker pull --platform linux/amd64 gcr.io/distroless/static:nonroot
docker tag gcr.io/distroless/static:nonroot localhost:5002/distroless-static:nonroot
docker push localhost:5002/distroless-static:nonroot

# Verify images in registry
log "Verifying images in registry..."
curl -v --noproxy "*" http://localhost:5002/v2/golang/tags/list
curl -v --noproxy "*" http://localhost:5002/v2/distroless-static/tags/list

# Build the application image
log "Building the application image..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' 's/registry:5000/localhost:5002/g' Dockerfile
else
    # Linux
    sed -i 's/registry:5000/localhost:5002/g' Dockerfile
fi

# Prepare build arguments
BUILD_ARGS=(
    --progress=plain
    --platform linux/amd64,linux/arm64
)

# Add proxy settings to build if enabled
if [ "$USE_PROXY" = true ]; then
    BUILD_ARGS+=(
        --build-arg http_proxy="$PROXY_URL"
        --build-arg https_proxy="$PROXY_URL"
        --build-arg HTTP_PROXY="$PROXY_URL"
        --build-arg HTTPS_PROXY="$PROXY_URL"
        --build-arg no_proxy="localhost,127.0.0.1,registry,registry:5000"
        --build-arg NO_PROXY="localhost,127.0.0.1,registry,registry:5000"
    )
else
    BUILD_ARGS+=(
        --build-arg http_proxy=""
        --build-arg https_proxy=""
        --build-arg HTTP_PROXY=""
        --build-arg HTTPS_PROXY=""
        --build-arg no_proxy="*"
        --build-arg NO_PROXY="*"
    )
fi

BUILD_ARGS+=(
    -t localhost:5002/$IMAGE_NAME:$IMAGE_TAG
    --push
    .
)

docker buildx build "${BUILD_ARGS[@]}"

# Clean up
log "Cleaning up..."
rm -f registry-config.json
docker rm -f registry
docker buildx rm multiarch-builder
docker network rm registry-net

success "Build process completed successfully!"
success "Image available at: localhost:5002/$IMAGE_NAME:$IMAGE_TAG" 