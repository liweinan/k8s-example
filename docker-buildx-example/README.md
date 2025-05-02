# Multi-Architecture Docker Build Example

This is a simple example demonstrating how to build Docker images for multiple architectures using Docker Buildx.

## Prerequisites

- Docker Desktop installed (with Buildx support)
- Docker Hub account (or other container registry)

## Building the Multi-Architecture Image

1. Create a new Buildx builder:
   ```bash
   docker buildx create --name mybuilder --use
   ```

2. Bootstrap the builder:
   ```bash
   docker buildx inspect --bootstrap
   ```

3. Build and push the multi-architecture image:
   ```bash
   docker buildx build \
     --platform linux/amd64,linux/arm64 \
     -t yourusername/multiarch-example:latest \
     --push .
   ```

   Replace `yourusername` with your Docker Hub username.

## Testing the Image

You can test the image on different architectures:

1. Run on your native architecture:
   ```bash
   docker run --rm yourusername/multiarch-example:latest
   ```

2. Run on a specific architecture (requires QEMU):
   ```bash
   docker run --rm --platform linux/amd64 yourusername/multiarch-example:latest
   ```

## Cleanup

To remove the Buildx builder:
```bash
docker buildx rm mybuilder
```

## Notes

- The application will display the Python version and the architecture it's running on
- The Dockerfile uses `--platform=$BUILDPLATFORM` to ensure proper multi-architecture support
- The image is based on Python 3.11 slim for a smaller footprint 