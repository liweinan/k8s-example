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