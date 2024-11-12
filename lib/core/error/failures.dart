abstract class Failure {
  final String message;
  final String code;

  const Failure({
    required this.message,
    required this.code,
  });
}

class WalletFailure extends Failure {
  const WalletFailure({
    required String message,
    required String code,
  }) : super(message: message, code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    required String message,
    required String code,
  }) : super(message: message, code: code);
}

class TransactionFailure extends Failure {
  const TransactionFailure({
    required String message,
    required String code,
  }) : super(message: message, code: code);
}

class CryptoFailure extends Failure {
  const CryptoFailure({
    required String message,
    required String code,
  }) : super(message: message, code: code);
}

class CacheFailure extends Failure {
  const CacheFailure({
    required String message,
    required String code,
  }) : super(message: message, code: code);
}

class ServerFailure extends Failure {
  const ServerFailure({
    required String message,
    required String code,
  }) : super(message: message, code: code);
}
