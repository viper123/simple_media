
import 'package:simple_media/error_codes.dart';

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