# render_web_dart

> **Unofficial, independent, community-built.** Not affiliated with, endorsed by
> or supported by [Render](https://render.com).

A **Dart** web service running on [Render](https://render.com), compiled ahead
of time and shipped as a container.

Render's runtimes are Node, Python, Ruby, Go, Rust, Elixir and Docker — there is
no Dart one. Docker is the way in, and it is a short way: `dart compile exe`
produces a self-contained native binary, so the runtime image holds one file and
starts in milliseconds.

Its twin, [`render_web_node`](https://github.com/timmaffett/render_web_node),
serves the **same three endpoints** in Node on the same plan. Deploy both and
Render's own metrics compare them — which is the point of having two.

## Endpoints

| | |
| --- | --- |
| `GET /` | runtime, version, uptime, request count, resident memory |
| `GET /health` | `{"ok": true}` — the health check path |
| `GET /work?n=30` | recursive `fib(n)`, bounded at 38, with the elapsed time |

`/work` exists to move the CPU graph. It is deliberately the least efficient way
to compute a Fibonacci number, and identical in both services.

```console
$ curl -s https://render-web-dart.onrender.com/ | jq -c
{"runtime":"dart","version":"3.13.0","uptimeSeconds":41,"requests":3,...}

$ curl -s 'https://render-web-dart.onrender.com/work?n=32' | jq -c
{"runtime":"dart","n":32,"value":2178309,"ms":29.1}
```

## Deploy

Blueprint, or point a new Docker web service at this repository:

| Field | Value |
| --- | --- |
| Runtime | Docker |
| Dockerfile Path | `./Dockerfile` |
| Health Check Path | `/health` |

Nothing else — no build command, no start command, no environment variables.
Render sets `PORT`; the server reads it and binds `0.0.0.0`, which Render
requires.

## The Dockerfile

Two stages. The first has the Dart SDK and produces `/app/server`; the second is
`debian:bookworm-slim` and receives only that binary. Dependencies are fetched
before the source is copied, so editing `bin/server.dart` reuses the cached
`pub get` layer.

Slim rather than `scratch`: `dart compile exe` links against glibc, so the
binary is native but not static.

## Locally

```bash
dart run bin/server.dart          # PORT defaults to 10000
docker build -t render-web-dart . && docker run -p 10000:10000 render-web-dart
```

The first is the fast loop; the second is what Render actually runs.

## Why not compile to JavaScript?

That is the [`render-dart`](https://www.npmjs.com/package/render-dart) approach,
and for **Render Workflows** tasks it is the better one — no container, and
Render's own SDK does the registration.

A web service has no such constraint. There is no SDK to register with, so the
only question is whether Docker is worth it, and for a long-lived HTTP server it
plainly is: real `dart:io` sockets, `dart:ffi`, isolates for more than one core,
and any package on pub.dev rather than only those with a web build.
