import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension AppNav on BuildContext {
  /// Steps back one screen, landing on [fallback] when there is no history.
  ///
  /// Auth screens are reachable both by push (walking the flow) and by
  /// redirect (deep link, expired session, verification bounce), so popping
  /// alone can leave nothing on screen and `go` alone throws the history away.
  void backOr(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
