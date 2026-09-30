import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Antwort auf eine GET-Anfrage.
final class HttpResponse {
  final int status;
  final Map<String, String> headers;
  final Uint8List body;

  const HttpResponse(this.status, this.headers, this.body);
}

/// Netzwerkzugriff hinter einer kleinen Schnittstelle, damit Tests ohne Netz
/// laufen und der Kern nicht an `dart:io` klebt.
abstract interface class HttpTransport {
  Future<HttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout});
}

/// Fehler beim Abruf mit stabilem Code.
final class HttpFailure implements Exception {
  /// `offline`, `timeout`, `tls`, `too_large` oder `io`.
  final String code;
  final String message;

  const HttpFailure(this.code, this.message);

  @override
  String toString() => 'HttpFailure($code): $message';
}

/// Transport auf Basis von `dart:io`. Prüft Zertifikate immer: Es gelten die
/// Systemzertifikate des Geräts (Android: Systemspeicher; Linux: zusätzlich
/// `SSL_CERT_FILE` und die üblichen Bündel unter `/etc/ssl`). Es gibt keinen
/// Weg, die Prüfung abzuschalten.
final class IoHttpTransport implements HttpTransport {
  static const int maxBodyBytes = 16 * 1024 * 1024;
  static const int maxRedirects = 3;
  static const Set<int> _redirectCodes = {301, 302, 303, 307, 308};

  /// Ziel einer Weiterleitung von [current] nach [location] (relativ oder absolut). Erlaubt ist nur
  /// `https` zu demselben Host und Port, damit weder Suchbegriffe im Klartext noch an Dritte gehen.
  /// Sonst null.
  static Uri? nextHop(Uri current, String location) {
    final Uri next;
    try {
      next = current.resolve(location);
    } on FormatException {
      return null;
    }
    if (next.scheme != 'https' || next.host != current.host || next.port != current.port) return null;
    return next;
  }

  final SecurityContext? _context;

  IoHttpTransport({SecurityContext? context}) : _context = context;

  static SecurityContext? _cached;

  static SecurityContext systemContext() {
    final cached = _cached;
    if (cached != null) return cached;
    final ctx = SecurityContext(withTrustedRoots: true);
    if (!Platform.isAndroid) {
      final candidates = <String>[
        ?Platform.environment['SSL_CERT_FILE'],
        '/etc/ssl/certs/ca-certificates.crt',
        '/etc/ssl/certs/ca-bundle.crt',
        '/etc/pki/tls/certs/ca-bundle.crt',
      ];
      final seen = <String>{};
      for (final path in candidates) {
        if (!seen.add(path)) continue;
        try {
          if (File(path).existsSync()) ctx.setTrustedCertificates(path);
        } on Object {
          // Ein unlesbares Bündel ist kein Fehler; die übrigen Quellen gelten weiter.
        }
      }
    }
    return _cached = ctx;
  }

  @override
  Future<HttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    final client = HttpClient(context: _context ?? systemContext())
      ..connectionTimeout = timeout
      ..autoUncompress = true;
    try {
      var target = uri;
      for (var hop = 0; hop <= maxRedirects; hop++) {
        final req = await client.getUrl(target).timeout(timeout);
        // Weiterleitungen prüft der Code selbst (nächster Sprung nur https zum selben Host).
        req.followRedirects = false;
        headers.forEach((k, v) => req.headers.set(k, v));
        final res = await req.close().timeout(timeout);
        final builder = BytesBuilder(copy: false);
        await for (final chunk in res.timeout(timeout)) {
          builder.add(chunk);
          if (builder.length > maxBodyBytes) {
            throw const HttpFailure('too_large', 'Die Antwort ist zu groß');
          }
        }
        final location = res.headers.value(HttpHeaders.locationHeader);
        if (_redirectCodes.contains(res.statusCode) && location != null) {
          final next = nextHop(target, location);
          if (next == null) {
            throw const HttpFailure('io', 'Weiterleitung auf einen anderen Ursprung oder ohne HTTPS abgelehnt');
          }
          target = next;
          continue;
        }
        final out = <String, String>{};
        res.headers.forEach((name, values) => out[name] = values.join(', '));
        return HttpResponse(res.statusCode, out, builder.takeBytes());
      }
      throw const HttpFailure('io', 'Zu viele Weiterleitungen');
    } on HttpFailure {
      rethrow;
    } on TimeoutException {
      throw const HttpFailure('timeout', 'Zeitüberschreitung');
    } on HandshakeException catch (e) {
      throw HttpFailure('tls', 'Zertifikat oder TLS-Verbindung abgelehnt: ${e.message}');
    } on TlsException catch (e) {
      throw HttpFailure('tls', 'TLS-Fehler: ${e.message}');
    } on SocketException catch (e) {
      throw HttpFailure('offline', 'Keine Verbindung: ${e.message}');
    } on HttpException catch (e) {
      throw HttpFailure('io', e.message);
    } finally {
      client.close(force: true);
    }
  }
}
