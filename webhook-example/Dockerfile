# Build the application from source
FROM docker.io/library/golang:1.18 AS builder

ENV HTTP_PROXY="http://host.docker.internal:1080"
ENV HTTPS_PROXY="http://host.docker.internal:1080"
ENV NO_PROXY="localhost,127.0.0.1,host.docker.internal"

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o webhook .

# Create a minimal container image
FROM docker.io/library/alpine:latest
WORKDIR /root/
COPY --from=builder /app/webhook .
CMD ["./webhook"]
