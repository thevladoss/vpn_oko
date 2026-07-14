import 'package:equatable/equatable.dart';

sealed class ProxyConfig extends Equatable {
  const ProxyConfig({
    required this.host,
    required this.port,
    required this.name,
  });

  final String host;
  final int port;
  final String name;

  String get outboundTag => 'proxy';

  @override
  List<Object?> get props => [host, port, name];
}

final class VlessConfig extends ProxyConfig {
  const VlessConfig({
    required super.host,
    required super.port,
    required super.name,
    required this.uuid,
    required this.transport,
    required this.security,
    this.sni,
    this.flow,
    this.publicKey,
    this.shortId,
    this.fingerprint,
    this.alpn = const [],
    this.wsPath,
    this.wsHostHeader,
    this.grpcServiceName,
  });

  final String uuid;
  final String transport;
  final String security;
  final String? sni;
  final String? flow;
  final String? publicKey;
  final String? shortId;
  final String? fingerprint;
  final List<String> alpn;
  final String? wsPath;
  final String? wsHostHeader;
  final String? grpcServiceName;

  @override
  List<Object?> get props => [
    host,
    port,
    name,
    uuid,
    transport,
    security,
    sni,
    flow,
    publicKey,
    shortId,
    fingerprint,
    alpn,
    wsPath,
    wsHostHeader,
    grpcServiceName,
  ];
}

final class VmessConfig extends ProxyConfig {
  const VmessConfig({
    required super.host,
    required super.port,
    required super.name,
    required this.uuid,
    this.alterId = 0,
    this.cipher = 'auto',
    this.network = 'tcp',
    this.tls = false,
    this.sni,
    this.alpn = const [],
    this.wsPath,
    this.wsHostHeader,
  });

  final String uuid;
  final int alterId;
  final String cipher;
  final String network;
  final bool tls;
  final String? sni;
  final List<String> alpn;
  final String? wsPath;
  final String? wsHostHeader;

  @override
  List<Object?> get props => [
    host,
    port,
    name,
    uuid,
    alterId,
    cipher,
    network,
    tls,
    sni,
    alpn,
    wsPath,
    wsHostHeader,
  ];
}

final class TrojanConfig extends ProxyConfig {
  const TrojanConfig({
    required super.host,
    required super.port,
    required super.name,
    required this.password,
    this.network = 'tcp',
    this.sni,
    this.alpn = const [],
    this.wsPath,
    this.wsHostHeader,
    this.allowInsecure = false,
  });

  final String password;
  final String network;
  final String? sni;
  final List<String> alpn;
  final String? wsPath;
  final String? wsHostHeader;
  final bool allowInsecure;

  @override
  List<Object?> get props => [
    host,
    port,
    name,
    password,
    network,
    sni,
    alpn,
    wsPath,
    wsHostHeader,
    allowInsecure,
  ];
}

final class ShadowsocksConfig extends ProxyConfig {
  const ShadowsocksConfig({
    required super.host,
    required super.port,
    required super.name,
    required this.method,
    required this.password,
  });

  final String method;
  final String password;

  @override
  List<Object?> get props => [host, port, name, method, password];
}

final class Hysteria2Config extends ProxyConfig {
  const Hysteria2Config({
    required super.host,
    required super.port,
    required super.name,
    required this.password,
    this.sni,
    this.obfs,
    this.obfsPassword,
    this.allowInsecure = false,
  });

  final String password;
  final String? sni;
  final String? obfs;
  final String? obfsPassword;
  final bool allowInsecure;

  @override
  List<Object?> get props => [
    host,
    port,
    name,
    password,
    sni,
    obfs,
    obfsPassword,
    allowInsecure,
  ];
}
