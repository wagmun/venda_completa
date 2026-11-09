# Build do servidor Dart (Shelf) e imagem final mínima.
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Imagem final enxuta.
FROM debian:stable-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/web /app/web

# Render injeta PORT; o servidor já lê Platform.environment['PORT'].
EXPOSE 3000
CMD ["/app/bin/server"]
