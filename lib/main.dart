import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_oko/app/app.dart';
import 'package:vpn_oko/app/di.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final dependencies = AppDependencies();
  runApp(OkoApp(dependencies: dependencies));
}

Stream<LicenseEntry> _fontLicenses() async* {
  const licenses = <String>[
    'google_fonts/OFL-SpaceGrotesk.txt',
    'google_fonts/OFL-Inter.txt',
    'google_fonts/OFL-JetBrainsMono.txt',
  ];
  for (final path in licenses) {
    final text = await rootBundle.loadString(path);
    yield LicenseEntryWithLineBreaks(const ['google_fonts'], text);
  }
}
