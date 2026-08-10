FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/luogo-relay .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates
COPY --from=build /out/luogo-relay /usr/local/bin/luogo-relay
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/luogo-relay"]
