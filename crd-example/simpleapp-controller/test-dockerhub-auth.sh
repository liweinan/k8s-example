#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
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
DOCKERHUB_USERNAME="weli"
DOCKERHUB_IMAGE_NAME="simpleapp-controller"
PROXY_URL="http://localhost:7890"
NO_PROXY="localhost,127.0.0.1,registry,registry:5000,localhost:5002,host.docker.internal"

# Check if password is provided
if [ -z "$DOCKERHUB_PASSWORD" ]; then
    error "DockerHub password is required"
    log "Please set the DOCKERHUB_PASSWORD environment variable"
    exit 1
fi

# Get token from auth.docker.io
log "Getting registry token..."
REGISTRY_TOKEN=$(curl -s \
    --proxy "$PROXY_URL" \
    --noproxy "$NO_PROXY" \
    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$DOCKERHUB_USERNAME/$DOCKERHUB_IMAGE_NAME:pull" \
    -u "$DOCKERHUB_USERNAME:$DOCKERHUB_PASSWORD" | jq -r .token)

if [ -z "$REGISTRY_TOKEN" ] || [ "$REGISTRY_TOKEN" = "null" ]; then
    error "Failed to get registry token"
    exit 1
fi

success "Successfully obtained registry token"

# Check repository manifest using registry.docker.io directly
log "Checking repository manifest..."
MANIFEST_RESPONSE=$(curl -s \
    --proxy "$PROXY_URL" \
    --noproxy "$NO_PROXY" \
    -H "Authorization: Bearer $REGISTRY_TOKEN" \
    -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
    "https://registry-1.docker.io/v2/$DOCKERHUB_USERNAME/$DOCKERHUB_IMAGE_NAME/manifests/latest")

if [ -z "$MANIFEST_RESPONSE" ]; then
    error "Empty response from Docker Hub"
    exit 1
fi

# Check for errors in response
if echo "$MANIFEST_RESPONSE" | grep -q "errors"; then
    error "Error in manifest response:"
    echo "$MANIFEST_RESPONSE" | jq .
    exit 1
fi

success "Successfully retrieved manifest"
echo "$MANIFEST_RESPONSE" | jq .

# Clean up
unset DOCKERHUB_PASSWORD
unset REGISTRY_TOKEN 