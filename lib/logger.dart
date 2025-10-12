
import 'package:flutter/foundation.dart';
import 'package:media/error_codes.dart';

abstract class Logger {
  void logM(String message);
  void logE(Error error);
}

class Log {
  static Logger _logger = DebugLogger();

  static void installLogger(Logger newLogger) {
    _logger = newLogger;
  }

  static void m(String message) {
    _logger.logM(message);
  }
  static void e(Error error) {
    _logger.logE(error);
  }
}

class DebugLogger implements Logger {
  @override
  void logM(String message) {
    debugPrint("[Logger][D] $message");
  }
  @override
  void logE(Error error) {
    debugPrint("[Logger][E] ${error.errorMeaning}");
  }
}