import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/add_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/refresh_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/remove_subscription.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({
    required this.repository,
    required this.addSubscription,
    required this.refreshSubscription,
    required this.removeSubscription,
    required this.clipboard,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const SubscriptionState()) {
    _subscription = repository.watchAll().listen(_onSubscriptions);
  }

  final SubscriptionRepository repository;
  final AddSubscription addSubscription;
  final RefreshSubscription refreshSubscription;
  final RemoveSubscription removeSubscription;
  final ClipboardSource clipboard;
  final DateTime Function() _now;

  late final StreamSubscription<List<Subscription>> _subscription;
  final Completer<void> _firstLoad = Completer<void>();

  Future<void> addFromClipboard() async {
    final String? raw;
    try {
      raw = await clipboard.readText();
    } on Object {
      _emitNotice(const SubError('Буфер обмена пуст'));
      return;
    }
    if (raw == null || raw.trim().isEmpty) {
      _emitNotice(const SubError('Буфер обмена пуст'));
      return;
    }
    await add(raw.trim());
  }

  Future<void> add(String url) async {
    emit(state.copyWith(adding: true, clearNotice: true));
    try {
      final result = await addSubscription(url);
      if (result.format == SubscriptionFormat.clashYaml ||
          result.format == SubscriptionFormat.unknown) {
        _emitNotice(const SubUnsupportedFormat());
      } else {
        _emitNotice(SubImported(result.imported, result.skipped));
      }
    } on Object catch (error) {
      _emitNotice(SubError(_messageFor(error)));
    } finally {
      if (!isClosed) emit(state.copyWith(adding: false));
    }
  }

  Future<void> refresh(int id) async {
    if (state.busyIds.contains(id)) return;
    final subscription = _find(id);
    if (subscription == null) return;
    _setBusy(id, busy: true);
    try {
      final result = await refreshSubscription(subscription);
      _emitNotice(SubRefreshed(result.imported, result.skipped));
    } on Object catch (error) {
      _emitNotice(SubError(_messageFor(error)));
    } finally {
      _setBusy(id, busy: false);
    }
  }

  Future<void> remove(int id) async {
    try {
      await removeSubscription(id);
      _emitNotice(const SubRemoved());
    } on Object catch (error) {
      _emitNotice(SubError(_messageFor(error)));
    }
  }

  Future<void> refreshStaleOnOpen() async {
    await _firstLoad.future;
    if (isClosed) return;
    final now = _now();
    for (final subscription in List<Subscription>.from(state.subscriptions)) {
      if (_isStale(subscription, now)) {
        await refresh(subscription.id);
      }
    }
  }

  bool _isStale(Subscription subscription, DateTime now) {
    final last = subscription.lastUpdatedAt;
    if (last == null) return true;
    if (subscription.updateIntervalHours <= 0) return false;
    return now.difference(last) >
        Duration(hours: subscription.updateIntervalHours);
  }

  Subscription? _find(int id) {
    for (final subscription in state.subscriptions) {
      if (subscription.id == id) return subscription;
    }
    return null;
  }

  void _onSubscriptions(List<Subscription> subscriptions) {
    if (isClosed) return;
    emit(state.copyWith(subscriptions: subscriptions, clearNotice: true));
    if (!_firstLoad.isCompleted) _firstLoad.complete();
  }

  void _setBusy(int id, {required bool busy}) {
    if (isClosed) return;
    final next = Set<int>.from(state.busyIds);
    if (busy) {
      next.add(id);
    } else {
      next.remove(id);
    }
    emit(state.copyWith(busyIds: next));
  }

  void _emitNotice(SubscriptionNotice notice) {
    if (isClosed) return;
    emit(state.copyWith(notice: notice));
  }

  String _messageFor(Object error) {
    if (error is SubscriptionFailure) return error.message;
    if (error is Failure) return error.toString();
    return error.toString();
  }

  @override
  Future<void> close() {
    unawaited(_subscription.cancel());
    return super.close();
  }
}
