import 'package:supabase_flutter/supabase_flutter.dart';

bool saleOutcomeIsUnconfirmed(Object error) =>
    error is! ArgumentError &&
    error is! StateError &&
    !(error is PostgrestException &&
        (error.code == 'P0001' ||
            error.code == '42501' ||
            error.code?.startsWith('22') == true ||
            error.code?.startsWith('23') == true ||
            error.code == 'PGRST202'));

String saleErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'You do not have permission to record sales. Contact your business owner.';
    }
    if (error.code == 'P0001') {
      final message = error.message.toLowerCase();
      if (message.contains('insufficient stock')) return 'Insufficient stock';
      if (message.contains('price') || message.contains('unpriced')) {
        return 'Check product prices before retrying this sale.';
      }
      if (message.contains('permission') || message.contains('unauthorized')) {
        return 'Your account cannot complete this sale. Contact your business owner.';
      }
      return 'The sale was rejected. Review the items and payment before retrying.';
    }
    if (error.code == 'PGRST202') {
      return 'The sale service needs updating. Contact support.';
    }
    return 'The sale could not be saved. Contact support if this continues.';
  }
  if (error is StateError) return error.message.toString();
  if (error is ArgumentError) return error.message.toString();
  return 'Could not confirm the sale. Check your connection and retry this sale; it will not be recorded twice.';
}
