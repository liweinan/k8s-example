# Kubernetes Webhook Example

This example demonstrates how to create and deploy a simple validating webhook in Kubernetes. The webhook ensures that any new pod created in the cluster has the `app` label.

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to connect to your cluster
- Docker installed and running
- `openssl` for generating certificates

## Steps

1.  **Generate TLS Certificates:**

    First, generate the necessary TLS certificates for the webhook server. The `generate-certs.sh` script will create a CA and use it to sign a server certificate.

    ```bash
    bash generate-certs.sh
    ```

2.  **Create a Kubernetes Secret:**

    Create a secret to store the webhook's server certificate and private key.

    ```bash
    kubectl create secret tls webhook-certs \
        --cert=webhook.crt \
        --key=webhook.key
    ```

3.  **Build and Load the Docker Image:**

    Build the Docker image for the webhook server and load it into your cluster's container runtime (e.g., Minikube's Docker daemon).

    ```bash
    # For Minikube, point your shell to Minikube's Docker daemon
    eval $(minikube docker-env)

    docker build -t webhook-server:latest .
    ```

4.  **Deploy the Webhook:**

    Deploy the webhook server and its associated resources to the cluster.

    ```bash
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    ```

5.  **Configure the Validating Webhook:**

    Before applying the `ValidatingWebhookConfiguration`, you need to inject the CA bundle into the `validating-webhook.yaml` file.

    ```bash
    CA_BUNDLE=$(cat ca.crt | base64 | tr -d '\n')
    sed "s/\${CA_BUNDLE}/$CA_BUNDLE/" validating-webhook.yaml | kubectl apply -f -
    ```

6.  **Test the Webhook:**

    Now, test the webhook by trying to create pods with and without the required `app` label.

    **a. Pod without the `app` label (should be rejected):**

    ```bash
    kubectl apply -f - <<EOF
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

    You should see an error message similar to this:
    `Error from server: error when creating "STDIN": admission webhook "pod-label-validator.example.com" denied the request: Required label 'app' is missing`

    **b. Pod with the `app` label (should be accepted):**

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-pod-valid
      labels:
        app: my-app
    spec:
      containers:
        - name: nginx
          image: nginx
    EOF
    ```

    This pod should be created successfully.

## Cleanup

To remove the resources created in this example, run the following commands:

```bash
kubectl delete pod test-pod-valid
kubectl delete validatingwebhookconfiguration pod-label-validator
kubectl delete service webhook-server
kubectl delete deployment webhook-server
kubectl delete secret webhook-certs
rm ca.crt ca.key ca.srl webhook.crt webhook.csr webhook.key
