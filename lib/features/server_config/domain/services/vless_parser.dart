import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';

final _uuidRe = RegExp(
  '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

VlessParseResult parseVless(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    return const VlessParseFailure(VlessError.empty);
  }
  final Uri uri;
  try {
    uri = Uri.parse(raw);
  } on FormatException {
    return const VlessParseFailure(VlessError.malformed);
  }
  if (uri.scheme != 'vless') {
    return const VlessParseFailure(VlessError.scheme);
  }
  final uuid = uri.userInfo;
  if (uuid.isEmpty || !_uuidRe.hasMatch(uuid)) {
    return const VlessParseFailure(VlessError.uuid);
  }
  if (uri.host.isEmpty) {
    return const VlessParseFailure(VlessError.host);
  }
  if (!uri.hasPort || uri.port < 1 || uri.port > 65535) {
    return const VlessParseFailure(VlessError.port);
  }
  try {
    final q = uri.queryParameters;
    final name = uri.fragment.isEmpty
        ? uri.host
        : Uri.decodeComponent(uri.fragment);
    final alpn = (q['alpn'] ?? '')
        .split(',')
        .where((e) => e.isNotEmpty)
        .toList();
    return VlessParsed(
      VlessConfig(
        uuid: uuid,
        host: uri.host,
        port: uri.port,
        transport: q['type'] ?? 'tcp',
        security: q['security'] ?? 'none',
        sni: q['sni'],
        name: name,
        flow: q['flow'],
        publicKey: q['pbk'],
        shortId: q['sid'],
        fingerprint: q['fp'],
        alpn: alpn,
        wsPath: q['path'],
        wsHostHeader: q['host'],
        grpcServiceName: q['serviceName'],
      ),
    );
  } on FormatException {
    return const VlessParseFailure(VlessError.malformed);
  }
}
