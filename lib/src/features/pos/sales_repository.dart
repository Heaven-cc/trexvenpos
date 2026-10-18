import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/sale.dart';

class SalesRepository {
  final SupabaseClient _supabase;

  SalesRepository(this._supabase);

  Future<Sale?> recoverLegacyReceipt(Sale sale) async {
    final payment = switch (sale.paymentMethod.trim().toLowerCase()) {
      'cash' => 'cash',
      'pos terminal' || 'card' => 'card',
      'transfer' || 'bank_transfer' => 'bank_transfer',
      'mobile_money' => 'mobile_money',
      'other' => 'other',
      _ => throw ArgumentError('Original payment method required.'),
    };
    final response = await _supabase.rpc(
      'recover_trexven_legacy_checkout',
      params: {
        'p_business_id': sale.businessId,
        'p_request_id': sale.id,
        'p_employee_id': sale.employeeId,
        'p_total': double.parse(sale.total.toStringAsFixed(2)),
        'p_items': sale.items.map((i) => i.toJson()).toList(),
        'p_payment_method': payment,
        'p_branch_id': sale.branchId,
      },
    );
    return response == null
        ? null
        : Sale.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Completes a POS sale.
  ///
  /// The Supabase RPC `submit_trexven_sale` atomically handles:
  /// 1. Creating the sale
  /// 2. Creating all sale items
  /// 3. Updating inventory
  /// 4. Recording payment method and returning the saved receipt
  /// 5. Replaying the same request without creating another sale
  ///
  /// Keeping this as one RPC transaction helps prevent partial sales.
  Future<Sale> completeSale(Sale sale) async {
    if (sale.payments != null) return _completeFinancialSale(sale);

    final payment = switch (sale.paymentMethod.trim().toLowerCase()) {
      'cash' => 'cash',
      'pos terminal' || 'card' => 'card',
      'transfer' || 'bank_transfer' => 'bank_transfer',
      'mobile_money' => 'mobile_money',
      'other' => 'other',
      _ => throw ArgumentError('Select a valid payment method.'),
    };
    if (sale.items.isEmpty ||
        !sale.total.isFinite ||
        sale.total < 0 ||
        sale.items.any(
          (item) =>
              item.quantity <= 0 ||
              !item.unitPrice.isFinite ||
              item.unitPrice < 0 ||
              !item.discount.isFinite ||
              item.discount < 0 ||
              item.discount > item.subtotal,
        )) {
      throw ArgumentError('Check the cart quantities and prices.');
    }
    final response = await _supabase.rpc(
      sale.branchId == null
          ? 'submit_trexven_sale'
          : 'submit_trexven_branch_sale',
      params: {
        'p_request_id': sale.id,
        if (sale.branchId != null) 'p_branch_id': sale.branchId,
        'p_business_id': sale.businessId,
        'p_employee_id': sale.employeeId,
        'p_total': double.parse(sale.total.toStringAsFixed(2)),
        'p_payment_method': payment,
        'p_quick': false,
        'p_items': sale.items.map((item) => item.toJson()).toList(),
      },
    );
    return Sale.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Sale> _completeFinancialSale(Sale sale) async {
    if (sale.items.isEmpty || !sale.total.isFinite || sale.total < 0)
      throw ArgumentError('Valid cart required.');
    final compatibleMethod = sale.credit != null || sale.payments!.length != 1
        ? 'other'
        : sale.payments!.single['method'] as String;
    final recovered = await recoverLegacyReceipt(
      sale.copyWith(paymentMethod: compatibleMethod),
    );
    if (recovered != null) return recovered;
    Map<String, dynamic>? credit = sale.credit;
    if (credit != null) {
      final id = await _supabase.rpc(
        'request_trexven_credit_approval',
        params: {
          'p_business_id': sale.businessId,
          'p_request_id': sale.id,
          'p_branch_id': sale.branchId,
          'p_payload': {
            'member': sale.employeeId,
            'total': sale.total,
            'items': sale.items.map((i) => i.toJson()).toList(),
            'payments': sale.payments,
            'credit': Map<String, dynamic>.from(credit)..remove('approval_id'),
            'branch': sale.branchId,
            'shift': sale.shiftId,
          },
        },
      );
      final approval = await _supabase
          .from('credit_approvals')
          .select('status')
          .eq('id', id)
          .single();
      if (approval['status'] != 'approved')
        throw StateError(
          'Credit sale awaits owner or explicitly authorized manager approval. Keep the original request.',
        );
      credit = {...credit, 'approval_id': id};
    }
    final response = await _supabase.rpc(
      'complete_trexven_transaction',
      params: {
        'p_request_id': sale.id,
        'p_business_id': sale.businessId,
        'p_employee_id': sale.employeeId,
        'p_total': double.parse(sale.total.toStringAsFixed(2)),
        'p_items': sale.items.map((i) => i.toJson()).toList(),
        'p_payments': sale.payments,
        'p_credit': credit,
        'p_branch_id': sale.branchId,
        'p_shift_id': sale.shiftId,
      },
    );
    return Sale.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Returns the most recent sales for an employee.
  /// Retained for legacy callers. Current UI uses the business-scoped reader.
  Future<List<Sale>> getRecentSales(String employeeId) async {
    final response = await _supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false)
        .limit(20);

    return (response as List)
        .map<Sale>((json) => _saleFromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// The database enforces the business-local day and branch assignments.
  Future<List<Sale>> getAuthorizedBusinessSales(
    String businessId, {
    String? branchId,
  }) async {
    if (businessId.trim().isEmpty) return const [];
    var query = _supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('business_id', businessId);
    if (branchId != null) query = query.eq('branch_id', branchId);
    final sales = <Sale>[];
    const pageSize = 200;
    for (var offset = 0; ; offset += pageSize) {
      final response = await query
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1);
      sales.addAll(
        (response as List).map(
          (row) => Sale.fromJson(Map<String, dynamic>.from(row)),
        ),
      );
      if (response.length < pageSize) return sales;
    }
  }

  Sale _saleFromJson(Map<String, dynamic> json) {
    final rawItems = json['sale_items'] as List? ?? [];

    final items = rawItems
        .map((item) => _saleItemFromJson(Map<String, dynamic>.from(item)))
        .toList();

    return Sale(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id']?.toString(),
      employeeId: json['employee_id'] as String,
      total: _toDouble(json['total']),
      paymentMethod: json['payment_method'] as String,
      timestamp: DateTime.parse(json['created_at'] as String),
      items: items,
    );
  }

  SaleItem _saleItemFromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['product_id'] as String,
      quantity: num.tryParse(json['quantity'].toString()) ?? 0,
      unitPrice: _toDouble(json['unit_price']),
      discount: _toDouble(json['discount']),
      total: _toDouble(json['total']),
      priceLevel: json['price_level'] as String? ?? 'standard',
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }
}
