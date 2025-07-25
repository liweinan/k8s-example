# Build the application from source
FROM docker.io/library/golang:1.18 AS builder
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
