import 'dart:io';

import 'package:flutter/services.dart';

/// Where the top of the phone points, from the phone's own compass
/// (Android's rotation sensor, the iPhone's location manager), from
/// magnetic north; [rough] where the phone itself doubts it (Android's
/// accuracy low, or the iPhone's error over 15°).
typedef Heading = ({double magnetic, bool rough});

abstract final class Compass {
  static const _channel = EventChannel('candra/heading');

  /// The headings while listened to; the phone's compass runs only then.
  static Stream<Heading> headings() => _channel.receiveBroadcastStream().map((
    event,
  ) {
    final map = (event as Map).cast<String, Object?>();
    final accuracy = (map['accuracy'] as num?)?.toDouble() ?? 0;
    return (
      magnetic: (map['heading'] as num).toDouble(),
      rough: Platform.isIOS ? (accuracy < 0 || accuracy > 15) : accuracy < 2,
    );
  });
}
