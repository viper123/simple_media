import 'package:simple_media/error_codes.dart';

/// Controls where audio-player logs are emitted.
///
/// * [none] — silence both the Dart-side logger and native platform logs.
/// * [onlyFlutter] — install the Dart-side logger only.
/// * [onlyNative] — enable native (iOS / Android) logs only.
/// * [full] — enable both Dart and native logs.
/// * [auto] — resolves to [full] in debug builds and [none] in release builds.
enum LogLevel { none, onlyFlutter, onlyNative, full, auto }

extension LogLevelX on LogLevel {
  /// Whether this level enables the Dart-side logger.
  bool get includesFlutter =>
      this == LogLevel.onlyFlutter || this == LogLevel.full;

  /// Whether this level enables native platform logs.
  bool get includesNative =>
      this == LogLevel.onlyNative || this == LogLevel.full;
}

abstract class Logger {
  void logM(String message);

  void logE(Error error, String? errorContext);
}

class Log {
  static Logger? _logger;

  static void installLogger(Logger newLogger) {
    _logger = newLogger;
  }

  static void m(String message) {
    _logger?.logM(message);
  }

  static void e(Error error, {String? errorContext}) {
    _logger?.logE(error, errorContext);
  }
}
