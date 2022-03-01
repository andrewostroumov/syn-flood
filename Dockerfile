######## Start a builder stage #######
FROM golang:1.17-alpine as builder

WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o syn-flood

######## Start a new stage from scratch #######
FROM alpine:latest

WORKDIR /opt/
COPY --from=builder /app/syn-flood .
USER root

CMD ["./syn-flood"]
