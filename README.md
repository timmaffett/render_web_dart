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

Live, on the free plan:

```console
$ curl -s https://render-web-dart.onrender.com/ | jq -c
{"runtime":"dart","version":"3.9.4","uptimeSeconds":10,"requests":6,
 "hostname":"srv-da3lugu7bikc73b9tgfg-...","processors":8,"memoryMb":7}
```

## Measured against the Node twin

Both on `free`, in `oregon`, called from the same laptop, best of seven — a free
instance shares a CPU, so the slow samples are the neighbours rather than the
runtime.

| `fib(n)` | Dart AOT | Node | |
| ---: | ---: | ---: | --- |
| 30 | 6.0 ms | 8.9 ms | 1.5x |
| 32 | 15.8 ms | 24.9 ms | 1.6x |
| 34 | 129.9 ms | 318.4 ms | 2.5x |
| 36 | 647.2 ms | 930.3 ms | 1.4x |

Resident memory, idle: **7 MB against 51 MB**.

**Anecdotal — one workload, one afternoon, two free instances.** Recursive
`fib` is integer arithmetic and function calls and nothing else; it says
nothing about JSON, I/O or anything a real service spends its time on. Re-run
it rather than trusting it, which is why the endpoint returns its own timing.

Worth noting against the numbers in
[`render-dart`](https://github.com/timmaffett/render-dart), where V8 *matched*
Dart AOT on the same recursion. That comparison was dart2js against a native
task spawned per call, and the process hop was most of the difference. Here both
servers are long-lived, so nothing is being spawned and the arithmetic is all
that is left.

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
