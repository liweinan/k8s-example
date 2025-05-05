# SimpleApp Controller

A Kubernetes controller for managing SimpleApp custom resources. This controller watches for SimpleApp resources and logs their details.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Building the Controller](#building-the-controller)
- [Deployment](#deployment)
- [Usage](#usage)
- [Development](#development)
- [Cleanup](#cleanup)

## Prerequisites

- Go 1.20
- Docker
- Access to a Kubernetes cluster
- kubectl configured to access your cluster

## Project Structure

```
simpleapp-controller/
├── api/
│   └── v1/
│       ├── groupversion_info.go  # API group and version definitions
│       └── simpleapp_types.go    # SimpleApp CRD type definitions
├── controllers/
│   └── simpleapp_controller.go   # Controller implementation
├── Dockerfile                    # Container image build instructions
├── build-local.sh               # Local build script with proxy support
├── controller-deployment.yaml    # Kubernetes deployment manifests
├── go.mod                       # Go module dependencies
└── main.go                      # Main program entry point
```

## Quick Start

1. Deploy the CRD:
   ```bash
   kubectl apply -f ../simpleapp-crd.yaml
   ```

2. Build and deploy the controller:
   ```bash
   # Build the multi-arch image using the build script
   ./build-local.sh

   # Deploy the controller
   kubectl apply -f controller-deployment.yaml
   ```

3. Create a SimpleApp instance:
   ```bash
   kubectl apply -f simpleapp-instance.yaml
   ```

## Building the Controller

### Local Development Build

For local development and testing:
```bash
go build -o simpleapp-controller .
```

### Multi-Architecture Container Build

This project uses Docker Buildx to create multi-architecture container images that support both `linux/amd64` and `linux/arm64` platforms. This is particularly useful when developing on Apple Silicon (ARM64) Macs and deploying to Linux AMD64 servers.

#### Using the Build Script

The project includes a `build-local.sh` script that handles the build process with proxy support:

```bash
# Make the script executable
chmod +x build-local.sh

# Basic usage
./build-local.sh

# With DockerHub push enabled
./build-local.sh --push-to-dockerhub

# With proxy settings
./build-local.sh --proxy=http://localhost:7890

# With both DockerHub push and proxy settings
./build-local.sh --push-to-dockerhub --proxy=http://localhost:7890

# Disable proxy
./build-local.sh --no-proxy
```

The build script:
- Sets up a local Docker registry
- Handles proxy configuration (if needed)
- Builds and pushes multi-arch images
- Cleans up resources after build

Available options:
- `--push-to-dockerhub`: Push the built image to DockerHub
- `--proxy=URL`: Set proxy URL for build process (e.g., `--proxy=http://localhost:7890`)
- `--no-proxy`: Disable proxy usage

#### Manual Build Process

If you prefer to build manually:

1. Configure Docker Buildx:
   ```bash
   docker buildx create --use
   ```

2. Build and push the multi-arch image:
   ```bash
   # If you need to use a proxy (e.g., for network access)
   export http_proxy=http://localhost:7890
   export https_proxy=http://localhost:7890

   # Build and push the multi-arch image
   docker buildx build --platform linux/amd64,linux/arm64 -t weli/simpleapp-controller:latest --push .
   ```

3. Verify the multi-arch image:
   ```bash
   docker buildx imagetools inspect weli/simpleapp-controller:latest
   ```

#### Dockerfile Details

The Dockerfile uses a multi-stage build process with platform-specific configurations:
- Build stages use `--platform=$BUILDPLATFORM` to ensure they run on the host's architecture
- The Go build process uses `TARGETOS` and `TARGETARCH` build arguments
- The final stage uses a minimal distroless base image
- Includes proxy support and IPv4 preference for network operations

#### Key Features
- Supports both AMD64 and ARM64 architectures
- Uses multi-stage builds for smaller final image size
- Based on distroless image for security
- Built with Go 1.21
- CGO disabled for better compatibility

## Deployment

1. Update the image name in `controller-deployment.yaml` if needed:
   ```yaml
   image: weli/simpleapp-controller:latest  # Update this to your registry path
   ```

2. Deploy the controller and RBAC resources:
   ```bash
   kubectl apply -f controller-deployment.yaml
   ```

## Usage

### Creating a SimpleApp Resource

Create a file named `simpleapp-instance.yaml` with the following content:
```yaml
apiVersion: example.com/v1
kind: SimpleApp
metadata:
  name: my-simple-app
  namespace: default
spec:
  appName: my-app
  replicas: 3
```

Apply the resource:
```bash
kubectl apply -f simpleapp-instance.yaml
```

### Verifying the Controller

1. Check if the controller is running:
   ```bash
   kubectl get pods -l app=simpleapp-controller
   ```

2. View controller logs:
   ```bash
   kubectl logs -l app=simpleapp-controller
   ```
   You should see log messages like:
   ```
   Hello, World! AppName: my-app, Replicas: 3
   ```

## Development

### Running Locally
```bash
go run main.go
```

### Dependencies
- Go 1.20
- Kubernetes client-go v0.29.0
- controller-runtime v0.17.0

### Controller Behavior
- Watches for SimpleApp resources in the cluster
- Logs "Hello, World!" along with the AppName and Replicas when a SimpleApp is created or modified
- Uses structured logging for Kubernetes integration
- Includes health and readiness probes
- Runs with proper RBAC permissions

## Cleanup

To remove the controller and CRD:
```bash
kubectl delete -f controller-deployment.yaml
kubectl delete -f ../simpleapp-crd.yaml
kubectl delete simpleapps --all
``` 