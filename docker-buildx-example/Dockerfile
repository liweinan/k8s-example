# Stage 1: Build for AMD64
FROM --platform=linux/amd64 localhost:5002/python:3.11-slim as amd64_builder
WORKDIR /build
RUN echo "Building for AMD64" > arch.txt
RUN echo "AMD64 specific build steps" > build.log
RUN echo "Hello from AMD64!" > message.txt

# Stage 2: Build for ARM64
FROM --platform=linux/arm64 localhost:5002/python:3.11-slim as arm64_builder
WORKDIR /build
RUN echo "Building for ARM64" > arch.txt
RUN echo "ARM64 specific build steps" > build.log
RUN echo "Hello from ARM64!" > message.txt

# Final stage: Combine results
FROM --platform=$BUILDPLATFORM localhost:5002/python:3.11-slim
WORKDIR /app

# Create a simple Python script to display architecture info
RUN echo 'import platform; print(f"Running on: {platform.machine()}")' > arch_info.py
RUN echo 'print("Build log contents:")' >> arch_info.py
RUN echo 'print("This image was built for:", platform.machine())' >> arch_info.py
RUN echo 'print("\nMessage:")' >> arch_info.py
RUN echo 'print("Hello from", platform.machine(), "!")' >> arch_info.py

# Set the entrypoint
ENTRYPOINT ["python", "arch_info.py"]

FROM golang:1.21 AS deps
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

FROM golang:1.21 AS builder
WORKDIR /app
COPY --from=deps /go/pkg/mod /go/pkg/mod
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o simpleapp-controller .

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /app/simpleapp-controller .
USER 65532:65532
ENTRYPOINT ["/simpleapp-controller"] 