#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Unset proxy variables
log "Unsetting proxy variables..."
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset no_proxy
unset NO_PROXY

# Clean up
log "Cleaning up previous containers..."
docker rm -f registry 2>/dev/null || true
docker buildx rm test-builder 2>/dev/null || true

# Create a Docker network for the registry
log "Creating Docker network..."
docker network create registry-net 2>/dev/null || true

# Start registry
log "Starting registry..."
docker run -d --name registry --network registry-net -p 5002:5000 registry:2

# Wait for registry
log "Waiting for registry to be ready..."
sleep 5

# Test registry connection without proxy
log "Testing registry connection..."
if curl -v --noproxy "*" http://localhost:5002/v2/_catalog; then
    success "Registry is accessible"
else
    error "Registry is not accessible"
    exit 1
fi

# Push test image
log "Pulling base image..."
docker pull --platform linux/amd64 python:3.11-slim
log "Tagging image..."
docker tag python:3.11-slim localhost:5002/python:3.11-slim-amd64
log "Pushing to registry..."
docker push localhost:5002/python:3.11-slim-amd64

# Verify image in registry
log "Verifying image in registry..."
curl -v --noproxy "*" http://localhost:5002/v2/python/tags/list

# Create registry config
log "Creating registry config..."
cat > registry-config.json << 'EOF'
[registry."registry:5000"]
  http = true
  insecure = true
EOF

# Create builder with network access
log "Creating buildx builder..."
docker buildx create --name test-builder \
    --driver docker-container \
    --driver-opt env.http_proxy="" \
    --driver-opt env.https_proxy="" \
    --driver-opt env.HTTP_PROXY="" \
    --driver-opt env.HTTPS_PROXY="" \
    --driver-opt env.no_proxy="*" \
    --driver-opt env.NO_PROXY="*" \
    --driver-opt network=registry-net \
    --config registry-config.json \
    --bootstrap
docker buildx use test-builder

# Network diagnostics
log "Running network diagnostics..."
log "Checking registry container network..."
docker inspect registry | grep -A 10 "NetworkSettings"
log "Checking buildx container network..."
docker inspect buildx_buildkit_test-builder0 | grep -A 10 "NetworkSettings"
log "Testing network connectivity between containers..."
docker run --rm --network registry-net registry:2 ping -c 1 registry
log "Testing registry access from buildx container..."
docker run --rm --network registry-net curlimages/curl -v http://registry:5000/v2/_catalog

# Update Dockerfile.test to use registry container name
log "Updating Dockerfile.test..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' 's/localhost:5002/registry:5000/g' Dockerfile.test
else
    # Linux
    sed -i 's/localhost:5002/registry:5000/g' Dockerfile.test
fi

# Test build with no proxy
log "Testing build with verbose output and no proxy..."
docker buildx build \
    --progress=plain \
    --build-arg http_proxy="" \
    --build-arg https_proxy="" \
    --build-arg HTTP_PROXY="" \
    --build-arg HTTPS_PROXY="" \
    --build-arg no_proxy="*" \
    --build-arg NO_PROXY="*" \
    --load \
    -f Dockerfile.test .

# Clean up config
log "Cleaning up registry config..."
rm -f registry-config.json

# Clean up
log "Cleaning up..."
docker rm -f registry
docker buildx rm test-builder
docker network rm registry-net

success "Test completed" 