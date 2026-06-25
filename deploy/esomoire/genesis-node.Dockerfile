FROM golang:1.24-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /out/esomoire-genesis-node ./cmd/esomoire-genesis-node

FROM alpine:3.20

RUN addgroup -S esomoire && adduser -S esomoire -G esomoire \
    && apk add --no-cache ca-certificates wget

USER esomoire
WORKDIR /app
COPY --from=builder /out/esomoire-genesis-node /app/esomoire-genesis-node

EXPOSE 8081
ENTRYPOINT ["/app/esomoire-genesis-node"]
