import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import 'product_provider.dart';

class CatalogEditScreen extends ConsumerStatefulWidget {
  const CatalogEditScreen({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<CatalogEditScreen> createState() => _CatalogEditScreenState();
}

class _CatalogEditScreenState extends ConsumerState<CatalogEditScreen> {
  final _request = Uuid().v4();
  final _stockRequest = Uuid().v4();
  late final Map<String, TextEditingController> _fields;
  final Map<String, TextEditingController> _attributes = {};
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic>? _intent;
  Map<String, dynamic>? _stockIntent;
  String? _group;
  String? _error;
  bool _busy = false;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _active = p.isActive;
    _group = p.catalogGroupId;
    _fields = {
      'name': p.name,
      'barcode': p.barcode ?? '',
      'sku': p.partNumber ?? '',
      'brand': p.brand ?? '',
      'category': p.category ?? '',
      'description': p.description ?? '',
      'image_url': p.imageUrl ?? '',
      'unit': p.unit,
      'selling_price': p.sellingPrice?.toString() ?? '',
      'delta': '',
      'reason': '',
    }.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    for (final e in {'size': '', 'color': '', ...p.variantAttributes}.entries) {
      _attributes[e.key] = TextEditingController(text: e.value.toString());
    }
    _loadGroups();
  }

  @override
  void dispose() {
    for (final c in [..._fields.values, ..._attributes.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String _business() {
    final id = ref.read(authStateProvider).activeBusiness?.id;
    if (id == null || id != widget.product.businessId) {
      throw StateError('Select the product business.');
    }
    return id;
  }

  Future<void> _loadGroups() async {
    try {
      final rows = await ref
          .read(productRepositoryProvider)
          .groups(_business());
      if (mounted) setState(() => _groups = rows);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = CustomerPresentation.error(
            e,
            fallback: 'Unable to load variant groups. Please try again.',
          ),
        );
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final permission = ref.read(permissionServiceProvider);
      if (!permission.canManageInventory) {
        throw StateError('Product editing is not permitted.');
      }
      if (_intent == null) {
        if (_fields['name']!.text.trim().isEmpty) {
          throw FormatException('Product name required.');
        }
        final draft = <String, dynamic>{
          for (final key in [
            'name',
            'barcode',
            'sku',
            'brand',
            'category',
            'description',
            'image_url',
            'unit',
          ])
            key: _fields[key]!.text.trim(),
          'active': _active,
          'catalog_group_id': _group,
          'variant_attributes': {
            for (final e in _attributes.entries)
              if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
          },
        };
        if (permission.canOverridePrice) {
          final raw = _fields['selling_price']!.text.trim();
          final price = raw.isEmpty ? null : num.tryParse(raw);
          if (raw.isNotEmpty &&
              (price == null ||
                  !price.isFinite ||
                  price < 0 ||
                  (price * 100 - (price * 100).round()).abs() > 0.0000001)) {
            throw FormatException(
              'Price must be nonnegative with up to two decimal places.',
            );
          }
          draft['selling_price'] = price;
        }
        _intent = draft;
      }
      await ref
          .read(productRepositoryProvider)
          .saveCatalogProduct(
            _business(),
            widget.product.id,
            _intent!,
            _request,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = CustomerPresentation.error(
            e,
            fallback: 'Save failed. Retry preserves this request.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adjust() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!ref.read(permissionServiceProvider).hasPermission('adjust_stock')) {
        throw StateError('Stock adjustment is not permitted.');
      }
      if (_stockIntent == null) {
        final delta = num.tryParse(_fields['delta']!.text);
        final reason = _fields['reason']!.text.trim();
        if (delta == null || !delta.isFinite || delta == 0 || reason.isEmpty) {
          throw FormatException('Enter a stock change and reason.');
        }
        _stockIntent = {'delta': delta, 'reason': reason};
      }
      await ref
          .read(productRepositoryProvider)
          .adjustStock(
            _business(),
            widget.product.id,
            _stockIntent!['delta'] as num,
            _stockIntent!['reason'] as String,
            _stockRequest,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = CustomerPresentation.error(
            e,
            fallback: 'Stock change failed. Retry sends the saved change.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAttribute() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Variation attribute'),
        content: TrexvenTextField(
          controller: controller,
          decoration: TrexvenInputDecoration(
            labelText: 'Attribute name, e.g. material',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    if (name.length > 40 || _attributes.containsKey(name)) {
      setState(
        () => _error = 'Use a unique attribute name with up to 40 characters.',
      );
      return;
    }
    setState(() => _attributes[name] = TextEditingController());
  }

  Future<void> _movements() async {
    try {
      final rows = await ref
          .read(productRepositoryProvider)
          .movements(_business(), widget.product.id);
      if (!mounted) return;
      await showDialog<void>(
        animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text('Stock movements'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (rows.isEmpty) Text('No recorded movements.'),
                for (final r in rows)
                  ListTile(
                    title: Text(
                      '${CustomerPresentation.label(r['movement_type'])}: ${r['quantity']}',
                    ),
                    subtitle: Text(
                      '${r['previous_quantity']} -> ${r['new_quantity']}\n${r['reason']}\n${r['created_at']}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted)
        setState(
          () => _error = CustomerPresentation.error(
            e,
            fallback: 'Unable to load movements. Please try again.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(permissionServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Edit product')),
      body: ListView(
        padding: TrexvenSpacing.cardPadding,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final key in [
            'name',
            'barcode',
            'sku',
            'brand',
            'category',
            'description',
            'image_url',
          ])
            TrexvenTextField(
              controller: _fields[key],
              enabled: !_busy && _intent == null && _stockIntent == null,
              maxLines: key == 'description' ? 3 : 1,
              decoration: TrexvenInputDecoration(
                labelText: CustomerPresentation.label(key),
              ),
            ),
          TrexvenDropdown<String>(
            initialValue: _fields['unit']!.text,
            decoration: TrexvenInputDecoration(labelText: 'Unit'),
            items: [
              for (final unit in {
                'piece',
                'kg',
                'g',
                'litre',
                'ml',
                'metre',
                'cm',
                _fields['unit']!.text,
              })
                DropdownMenuItem(value: unit, child: Text(unit)),
            ],
            onChanged: _busy || _intent != null
                ? null
                : (v) => setState(() => _fields['unit']!.text = v ?? 'piece'),
          ),
          Text('Variants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TrexvenDropdown<String>(
            initialValue: _groups.any((g) => g['id'] == _group) ? _group : null,
            decoration: TrexvenInputDecoration(labelText: 'Variant group'),
            items: [
              DropdownMenuItem(value: null, child: Text('Standalone product')),
              for (final g in _groups)
                DropdownMenuItem(
                  value: g['id'] as String,
                  child: Text(g['name'].toString()),
                ),
            ],
            onChanged: _busy || _intent != null
                ? null
                : (v) => setState(() => _group = v),
          ),
          for (final e in _attributes.entries)
            TrexvenTextField(
              controller: e.value,
              enabled: !_busy && _intent == null,
              decoration: TrexvenInputDecoration(labelText: e.key),
            ),
          TextButton(
            onPressed: _busy || _intent != null ? null : _addAttribute,
            child: Text('Add variation attribute'),
          ),
          if (permission.canOverridePrice)
            TrexvenTextField(
              controller: _fields['selling_price'],
              enabled: !_busy && _intent == null,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: TrexvenInputDecoration(
                labelText: 'Selling price (blank means pending)',
              ),
            ),
          SwitchListTile(
            title: Text('Active'),
            value: _active,
            onChanged: _busy || _intent != null
                ? null
                : (v) => setState(() => _active = v),
          ),
          FilledButton(
            onPressed: _busy || !permission.canManageInventory ? null : _save,
            child: Text(
              _intent == null ? 'Save product' : 'Retry saved product',
            ),
          ),
          Text(
            'Recorded stock: ${widget.product.stock} ${widget.product.unit}',
          ),
          TextButton(
            onPressed: _busy ? null : _movements,
            child: Text('View stock movements'),
          ),
          if (permission.hasPermission('adjust_stock')) ...[
            const SizedBox(height: 16),
            Text('Stock adjustment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TrexvenTextField(
              controller: _fields['delta'],
              enabled: !_busy && _stockIntent == null,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: TrexvenInputDecoration(labelText: 'Stock change'),
            ),
            TrexvenTextField(
              controller: _fields['reason'],
              enabled: !_busy && _stockIntent == null,
              decoration: TrexvenInputDecoration(labelText: 'Reason'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _adjust,
              child: Text(
                _stockIntent == null
                    ? 'Apply stock change'
                    : 'Retry saved stock change',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
