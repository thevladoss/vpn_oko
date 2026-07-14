import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';

String describeVlessError(VlessError error) => switch (error) {
  VlessError.empty => 'Буфер пуст',
  VlessError.malformed => 'Ссылка повреждена',
  VlessError.scheme => 'Это не vless://-ссылка',
  VlessError.uuid => 'Неверный UUID',
  VlessError.host => 'Не указан хост',
  VlessError.port => 'Неверный порт',
};
