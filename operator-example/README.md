# Kubernetes Operator Example using Kubebuilder

This example demonstrates how to create a Kubernetes operator using kubebuilder. The operator manages a custom resource called `Website` that automatically creates and manages deployments and services for web applications.

## Prerequisites

- Go 1.21 or later
- kubebuilder 3.14.0 or later
- Docker
- Kubernetes cluster (minikube, kind, or any other cluster)
- kubectl configured to communicate with your cluster

## Project Structure

```
operator-example/
├── api/                    # API definitions
│   └── v1/                # v1 version of the API
│       ├── website_types.go
│       └── website_webhook.go
├── config/                # Configuration files
│   ├── crd/              # CRD definitions
│   ├── rbac/             # RBAC configurations
│   ├── manager/          # Manager configurations
│   └── webhook/          # Webhook configurations
├── controllers/           # Controller implementations
│   └── website_controller.go
├── main.go               # Entry point
└── Makefile             # Build automation
```

## Features

- Custom Resource Definition (CRD) for Website resources
- Automatic deployment and service creation
- Status updates and conditions
- Webhook validation
- Metrics and health probes
- Leader election for high availability

## Getting Started

1. Initialize the project:
   ```bash
   kubebuilder init --domain example.com --repo github.com/yourusername/operator-example
   ```

2. Create the API:
   ```bash
   kubebuilder create api --group web --version v1 --kind Website
   ```

3. Build and deploy:
   ```bash
   make docker-build docker-push IMG=yourusername/operator-example:latest
   make deploy IMG=yourusername/operator-example:latest
   ```

4. Create a Website resource:
   ```yaml
   apiVersion: web.example.com/v1
   kind: Website
   metadata:
     name: example-website
   spec:
     image: nginx:latest
     replicas: 3
     port: 80
   ```

## Development

- Run locally:
  ```bash
  make run
  ```

- Run tests:
  ```bash
  make test
  ```

- Generate manifests:
  ```bash
  make manifests
  ```

## Cleanup

To remove the operator and its resources:
```bash
make undeploy
```

## License

MIT 