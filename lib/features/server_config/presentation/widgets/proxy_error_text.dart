import 'package:vpn_oko/features/server_config/domain/entities/proxy_parse_result.dart';

String describeProxyError(ProxyParseError error) => switch (error) {
  ProxyParseError.empty => 'Буфер пуст',
  ProxyParseError.unsupported => 'Неподдерживаемая ссылка',
  ProxyParseError.malformed => 'Ссылка повреждена',
  ProxyParseError.missingField => 'В ссылке не хватает данных',
};
