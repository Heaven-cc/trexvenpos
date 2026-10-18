import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import 'product_provider.dart';

class QuickAddScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;

  const QuickAddScreen({super.key, this.initialBarcode});

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _partNumberController;
  late final TextEditingController _brandController;

  final _nameFocusNode = FocusNode();
  final _barcodeFocusNode = FocusNode();
  final _partNumberFocusNode = FocusNode();
  final _brandFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _showAdditionalDetails = false;
  final String _productRequestId = Uuid().v4();

  bool get _hasScannedBarcode {
    return widget.initialBarcode != null &&
        widget.initialBarcode!.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();

    _barcodeController = TextEditingController(
      text: widget.initialBarcode ?? '',
    );

    _partNumberController = TextEditingController();

    _brandController = TextEditingController();
    _showAdditionalDetails = _hasScannedBarcode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _partNumberController.dispose();
    _brandController.dispose();

    _nameFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _partNumberFocusNode.dispose();
    _brandFocusNode.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (!ref.read(permissionServiceProvider).canQuickAddProduct) {
      _showError('You do not have permission to add products.');
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final businessId = ref.read(authStateProvider).activeBusiness?.id;

    if (businessId == null ||
        businessId.isEmpty ||
        ref.read(authStateProvider).employee?.businessId != businessId) {
      _showError('No active business is selected.');
      return;
    }

    final barcode = _barcodeController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(productRepositoryProvider);

      // Check for an existing product one more time
      // before inserting.
      if (barcode.isNotEmpty) {
        final existingProduct = await repository.findProductByBarcode(
          barcode,
          businessId,
        );

        if (existingProduct != null) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isSubmitting = false;
          });

          await _showExistingProductDialog(existingProduct);

          return;
        }
      }

      final product = Product(
        id: _productRequestId,
        name: _nameController.text.trim(),
        barcode: barcode.isEmpty ? null : barcode,
        partNumber: _partNumberController.text.trim().isEmpty
            ? null
            : _partNumberController.text.trim(),
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        status: ProductStatus.pending,
        businessId: businessId,
      );

      final savedProduct = await repository.quickAddProduct(product);

      if (!mounted) {
        return;
      }

      // Return the actual newly-created
      // Product to the ScannerScreen.
      Navigator.pop(context, savedProduct);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      _showError('Unable to add the product. Please try again.');
    }
  }

  Future<void> _showExistingProductDialog(Product product) async {
    await showModalBottomSheet<void>(
      sheetAnimationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.page)),
context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),

                SizedBox(height: PosSpace.md),

                Text(
                  'Product Already Exists',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: TrexvenFontSize.input,
                  ),
                ),

                SizedBox(height: PosSpace.md),

                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: TrexvenSpacing.buttonHeight,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, product);
                      },
                      style: Theme.of(context).elevatedButtonTheme.style,
                      child: Text(
                        'Use Existing Product',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.input,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        content: Text(message),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TrexvenInputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),

        SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: TrexvenFontSize.body,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pending_actions_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending approval',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Products added from the POS remain pending until they are reviewed.',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.body,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewProduct() async {
    if (_isSubmitting || !ref.read(permissionServiceProvider).canQuickAddProduct) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Review product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_nameController.text.trim(),
              style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text('Brand: ${_brandController.text.trim().isEmpty ? 'Not specified' : _brandController.text.trim()}'),
            if (_partNumberController.text.trim().isNotEmpty)
              Text('Part number: ${_partNumberController.text.trim()}'),
            if (_barcodeController.text.trim().isNotEmpty)
              Text('Barcode: ${_barcodeController.text.trim()}'),
            const SizedBox(height: 12),
            const Text('This product will be submitted as pending approval.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Edit')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit product')),
        ],
      ),
    );
    if (confirmed == true && mounted) await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = ref.watch(permissionServiceProvider).canQuickAddProduct;
    if (!canAdd) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Product')),
        body: const Center(child: Text('You do not have permission to add products.')),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text('Quick inventory submission',
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(Icons.shield_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Submitted for approval',
                        style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text('New products are reviewed before activation.',
                        style: Theme.of(context).textTheme.bodySmall),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Product details',
                      style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TrexvenTextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_brandFocusNode),
                      decoration: _inputDecoration(
                        label: 'Product name *',
                        hint: 'e.g. Coca-Cola 50cl',
                        icon: Icons.inventory_2_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Product name is required';
                        if (value.trim().length < 2) return 'Enter a valid product name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TrexvenTextFormField(
                      controller: _brandController,
                      focusNode: _brandFocusNode,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _reviewProduct(),
                      decoration: _inputDecoration(
                        label: 'Brand (optional)',
                        hint: 'e.g. Coca-Cola',
                        icon: Icons.workspace_premium_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : () =>
                        setState(() => _showAdditionalDetails = !_showAdditionalDetails),
                      icon: Icon(_showAdditionalDetails
                        ? Icons.expand_less_rounded : Icons.tune_rounded),
                      label: const Text('Additional details'),
                    ),
                    if (_showAdditionalDetails) ...[
                      const SizedBox(height: 12),
                      TrexvenTextFormField(
                        controller: _partNumberController,
                        focusNode: _partNumberFocusNode,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_barcodeFocusNode),
                        decoration: _inputDecoration(
                          label: 'Part number / SKU (optional)',
                          hint: 'e.g. COKE-50CL',
                          icon: Icons.tag_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TrexvenTextFormField(
                        controller: _barcodeController,
                        focusNode: _barcodeFocusNode,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\\s')),
                        ],
                        decoration: _inputDecoration(
                          label: _hasScannedBarcode ? 'Scanned barcode (optional)' : 'Barcode (optional)',
                          hint: 'Enter barcode',
                          icon: Icons.qr_code_scanner_outlined,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                  'This submits a product request. It will not become available for sale until approved.',
                )),
              ]),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _reviewProduct,
                icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_circle_outline),
                label: Text(_isSubmitting ? 'Submitting…' : 'Review Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
