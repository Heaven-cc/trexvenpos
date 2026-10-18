import 'dart:async';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Presentation only. Never used as an authorization or payment-state contract.
abstract final class CustomerPresentation {
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
    'start': 'START',
    'core': 'CORE',
    'pro': 'PRO',
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

  static String _currencySymbol(String? currency) {
    if (currency == null || currency.trim().isEmpty) return '₦';
    final code = currency.trim().toUpperCase();
    switch (code) {
      case 'NGN':
        return '₦';
      case 'USD':
      case 'CAD':
      case 'AUD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'GHS':
        return 'GH₵';
      case 'KES':
        return 'KSh';
      case 'ZAR':
        return 'R';
      case 'INR':
        return '₹';
      case 'JPY':
      case 'CNY':
        return '¥';
      default:
        if (currency.length <= 3 && !RegExp(r'^[A-Za-z]{3}$').hasMatch(currency)) {
          return currency;
        }
        return '₦';
    }
  }

  static String money(num value, {String? currency}) => NumberFormat.currency(
    symbol: _currencySymbol(currency),
    decimalDigits: 2,
  ).format(value);
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
