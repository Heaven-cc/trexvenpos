import 'dart:async';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Presentation only. Never used as an authorization or payment-state contract.
abstract final class CustomerPresentation {
  static const unavailable = 'Not available';
  static const retry = 'Try again';
  static String amount(Object? value, {String? currency}) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    return number == null ? 'Not available' : money(number, currency: currency);
  }

  static String stockDiscrepancies(Object? value) {
    if (value is! List) return 'Stock differences unavailable';
    if (value.isEmpty) return 'No stock differences';
    return value
        .whereType<Map>()
        .map(
          (row) =>
              'Recorded ${row['requested'] ?? '—'} units; stock shortfall ${row['shortfall'] ?? '—'} units',
        )
        .join('\n');
  }

  static const _labels = {
    'start': 'Start',
    'core': 'Core',
    'pro': 'Pro',
    'sales_employee': 'Sales employee',
    'inventory_employee': 'Inventory employee',
    'owner': 'Owner',
    'manager': 'Manager',
    'employee': 'Employee',
    'pos': 'Point of sale',
    'inventory': 'Inventory',
    'barcode': 'Barcode scanning',
    'sales': 'Sales',
    'basic_reports': 'Basic reports',
    'basic_employees': 'Employee management',
    'basic_vision': 'Vision insights',
    'enhanced_vision': 'Enhanced Vision insights',
    'highest_vision': 'Advanced Vision insights',
    'advanced_inventory': 'Advanced inventory',
    'low_stock_alerts': 'Low-stock alerts',
    'employee_permissions': 'Employee permissions',
    'advanced_reports': 'Advanced reports',
    'multiple_pricing': 'Multiple price levels',
    'analytics': 'Business analytics',
    'advanced_analytics': 'Advanced analytics',
    'detailed_activity_logs': 'Detailed activity history',
    'advanced_employee_controls': 'Advanced employee controls',
    'priority_support': 'Priority support',
    'early_access': 'Early access',
    'bank_transfer': 'Bank transfer',
    'cash_in': 'Cash in',
    'cash_out': 'Cash out',
    'past_due': 'Payment overdue',
    'trialing': 'Trial',
    'unconfigured': 'Not enrolled',
    'not configured': 'Not enrolled',
    'requested': 'Awaiting review',
    'verified': 'Confirmed',
    'customer_return': 'Customer return',
    'supplier_return': 'Supplier return',
    'pending_price': 'Awaiting price',
    'count_adjustment': 'Stocktake adjustment',
  };
  static String label(Object? value, {String fallback = 'Unavailable'}) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;
    return _labels[raw.toLowerCase()] ??
        raw
            .replaceAll('_', ' ')
            .split(' ')
            .where((s) => s.isNotEmpty)
            .map((s) => '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}')
            .join(' ');
  }

  /// Normalize saved registration values without inferring a currency.
  static String? currencyCode(String? currency) {
    final raw = currency?.trim() ?? '';
    if (raw.isEmpty) return null;
    // Compatibility with the original registration dropdown's persisted labels.
    const registrationLabels = {
      'Nigerian Naira (₦)': 'NGN',
      'Ghanaian Cedi (₵)': 'GHS',
      'Kenyan Shilling (KSh)': 'KES',
      'South African Rand (R)': 'ZAR',
      'US Dollar (\$)': 'USD',
      'British Pound (£)': 'GBP',
    };
    final code = registrationLabels[raw] ?? raw.toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(code) ? code : null;
  }

  static String money(num value, {String? currency}) {
    if (!value.isFinite) return unavailable;
    final code = currencyCode(currency);
    if (code == null) return 'Currency unavailable';
    // ISO code disambiguates currencies; intl supplies their decimal precision.
    return NumberFormat.currency(name: code, symbol: '$code ').format(value);
  }
  static String date(Object? value, {bool includeTime = false}) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not available';
    return (includeTime
            ? DateFormat('d MMM yyyy, h:mm a')
            : DateFormat('d MMM yyyy'))
        .format(date.toLocal());
  }

  static String operation(Object? value) => const {
    'complete_trexven_transaction': 'Complete sale',
    'submit_trexven_sale': 'Record sale',
    'submit_trexven_branch_sale': 'Record branch sale',
    'record_pos_expense': 'Record expense',
    'request_trexven_credit_approval': 'Request credit approval',
    'record_trexven_credit_repayment': 'Record credit repayment',
    'request_trexven_return': 'Request customer return',
    'approve_trexven_return': 'Approve customer return',
    'dispatch_trexven_stock_transfer': 'Dispatch stock transfer',
    'receive_trexven_stock_transfer': 'Receive stock transfer',
    'open_trexven_cash_shift': 'Open cash drawer',
    'close_trexven_cash_shift': 'Close cash drawer',
    'join_trexven_cash_shift': 'Join cash drawer',
  }[value?.toString()] ?? 'Business operation';

  static String angelError(int status) => switch (status) {
    429 => 'Angel is receiving too many requests. Wait a moment before trying again.',
    401 => 'Your session expired. Sign in again to use Angel.',
    403 => 'Angel access is unavailable for this account. Contact the business owner.',
    502 || 503 || 504 => 'Angel is temporarily unavailable. Your request could not be completed.',
    _ => 'Angel could not respond. Check your connection and try again.',
  };

  static String operationError(Object? value) {
    final message = value?.toString().toLowerCase() ?? '';
    if (message.contains('permission') || message.contains('not authorized')) {
      return 'Your account cannot make this change. Contact the business owner.';
    }
    if (message.contains('stock') || message.contains('stale')) {
      return 'Product details have changed. Review the current inventory before continuing.';
    }
    if (message.contains('duplicate') || message.contains('already')) {
      return 'This request may already be recorded. Check its status before trying again.';
    }
    return 'The change could not be confirmed. Check its status and retain the original request.';
  }

  static String employeeLoginError(Object? value, {int? status}) {
    final message = value?.toString().toLowerCase() ?? '';
    if (status == 429 || message.contains('rate limit')) {
      return 'Too many sign-in attempts. Wait a moment before trying again.';
    }
    if (message.contains('inactive') || message.contains('suspended')) {
      return 'Your employee access is inactive. Contact the business owner.';
    }
    if (status == 401 || message.contains('invalid employee id or password')) {
      return 'The Employee ID or password is incorrect.';
    }
    if (status == 403) return 'Employee access could not be verified. Contact the business owner.';
    return 'Unable to sign in. Check your connection and try again.';
  }

  static String error(
    Object? error, {
    String fallback = 'We could not complete this action. Please try again.',
  }) {
    if (error is PostgrestException && error.code == '42501') {
      return 'Your account cannot complete this action. Check your business access or contact support.';
    }
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login'))
        return 'The email or password is incorrect.';
      if (message.contains('email not confirmed'))
        return 'Verify your email before signing in.';
      if (message.contains('rate limit') || message.contains('too many'))
        return 'Please wait a moment before trying again.';
      return 'We could not verify your account. Please try again.';
    }
    if (error is TimeoutException)
      return 'The connection timed out. Please try again.';
    return fallback;
  }
}
