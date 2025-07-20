# Kustomize Example

This project demonstrates a minimal usage of Kustomize to manage Kubernetes configurations for different environments.

## Structure

-   `base`: Contains the base Kubernetes resources (deployment and service).
-   `overlays`: Contains environment-specific configurations.
    -   `staging`: Overrides the base configuration for the staging environment.
    -   `production`: Overrides the base configuration for the production environment.

## Kustomize vs. `kubectl apply -f`

`kubectl apply -f <file>` is a direct, imperative way to apply configurations, while Kustomize offers a more structured, declarative approach.

-   **Configuration Reuse**: Kustomize excels at reusing a common `base` configuration across multiple environments (`overlays`) without duplicating YAML files. `kubectl apply -f` requires manual copying and modification for each environment.
-   **Template-Free**: Kustomize works by patching standard YAML files, avoiding the complexity of templating languages like Helm.
-   **Environment Management**: With Kustomize, the differences between environments are clearly defined in patches, making the configuration easier to manage and understand.

## Usage

To apply the configurations, you use `kubectl` with the `-k` flag pointing to an overlay directory (`staging` or `production`). Kustomize automatically includes the `base` resources and merges the overlay-specific patches, so you only need to apply the overlay.

### Apply Staging Configuration

```bash
kubectl apply -k overlays/staging
```

This command applies the base configuration along with the staging-specific patches (e.g., 3 replicas).

### Apply Production Configuration

```bash
kubectl apply -k overlays/production
```

This command applies the base configuration along with the production-specific patches (e.g., 5 replicas).

### View the Kustomized Output

To see the generated Kubernetes manifest without applying it, you can use `kubectl kustomize`:

```bash
# View staging output
kubectl kustomize overlays/staging

# View production output
kubectl kustomize overlays/production
