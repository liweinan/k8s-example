# Pod Test

A simple Go program to create and test a minimal Kubernetes pod using the nginx container.

## Prerequisites

- Go 1.21 or later
- Kubernetes cluster (tested with Ubuntu snap k8s)
- kubectl configured with proper permissions

## Building

1. Install dependencies:
```bash
go mod tidy
```

2. Build the program:
```bash
go build pod-test.go
```

## Running

Run the program with sudo (required for k8s snap):
```bash
sudo ./pod-test
```

Optional flags:
- `-debug`: Enable debug mode to show environment information
- `-namespace`: Specify the namespace (default: "default")
- `-kubeconfig`: Specify the kubeconfig path (default: auto-detected)

Example with debug mode:
```bash
sudo ./pod-test -debug
```

## Testing the Created Pod

Once the pod is running, you can interact with it in several ways:

1. Get a shell inside the pod:
```bash
sudo k8s kubectl exec -it <pod-name> -- /bin/sh
```

2. Test the nginx web server:
```bash
# From inside the pod
curl localhost:80

# From your host
curl http://<pod-ip>:80
```

3. View pod logs:
```bash
sudo k8s kubectl logs <pod-name>
```

4. Get pod details:
```bash
sudo k8s kubectl describe pod <pod-name>
```

5. Get pod IP and status:
```bash
sudo k8s kubectl get pod <pod-name> -o wide
```

## Pod Details

The created pod:
- Uses the nginx:latest image
- Exposes port 80
- Runs in the default namespace
- Has a unique name based on timestamp
- Includes a readiness check

## Troubleshooting

1. If you get permission errors:
   - Ensure you're running with sudo
   - Check that your k8s snap installation is working correctly

2. If the pod stays in Pending state:
   - Check node resources
   - Verify image pull permissions
   - Check pod events with `k8s kubectl describe pod <pod-name>`

3. If you can't connect to the pod:
   - Verify the pod is Running
   - Check the pod IP with `k8s kubectl get pod <pod-name> -o wide`
   - Ensure network policies allow the connection

## Cleanup

To delete the test pod:
```bash
sudo k8s kubectl delete pod <pod-name>
``` 