#!/bin/bash

# Exit on error
set -e

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

# Configuration
USE_PROXY=true  # Set to false to disable proxy
PUSH_TO_DOCKERHUB=false  # Set to true to push to DockerHub
DOCKERHUB_USERNAME="weli"  # Your DockerHub username
PROXY_URL=""  # Will be set by command line argument
REGISTRY_PORT=5002
REGISTRY_HOST="localhost"
IMAGE_NAME="simpleapp-controller"
IMAGE_TAG="latest"
DOCKERHUB_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --push-to-dockerhub)
            PUSH_TO_DOCKERHUB=true
            shift
            ;;
        --no-proxy)
            USE_PROXY=false
            shift
            ;;
        --proxy=*)
            USE_PROXY=true
            PROXY_URL="${key#*=}"
            # Convert localhost to host.docker.internal for container operations
            CONTAINER_PROXY_URL=$(echo $PROXY_URL | sed 's/localhost/host.docker.internal/g')
            shift
            ;;
        *)
            error "Unknown option: $key"
            exit 1
            ;;
    esac
done

# Configure proxy settings
if [ "$USE_PROXY" = true ]; then
    if [ -z "$PROXY_URL" ]; then
        error "Proxy is enabled but no proxy URL was provided. Use --proxy=URL"
        exit 1
    fi
    log "Setting up proxy..."
    # Use localhost proxy for host operations
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    # Use container proxy for build args
    BUILD_PROXY_ARGS="--build-arg http_proxy=$CONTAINER_PROXY_URL --build-arg https_proxy=$CONTAINER_PROXY_URL"
    # Don't proxy local registry access
    export no_proxy="localhost,127.0.0.1,registry,registry:5000"
    export NO_PROXY="localhost,127.0.0.1,registry,registry:5000"
else
    log "Proxy disabled..."
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY
    BUILD_PROXY_ARGS=""
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
        --build-arg http_proxy="$CONTAINER_PROXY_URL"
        --build-arg https_proxy="$CONTAINER_PROXY_URL"
        --build-arg HTTP_PROXY="$CONTAINER_PROXY_URL"
        --build-arg HTTPS_PROXY="$CONTAINER_PROXY_URL"
        --build-arg no_proxy="localhost,127.0.0.1,registry,registry:5000"
    )
fi

# Build and push to local registry
log "Building and pushing to local registry..."
docker buildx build "${BUILD_ARGS[@]}" \
    -t localhost:5002/$IMAGE_NAME:$IMAGE_TAG \
    --push \
    .

success "Image built and pushed to local registry successfully"

# Push to DockerHub if enabled
if [ "$PUSH_TO_DOCKERHUB" = true ]; then
    log "Preparing to push to DockerHub..."
    
    # Pull images from local registry for each architecture
    log "Pulling AMD64 image from local registry..."
    docker pull localhost:5002/$IMAGE_NAME:$IMAGE_TAG
    docker tag localhost:5002/$IMAGE_NAME:$IMAGE_TAG $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-amd64
    
    log "Pulling ARM64 image from local registry..."
    docker pull --platform linux/arm64 localhost:5002/$IMAGE_NAME:$IMAGE_TAG
    docker tag localhost:5002/$IMAGE_NAME:$IMAGE_TAG $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-arm64
    
    # Push architecture-specific tags to DockerHub
    log "Pushing architecture-specific tags to DockerHub..."
    docker push $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-amd64
    docker push $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-arm64
    
    # Create and push multi-arch manifest
    log "Creating and pushing multi-arch manifest..."
    docker manifest create $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG \
        $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-amd64 \
        $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-arm64
    
    # Annotate the manifest with architecture and OS information
    docker manifest annotate $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG \
        $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-amd64 --os linux --arch amd64
    docker manifest annotate $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG \
        $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG-arm64 --os linux --arch arm64
    
    # Push the manifest
    docker manifest push $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG
    
    success "Successfully pushed multi-arch image to DockerHub: $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG"
fi

# Clean up
log "Cleaning up..."
docker buildx rm multiarch-builder || true
docker rm -f registry || true
docker network rm registry-net || true
rm -f registry-config.json || true

success "Build process completed successfully!" 