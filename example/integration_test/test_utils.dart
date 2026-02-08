import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> withTimeout<T>(
  Future<T> expectFunction,
  Duration timeout,
  String functionName,
) async {
  try {
    await expectFunction.timeout(timeout);
  } catch (e, stack) {
    debugPrint("$functionName timed out with error: $e, $stack");
  }
}

Matcher hasSeconds(int seconds) => _SecondsDurationMatcher(seconds);

class _SecondsDurationMatcher extends Matcher {

  final int seconds;
  _SecondsDurationMatcher(this.seconds);

  @override
  bool matches(item, Map matchState) {
    return item is Duration && item.inSeconds == seconds;
  }

  @override
  Description describe(Description description) =>
      description.add('a Duration with seconds property equal to ')
          .addDescriptionOf(seconds);
}


Future<bool> streamHasItems(Stream<dynamic> stream, List<dynamic> items, Duration timeout) async {
  final s = _StreamEmitsElementsFromList(stream, items, timeout);
  final result = await s.valuesAreEmitted();
  s.dispose();
  return result;
}

class _StreamEmitsElementsFromList<T> {

  _StreamEmitsElementsFromList(this.stream, List<T> items, this.timeout) {

    list = [];
    list.addAll(items);

    _subs = stream.listen((data){
      if (list.contains(data)) {
        list.remove(data);
      }
    });
  }

  StreamSubscription<T>? _subs;
  final Stream<T> stream;
  late List<T> list;
  final Duration timeout;

  Future<bool> valuesAreEmitted() => Future.delayed(timeout, () {
    return list.isEmpty;
  });


  void dispose() {
    _subs?.cancel();
  }
}

Duration a1s() => const Duration(seconds: 1);
Duration a2s() => const Duration(seconds: 2);
Duration a3s() => const Duration(seconds: 3);
Duration a5s() => const Duration(seconds: 5);