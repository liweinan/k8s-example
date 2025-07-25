# Build the application from source
FROM golang:1.18 AS builder
WORKDIR /app

COPY go.mod go.sum ./
RUN cat /etc/hosts 
RUN GOPROXY="direct" http_proxy=http://192.168.0.123:1080 https_proxy=http://192.168.0.123:1080 go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o webhook .

# Create a minimal container image
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/webhook .
CMD ["./webhook"]
