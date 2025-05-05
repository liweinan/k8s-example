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

# Configure Docker to use insecure registry
echo -e "${YELLOW}Configuring Docker settings...${NC}"
if ! grep -q "insecure-registries" /Users/weli/.docker/daemon.json 2>/dev/null; then
    echo '{
  "insecure-registries": ["localhost:5002"]
}' > /Users/weli/.docker/daemon.json
    echo -e "${YELLOW}Restarting Docker Desktop...${NC}"
    osascript -e 'quit app "Docker Desktop"'
    sleep 5
    open -a Docker
    echo -e "${YELLOW}Waiting for Docker to restart...${NC}"
    sleep 30
fi

# Function to check if registry is ready
check_registry_health() {
    echo -e "${YELLOW}Checking registry health...${NC}"
    if curl -s http://localhost:5002/v2/ > /dev/null; then
        echo -e "${GREEN}Registry is ready!${NC}"
        return 0
    else
        echo -e "${RED}Registry is not ready yet${NC}"
        return 1
    fi
}

echo -e "${BLUE}Starting local build process...${NC}"

# Clean up any existing containers
echo -e "${YELLOW}Cleaning up...${NC}"
docker rm -f registry 2>/dev/null || true

# Step 1: Start local registry
echo -e "${YELLOW}Step 1: Starting local registry...${NC}"
docker run -d --name registry -p 5002:5000 registry:2
echo -e "${YELLOW}Waiting for registry to be ready...${NC}"

# Wait for registry to be ready
max_attempts=5
attempt=1
while [ $attempt -le $max_attempts ]; do
    echo -e "${YELLOW}Attempt $attempt: Checking registry health...${NC}"
    echo -e "${YELLOW}Registry logs:${NC}"
    docker logs registry
    if check_registry_health; then
        break
    fi
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Registry failed to start after $max_attempts attempts${NC}"
        exit 1
    fi
    sleep 5
    attempt=$((attempt + 1))
done

# Step 2: Set up base images in local registry
echo -e "${YELLOW}Step 2: Setting up base images in local registry...${NC}"
echo -e "${YELLOW}Pulling and pushing Python base images...${NC}"

# Handle ARM64 base image
echo -e "${YELLOW}Handling ARM64 base image...${NC}"
docker pull python:3.11-slim
docker tag python:3.11-slim localhost:5002/python:3.11-slim
docker push localhost:5002/python:3.11-slim

# Step 3: Build the application image
echo -e "${YELLOW}Step 3: Building the application image...${NC}"
docker buildx build --platform linux/arm64 -t localhost:5002/app:latest --push .

# Step 4: Clean up
echo -e "${YELLOW}Step 4: Cleaning up...${NC}"
docker rm -f registry

echo -e "${GREEN}Build process completed successfully!${NC}"
echo -e "${GREEN}Image available at: localhost:5002/app:latest${NC}" 