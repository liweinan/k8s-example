# Application Operator

A Kubernetes operator that manages application deployments with a simplified interface. This operator provides a custom resource `Application` that makes it easier to deploy and manage applications in Kubernetes.

## Features

- Simplified application deployment using a single custom resource
- Automatic creation of Deployments and Services
- Resource management (CPU and Memory limits/requests)
- Environment variable configuration
- Status monitoring and reporting
- Automatic reconciliation of desired state

## Prerequisites

- Kubernetes cluster
- kubectl configured to communicate with your cluster
- Go 1.19 or later
- Make

## Installation

1. Install the CRD:
```bash
make install
```

2. Run the operator:
```bash
make run
```

## Usage

### Creating an Application

Create an Application resource using the following YAML:

```yaml
apiVersion: apps.example.com/v1alpha1
kind: Application
metadata:
  name: sample-app
spec:
  image: nginx:latest
  replicas: 3
  port: 80
  resources:
    cpuRequest: "100m"
    memoryRequest: "128Mi"
    cpuLimit: "200m"
    memoryLimit: "256Mi"
  env:
    - name: ENVIRONMENT
      value: production
    - name: LOG_LEVEL
      value: info
```

Apply the configuration:
```bash
kubectl apply -f config/samples/apps_v1alpha1_application.yaml
```

### Application Resource Fields

- `image`: Container image to run
- `replicas`: Number of desired pods (default: 1)
- `port`: Port that the application listens on (default: 80)
- `resources`: Compute resource requirements
  - `cpuRequest`: CPU request (e.g., "100m", "0.1", "1")
  - `memoryRequest`: Memory request (e.g., "64Mi", "1Gi")
  - `cpuLimit`: CPU limit
  - `memoryLimit`: Memory limit
- `env`: List of environment variables
  - `name`: Environment variable name
  - `value`: Environment variable value

### Monitoring

The operator automatically updates the Application status with:
- Available replicas
- Ready replicas
- Updated replicas
- Conditions

View the status:
```bash
kubectl describe application <application-name>
```

### Generated Resources

The operator automatically creates and manages:
1. Deployment
   - Manages the application pods
   - Handles scaling and updates
2. Service
   - Type: ClusterIP
   - Exposes the application port

View the generated resources:
```bash
kubectl get deployments
kubectl get services
kubectl get pods
```

## Development

### Project Structure

```
operator-example/
├── api/                    # API definitions
│   └── v1alpha1/          # v1alpha1 API version
├── config/                # Configuration files
│   ├── crd/              # CRD definitions
│   └── samples/          # Sample resources
├── internal/             # Internal packages
│   └── controller/       # Controller implementation
└── cmd/                  # Command line entry point
```

### Building

Build the operator:
```bash
make build
```

### Testing

Run the tests:
```bash
make test
```

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

