/// User-facing failure representations
sealed class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});
}

class NetworkFailure extends Failure {
  final int? statusCode;
  const NetworkFailure(super.message, {super.code, this.statusCode});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class GraphFailure extends Failure {
  const GraphFailure(super.message, {super.code});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred', String? code])
      : super(code: code);
}
