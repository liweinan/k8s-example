#!/bin/bash

# Exit on error
set -e

# Configuration
USE_PROXY=true  # Set to false to disable proxy
PROXY_URL=""  # Will be set by command line argument
PUSH_TO_DOCKERHUB=false  # Set to true to push to DockerHub
DOCKERHUB_USERNAME=""  # Will be set by command line argument
REGISTRY_PORT=5002
REGISTRY_HOST="localhost"
IMAGE_NAME="app"
IMAGE_TAG="latest"
DOCKERHUB_IMAGE_NAME=""  # Will be set based on username

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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --no-proxy)
            USE_PROXY=false
            shift
            ;;
        --proxy=*)
            USE_PROXY=true
            PROXY_URL="${key#*=}"
            shift
            ;;
        --push-to-dockerhub)
            PUSH_TO_DOCKERHUB=true
            shift
            ;;
        --dockerhub-username=*)
            DOCKERHUB_USERNAME="${key#*=}"
            DOCKERHUB_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME"
            shift
            ;;
        *)
            error "Unknown option: $key"
            exit 1
            ;;
    esac
done

# Validate DockerHub settings if pushing
if [ "$PUSH_TO_DOCKERHUB" = true ]; then
    if [ -z "$DOCKERHUB_USERNAME" ]; then
        error "DockerHub username is required when pushing to DockerHub"
        exit 1
    fi
    log "Will push to DockerHub as: $DOCKERHUB_IMAGE_NAME"
fi

# Configure proxy settings
if [ "$USE_PROXY" = true ]; then
    if [ -z "$PROXY_URL" ]; then
        error "Proxy URL is required when proxying is enabled"
        exit 1
    fi
    log "Setting up proxy at $PROXY_URL..."
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    # Don't proxy local registry access
    export no_proxy="localhost,127.0.0.1,registry,registry:5000,localhost:5002"
    export NO_PROXY="localhost,127.0.0.1,registry,registry:5000,localhost:5002"
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
    --driver-opt image=moby/buildkit:buildx-stable-1
    --driver-opt env.BUILDKITD_FLAGS="--allow-insecure-entitlement=network.host --containerd-worker=true"
    --platform linux/amd64,linux/arm64
    --config registry-config.json
    --use
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

# Enable containerd image store and verify setup
docker buildx inspect multiarch-builder --bootstrap

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
docker pull --platform linux/amd64 python:3.11-slim
docker tag python:3.11-slim localhost:5002/python:3.11-slim-amd64
docker push localhost:5002/python:3.11-slim-amd64

# Handle ARM64 base image
log "Handling ARM64 base image..."
docker pull --platform linux/arm64 python:3.11-slim
docker tag python:3.11-slim localhost:5002/python:3.11-slim-arm64
docker push localhost:5002/python:3.11-slim-arm64

# Verify images in registry
log "Verifying images in registry..."
curl -v --noproxy "*" http://localhost:5002/v2/python/tags/list

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
    --builder multiarch-builder
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
        --build-arg no_proxy="localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"
        --build-arg NO_PROXY="localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"
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

# Add tags based on push target
BUILD_ARGS+=(
    -t localhost:5002/$IMAGE_NAME:$IMAGE_TAG
)

if [ "$PUSH_TO_DOCKERHUB" = true ]; then
    BUILD_ARGS+=(
        -t $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG
    )
fi

BUILD_ARGS+=(
    --push
    .
)

docker buildx build "${BUILD_ARGS[@]}"

# If pushing to DockerHub, verify the manifest
if [ "$PUSH_TO_DOCKERHUB" = true ]; then
    log "Verifying DockerHub manifest..."
    # First try to get the manifest without authentication
    CURL_ARGS=()
    if [ "$USE_PROXY" = true ]; then
        CURL_ARGS=(
            --proxy "$PROXY_URL"
            --noproxy "localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"
        )
    else
        CURL_ARGS=(
            --noproxy "*"
        )
    fi

    MANIFEST_INFO=$(curl -s "${CURL_ARGS[@]}" \
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        https://registry.hub.docker.com/v2/$DOCKERHUB_USERNAME/$IMAGE_NAME/manifests/$IMAGE_TAG)
    
    # If that fails, try with authentication
    if [ $? -ne 0 ] || [ -z "$MANIFEST_INFO" ]; then
        log "Trying to verify manifest with authentication..."
        # Get DockerHub token
        TOKEN=$(curl -s "${CURL_ARGS[@]}" \
            -H "Content-Type: application/json" \
            -X POST \
            -d '{"username": "'"$DOCKERHUB_USERNAME"'", "password": "'"$DOCKERHUB_PASSWORD"'"}' \
            https://hub.docker.com/v2/users/login/ | jq -r .token)
        
        if [ -n "$TOKEN" ]; then
            MANIFEST_INFO=$(curl -s "${CURL_ARGS[@]}" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
                https://registry.hub.docker.com/v2/$DOCKERHUB_USERNAME/$IMAGE_NAME/manifests/$IMAGE_TAG)
        fi
    fi
    
    if [ -n "$MANIFEST_INFO" ] && echo "$MANIFEST_INFO" | grep -q "amd64" && echo "$MANIFEST_INFO" | grep -q "arm64"; then
        success "DockerHub manifest verification successful - both architectures present"
    else
        log "Could not verify DockerHub manifest - this is expected if you don't have access to the repository"
        log "You can verify the manifest manually by running:"
        log "docker manifest inspect $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG"
    fi
    
    success "Successfully pushed multi-arch image to DockerHub: $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG"
fi

# Clean up
log "Cleaning up..."
rm -f registry-config.json
docker rm -f registry
docker buildx rm multiarch-builder
docker network rm registry-net

success "Build process completed successfully!"
success "Image available at: localhost:5002/$IMAGE_NAME:$IMAGE_TAG"
if [ "$PUSH_TO_DOCKERHUB" = true ]; then
    success "Image also available at: $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG"
fi 