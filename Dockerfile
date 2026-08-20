# Render has no Dart runtime, so this ships as a container. Two stages: the
# Dart SDK compiles a self-contained executable, and only that binary reaches
# the runtime image.
FROM dart:3.9 AS build

WORKDIR /app
# Dependencies first, so a source-only change reuses the cached layer.
COPY pubspec.yaml ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o /app/server

# `dart compile exe` produces a native binary that still needs glibc, so this
# uses Debian slim rather than scratch.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/server /app/server

# Render sets PORT; the default matches its convention for a bare `docker run`.
ENV PORT=10000
EXPOSE 10000
CMD ["/app/server"]
