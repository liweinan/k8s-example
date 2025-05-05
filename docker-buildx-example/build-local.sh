#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Step 2: Create a new builder instance
echo -e "${GREEN}Step 2: Creating new builder instance...${NC}"
docker buildx create --name multiarch-builder --driver docker-container --bootstrap
docker buildx use multiarch-builder

# Step 3: Verify the builder
echo -e "${GREEN}Step 3: Verifying builder...${NC}"
docker buildx inspect --bootstrap

# Step 4: Build and push to local registry
echo -e "${GREEN}Step 4: Building and pushing to local registry...${NC}"
docker buildx build --platform linux/amd64,linux/arm64 \
    -t localhost:5002/multiarch-example:latest \
    --push --provenance=false --sbom=false .

# Step 5: Verify the build
echo -e "${GREEN}Step 5: Verifying the build...${NC}"
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