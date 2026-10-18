import 'dart:convert';
import 'encrypted_state.dart';

class OperationJournal {
  final Future<DurableState> Function() stateFactory;
  Future<DurableState>? _state;
  OperationJournal({this.stateFactory = createOperationState});
  Future<DurableState> get state => _state ??= stateFactory();
  Future<Map<String, dynamic>?> pending() async {
    final value = (await (await state).read())['pending'];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<Map<String, dynamic>> reserve(
    String user,
    String business,
    String rpc,
    Map<String, dynamic> args,
  ) async {
    return (await state).mutate((state) {
      final prior = state['pending'];
      if (prior != null) {
        final old = Map<String, dynamic>.from(prior as Map);
        final a = Map<String, dynamic>.from(old['args'] as Map)
          ..remove('p_request_id');
        final b = Map<String, dynamic>.from(args)..remove('p_request_id');
        if (old['user'] != user ||
            old['business'] != business ||
            old['rpc'] != rpc ||
            jsonEncode(a) != jsonEncode(b)) {
          throw StateError(
            'Recover the original pending operation before starting another.',
          );
        }
        return Map<String, dynamic>.from(old['args'] as Map);
      }
      state['pending'] = {
        'user': user,
        'business': business,
        'rpc': rpc,
        'args': args,
      };
      return args;
    });
  }

  Future<void> complete(String user, String business, String request) async =>
      (await state).mutate((state) {
        final p = state['pending'] as Map?;
        if (p == null) return;
        if (p['user'] != user ||
            p['business'] != business ||
            (p['args'] as Map)['p_request_id'] != request) {
          throw StateError('Financial request context changed.');
        }
        state.remove('pending');
      });
}
