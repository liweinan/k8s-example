# Kubernetes Examples Collection

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/liweinan/k8s-example)

This repository contains a collection of practical Kubernetes examples and tutorials, covering various aspects of Kubernetes deployment, configuration, and management.

## Project Structure

```
.
├── crd-example/           # Custom Resource Definition examples
├── docker-buildx-example/ # Multi-architecture Docker builds
├── ingress-example/       # Kubernetes Ingress configuration
├── oc-deploy-example/     # OpenShift deployment examples
├── operator-example/      # Kubernetes Operator patterns
├── pod-test/             # Pod configuration and testing
├── prow-example/         # Prow CI/CD configuration
├── deployment.yaml       # Basic Nginx deployment
├── service.yaml         # NodePort service example
└── docs/
    └── tutorial.md      # Detailed tutorials and guides
```

## Subprojects Overview

### 1. Basic Kubernetes Service
- **Files**: `deployment.yaml`, `service.yaml`
- **Description**: A minimal example of deploying an Nginx web server and exposing it via NodePort
- **Features**: Basic deployment and service configuration
- **Tutorial**: See [docs/tutorial.md](docs/tutorial.md)

### 2. Custom Resource Definitions (CRD)
- **Location**: `crd-example/`
- **Description**: Examples of creating and using Custom Resource Definitions in Kubernetes
- **Use Cases**: Extending Kubernetes API with custom resources

### 3. Docker Multi-Architecture Builds
- **Location**: `docker-buildx-example/`
- **Description**: Examples of using Docker Buildx for multi-architecture container builds
- **Features**: Cross-platform container builds

### 4. Kubernetes Ingress
- **Location**: `ingress-example/`
- **Description**: Examples of configuring Ingress resources for HTTP/HTTPS routing
- **Features**: Load balancing, SSL termination, path-based routing

### 5. OpenShift Deployment
- **Location**: `oc-deploy-example/`
- **Description**: Examples of deploying applications on OpenShift
- **Features**: OpenShift-specific configurations and best practices

### 6. Kubernetes Operator
- **Location**: `operator-example/`
- **Description**: Examples of building and deploying Kubernetes Operators
- **Features**: Custom controller patterns, operator SDK usage

### 7. Pod Testing
- **Location**: `pod-test/`
- **Description**: Examples of pod configuration and testing scenarios
- **Features**: Pod lifecycle management, testing patterns

### 8. Prow CI/CD
- **Location**: `prow-example/`
- **Description**: Examples of Prow CI/CD configuration for Kubernetes
- **Features**: Automated testing, code review, and deployment workflows

## Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/k8s-example.git
   cd k8s-example
   ```

2. Choose a subproject that matches your needs
3. Follow the specific instructions in each subproject's directory
4. For basic Kubernetes concepts, start with the tutorial in [docs/tutorial.md](docs/tutorial.md)

## Prerequisites

- A running Kubernetes cluster (Minikube, Kind, or cloud-based like EKS/GKE)
- `kubectl` installed and configured
- Basic understanding of Kubernetes concepts
- Docker (for container-related examples)
- Go (for operator and CRD examples)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. When contributing:
1. Create a new branch for your feature
2. Add appropriate documentation
3. Include tests where applicable
4. Follow the existing code style

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Prow Documentation](https://docs.prow.k8s.io/)
