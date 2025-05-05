#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Unset proxy environment variables
echo -e "${YELLOW}Removing proxy settings...${NC}"
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY

# Get host IP (use en0 interface on macOS)
HOST_IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
fi
echo -e "${YELLOW}Using host IP: $HOST_IP${NC}"

# Configure Docker to use insecure registry
echo -e "${YELLOW}Configuring Docker settings...${NC}"
if ! grep -q "insecure-registries" /Users/weli/.docker/daemon.json 2>/dev/null; then
    echo '{
  "insecure-registries": ["'$HOST_IP':5002"]
}' > /Users/weli/.docker/daemon.json
    echo -e "${YELLOW}Restarting Docker Desktop...${NC}"
    osascript -e 'quit app "Docker Desktop"'
    sleep 5
    open -a Docker
    echo -e "${YELLOW}Waiting for Docker to restart...${NC}"
    sleep 30
fi

# Function to check if registry is ready
check_registry() {
    echo -e "${BLUE}Waiting for registry to be ready...${NC}"
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}Attempt $attempt: Checking registry health...${NC}"
        # Check if container is running
        if ! docker ps | grep -q registry; then
            echo -e "${RED}Registry container is not running!${NC}"
            docker ps -a | grep registry
            return 1
        fi
        
        # Check registry logs
        echo -e "${YELLOW}Registry logs:${NC}"
        docker logs registry --tail 10
        
        # Check registry health endpoint
        if curl -s http://$HOST_IP:5002/v2/ > /dev/null; then
            echo -e "${GREEN}Registry is ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Registry not ready yet, waiting...${NC}"
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e "${RED}Registry failed to start after $max_attempts attempts${NC}"
    return 1
}

# Function to verify base images
verify_base_images() {
    echo -e "${BLUE}Verifying base images in registry...${NC}"
    local images=("python:3.11-slim-arm64" "python:3.11-slim-amd64")
    for image in "${images[@]}"; do
        echo -e "${YELLOW}Checking $image...${NC}"
        if ! curl -s http://$HOST_IP:5002/v2/python/manifests/$(echo $image | cut -d: -f2) > /dev/null; then
            echo -e "${RED}Failed to verify $image in registry${NC}"
            return 1
        fi
        echo -e "${GREEN}$image verified successfully${NC}"
    done
    return 0
}

# Cleanup function
cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    # Stop and remove existing registry container if it exists
    if docker ps -a | grep -q registry; then
        echo -e "${BLUE}Removing existing registry container...${NC}"
        docker stop registry || true
        docker rm registry || true
    fi

    # Remove existing builder if it exists
    if docker buildx ls | grep -q multiarch-builder; then
        echo -e "${BLUE}Removing existing builder...${NC}"
        docker buildx rm multiarch-builder || true
    fi
}

# Trap Ctrl+C and call cleanup
trap cleanup EXIT

echo -e "${BLUE}Starting local build process...${NC}"

# Cleanup before starting
cleanup

# Step 1: Start local registry
echo -e "${GREEN}Step 1: Starting local registry...${NC}"
docker run -d --name registry -p 5002:5000 \
    -v $(pwd)/registry-config.yml:/etc/docker/registry/config.yml \
    registry:2

# Wait for registry to be ready
check_registry || exit 1

# Step 2: Pull and push base images to local registry
echo -e "${GREEN}Step 2: Setting up base images in local registry...${NC}"
echo -e "${BLUE}Pulling and pushing Python base images...${NC}"

# For ARM64
echo -e "${BLUE}Handling ARM64 base image...${NC}"
docker pull --platform linux/arm64 python:3.11-slim
docker tag python:3.11-slim $HOST_IP:5002/python:3.11-slim-arm64
docker push $HOST_IP:5002/python:3.11-slim-arm64

# For AMD64
echo -e "${BLUE}Handling AMD64 base image...${NC}"
docker pull --platform linux/amd64 python:3.11-slim
docker tag python:3.11-slim $HOST_IP:5002/python:3.11-slim-amd64
docker push $HOST_IP:5002/python:3.11-slim-amd64

# Verify base images are in registry
verify_base_images || exit 1

# Step 3: Create a new builder instance
echo -e "${GREEN}Step 3: Creating new builder instance...${NC}"
docker buildx create --name multiarch-builder --driver docker-container --bootstrap
docker buildx use multiarch-builder

# Step 4: Verify the builder
echo -e "${GREEN}Step 4: Verifying builder...${NC}"
docker buildx inspect --bootstrap

# Step 5: Build and push to local registry
echo -e "${GREEN}Step 5: Building and pushing to local registry...${NC}"
echo -e "${YELLOW}Build command:${NC}"
echo "docker buildx build --platform linux/amd64,linux/arm64 -t $HOST_IP:5002/multiarch-example:latest --push --provenance=false --sbom=false ."
docker buildx build --platform linux/amd64,linux/arm64 \
    -t $HOST_IP:5002/multiarch-example:latest \
    --push --provenance=false --sbom=false .

# Step 6: Verify the build
echo -e "${GREEN}Step 6: Verifying the build...${NC}"
echo -e "${BLUE}Inspecting manifest list:${NC}"
docker buildx imagetools inspect $HOST_IP:5002/multiarch-example:latest

echo -e "${BLUE}Testing on native architecture:${NC}"
docker run --rm $HOST_IP:5002/multiarch-example:latest

echo -e "${BLUE}Testing on AMD64:${NC}"
docker run --rm --platform linux/amd64 $HOST_IP:5002/multiarch-example:latest

echo -e "${BLUE}Testing on ARM64:${NC}"
docker run --rm --platform linux/arm64 $HOST_IP:5002/multiarch-example:latest

echo -e "${GREEN}Local build process completed successfully!${NC}"
echo -e "${BLUE}You can now push to Docker Hub using the instructions in README.md${NC}" 