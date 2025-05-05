#!/bin/bash

# Exit on error
set -xe

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
SKIP_SETUP=false  # Set to true to skip network and builder setup

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
            shift
            ;;
        --dockerhub-username=*)
            DOCKERHUB_USERNAME="${key#*=}"
            DOCKERHUB_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME"
            shift
            ;;
        --skip-setup)
            SKIP_SETUP=true
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
        error "Proxy URL is required when proxying is enabled"
        exit 1
    fi
    # Convert localhost to host.docker.internal for container operations
    HOST_PROXY_URL=$(echo "$PROXY_URL" | sed 's/localhost/127.0.0.1/g')
    CONTAINER_PROXY_URL=$(echo "$PROXY_URL" | sed 's/localhost/host.docker.internal/g')
    log "Using proxy URL: $HOST_PROXY_URL (host) / $CONTAINER_PROXY_URL (container)"
    
    # Test proxy connection before proceeding
    log "Testing proxy connection..."
    if ! curl -s --noproxy "*" --connect-timeout 5 "$HOST_PROXY_URL" > /dev/null; then
        error "Proxy is not accessible at $HOST_PROXY_URL"
        error "Please ensure the proxy is running and accessible"
        exit 1
    fi
    success "Proxy connection test successful"

    # Test host.docker.internal resolution
    log "Testing host.docker.internal resolution..."
    if ! ping -c 1 host.docker.internal > /dev/null 2>&1; then
        log "host.docker.internal not resolved, trying alternative methods..."
        # Try to get the host IP from Docker
        HOST_IP=$(docker run --rm alpine sh -c "getent ahostsv4 host.docker.internal | awk 'NR==1{print \$1}'" || echo "192.168.65.2")
        log "Using host IP: $HOST_IP"
        CONTAINER_PROXY_URL=$(echo "$PROXY_URL" | sed "s/localhost/$HOST_IP/g")
        log "Updated container proxy URL: $CONTAINER_PROXY_URL"
    fi
    
    # Host proxy settings
    export http_proxy=$HOST_PROXY_URL
    export https_proxy=$HOST_PROXY_URL
    export HTTP_PROXY=$HOST_PROXY_URL
    export HTTPS_PROXY=$HOST_PROXY_URL
    export no_proxy="localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"
    export NO_PROXY="localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"
    
    # Configure Docker daemon proxy settings with host proxy
    mkdir -p ~/.docker
    cat > ~/.docker/config.json << EOF
{
    "proxies": {
        "default": {
            "httpProxy": "$HOST_PROXY_URL",
            "httpsProxy": "$HOST_PROXY_URL",
            "noProxy": "localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"
        }
    },
    "experimental": "enabled"
}
EOF

    # Enable experimental features for Docker CLI
    export DOCKER_CLI_EXPERIMENTAL=enabled

    # Configure Go module proxy settings with mirror
    export GOPROXY="https://goproxy.cn,direct"
    export GONOSUMDB="*"
    export GONOPROXY="*"
    export GOINSECURE="*"
    log "Using Go module mirror: $GOPROXY"

    # Test Go module mirror
    log "Testing Go module mirror..."
    if ! go env GOPROXY | grep -q "goproxy.cn"; then
        error "Failed to set Go module mirror"
        exit 1
    fi
    success "Go module mirror configured successfully"

    # Set container proxy settings for buildx (without Go proxy settings)
    BUILD_PROXY_ARGS="--build-arg http_proxy=$CONTAINER_PROXY_URL --build-arg https_proxy=$CONTAINER_PROXY_URL"
else
    log "Proxy disabled..."
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY
    unset GOPROXY
    unset GONOSUMDB
    unset GONOPROXY
    unset GOINSECURE
    BUILD_PROXY_ARGS=""
fi

# Clean up any existing containers and builders
if [ "$SKIP_SETUP" = false ]; then
    log "Cleaning up..."
    docker rm -f registry 2>/dev/null || true
    docker buildx rm multiarch-builder 2>/dev/null || true

    # Create Docker network
    log "Creating Docker network..."
    docker network create registry-net 2>/dev/null || true

    # Create registry configs
    log "Creating registry configs..."

    # Config for registry container
    cat > registry-config.yml << 'EOF'
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
compatibility:
  schema1:
    enabled: true
  manifest:
    enabled: true
    allow:
      - application/vnd.docker.distribution.manifest.v2+json
      - application/vnd.docker.distribution.manifest.list.v2+json
      - application/vnd.oci.image.manifest.v1+json
      - application/vnd.oci.image.index.v1+json
EOF

    # Config for buildx
    cat > registry-config.json << 'EOF'
[registry."localhost:5002"]
  http = true
  insecure = true
  mirrors = ["http://localhost:5002"]
EOF

    # Start local registry with explicit HTTP configuration and logging
    log "Starting local registry..."
    docker run -d --name registry \
        --network registry-net \
        -p 5002:5000 \
        -p 5003:5001 \
        -v $(pwd)/registry-config.yml:/etc/docker/registry/config.yml \
        -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
        -e REGISTRY_HTTP_NET=tcp \
        -e REGISTRY_LOG_LEVEL=debug \
        -e REGISTRY_LOG_FORMATTER=text \
        registry:2

    # Wait for registry to be ready
    log "Waiting for registry to be ready..."
    until curl -s --noproxy "*" http://localhost:5002/v2/_catalog > /dev/null; do
        sleep 1
    done

    # Show registry logs for debugging
    log "Registry logs:"
    docker logs registry

    # Test registry connection
    log "Testing registry connection..."
    if curl -v --noproxy "*" http://localhost:5002/v2/_catalog; then
        success "Registry is accessible"
    else
        error "Registry is not accessible"
        docker logs registry
        exit 1
    fi

    # Test registry manifest functionality
    log "Testing registry manifest functionality..."

    # Create test images
    log "Creating test images..."
    # Pull and tag AMD64 image
    log "Pulling and tagging AMD64 image..."
    docker pull --platform linux/amd64 busybox:latest
    docker tag busybox:latest localhost:5002/test-busybox:latest-amd64
    docker push localhost:5002/test-busybox:latest-amd64
    docker rmi busybox:latest localhost:5002/test-busybox:latest-amd64

    # Pull and tag ARM64 image
    log "Pulling and tagging ARM64 image..."
    docker pull --platform linux/arm64 busybox:latest
    docker tag busybox:latest localhost:5002/test-busybox:latest-arm64
    docker push localhost:5002/test-busybox:latest-arm64
    docker rmi busybox:latest localhost:5002/test-busybox:latest-arm64

    # Verify images are pushed correctly
    log "Verifying individual architecture images..."
    for arch in amd64 arm64; do
        log "Verifying ${arch} image..."
        MANIFEST_CHECK=$(curl -s --noproxy "*" \
            -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
            http://localhost:5002/v2/test-busybox/manifests/latest-${arch})
        if [ -z "$MANIFEST_CHECK" ]; then
            error "${arch} image manifest not found"
            docker logs --since 30s registry
            exit 1
        fi
        log "${arch} image manifest found: $MANIFEST_CHECK"
    done

    # Create and push multi-arch manifest using buildx
    log "Creating and pushing multi-arch manifest..."
    docker buildx imagetools create -t localhost:5002/test-busybox:latest \
        localhost:5002/test-busybox:latest-amd64 \
        localhost:5002/test-busybox:latest-arm64

    # Wait for manifest to be available
    log "Waiting for manifest to be available..."
    sleep 5

    # Verify the manifest list contains both architectures
    log "Verifying manifest exists in registry..."
    MANIFEST_RESPONSE=$(curl -s --noproxy "*" \
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        http://localhost:5002/v2/test-busybox/manifests/latest)
    log "Manifest response: $MANIFEST_RESPONSE"

    # Check if both architectures are present
    if ! echo "$MANIFEST_RESPONSE" | grep -q "amd64" || ! echo "$MANIFEST_RESPONSE" | grep -q "arm64"; then
        error "Manifest does not contain both architectures"
        docker logs --since 30s registry
        exit 1
    fi

    success "Test manifest contains both architectures"
else
    log "Skipping setup phase as requested..."
fi

# Now proceed with the actual build
log "Proceeding with main build process..."

if [ "$SKIP_SETUP" = false ]; then
    log "Creating new builder..."
    BUILDX_ARGS=(
        --name multiarch-builder
        --driver docker-container
        --driver-opt network=host
        --driver-opt image=moby/buildkit:buildx-stable-1
        --driver-opt env.BUILDKITD_FLAGS="--allow-insecure-entitlement=network.host --containerd-worker=true"
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
            export http_proxy='$CONTAINER_PROXY_URL'
            export https_proxy='$CONTAINER_PROXY_URL'
            export HTTP_PROXY='$CONTAINER_PROXY_URL'
            export HTTPS_PROXY='$CONTAINER_PROXY_URL'
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

    # Enable containerd image store
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
else
    log "Using existing builder..."
    docker buildx use multiarch-builder
fi

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

# Handle distroless base image for AMD64
log "Handling distroless base image for AMD64..."
docker pull --platform linux/amd64 gcr.io/distroless/static:nonroot
docker tag gcr.io/distroless/static:nonroot localhost:5002/distroless-static:nonroot-amd64
docker push localhost:5002/distroless-static:nonroot-amd64

# Handle distroless base image for ARM64
log "Handling distroless base image for ARM64..."
docker pull --platform linux/arm64 gcr.io/distroless/static:nonroot
docker tag gcr.io/distroless/static:nonroot localhost:5002/distroless-static:nonroot-arm64
docker push localhost:5002/distroless-static:nonroot-arm64

# Build and push multi-architecture image
log "Building and pushing multi-architecture image..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --push \
    -t "${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}" \
    --build-arg CONTAINER_PROXY_URL="${CONTAINER_PROXY_URL}" \
    --build-arg http_proxy="${CONTAINER_PROXY_URL}" \
    --build-arg https_proxy="${CONTAINER_PROXY_URL}" \
    .

# Verify the image was pushed successfully
log "Verifying image push..."
docker buildx imagetools inspect "${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}"
if [ $? -eq 0 ]; then
    success "Image successfully built and pushed to ${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}"
else
    error "Failed to verify image push"
    exit 1
fi

# Push to DockerHub if enabled
if [ "$PUSH_TO_DOCKERHUB" = true ]; then
    log "Preparing to push to DockerHub..."
    
    # Get token from auth.docker.io
    log "Getting registry token..."
    REGISTRY_TOKEN=$(curl -s --proxy ${HOST_PROXY_URL} --noproxy ${NO_PROXY} \
      "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${DOCKERHUB_IMAGE_NAME}:pull,push" \
      -u "${DOCKERHUB_USERNAME}:${DOCKERHUB_PASSWORD}" | jq -r .token)

    if [ -z "${REGISTRY_TOKEN}" ] || [ "${REGISTRY_TOKEN}" = "null" ]; then
      error "Failed to obtain registry token"
      exit 1
    fi

    success "Successfully obtained registry token"

    log "Checking repository manifest..."
    MANIFEST_RESPONSE=$(curl -s --proxy ${HOST_PROXY_URL} --noproxy ${NO_PROXY} \
      -H "Authorization: Bearer ${REGISTRY_TOKEN}" \
      -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
      "https://registry-1.docker.io/v2/${DOCKERHUB_IMAGE_NAME}/manifests/latest")

    echo "${MANIFEST_RESPONSE}"

    if echo "${MANIFEST_RESPONSE}" | grep -q "MANIFEST_UNKNOWN" || echo "${MANIFEST_RESPONSE}" | grep -q "errors"; then
      log "Repository does not exist yet or is empty, proceeding with push..."
    else
      success "Repository ${DOCKERHUB_IMAGE_NAME} is accessible"
      log "Current manifest:"
      echo "${MANIFEST_RESPONSE}" | jq .
    fi

    log "Pulling AMD64 image from local registry..."
    docker pull --platform linux/amd64 ${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:latest
    docker tag ${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:latest ${DOCKERHUB_IMAGE_NAME}:latest

    log "Pushing to DockerHub..."
    docker push ${DOCKERHUB_IMAGE_NAME}:latest

    log "Verifying DockerHub manifest..."
    for i in {1..3}; do
      log "Attempt $i: Verifying manifest..."
      MANIFEST_INFO=$(curl -s --proxy ${HOST_PROXY_URL} --noproxy ${NO_PROXY} \
        -H "Authorization: Bearer ${REGISTRY_TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        "https://registry-1.docker.io/v2/${DOCKERHUB_IMAGE_NAME}/manifests/latest")

      if [ -z "${MANIFEST_INFO}" ]; then
        error "Empty response from registry"
        if [ $i -lt 3 ]; then
          log "Retrying in 5 seconds..."
          sleep 5
          continue
        fi
        exit 1
      fi

      if echo "${MANIFEST_INFO}" | grep -q "errors"; then
        error "Error in manifest response:"
        echo "${MANIFEST_INFO}" | jq .
        if [ $i -lt 3 ]; then
          log "Retrying in 5 seconds..."
          sleep 5
          continue
        fi
        exit 1
      fi

      success "Image successfully pushed and verified on DockerHub"
      log "Final manifest:"
      echo "${MANIFEST_INFO}" | jq .
      break
    done
    
    success "Successfully pushed multi-arch image to DockerHub: $DOCKERHUB_IMAGE_NAME:$IMAGE_TAG"
fi

# Clean up
log "Cleaning up..."
if [ "$SKIP_SETUP" = false ]; then
    docker buildx rm multiarch-builder || true
    docker rm -f registry || true
    docker network rm registry-net || true
    rm -f registry-config.yml registry-config.json || true
else
    log "Skipping cleanup of builder and network as requested..."
fi

success "Build process completed successfully!" 