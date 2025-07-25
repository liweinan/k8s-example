# Kubernetes Validating Webhook Example

This project demonstrates a simple validating admission webhook for Kubernetes. The webhook ensures that any new pod created has a specific label (`required-label`).

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to connect to your cluster
- Docker (if you need to build the image from source)

## How it Works

1.  `main.go`: A simple Go HTTP server that listens for admission review requests from the Kubernetes API server.
2.  `deployment.yaml`: Deploys the webhook server as a pod in the cluster.
3.  `service.yaml`: Exposes the webhook server via a ClusterIP service.
4.  `validating-webhook.yaml`: Registers the webhook with the Kubernetes API, telling it to send pod validation requests to the service.
5.  `network-policy.yaml`: A network policy that allows the Kubernetes API server (from the `kube-system` namespace) to connect to the webhook pod. This is often required in clusters with network plugins like Cilium or Calico.

## Deployment Steps

### 1. Generate TLS Certificates

The API server communicates with the webhook over TLS. The following script generates a self-signed certificate authority (CA) and a server certificate for the webhook.

```bash
./generate-certs.sh
```

### 2. Create the TLS Secret

Create a Kubernetes secret to store the server certificate and key. The webhook pod will mount this secret.

```bash
sudo k8s kubectl create secret tls webhook-certs \
    --cert=webhook.crt \
    --key=webhook.key
```

### 3. Deploy the Webhook Server and Service

```bash
sudo k8s kubectl apply -f deployment.yaml
sudo k8s kubectl apply -f service.yaml
```

### 4. Apply the Network Policy

This policy allows the API server to call the webhook.

```bash
sudo k8s kubectl apply -f network-policy.yaml
```

### 5. Create the Validating Webhook Configuration

Now, register the webhook with the cluster. We need to inject the CA bundle into the configuration file so the API server can trust our webhook's certificate.

```bash
CA_BUNDLE=$(cat ca.crt | base64 | tr -d '\n')
sed "s/CA_BUNDLE_PLACEHOLDER/${CA_BUNDLE}/" validating-webhook.yaml | sudo k8s kubectl apply -f -
```

## Testing the Webhook

### Test Case 1: Create a Pod WITHOUT the required label (Should be rejected)

```bash
# You may need to delete the old pod first: sudo k8s kubectl delete pod test-pod-invalid
sudo k8s kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-invalid
spec:
  containers:
  - name: nginx
    image: nginx
EOF
```
You should see an error message from the webhook: `Error from server: error when creating "STDIN": admission webhook "pod-label-validator.example.com" denied the request: Pod must include the label 'required-label'`.

### Test Case 2: Create a Pod WITH the required label (Should be accepted)

```bash
sudo k8s kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-valid
  labels:
    required-label: "true"
spec:
  containers:
  - name: nginx
    image: nginx
EOF
```
You should see `pod/test-pod-valid created`.

## Cleanup

To remove all the resources created by this example, run the following commands:

```bash
# Delete the test pods
sudo k8s kubectl delete pod test-pod-invalid --ignore-not-found=true
sudo k8s kubectl delete pod test-pod-valid --ignore-not-found=true

# Delete the webhook configuration, service, deployment, secret, and network policy
sudo k8s kubectl delete validatingwebhookconfiguration pod-label-validator.example.com
sudo k8s kubectl delete service webhook-server
sudo k8s kubectl delete deployment webhook-server
sudo k8s kubectl delete secret webhook-certs
sudo k8s kubectl delete networkpolicy allow-webhook-access

# Delete the generated certificate files
rm ca.crt ca.key server.csr webhook.crt webhook.key
