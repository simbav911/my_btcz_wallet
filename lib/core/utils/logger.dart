import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class WalletLogger {
  static void debug(String message) {
    logger.d('🔍 $message');
  }

  static void info(String message) {
    logger.i('ℹ️ $message');
  }

  static void warning(String message) {
    logger.w('⚠️ $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.e('❌ $message', error: error, stackTrace: stackTrace);
  }

  static void verbose(String message) {
    logger.v('📝 $message');
  }

  static void wtf(String message) {
    logger.wtf('💥 $message');
  }
}
