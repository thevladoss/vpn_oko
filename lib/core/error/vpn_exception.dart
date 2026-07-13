import 'package:flutter/services.dart';
import 'package:vpn_oko/core/error/failures.dart';

Failure mapPlatformException(PlatformException exception) => VpnStartFailure(
      exception.code,
      exception.message ?? exception.code,
    );
