# SimpleApp Controller

A Kubernetes controller for managing SimpleApp custom resources. This controller watches for SimpleApp resources and logs their details.

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
├── controller-deployment.yaml    # Kubernetes deployment manifests
├── go.mod                       # Go module dependencies
└── main.go                      # Main program entry point
```

## Prerequisites

- Go 1.20
- Docker
- Access to a Kubernetes cluster
- kubectl configured to access your cluster

## Installation

1. First, deploy the CustomResourceDefinition (CRD):

```bash
kubectl apply -f ../simpleapp-crd.yaml
```

2. Build the controller binary locally (optional, for testing):

```bash
go build -o simpleapp-controller .
```

3. Build the Docker image:

```bash
docker build -t simpleapp-controller:latest .
```

4. Verify the Docker image:

```bash
docker images | grep simpleapp-controller
```

5. Update the image name in `controller-deployment.yaml` to match your registry:

```yaml
image: simpleapp-controller:latest  # Update this to your registry path if needed
```

6. Deploy the controller and RBAC resources:

```bash
kubectl apply -f controller-deployment.yaml
```

## Usage

1. Create a SimpleApp resource:

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

Save this to `simpleapp-instance.yaml` and apply:

```bash
kubectl apply -f simpleapp-instance.yaml
```

2. Verify the controller is running:

```bash
kubectl get pods -l app=simpleapp-controller
```

3. Check controller logs:

```bash
kubectl logs -l app=simpleapp-controller
```

You should see log messages like:
```
Hello, World! AppName: my-app, Replicas: 3
```

## Development

To run the controller locally for development:

```bash
go run main.go
```

## Dependencies

The project uses the following major dependencies:
- Go 1.20
- Kubernetes client-go v0.29.0
- controller-runtime v0.17.0

## Controller Behavior

The controller:
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