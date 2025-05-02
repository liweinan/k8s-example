# Docker Buildx Multi-Architecture Example

This is a minimal project that demonstrates how to build multi-architecture Docker images using Docker Buildx. The project includes a simple Python application and a Dockerfile configured for multi-arch builds.

## Project Structure

```
.
├── Dockerfile          # Multi-arch Dockerfile
├── app.py             # Simple Python application
└── README.md          # This file
```

## Prerequisites

- Docker Desktop with Buildx support
- Docker Hub account (for pushing images)
- Local Docker registry (for testing)

## Architecture Overview

```mermaid
graph TD
    subgraph Host Machine
        A[Docker Daemon] --> B[Local Registry]
        A --> C[Buildx Builder Container]
        C --> D[Build Container arm64]
        C --> E[Build Container amd64]
        E --> F[QEMU Container]
        F --> E
    end
    
    subgraph Build Process
        D --> G[arm64 Image]
        E --> H[amd64 Image]
        G --> I[Multi-arch Image]
        H --> I
    end
    
    subgraph Image Storage
        I --> B
        B --> J[arm64 Manifest]
        B --> K[amd64 Manifest]
        J --> L[arm64 Layers]
        K --> M[amd64 Layers]
    end
    
    subgraph Image Usage
        B --> N[Pull arm64 Image]
        B --> O[Pull amd64 Image]
    end

    style F fill:#f9f,stroke:#333,stroke-width:2px
```

Note: The QEMU container (highlighted in pink) is only created when building for non-native architectures. For example, when building an amd64 image on an arm64 machine, the QEMU container provides the necessary emulation environment.

## Build Process Flow

```mermaid
sequenceDiagram
    participant User
    participant Docker
    participant LocalRegistry
    participant Buildx
    participant BuildArm64
    participant BuildAmd64
    participant QEMU
    
    User->>Docker: docker login
    User->>Docker: docker pull python:3.11-slim
    User->>Docker: docker tag & push base image
    Docker->>LocalRegistry: Store base image
    
    User->>Docker: docker buildx create
    Docker->>Buildx: Create builder container
    Buildx->>BuildArm64: Create arm64 build container
    Buildx->>BuildAmd64: Create amd64 build container
    BuildAmd64->>QEMU: Create QEMU container
    
    User->>Docker: docker buildx build
    Docker->>Buildx: Start build process
    
    par arm64 build
        Buildx->>BuildArm64: Build native image
        BuildArm64->>Buildx: Return arm64 image layers
    and amd64 build
        Buildx->>BuildAmd64: Build amd64 image
        BuildAmd64->>QEMU: Use emulation
        QEMU->>BuildAmd64: Provide emulated environment
        BuildAmd64->>Buildx: Return amd64 image layers
    end
    
    Buildx->>Buildx: Create manifest list
    Buildx->>LocalRegistry: Push multi-arch image with manifest
```

## How QEMU Emulation Works

When building an AMD64 image on an ARM64 machine, the process works as follows:

1. **Binary Format Registration**:
   - The QEMU container registers binary formats in the host's `/proc/sys/fs/binfmt_misc/`
   - This tells the kernel how to handle AMD64 binaries on ARM64

2. **Build Process**:
   - The AMD64 build container provides a complete AMD64 environment
   - It manages the build context, layers, and Dockerfile instructions
   - When AMD64 binaries need to be executed:
     - The kernel intercepts the execution
     - Forwards it to QEMU in the QEMU container
     - QEMU emulates the AMD64 environment and executes the binaries
     - Results are returned to the build container

3. **Why Two Containers?**
   - **AMD64 Build Container**:
     - Provides a complete AMD64 environment
     - Manages build context and layers
     - Handles Dockerfile instructions
     - Maintains correct file system structure
     - Manages build dependencies and tools
   
   - **QEMU Container**:
     - Provides CPU emulation
     - Handles binary execution
     - Manages system call translation
     - Does not manage build environment

4. **Example Flow**:
   ```mermaid
   sequenceDiagram
       participant Build as AMD64 Build Container
       participant Kernel as Host Kernel
       participant QEMU as QEMU Container
       
       Build->>Kernel: Execute AMD64 binary
       Note over Build,Kernel: Build container manages environment
       Kernel->>QEMU: Forward execution
       QEMU->>QEMU: Emulate AMD64 environment
       QEMU->>Kernel: Return results
       Kernel->>Build: Return execution results
       Note over Build,Kernel: Build container continues build process
   ```

This separation of concerns allows:
- The build container to focus on managing the build environment and process
- The QEMU container to focus on CPU emulation
- Better isolation and reliability of the build process
- Proper handling of architecture-specific build requirements

## Dockerfile Explanation

The Dockerfile is configured to support multi-architecture builds using architecture-specific base images and a target-platform-based final stage:

```dockerfile
# Stage 1: Build for AMD64
FROM --platform=linux/amd64 localhost:5002/python:3.11-slim-amd64 AS amd64_builder
WORKDIR /build
RUN echo "Building for AMD64" > arch.txt
RUN echo "AMD64 specific build steps" > build.log
RUN echo "Hello from AMD64!" > message.txt

# Stage 2: Build for ARM64
FROM --platform=linux/arm64 localhost:5002/python:3.11-slim-arm64 AS arm64_builder
WORKDIR /build
RUN echo "Building for ARM64" > arch.txt
RUN echo "ARM64 specific build steps" > build.log
RUN echo "Hello from ARM64!" > message.txt

# Final stage: Combine results
FROM localhost:5002/python:3.11-slim-amd64 AS final_amd64
FROM localhost:5002/python:3.11-slim-arm64 AS final_arm64
FROM final_$TARGETARCH
WORKDIR /app

# Clean up any existing files first
RUN rm -rf /app/*

# Copy build artifacts from both architectures
COPY --from=amd64_builder /build/arch.txt /app/amd64_arch.txt
COPY --from=amd64_builder /build/message.txt /app/amd64_message.txt
COPY --from=arm64_builder /build/arch.txt /app/arm64_arch.txt
COPY --from=arm64_builder /build/message.txt /app/arm64_message.txt

# Copy and make the app executable
COPY app.py .
RUN chmod +x app.py

# Verify the contents of /app
RUN ls -la /app

# Set the entrypoint
ENTRYPOINT ["./app.py"]
```

### Key Features of the Multi-Stage Build:

1. **Architecture-Specific Base Images**:
   - Uses tagged base images for each architecture (`python:3.11-slim-amd64` and `python:3.11-slim-arm64`)
   - Ensures correct base image selection for each build stage
   - Prevents SHA256 hash confusion issues

2. **Platform-Specific Build Stages**:
   - `amd64_builder`: Runs on AMD64 platform with AMD64-specific base image
   - `arm64_builder`: Runs on ARM64 platform with ARM64-specific base image
   - Each stage can have its own build process and dependencies

3. **Dynamic Final Stage Selection**:
   - Creates separate final stages for each architecture
   - Uses `$TARGETARCH` to automatically select the correct final image
   - Ensures proper runtime environment for each platform

4. **Build Artifact Management**:
   - Cleans up target directory before copying files
   - Copies build artifacts from both architectures
   - Verifies file contents with directory listing
   - Maintains proper file permissions

---

这三行的含义以及最后一行 `FROM final_$TARGETARCH` 的作用如下：

### 三行代码的含义
```dockerfile
# Final stage: Combine results
FROM localhost:5002/python:3.11-slim-amd64 AS final_amd64
FROM localhost:5002/python:3.11-slim-arm64 AS final_arm64
FROM final_$TARGETARCH
```

1. **`FROM localhost:5002/python:3.11-slim-amd64 AS final_amd64`**
   - 定义了一个名为 `final_amd64` 的构建阶段，基于 `localhost:5002/python:3.11-slim-amd64` 镜像，用于 AMD64 架构的最终镜像。
   - 这一阶段为 AMD64 架构准备了一个基础镜像。

2. **`FROM localhost:5002/python:3.11-slim-arm64 AS final_arm64`**
   - 定义了一个名为 `final_arm64` 的构建阶段，基于 `localhost:5002/python:3.11-slim-arm64` 镜像，用于 ARM64 架构的最终镜像。
   - 这一阶段为 ARM64 架构准备了一个基础镜像。

3. **`FROM final_$TARGETARCH`**
   - 这一行使用了 Docker 构建时的架构变量 `$TARGETARCH`，动态选择最终镜像的基础阶段（`final_amd64` 或 `final_arm64`）。
   - `$TARGETARCH` 是一个在构建多架构镜像时由 Docker 自动设置的环境变量，表示目标架构（例如 `amd64` 或 `arm64`）。
   - 根据构建时的目标架构，Docker 会将 `final_$TARGETARCH` 解析为 `final_amd64` 或 `final_arm64`，从而选择对应的基础镜像。

### 为什么需要最后一行 `FROM final_$TARGETARCH`？
最后一行是实现 **多架构支持** 的关键。以下是具体原因：

1. **动态选择架构**：
   - Docker 的多架构构建（multi-architecture build）需要在同一个 Dockerfile 中支持不同的硬件架构（例如 AMD64 和 ARM64）。
   - 通过 `final_amd64` 和 `final_arm64` 定义了两个架构特定的构建阶段，但最终镜像需要根据目标平台动态选择其中一个。
   - `FROM final_$TARGETARCH` 使用 `$TARGETARCH` 变量来动态选择正确的阶段（`final_amd64` 或 `final_arm64`），确保最终镜像基于目标架构的正确基础镜像。

2. **支持 Docker BuildKit 的多架构构建**：
   - 当使用 Docker BuildKit（默认在现代 Docker 版本中启用）进行构建时，`--platform` 参数可以指定多个目标架构（例如 `linux/amd64,linux/arm64`）。
   - `$TARGETARCH` 变量会根据 `--platform` 的值自动设置为 `amd64` 或 `arm64`，从而让 Dockerfile 在构建时自动适配目标架构。
   - 没有 `FROM final_$TARGETARCH`，Docker 无法动态选择正确的最终镜像，导致无法生成多架构镜像。

3. **简化 Dockerfile 的逻辑**：
   - 直接使用 `FROM final_$TARGETARCH` 避免了为每种架构编写单独的 Dockerfile 或使用复杂的条件逻辑。
   - 它将架构选择交给 Docker 的构建系统，保持 Dockerfile 的简洁性和可维护性。

### 总结
- 这三行代码通过定义两个架构特定的最终阶段（`final_amd64` 和 `final_arm64`）并使用 `FROM final_$TARGETARCH` 来动态选择正确的阶段，实现了多架构镜像的构建。
- 最后一行 `FROM final_$TARGETARCH` 是必需的，因为它通过 `$TARGETARCH` 变量动态选择目标架构的基础镜像，确保构建的镜像与目标平台兼容。这是多架构 Dockerfile 的常见模式，特别是在使用 Docker BuildKit 构建多平台镜像时。

---

### Best Practices to Minimize Warnings

1. **Base Image Handling**:
   - Prepare architecture-specific base images:
     ```bash
     # Pull and tag AMD64 image
     docker pull --platform linux/amd64 python:3.11-slim
     docker tag python:3.11-slim localhost:5002/python:3.11-slim-amd64
     
     # Pull and tag ARM64 image
     docker pull --platform linux/arm64 python:3.11-slim
     docker tag python:3.11-slim localhost:5002/python:3.11-slim-arm64
     
     # Push to local registry
     docker push localhost:5002/python:3.11-slim-amd64
     docker push localhost:5002/python:3.11-slim-arm64
     ```
   - Use explicit platform specifications in build stages
   - Use `$TARGETARCH` for final stage selection
   - Maintain separate base images for each architecture in local registry

2. **Build and Test Process**:
   - Build multi-arch images with explicit platforms:
     ```bash
     docker buildx build --platform linux/amd64,linux/arm64 -t localhost:5002/multiarch-example:latest --push .
     ```
   - Test each architecture variant:
     ```bash
     # Test native architecture version
     docker run --rm localhost:5002/multiarch-example:latest
     
     # Test specific architecture version
     docker run --rm --platform linux/amd64 localhost:5002/multiarch-example:latest
     ```
   - Verify both architecture variants work correctly
   - Use `--push` flag to ensure proper image publishing

3. **Platform Selection and Variables**:
   - Use explicit platform specifications only in build stages
   - Let final stage inherit target platform through `$TARGETARCH`
   - Keep base images for all target platforms in local registry
   - Verify image functionality on all target architectures

## Architecture Compatibility

| Host Architecture | Compatible Variants |
|------------------|---------------------|
| arm64            | arm64/v8, arm64     |
| amd64            | amd64, x86_64       |
| arm/v7           | arm/v7, arm32       |

## Architecture Selection Process

When pulling and running a multi-architecture image, Docker automatically selects the appropriate architecture based on several factors:

### Automatic Architecture Selection

1. **Host Architecture Detection**
   ```mermaid
   sequenceDiagram
       participant User
       participant Docker
       participant Registry
       participant Host
       
       User->>Docker: docker pull multiarch-example:latest
       Docker->>Host: Detect system architecture
       Host-->>Docker: Return architecture (e.g., arm64)
       Docker->>Registry: Request manifest list
       Registry-->>Docker: Return manifest list
       Docker->>Docker: Match host architecture to manifest
       Docker->>Registry: Pull matching architecture image
       Registry-->>Docker: Return architecture-specific image
   ```

2. **Selection Process**
   - Docker first detects the host system's architecture
   - When pulling an image, it requests the manifest list
   - The manifest list contains all available architectures
   - Docker matches the host architecture with the available options
   - The matching architecture-specific image is pulled

3. **Fallback Behavior**
   - If exact architecture match isn't found, Docker looks for compatible variants
   - Example: `arm64` might use `arm64/v8` if available
   - If no compatible architecture is found, pull fails

### Manual Architecture Selection

You can override the automatic selection using the `--platform` flag:

```bash
# Force using amd64 architecture
docker run --platform linux/amd64 multiarch-example:latest

# Force using arm64 architecture
docker run --platform linux/arm64 multiarch-example:latest
```

## Step-by-Step Guide

### Step 1: Setup Local Registry with Manifest Support

1. Create a registry configuration file (`registry-config.yml`):
```yaml
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
compatibility:
  schema1:
    enabled: true
  manifest:
    enabled: true
    allow:
      - application/vnd.docker.distribution.manifest.v2+json
      - application/vnd.docker.distribution.manifest.list.v2+json
      - application/vnd.oci.image.manifest.v1+json
      - application/vnd.oci.image.index.v1+json
```

2. Start the registry with manifest support:
```bash
# Start a local registry with manifest support (using port 5002)
docker run -d -p 5002:5000 --name registry \
    -v $(pwd)/registry-config.yml:/etc/docker/registry/config.yml \
    registry:2
```

### Step 2: Setup Buildx Builder

Create a Buildx builder that uses the Docker daemon directly:

```bash
# Create a new builder that uses the Docker daemon directly
docker buildx create --use --name mybuilder --driver docker-container --driver-opt network=host
```

### Step 3: Prepare Base Images

Before building the multi-arch image, prepare architecture-specific base images in the local registry:

```bash
# Pull and tag AMD64 image
docker pull --platform linux/amd64 python:3.11-slim
docker tag python:3.11-slim localhost:5002/python:3.11-slim-amd64
docker push localhost:5002/python:3.11-slim-amd64

# Pull and tag ARM64 image
docker pull --platform linux/arm64 python:3.11-slim
docker tag python:3.11-slim localhost:5002/python:3.11-slim-arm64
docker push localhost:5002/python:3.11-slim-arm64
```

### Step 4: Build and Push to Local Registry

Build and push the multi-architecture image to your local registry:

1. Build and push both architectures in a single command:
```bash
# Build and push both architectures
docker buildx build --platform linux/amd64,linux/arm64 \
    -t localhost:5002/multiarch-example:latest \
    --push --provenance=false --sbom=false .

# Verify the manifest list was created
docker buildx imagetools inspect localhost:5002/multiarch-example:latest
```

Note: The `--provenance=false --sbom=false` flags disable the generation of attestation manifests.

### Step 5: Verify the Build

After pushing to the local registry, verify the multi-architecture image:

1. Test the image on different architectures:
```bash
# Run on your native architecture
docker run --rm localhost:5002/multiarch-example:latest

# Run on AMD64 (will use emulation if not on AMD64 machine)
docker run --rm --platform linux/amd64 localhost:5002/multiarch-example:latest

# Run on ARM64 (will use emulation if not on ARM64 machine)
docker run --rm --platform linux/arm64 localhost:5002/multiarch-example:latest
```

The application will display:
- Python version
- Architecture information
- Platform details
- Build artifacts from both architectures

### Step 6: Push to Docker Hub

After verifying the multi-arch image works in the local registry, push it to Docker Hub:

1. Tag and push each architecture:
```bash
# For ARM64
docker pull --platform linux/arm64 localhost:5002/multiarch-example:latest
docker tag localhost:5002/multiarch-example:latest weli/multiarch-example:arm64
docker push weli/multiarch-example:arm64

# For AMD64
docker pull --platform linux/amd64 localhost:5002/multiarch-example:latest
docker tag localhost:5002/multiarch-example:latest weli/multiarch-example:amd64
docker push weli/multiarch-example:amd64
```

2. Create and push the manifest list:
```bash
# Create a manifest list that points to both architectures
docker manifest create weli/multiarch-example:latest \
    --amend weli/multiarch-example:amd64 \
    --amend weli/multiarch-example:arm64

# Push the manifest list
docker manifest push weli/multiarch-example:latest
```

3. Verify the manifest list:
```bash
# Check the manifest list
docker manifest inspect weli/multiarch-example:latest
```

Now, when users pull either `localhost:5002/multiarch-example:latest` or `weli/multiarch-example:latest`, Docker will automatically select the correct architecture based on their host platform.

### Step 7: Cleanup

When you're done, clean up the resources:

```bash
# Remove the Buildx builder
docker buildx rm mybuilder

# Stop and remove the local registry
docker stop registry
docker rm registry

# Remove the registry configuration
rm registry-config.yml
```

## Troubleshooting

### Build Cache Issues

If you encounter issues with stale artifacts or unexpected files in your image, it might be due to the build cache. Here's how to resolve such issues:

1. Clean the buildx cache:
   ```bash
   # Remove all buildx cache
   docker buildx prune -f
   ```

2. Rebuild without using cache:
   ```bash
   # Build with --no-cache flag
   docker buildx build --no-cache --platform linux/amd64,linux/arm64 -t localhost:5002/multiarch-example:latest --push .
   ```

3. Clean up local images and pull fresh:
   ```bash
   # Remove local image
   docker rmi -f localhost:5002/multiarch-example:latest
   
   # Pull fresh image
   docker pull localhost:5002/multiarch-example:latest
   ```

### Network Issues

If you encounter network issues when pushing directly to Docker Hub with Buildx, use this manual process:
1. Build the multi-arch image locally
2. Push to a local registry
3. Manually tag and push each architecture to Docker Hub
4. Verify the images can be pulled for each architecture

### Platform Mismatch Warnings

You might see warnings like:
```
WARN: InvalidBaseImagePlatform: Base image was pulled with platform "linux/arm64", expected "linux/amd64"
```
This warning is expected when building multi-architecture images and can be safely ignored if:
1. You're using a local registry
2. The final image works correctly on all target platforms
3. The build completes successfully

## Best Practices

1. **Clean Builds**:
   - Use `--no-cache` when troubleshooting build issues
   - Regularly clean buildx cache with `docker buildx prune`
   - Remove local images before testing fresh builds

2. **Image Verification**:
   - Always test images on all target architectures
   - Verify the contents and behavior of the final image
   - Check for any unexpected files or artifacts

3. **Local Registry Usage**:
   - Use a local registry for faster development and testing
   - Tag and push base images to local registry first
   - Test images locally before pushing to Docker Hub

### Platform Selection Warning

When running multi-architecture images, you might see a warning like:
```
WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)
```

This warning appears when:
1. You're running on one architecture (e.g., ARM64/Apple Silicon)
2. Docker pulls the image variant for a different architecture (e.g., AMD64)
3. No specific platform was requested in the run command

To resolve this, explicitly specify the platform when running the container:

```bash
# Run using your host's native architecture
docker run --rm --platform linux/arm64 localhost:5002/multiarch-example:latest

# Force running AMD64 version (will use emulation if needed)
docker run --rm --platform linux/amd64 localhost:5002/multiarch-example:latest
```

The `--platform` flag tells Docker which version of the image to use:
- `linux/arm64`: Uses native ARM64 version (best performance on Apple Silicon/ARM machines)
- `linux/amd64`: Uses AMD64 version (might use emulation on ARM machines)

If you don't specify a platform:
1. Docker will try to use the image that matches your build platform
2. This might not be optimal for your host architecture
3. You'll see the warning message about platform mismatch

### Platform Variables in Multi-Architecture Builds

The Dockerfile uses two important platform-related variables:

1. **$BUILDPLATFORM**:
   - Represents the platform where the build is running
   - Often defaults to AMD64 in buildx environments
   - Used when you need to run build-time operations
   - Example: `FROM --platform=$BUILDPLATFORM golang:1.21` for a build stage

2. **$TARGETPLATFORM**:
   - Represents the platform for which the image is being built
   - Matches the actual target architecture (ARM64 or AMD64)
   - Used for the runtime image
   - Example: `FROM --platform=$TARGETPLATFORM python:3.11-slim` for the final stage
   - This is actually the default behavior, so `--platform=$TARGETPLATFORM` is optional

When using these variables:
- Use `$BUILDPLATFORM` for build stages that need to run during image creation
- Use `$TARGETPLATFORM` (or omit platform specification) for the final runtime stage
- This ensures Docker selects the correct architecture by default when running the container

For example, in our Dockerfile:
```dockerfile
# Build stages use specific platforms
FROM --platform=linux/amd64 python:3.11-slim AS amd64_builder
...
FROM --platform=linux/arm64 python:3.11-slim AS arm64_builder
...

# Final stage uses TARGETPLATFORM (or no platform specification)
FROM python:3.11-slim
# This automatically matches the running platform
```

This setup ensures that:
1. Build stages run on their specified platforms
2. The final image automatically matches your host architecture
3. No platform warning appears when running without `--platform` flag

### Common Build Warnings

When building multi-architecture images, you might encounter these warnings:

1. **Redundant Target Platform Warning**:
   ```
   WARN: RedundantTargetPlatform: Setting platform to predefined $TARGETPLATFORM in FROM is redundant
   ```
   - This occurs when you explicitly specify `--platform=$TARGETPLATFORM`
   - Solution: Remove the platform specification from the final stage
   - Example:
     ```dockerfile
     # Instead of:
     FROM --platform=$TARGETPLATFORM python:3.11-slim
     
     # Use:
     FROM python:3.11-slim
     ```

2. **Invalid Base Image Platform Warning**:
   ```
   WARN: InvalidBaseImagePlatform: Base image was pulled with platform "linux/arm64", expected "linux/amd64"
   ```
   - This occurs during multi-arch builds when the base image platform doesn't match the build stage
   - It's expected behavior and can be safely ignored when:
     - You're using a local registry
     - The final image works correctly on all target platforms
     - The build completes successfully
   - The warning appears because buildx is checking platform compatibility

3. **Best Practices to Minimize Warnings**:
   - Use explicit platforms only for build stages
   - Let the final stage inherit the target platform automatically
   - Keep base images for all target platforms in local registry
   - Verify the final image works on all architectures

## Running on Ubuntu Linux

To run the multi-architecture image on Ubuntu Linux, follow these steps:

### Step 1: Install Docker

If Docker is not already installed, install it using the official Docker repository:

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add your user to the docker group
sudo usermod -aG docker $USER
```

Note: You'll need to log out and back in for the group changes to take effect.

### Step 2: Pull and Run the Image

1. **Check Your System Architecture**:
   ```bash
   # Check your system architecture
   uname -m
   
   # For AMD64/Intel systems, this should show: x86_64
   # For ARM64 systems, this should show: aarch64
   ```

2. **For AMD64/Intel Systems**:
   ```bash
   # Pull and run the AMD64-specific version (recommended)
   docker run --rm weli/multiarch-example:amd64

   # Note: Using --platform with latest tag will not work
   # docker run --rm --platform linux/amd64 weli/multiarch-example:latest  # This will fail
   ```

3. **For ARM64 Systems**:
   ```bash
   # Pull and run the ARM64-specific version (recommended)
   docker run --rm weli/multiarch-example:arm64

   # Or use the latest tag (which points to ARM64)
   docker run --rm weli/multiarch-example:latest
   ```

4. **Important Note About Architecture Selection**:
   - The `latest` tag specifically points to the ARM64 version
   - You cannot use `--platform` flag with `latest` tag to run a different architecture
   - Always use the architecture-specific tag (`amd64` or `arm64`) for your system
   - The warning about platform mismatch is expected when running a different architecture than your host
   - The image will still work correctly through emulation

### Expected Output

When running the container, you should see output similar to:

```bash
# For AMD64 systems
Hello from Python 3.11.12!
Running on x86_64 architecture
Platform: Linux-5.15.0-xx-generic-x86_64-with-glibc2.35

# For ARM64 systems
Hello from Python 3.11.12!
Running on aarch64 architecture
Platform: Linux-5.15.0-xx-generic-aarch64-with-glibc2.35

Build artifacts from both architectures:

AMD64 build info:
Building for AMD64
Hello from AMD64!

ARM64 build info:
Building for ARM64
Hello from ARM64!
```

### Troubleshooting

1. **Platform Mismatch Warning**:
   If you see a warning like:
   ```
   WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)
   ```
   This is expected when:
   - Running AMD64 image on ARM64 host (or vice versa)
   - The image will still work through emulation
   - For best performance, use the architecture-specific tag matching your host

2. **Platform Mismatch Error**:
   If you see an error like:
   ```
   Error response from daemon: image with reference weli/multiarch-example:latest was found but its platform (linux/arm64) does not match the specified platform (linux/amd64)
   ```
   This means:
   - You're trying to use `--platform` with the `latest` tag
   - The `latest` tag is specifically pointing to ARM64
   - Solution: Use the architecture-specific tag instead:
     ```bash
     # For AMD64 systems
     docker run --rm weli/multiarch-example:amd64
     
     # For ARM64 systems
     docker run --rm weli/multiarch-example:arm64
     ```

3. **Permission Issues**:
   If you see permission errors, ensure your user is in the docker group:
   ```bash
   # Check if your user is in the docker group
   groups
   
   # If not, add your user to the docker group
   sudo usermod -aG docker $USER
   ```

4. **Network Issues**:
   If you have trouble pulling the image, check your network connection and Docker Hub access:
   ```bash
   # Test Docker Hub connectivity
   docker run --rm hello-world
   ```