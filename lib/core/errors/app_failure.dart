class AppFailure implements Exception {
  const AppFailure(this.userMessage, {this.code});

  final String userMessage;
  final String? code;

  @override
  String toString() => userMessage;
}
