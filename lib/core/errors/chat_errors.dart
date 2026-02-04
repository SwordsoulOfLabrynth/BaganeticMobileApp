class ChatError implements Exception {
  const ChatError(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'ChatError($code): $message';
}

class NetworkError extends ChatError {
  const NetworkError(super.message, {super.code, super.cause});
}

class AuthError extends ChatError {
  const AuthError(super.message, {super.code, super.cause});
}

class ValidationError extends ChatError {
  const ValidationError(super.message, {super.code, super.cause});
}

class PermissionError extends ChatError {
  const PermissionError(super.message, {super.code, super.cause});
}

class UnknownChatError extends ChatError {
  const UnknownChatError(super.message, {super.code, super.cause});
}
