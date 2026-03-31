import 'dart:async';

class Debouncer<T> {
  final Duration delay;
  Timer? _timer;
  void Function(T value)? action;

  Debouncer({required this.delay});

  void call(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      action?.call(value);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
