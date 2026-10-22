import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/sale_errors.dart';

import 'cart_provider.dart';
import 'sale_completion_dialog.dart';
import 'payment_confirmation_dialog.dart';
import 'offline_cash_screen.dart';
import '../../services/offline_cash_queue.dart';
import 'sales_provider.dart';
import 'pending_sale_provider.dart';
import '../../services/pending_sale.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import '../../models/sale.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final bool offlineCash;
  const CheckoutScreen({super.key, this.offlineCash = false});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final String _paymentMethod = 'Cash';
  bool _isProcessing = false;
  bool _hasUnconfirmedSale = false;
  double? _cashTendered, _cashChange;

  Future<void> _completeCheckout() async {
    if (_isProcessing) return;

    final cartItems = ref.read(cartProvider);

    if (cartItems.isEmpty) {
      _showError('Your cart is empty.');
      return;
    }

    final auth = ref.read(authStateProvider);
    if (auth.offlineCashOnly && !widget.offlineCash) {
      _showError('Reconnect and verify access for online checkout.');
      return;
    }

    final business = auth.activeBusiness;

    final employee = auth.employee;

    if (business == null) {
      _showError('No active business is selected.');
      return;
    }

    if (employee == null) {
      _showError('No employee account is currently signed in.');
      return;
    }

    if (!ref.read(permissionServiceProvider).canCompleteSales ||
        employee.businessId != business.id ||
        cartItems.any((item) => item.product.businessId != business.id)) {
      _showError('You do not have permission to complete this sale.');
      return;
    }

    DateTime? offlineExpires;
    String? originalBranch = ref.read(branchContextProvider)?.id;
    if (!widget.offlineCash && business.branchesEnabled && originalBranch == null) {
      _showError('Select an authorized branch before collecting payment.');
      return;
    }
    setState(() {
      _isProcessing = true;
    });

    try {
    // The durable journal, not this screen's transient flag, decides whether
    // another payment can be collected after a restart or route recreation.
    Sale? recoverySale;
    try {
      if (widget.offlineCash) {
        final ticket = await (await ref.read(offlineCashQueueProvider.future))
            .authorizedTicket(employee.userId, business.id, employee.membershipId, DateTime.now());
        originalBranch = (ticket['scope'] as Map)['branch_id'] as String?;
        offlineExpires = DateTime.parse((ticket['scope'] as Map)['expires_at'] as String);
      }
      final retained = await (await ref.read(
        pendingSaleStoreProvider.future,
      )).read();
      if (retained != null) {
        if (widget.offlineCash) throw StateError('Recover the retained online sale before offline checkout.');
        if (!retained.belongsTo(
          employee.userId,
          business.id,
          employee.membershipId,
        )) {
          throw StateError(
            'A sale from another employee or business is retained. Recover it with the original account before collecting another payment.',
          );
        }
        final branch = ref.read(branchContextProvider);
        if (retained.sale.branchId != null &&
            branch?.id != retained.sale.branchId) {
          throw StateError(
            'Select the original authorized branch before recovering the retained sale.',
          );
        }
        recoverySale = retained.sale;
        if (mounted) setState(() => _hasUnconfirmedSale = true);
      } else if (_hasUnconfirmedSale) {
        throw StateError(
          'The original request is no longer available. Check sale history before collecting payment again.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError(CustomerPresentation.error(
          e,
          fallback: 'Unable to verify pending sales. Do not collect payment again.',
        ));
      }
      return;
    }
    final Sale sale;
    if (recoverySale != null) {
      // Recovery submits the exact flushed payment and request, without asking
      // the cashier to confirm or collect another payment.
      sale = recoverySale;
    } else {
      final total = ref.read(cartProvider.notifier).total;
      String? shiftId;
      var cashAllowed = true;
      try {
        if (widget.offlineCash) {
          final ticket = await (await ref.read(
            offlineCashQueueProvider.future,
          )).ticket();
          shiftId = (ticket?['scope'] as Map?)?['shift_id'] as String?;
        } else {
          final api = OperationsClient.pos(
            ref.read(supabaseProvider),
            business.id,
          );
          final cashContext = await api.cashContext();
          if (!mounted) return;
          shiftId = await chooseCashShift(
            context,
            api,
            allowNoDrawer: true,
            cashContext: cashContext,
            branchId: originalBranch, restrictBranch: true,
          );
          cashAllowed = cashContext['configured'] != true || shiftId != null;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError(
            CustomerPresentation.error(
              e,
              fallback: 'We could not complete this action. Please try again.',
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final draft = await confirmPayment(
        context,
        total,
        _paymentMethod,
        offline: widget.offlineCash,
        authorizationExpiresAt: offlineExpires,
        contextIsCurrent: () {
          if (!mounted) return false;
          final current = ref.read(authStateProvider);
          return mounted && current.employee?.userId == employee.userId &&
              current.employee?.membershipId == employee.membershipId &&
              current.activeBusiness?.id == business.id &&
              (widget.offlineCash || ref.read(branchContextProvider)?.id == originalBranch);
        },
        cashAllowed: cashAllowed,
        currency: business.currency,
      );
      if (draft == null || !mounted) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      _cashTendered = draft.cashTendered;
      _cashChange = draft.cashChange;
      final afterConfirm = ref.read(authStateProvider);
      if (afterConfirm.employee?.userId != employee.userId ||
          afterConfirm.employee?.membershipId != employee.membershipId ||
          !ref.read(permissionServiceProvider).canCompleteSales ||
          (!widget.offlineCash && ref.read(branchContextProvider)?.id != originalBranch) ||
          afterConfirm.activeBusiness?.id != business.id) {
        setState(() => _isProcessing = false);
        _showError('Original employee and business required.');
        return;
      }
      final branch = ref.read(branchContextProvider);
      final branchId = widget.offlineCash ? originalBranch : branch?.id;
      if (business.branchesEnabled &&
          (branchId == null || (!widget.offlineCash && branch?.businessId != business.id))) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Select an authorized branch before checkout.'),
          ),
        );
        return;
      }
      sale = Sale(
        id: ref.read(cartProvider.notifier).checkoutRequestId,
        businessId: business.id,
        branchId: business.branchesEnabled ? branchId : null,
        employeeId: employee.membershipId,
        total: total,
        paymentMethod: widget.offlineCash ? "cash" : _paymentMethod,
        payments: widget.offlineCash ? null : draft.payments,
        credit: draft.credit,
        shiftId: shiftId,
        timestamp: draft.confirmedAt,
        items: cartItems
            .map(
              (item) => SaleItem(
                productId: item.product.id,
                productName: item.product.name,
                quantity: item.quantity,
                unitPrice: item.selectedPrice,
                discount: item.discount,
                total: item.total,
                priceLevel: item.priceLevel,
              ),
            )
            .toList(),
      );
    }

    PendingSaleStore? store;
    try {
      if (widget.offlineCash) {
        final queue = await ref.read(offlineCashQueueProvider.future);
        final ticket = await queue.ticket();
        if (ticket == null)
          throw StateError('Refresh a signed cash catalog online first.');
        final time = DateTime.now();
        await queue.enqueue(
          OfflineCashEntry(
            sale: sale,
            userId: employee.userId,
            ticket: ticket,
            occurredAt: sale.timestamp,
          ),
          time,
        );
        ref.read(cartProvider.notifier).clear();
        if (!mounted) return;
        await showDialog<void>(
          animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            scrollable: true,
            title: Text('Cash receipt · Pending Sync'),
            content: SelectableText(
              'Request: ${sale.id}\nCash applied: ${_formatPrice(sale.total)}\n' +
                  sale.items
                      .map((i) => '${i.productName.isEmpty ? 'Product' : i.productName} × ${i.quantity}: ${_formatPrice(i.total)}')
                      .join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Keep for synchronization'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }
      final resolvedStore = await ref.read(pendingSaleStoreProvider.future);
      store = resolvedStore;
      final completed = await PendingSaleSubmission(resolvedStore).submit(
        userId: employee.userId,
        sale: sale,
        send: ref.read(salesRepositoryProvider).completeSale,
      );

      if (!mounted) return;
      final current = ref.read(authStateProvider);
      if (current.employee?.userId != employee.userId ||
          current.employee?.membershipId != employee.membershipId ||
          current.activeBusiness?.id != business.id) {
        ref.invalidate(pendingSaleProvider);
        throw StateError(
          'Sign in with the original employee and business to recover this sale.',
        );
      }
      setState(() => _hasUnconfirmedSale = false);

      ref.read(cartProvider.notifier).clear();
      ref.invalidate(recentSalesProvider);

      await showDialog<void>(
        animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
        barrierDismissible: false,
        builder: (_) => SaleCompletionDialog(sale: completed, currency: business.currency,
          cashTendered: _cashTendered, cashChange: _cashChange),
      );
      final acknowledging = ref.read(authStateProvider);
      if (acknowledging.employee?.userId != employee.userId ||
          acknowledging.employee?.membershipId != employee.membershipId ||
          acknowledging.activeBusiness?.id != business.id) {
        ref.invalidate(pendingSaleProvider);
        throw StateError(
          'The original employee must acknowledge this receipt.',
        );
      }
      await resolvedStore.acknowledge(sale.id);
      ref.invalidate(pendingSaleProvider);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).trexvenColors.success!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).scaffoldBackgroundColor,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sale completed successfully.',
                  style: TextStyle(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      var pendingRemains = store != null;
      try { if (store != null) pendingRemains = await store.read() != null; } catch (_) { /* Storage uncertainty keeps recovery locked. */ }
      if (!mounted) return;
      if (pendingRemains) ref.invalidate(pendingSaleProvider);
      setState(() => _hasUnconfirmedSale = pendingRemains);

      _showError(saleErrorMessage(e));
      if (pendingRemains) {
        // Return to the global recovery gate; do not strand the cashier here.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
    } catch (error) {
      if (!mounted) return;
      // Cover preparation/dialog failures as well as submission. Do not leave
      // PopScope and payment controls permanently locked by a transient flag.
      var retained = false;
      if (!widget.offlineCash) {
        try {
          retained = await (await ref.read(pendingSaleStoreProvider.future)).read() != null;
        } catch (_) {
          retained = true; // Uncertain storage stays behind recovery.
        }
        if (!mounted) return;
        ref.invalidate(pendingSaleProvider);
      }
      if (mounted) {
        setState(() => _hasUnconfirmedSale = retained);
        _showError(saleErrorMessage(error));
        if (retained) Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onError,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    return CustomerPresentation.money(price,
      currency: ref.read(authStateProvider).activeBusiness?.currency);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    final cartNotifier = ref.read(cartProvider.notifier);

    final total = cartNotifier.total;

    final itemCount = cartNotifier.itemCount;

    return PopScope(
      canPop: !_isProcessing && !_hasUnconfirmedSale,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        appBar: AppBar(
          toolbarHeight: 56 * (MediaQuery.textScalerOf(context).scale(16) / 16),
          leading: IconButton(
            onPressed: _isProcessing || _hasUnconfirmedSale
                ? null
                : () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: TrexvenFontSize.section,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Review your order',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: TrexvenFontSize.caption,
                ),
              ),
            ],
          ),
        ),

        body: SafeArea(
          top: false,
          child: cart.isEmpty
              ? _buildEmptyCart()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (MediaQuery.textScalerOf(context).scale(16) > 20 ||
                        constraints.maxHeight < 600) {
                      return _buildCartContent(
                        cart,
                        itemCount,
                        footer: _buildCheckoutBottom(total),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: _buildCartContent(cart, itemCount)),

                        if (_hasUnconfirmedSale)
                          Padding(
                            padding: TrexvenSpacing.cardPadding,
                            child: Text(
                              'The sale outcome is unconfirmed. Retry the original sale to retrieve its receipt before starting another.',
                            ),
                          ),
                        _buildCheckoutBottom(total),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCartContent(
    List<CartItem> cart,
    num itemCount, {
    Widget? footer,
  }) {
    return ListView(
      padding: TrexvenSpacing.pagePadding,
      children: [
        _buildSummaryHeader(itemCount, cart.length),

        SizedBox(height: PosSpace.md),

        ...cart.map((item) => _buildCartItem(item)),
        if (footer != null && _hasUnconfirmedSale)
          const Padding(
            padding: TrexvenSpacing.cardPadding,
            child: Text(
              'The sale outcome is unconfirmed. Retry the original sale to retrieve its receipt before starting another.',
            ),
          ),
        if (footer != null) footer,
      ],
    );
  }

  Widget _buildSummaryHeader(num itemCount, int uniqueItems) {
    return Container(
      padding: const EdgeInsets.all(TrexvenSpacing.fieldGap - TrexvenSpacing.labelGap / 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Order',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'} • $uniqueItems ${uniqueItems == 1 ? 'product' : 'products'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: TrexvenFontSize.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: PosSpace.md),
      padding: const EdgeInsets.all(PosSpace.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductThumbnail(item),
              const SizedBox(width: TrexvenSpacing.labelGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _priceLevelName(item.priceLevel),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatPrice(item.selectedPrice)} each',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TrexvenSpacing.labelGap),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TrexvenSpacing.labelGap,
            runSpacing: TrexvenSpacing.labelGap,
            children: [
              _buildQuantityControls(item),
              Text(
                _formatPrice(item.total),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _isProcessing || _hasUnconfirmedSale
                    ? null
                    : () {
                        ref
                            .read(cartProvider.notifier)
                            .removeProduct(item.product.id, item.priceLevel);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(CartItem item) {
    final imageUrl = item.product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 27,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      child: Image.network(
        imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 58,
            height: 58,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 25,
            ),
          );
        },
      ),
    );
  }

  Future<void> _editQuantity(CartItem item) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final result = await showDialog<String>(
      animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
      builder: (ctx) => TextControllerScope(
        controllers: [controller],
        child: AlertDialog(
        scrollable: true,
        title: Text('Quantity in ${item.product.unit}'),
        content: TrexvenTextField(
          label: 'Quantity',
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: item.product.supportsFractionalQuantity,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Apply'),
          ),
        ],
      )),
    );
    if (result == null || !mounted || _isProcessing || _hasUnconfirmedSale) return;
    try {
      final quantity = num.tryParse(result);
      if (quantity == null || quantity <= 0)
        throw FormatException('Enter a positive quantity.');
      ref
          .read(cartProvider.notifier)
          .updateQuantity(item.product.id, item.priceLevel, quantity);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildQuantityControls(CartItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          _quantityButton(
            icon: Icons.remove_rounded,
            onPressed: _isProcessing || _hasUnconfirmedSale
                ? null
                : () {
                    ref
                        .read(cartProvider.notifier)
                        .decrement(item.product.id, item.priceLevel);
                  },
          ),

          InkWell(
            onTap: _isProcessing || _hasUnconfirmedSale
                ? null
                : () => _editQuantity(item),
            child: SizedBox(
              width: 46,
              height: 44,
              child: Center(
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: TrexvenFontSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          _quantityButton(
            icon: Icons.add_rounded,
            onPressed: _isProcessing || _hasUnconfirmedSale
                ? null
                : () {
                    ref
                        .read(cartProvider.notifier)
                        .increment(item.product.id, item.priceLevel);
                  },
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: icon == Icons.add_rounded ? 'Increase quantity'
            : icon == Icons.remove_rounded ? 'Decrease quantity' : 'Decrease quantity',
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 17,
          color: onPressed == null ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  String _priceLevelName(String level) {
    if (level.isEmpty) {
      return 'Price';
    }

    return level
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Widget _buildCheckoutBottom(double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Payment methods and allocations are handled in Confirm Payment.

          SizedBox(height: PosSpace.md),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Total to pay',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: TrexvenFontSize.input,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatPrice(total),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          SizedBox(height: PosSpace.md),

          ConstrainedBox(
            constraints: BoxConstraints(minHeight: TrexvenSpacing.buttonHeight),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _completeCheckout,
                style: Theme.of(context).elevatedButtonTheme.style,
                child: _isProcessing
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 21),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _hasUnconfirmedSale ? 'Recover original sale' : 'Proceed to Payment',
                              style: TextStyle(
                                fontSize: TrexvenFontSize.input,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() => PosStateView(title: 'Your cart is empty',
    message: 'Scan a barcode or search for a product to start a sale.', icon: Icons.shopping_cart_outlined,
    action: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to POS')));
}
