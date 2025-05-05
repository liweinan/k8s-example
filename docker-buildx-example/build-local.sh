#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if registry is ready
check_registry() {
    echo -e "${BLUE}Waiting for registry to be ready...${NC}"
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:5002/v2/ > /dev/null; then
            echo -e "${GREEN}Registry is ready!${NC}"
            return 0
        fi
        echo -e "${BLUE}Attempt $attempt: Registry not ready yet, waiting...${NC}"
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e "${RED}Registry failed to start after $max_attempts attempts${NC}"
    return 1
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
docker tag python:3.11-slim localhost:5002/python:3.11-slim-arm64
docker push localhost:5002/python:3.11-slim-arm64

# For AMD64
echo -e "${BLUE}Handling AMD64 base image...${NC}"
docker pull --platform linux/amd64 python:3.11-slim
docker tag python:3.11-slim localhost:5002/python:3.11-slim-amd64
docker push localhost:5002/python:3.11-slim-amd64

# Step 3: Create a new builder instance
echo -e "${GREEN}Step 3: Creating new builder instance...${NC}"
docker buildx create --name multiarch-builder --driver docker-container --bootstrap
docker buildx use multiarch-builder

# Step 4: Verify the builder
echo -e "${GREEN}Step 4: Verifying builder...${NC}"
docker buildx inspect --bootstrap

# Step 5: Build and push to local registry
echo -e "${GREEN}Step 5: Building and pushing to local registry...${NC}"
docker buildx build --platform linux/amd64,linux/arm64 \
    -t localhost:5002/multiarch-example:latest \
    --push --provenance=false --sbom=false .

# Step 6: Verify the build
echo -e "${GREEN}Step 6: Verifying the build...${NC}"
echo -e "${BLUE}Inspecting manifest list:${NC}"
docker buildx imagetools inspect localhost:5002/multiarch-example:latest

echo -e "${BLUE}Testing on native architecture:${NC}"
docker run --rm localhost:5002/multiarch-example:latest

echo -e "${BLUE}Testing on AMD64:${NC}"
docker run --rm --platform linux/amd64 localhost:5002/multiarch-example:latest

echo -e "${BLUE}Testing on ARM64:${NC}"
docker run --rm --platform linux/arm64 localhost:5002/multiarch-example:latest

echo -e "${GREEN}Local build process completed successfully!${NC}"
echo -e "${BLUE}You can now push to Docker Hub using the instructions in README.md${NC}" 