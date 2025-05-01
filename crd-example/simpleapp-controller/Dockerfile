FROM golang:1.20 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o simpleapp-controller .

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /app/simpleapp-controller .
USER 65532:65532
ENTRYPOINT ["/simpleapp-controller"] 