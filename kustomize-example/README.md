# Kustomize Example

This project demonstrates a minimal usage of Kustomize to manage Kubernetes configurations for different environments.

## Structure

- `base`: Contains the base Kubernetes resources (deployment and service).
- `overlays`: Contains environment-specific configurations.
  - `staging`: Overrides the base configuration for the staging environment.
  - `production`: Overrides the base configuration for the production environment.

## Usage

To apply the configurations, use `kubectl` with the `-k` flag, which points to a directory containing a `kustomization.yaml` file.

### Apply Base Configuration

```bash
kubectl apply -k base
```

### Apply Staging Configuration

```bash
kubectl apply -k overlays/staging
```

This will apply the base configuration along with the staging-specific patches (e.g., 3 replicas).

### Apply Production Configuration

```bash
kubectl apply -k overlays/production
```

This will apply the base configuration along with the production-specific patches (e.g., 5 replicas).

### View the Kustomized Output

To see the generated Kubernetes manifest without applying it, you can use `kubectl kustomize`:

```bash
# View staging output
kubectl kustomize overlays/staging

# View production output
kubectl kustomize overlays/production
