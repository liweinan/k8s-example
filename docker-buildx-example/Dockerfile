# Use Python slim image as base
FROM --platform=$BUILDPLATFORM localhost:5002/python:3.11-slim

# Set working directory
WORKDIR /app

# Copy the application
COPY app.py .

# Make the script executable
RUN chmod +x app.py

# Set the entrypoint
ENTRYPOINT ["./app.py"] 