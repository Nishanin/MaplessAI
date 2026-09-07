/// Base application exception
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class NetworkException extends AppException {
  final int? statusCode;
  const NetworkException(super.message, {super.code, this.statusCode, super.details});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.details});
}

class GraphException extends AppException {
  const GraphException(super.message, {super.code, super.details});
}
