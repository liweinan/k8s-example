# Pod Creation Test

This is a test project to verify pod creation and cache synchronization in Kubernetes using client-go, similar to how Prow's Plank component works.

## Purpose

The test program helps diagnose issues with:
- Pod creation permissions
- Cache synchronization
- Network connectivity
- API server responsiveness

It creates a test pod and waits for it to appear in the cache, measuring the time taken for cache synchronization.

## Prerequisites

- Go 1.21 or later
- Access to a Kubernetes cluster
- kubectl configured to access the cluster

## Setup

1. Initialize the Go module and download dependencies:
```bash
go mod tidy
```

2. Build the program:
```bash
go build pod-test.go
```

## Usage

### Running Locally

```bash
./pod-test
```

### Running Inside a Pod

1. Copy the binary to the target pod:
```bash
kubectl cp pod-test <namespace>/<pod-name>:/tmp/
```

2. Execute the test:
```bash
kubectl exec -it <namespace>/<pod-name> -- /tmp/pod-test
```

## Output

The program will:
1. Create a test pod with a unique name
2. Print when the pod is created
3. Wait for the pod to appear in the cache
4. Print the time taken for cache synchronization

Example output:
```
Creating pod test-pod-20240321123456...
Pod created: test-pod-20240321123456
Waiting for pod to appear in cache...
Pod test-pod-20240321123456 appeared in cache after 1.234s
```

## Configuration

The program uses the following configuration:
- Kubernetes API server: https://10.152.183.1:443
- Service account token: /var/run/secrets/kubernetes.io/serviceaccount/token
- CA certificate: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
- Namespace: default
- Pod timeout: 30 seconds

## Troubleshooting

If the test fails:
1. Check if the service account has necessary permissions
2. Verify network connectivity to the API server
3. Check API server logs for any errors
4. Ensure the pod creation timeout is sufficient

## Cleanup

The test pod will remain in the cluster after the test. To clean up:
```bash
kubectl delete pod test-pod-<timestamp>
``` 