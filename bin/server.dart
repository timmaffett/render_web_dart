// The same three endpoints as render_web_node/server.js, in Dart.
//
// Render has no Dart runtime, so this deploys as a Docker image: the Dockerfile
// compiles it with `dart compile exe` and copies the binary into a small
// runtime image. Nothing here is Render-specific beyond reading PORT.
//
// Identical work to the Node version, so the two can be compared on CPU,
// latency and memory in Render's own metrics.
import 'dart:convert';
import 'dart:io';

final _started = DateTime.now();
var _requests = 0;

/// Deliberately slow, so /work moves the CPU graph.
int _fib(int n) => n < 2 ? n : _fib(n - 1) + _fib(n - 2);

Future<void> main() async {
  // Render supplies PORT and expects a bind on 0.0.0.0.
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 10000;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('dart web service listening on $port');

  await for (final request in server) {
    _requests++;
    final response = request.response;

    void send(int status, Map<String, Object?> body) {
      final json = const JsonEncoder.withIndent('  ').convert(body);
      response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(json);
    }

    switch (request.uri.path) {
      case '/health':
        send(200, {'ok': true});

      case '/work':
        // Bounded: an unbounded n would let anyone hang the instance.
        final requested = int.tryParse(request.uri.queryParameters['n'] ?? '') ?? 30;
        final n = requested.clamp(1, 38);
        final watch = Stopwatch()..start();
        final value = _fib(n);
        watch.stop();
        send(200, {
          'runtime': 'dart',
          'n': n,
          'value': value,
          'ms': watch.elapsedMicroseconds / 1000,
        });

      case '/':
        send(200, {
          'runtime': 'dart',
          'version': Platform.version.split(' ').first,
          'uptimeSeconds': DateTime.now().difference(_started).inSeconds,
          'requests': _requests,
          'hostname': Platform.localHostname,
          'processors': Platform.numberOfProcessors,
          'memoryMb': (ProcessInfo.currentRss / 1e6).round(),
        });

      default:
        send(404, {'error': 'no route for ${request.uri.path}'});
    }

    await response.close();
  }
}
