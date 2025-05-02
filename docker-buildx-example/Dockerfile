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