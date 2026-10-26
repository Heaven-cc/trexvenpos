import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import 'angel_scan_client.dart';

/// Each app owns its copy of this screen. Recognition never commits inventory.
class ProductReviewScreen extends StatefulWidget {
  final AngelScanClient api;
  final bool singleProduct;
  final bool allowExisting;
  final String sourceLabel;
  final String? sourceName;
  final List<Map<String, dynamic>> initialDocuments;
  final Future<List<Map<String, dynamic>>> Function(
    List<Map<String, dynamic>> rows,
  )?
  validateCatalog;
  final Future<void> Function(
    List<Map<String, dynamic>> rows,
    String requestId,
  )?
  confirmCatalog;
  final bool owner;
  final List<Map<String, dynamic>> initialItems;
  final String? existingRequestId;
  final String? automaticSourceHash;
  final Future<bool> Function(Map<String, dynamic> product)? onSale;
  final bool Function()? contextIsCurrent;
  const ProductReviewScreen({
    super.key,
    required this.api,
    this.owner = false,
    this.singleProduct = false,
    this.allowExisting = true,
    this.sourceLabel = 'Product list scanned by Angel',
    this.sourceName,
    this.initialDocuments = const [],
    this.validateCatalog,
    this.confirmCatalog,
    this.onSale,
    this.contextIsCurrent,
    this.initialItems = const [],
    this.existingRequestId,
    this.automaticSourceHash,
  });
  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _documents = [];
  final Set<String> _sources = {};
  final Set<String> _sold = {};
  final String _request = const Uuid().v4();
  bool _busy = false, _submitted = false, _attempted = false;
  Map<String, dynamic>? _research;
  List<Map<String, dynamic>>? _catalogPayload;
  bool get _catalog => widget.confirmCatalog != null;
  String? _error, _message;
  String? _user;
  bool get _inventory => widget.api.inventoryMode;
  @override
  void initState() {
    super.initState();
    _user = widget.api.client.auth.currentUser?.id;
    _documents.addAll(widget.initialDocuments);
    if (widget.automaticSourceHash?.isNotEmpty == true) {
      _sources.add(widget.automaticSourceHash!);
    }
    for (final row in widget.initialItems) {
      final matches = (row['matches'] as List? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      final exact =
          !_catalog &&
              matches.length == 1 &&
              (matches.single['score'] as num? ?? 0) >= 95
          ? matches.single
          : null;
      final selected = row['product_id'] != null
          ? <String, dynamic>{
              'product_id': row['product_id'],
              'name': row['name'],
              'unit': row['current_unit'] ?? row['unit'],
            }
          : exact;
      _items.add({
        ...row,
        '_reviewed': _catalog,
        if (!_catalog && selected != null) 'product_id': selected['product_id'],
        if (!_catalog && selected != null) '_selected': selected,
      });
    }
  }

  void _check() {
    widget.api.checkSession();
    if (widget.api.client.auth.currentUser?.id != _user ||
        widget.contextIsCurrent?.call() == false) {
      throw StateError('Your business or branch changed. Reopen Angel Scan.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _check();
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Unable to complete this step. Check your connection, image format and current access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(int index) async {
    if (_busy || _submitted || _attempted) return;
    if (_catalog) {
      await _editCatalog(index);
      return;
    }
    final item = _items[index];
    final fields = <String, TextEditingController>{
      for (final key in [
        'name',
        'brand',
        'sku',
        'barcode',
        'quantity',
        'cost',
        'selling_price',
        'unit',
      ])
        key: TextEditingController(
          text:
              '${item[key] ?? (key == 'unit'
                      ? 'piece'
                      : key == 'quantity' && widget.singleProduct
                      ? 1
                      : '')}',
        ),
    };
    Map<String, dynamic>? chosen = item['_selected'] as Map<String, dynamic>?;
    var matches = (item['matches'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    String? error;
    bool searching = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            _inventory ? 'Review product' : 'Select inventory product',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item['uncertain'] != false)
                    const Text(
                      'Identification needs confirmation. Check the original product or document.',
                    ),
                  if (item['evidence'] != null) Text('${item['evidence']}'),
                  TextField(
                    controller: fields['name'],
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: searching
                        ? null
                        : () async {
                            update(() => searching = true);
                            try {
                              final found = await widget.api.search(
                                fields['name']!.text,
                              );
                              _check();
                              if (context.mounted) {
                                update(() {
                                  matches = found;
                                  chosen = null;
                                });
                              }
                            } catch (_) {
                              if (context.mounted) {
                                update(
                                  () => error =
                                      'Search unavailable. Check access.',
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                update(() => searching = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('Search inventory'),
                  ),
                  if (matches.isEmpty && chosen == null)
                    const Text(
                      'Product Not Found. Refine the name or review as a new inventory product.',
                    ),
                  for (final match in matches)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        chosen?['product_id'] == match['product_id']
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text('${match['name']}'),
                      subtitle: Text(
                        '${match['brand'] ?? ''} ${match['sku'] ?? ''}\n'
                        'Stock: ${match['quantity']} • Price: ${match['selling_price'] ?? 'Not set'}'
                        '${match['active'] == true ? '' : ' • Unavailable for sale'}',
                      ),
                      onTap: () => update(() => chosen = match),
                    ),
                  if (_inventory) ...[
                    TextButton(
                      onPressed: () => update(() => chosen = null),
                      child: const Text('Create as new product'),
                    ),
                    if (chosen == null) ...[
                      for (final key in ['brand', 'sku', 'barcode', 'unit'])
                        TextField(
                          controller: fields[key],
                          decoration: InputDecoration(
                            labelText: {
                              'brand': 'Brand',
                              'sku': 'SKU / part number',
                              'barcode': 'Barcode',
                              'unit':
                                  'Unit (piece, kg, g, litre, ml, metre, cm)',
                            }[key],
                          ),
                        ),
                      TextField(
                        controller: fields['selling_price'],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText:
                              'Selling price (leave blank for pending product)',
                        ),
                      ),
                    ] else
                      const Text(
                        'Restock selected product. Existing identity and selling price are preserved.',
                      ),
                    TextField(
                      controller: fields['quantity'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity to add',
                      ),
                    ),
                    TextField(
                      controller: fields['cost'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Purchase unit cost (optional)',
                      ),
                    ),
                    if (item['line_total'] != null)
                      Text('Document line total: ${item['line_total']}'),
                  ],
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qty = num.tryParse(fields['quantity']!.text);
                final costText = fields['cost']!.text.trim(),
                    priceText = fields['selling_price']!.text.trim();
                final cost = num.tryParse(costText),
                    price = num.tryParse(priceText);
                if ((_inventory && chosen != null && !widget.allowExisting) ||
                    (_inventory &&
                        (fields['name']!.text.trim().isEmpty ||
                            qty == null ||
                            !qty.isFinite ||
                            qty <= 0 ||
                            qty > 1000000 ||
                            (qty * 1000 - (qty * 1000).round()).abs() >
                                .0000001 ||
                            !const [
                              'piece',
                              'kg',
                              'g',
                              'litre',
                              'ml',
                              'metre',
                              'cm',
                            ].contains(
                              chosen?['unit'] ?? fields['unit']!.text.trim(),
                            ) ||
                            ((chosen?['unit'] ?? fields['unit']!.text.trim()) ==
                                    'piece' &&
                                qty % 1 != 0) ||
                            (costText.isNotEmpty &&
                                (cost == null ||
                                    !cost.isFinite ||
                                    cost < 0 ||
                                    cost > 1e11 ||
                                    (cost * 100 - (cost * 100).round()).abs() >
                                        .0000001)) ||
                            (chosen == null &&
                                priceText.isNotEmpty &&
                                (price == null ||
                                    !price.isFinite ||
                                    price < 0 ||
                                    price > 1e11 ||
                                    (price * 100 - (price * 100).round())
                                            .abs() >
                                        .0000001)))) ||
                    (!_inventory &&
                        (chosen == null || chosen!['active'] != true))) {
                  update(
                    () => error = _inventory
                        ? (!widget.allowExisting && chosen != null
                              ? 'Enable Update existing products on the import screen before restocking.'
                              : 'Review the product, quantity and prices.')
                        : 'Select an active inventory product with a price.',
                  );
                  return;
                }
                setState(() {
                  for (final key in [
                    'name',
                    'brand',
                    'sku',
                    'barcode',
                    'unit',
                  ]) {
                    item[key] = fields[key]!.text.trim();
                  }
                  item['quantity'] = qty;
                  item['cost'] = cost;
                  item['selling_price'] = chosen == null ? price : null;
                  item['product_id'] = chosen?['product_id'];
                  item['_selected'] = chosen;
                  item['_reviewed'] = true;
                  if (chosen != null) {
                    item['name'] = chosen!['name'];
                    item['unit'] = chosen!['unit'] ?? item['unit'];
                  }
                });
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm product'),
            ),
          ],
        ),
      ),
    );
    // Disposing after the route's exit animation avoids controllers being used by closing fields.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      for (final c in fields.values) {
        c.dispose();
      }
    });
    if (saved == true && !_inventory && mounted) await _sell(index);
  }

  Future<void> _sell(int index) => _run(() async {
    final item = _items[index];
    final selected = item['_selected'];
    if (selected is! Map<String, dynamic>) return;
    final id = '${selected['product_id']}';
    if (_sold.contains(id)) {
      final repeat = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Add this product again?'),
          content: Text(
            '${selected['name']} is already added from this scanner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Add another'),
            ),
          ],
        ),
      );
      if (repeat != true) return;
    }
    _check();
    final added = await widget.onSale?.call(selected) ?? false;
    if (mounted) {
      setState(() {
        if (added) _sold.add(id);
        _message = added
            ? 'Added to checkout'
            : 'Product was not added. Verify current price and branch access.';
      });
    }
    if (added && widget.singleProduct && mounted) Navigator.pop(context);
  });
  Future<void> _submit() => _run(() async {
    if (_items.isEmpty || _items.any((i) => i['_reviewed'] != true)) {
      throw StateError('Confirm every product before continuing.');
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          widget.owner
              ? 'Confirm inventory changes'
              : 'Send to owner for approval',
        ),
        content: Text(
          '${_items.length} product lines will be ${widget.owner ? 'submitted and posted after your approval' : 'submitted for review'}.\n'
          'Total quantity: ${_items.fold<num>(0, (sum, i) => sum + (i['quantity'] as num))}\nExisting selling prices are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(widget.owner ? 'Approve and post' : 'Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _check();
    setState(() => _attempted = true);
    final hashes = _sources.toList()..sort();
    final documentHash = hashes.length == 1
        ? hashes.single
        : (await Sha256().hash(
            utf8.encode(hashes.join(':')),
          )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final reviewed = _items
        .map(
          (i) => <String, dynamic>{
            for (final key in [
              'product_id',
              'name',
              'brand',
              'sku',
              'barcode',
              'category',
              'unit',
              'quantity',
              'cost',
              'selling_price',
              'line_total',
              'evidence',
              'uncertain',
            ])
              if (i[key] != null) key: i[key],
          },
        )
        .toList();
    final request = widget.existingRequestId != null
        ? Map<String, dynamic>.from(
            await widget.api.client.rpc(
                  'revise_angel_inventory_request',
                  params: {
                    'p_business_id': widget.api.businessId,
                    'p_request_id': widget.existingRequestId,
                    'p_items': reviewed,
                  },
                )
                as Map,
          )
        : await widget.api.submit(
            requestId: _request,
            documentHash: documentHash,
            items: reviewed,
            metadata: {'sources': hashes, 'documents': _documents},
          );
    _check();
    var result = request;
    if (widget.owner &&
        (request['duplicate'] != true ||
            request['id'] == _request ||
            request['id'] == widget.existingRequestId)) {
      result = await widget.api.decide('${request['id']}', true);
    }
    if (!mounted) return;
    setState(() {
      _submitted = true;
      _message =
          '${request['duplicate'] == true ? 'Document already submitted. ' : ''}'
          'Request ${request['id']}\nDecision: ${result['status']} • Stock: ${result['application_status']}'
          '${result['application_error'] == null ? '' : '\n${result['application_error']}'}\n'
          '${widget.owner ? 'Open Notifications to inspect the final request or retry a failed posting.' : 'No stock changes until the owner approves. Track the request in your inventory requests.'}';
    });
  });
  Future<void> _history() async {
    try {
      _check();
      final requests = await widget.api.client
          .from('angel_inventory_approval_requests')
          .select(
            'id,branch_id,status,application_status,application_error,items,created_at',
          )
          .eq('business_id', widget.api.businessId)
          .order('created_at', ascending: false)
          .limit(30);
      _check();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .75,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Recent inventory requests',
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                if (requests.isEmpty)
                  const ListTile(title: Text('No requests yet')),
                for (final r in requests)
                  ExpansionTile(
                    title: Text(
                      '${r['status']} · Stock: ${r['application_status']}',
                    ),
                    subtitle: Text('${r['created_at']}\n${r['id']}'),
                    children: [
                      if (r['application_error'] != null)
                        Text('${r['application_error']}'),
                      for (final i in r['items'] as List)
                        ListTile(
                          dense: true,
                          title: Text('${i['name']} × ${i['quantity']}'),
                          subtitle: Text(
                            i['product_id'] == null ? 'New product' : 'Restock',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Request history unavailable. Verify current access.',
        );
      }
    }
  }

  Future<void> _publicResearch() => _run(() async {
    if (_items.isEmpty) return;
    final result = await widget.api.researchProduct(_items.first);
    _check();
    if (mounted) setState(() => _research = result);
  });

  Future<void> _editCatalog(int index) async {
    final row = _items[index];
    final existing = row['product_id'] != null;
    final keys = [
      'name',
      'brand',
      'sku',
      'barcode',
      'unit',
      existing ? 'stock_delta' : 'initial_quantity',
      if (existing) 'stock_reason',
      if (!existing) 'selling_price',
    ];
    final fields = {
      for (final key in keys)
        key: TextEditingController(text: '${row[key] ?? ''}'),
    };
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Edit product'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (existing)
                    const Text(
                      'Restock: the current selling price is preserved.',
                    ),
                  for (final key in keys)
                    TextField(
                      controller: fields[key],
                      enabled: !saving,
                      decoration: InputDecoration(
                        labelText: key.replaceAll('_', ' '),
                      ),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final candidate = Map<String, dynamic>.from(row)
                          ..remove('_reviewed');
                        for (final key in keys) {
                          final text = fields[key]!.text.trim();
                          candidate.remove(key);
                          if (text.isNotEmpty) candidate[key] = text;
                        }
                        final rows = [
                          for (var n = 0; n < _items.length; n++)
                            n == index
                                ? candidate
                                : (Map<String, dynamic>.from(_items[n])
                                    ..remove('_reviewed')),
                        ];
                        final checked = await widget.validateCatalog!(rows);
                        _check();
                        if (!mounted || !dialogContext.mounted) return;
                        setState(() {
                          _items.clear();
                          _items.addAll(
                            checked.map((i) => {...i, '_reviewed': true}),
                          );
                        });
                        Navigator.pop(dialogContext);
                      } catch (e) {
                        if (context.mounted) {
                          update(() {
                            error = e is FormatException
                                ? e.message
                                : 'Review the values and current business access.';
                            saving = false;
                          });
                        }
                      }
                    },
              child: const Text('Save product'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      for (final c in fields.values) {
        c.dispose();
      }
    });
  }

  Future<void> _submitCatalog() => _run(() async {
    if (_items.isEmpty) throw StateError('Add at least one product.');
    final rows = _items
        .map((i) => Map<String, dynamic>.from(i)..remove('_reviewed'))
        .toList();
    // All catalog rows pass the original parser, identifier matching and update safeguards again.
    final checked = _catalogPayload ?? await widget.validateCatalog!(rows);
    _check();
    if (!_attempted) {
      _catalogPayload = checked
          .map((i) => Map<String, dynamic>.from(i))
          .toList();
      _items.clear();
      _items.addAll(checked.map((i) => {...i, '_reviewed': true}));
      if (mounted) setState(() => _attempted = true);
    }
    await widget.confirmCatalog!(
      checked.map((i) => Map<String, dynamic>.from(i)).toList(),
      _request,
    );
    _check();
    if (mounted) Navigator.pop(context, true);
  });

  Widget _metric(String label, int value) => Expanded(
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            Text(label),
          ],
        ),
      ),
    ),
  );

  Widget _productRow(int index) {
    final item = _items[index];
    final match = item['_selected'] as Map?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          item['_reviewed'] == true
              ? Icons.check_circle_outline
              : Icons.edit_outlined,
        ),
        title: Text('${item['name'] ?? 'Name required'}'),
        subtitle: Text(
          '${_catalog ? (item['stock_delta'] ?? item['initial_quantity'] ?? 0) : item['quantity'] ?? 'Quantity required'} ${item['unit'] ?? 'piece'} · '
          '${item['product_id'] == null ? 'New / unmatched' : 'Existing · restock'}'
          '${item['_reviewed'] == true ? '' : ' · Needs review'}'
          '${match == null ? '' : "\nInventory: ${match['name']}"}',
        ),
        onTap: _busy || _submitted || _attempted ? null : () => _edit(index),
        trailing: _busy || _submitted || _attempted
            ? null
            : IconButton(
                tooltip: 'Remove product',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _items.removeAt(index)),
              ),
      ),
    );
  }

  Widget _sourceLink(dynamic source) {
    final citation = source is Map ? source['url_citation'] ?? source : source;
    final raw = citation is Map
        ? citation['url']?.toString() ?? ''
        : citation.toString();
    final uri = Uri.tryParse(raw);
    final title = citation is Map ? citation['title']?.toString() ?? raw : raw;
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return SelectableText(title);
    }
    return TextButton.icon(
      onPressed: _busy
          ? null
          : () => _run(() async {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                throw StateError('Unable to open this source.');
              }
            }),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  List<Widget> _singleDetails() {
    final item = _items.first;
    final matches = item['matches'] as List? ?? [];
    return [
      Text('${item['name']}', style: Theme.of(context).textTheme.titleLarge),
      Text(widget.sourceLabel, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      for (final key in ['brand', 'sku', 'barcode', 'evidence'])
        if (item[key] != null && '${item[key]}'.isNotEmpty)
          Text('${key.toUpperCase()}: ${item[key]}'),
      const SizedBox(height: 8),
      Text(
        item['uncertain'] == false
            ? 'Visible identifiers extracted. Verify the inventory match.'
            : 'Identification uncertain. Confirm details against the product.',
      ),
      if (matches.isEmpty)
        const Text(
          'Not found in this business inventory. Online identification is unverified.',
        ),
      for (final value in matches)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${value['name']}'),
          subtitle: Text(
            'Stock: ${value['quantity']} · Price: ${value['selling_price'] ?? 'Not set'}\n'
            '${(value['score'] as num? ?? 0) >= 95 ? 'Identifier match — confirm' : 'Suggested match — review required'}',
          ),
        ),
      OutlinedButton.icon(
        onPressed: _busy || _attempted ? null : () => _edit(0),
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          _inventory
              ? 'Edit and verify product'
              : 'Select product and add to checkout',
        ),
      ),
      TextButton.icon(
        onPressed: _busy ? null : _publicResearch,
        icon: const Icon(Icons.travel_explore),
        label: const Text('Research product online'),
      ),
      if (_research != null) ...[
        const Text('Public research · advisory only'),
        SelectableText('${_research!['summary'] ?? 'No findings available.'}'),
        for (final source in _research!['sources'] as List? ?? [])
          _sourceLink(source),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final existing = _items.where((i) => i['product_id'] != null).length;
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      shrinkWrap: widget.singleProduct,
      children: [
        if (widget.singleProduct && _items.isNotEmpty)
          ..._singleDetails()
        else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(widget.sourceLabel),
              subtitle: Text(
                widget.sourceName ??
                    '${_items.length} product lines · review before confirming',
              ),
            ),
          ),
          for (final doc in _documents)
            if (doc['supplier'] != null || doc['document_number'] != null)
              Text('${doc['supplier'] ?? ''} ${doc['document_number'] ?? ''}'),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Products', _items.length),
              _metric('Existing', existing),
              _metric('New', _items.length - existing),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++) _productRow(i),
        ],
        if (_busy)
          const Padding(padding: EdgeInsets.all(12), child: Text('Working…')),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_message?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SelectableText(_message!),
          ),
        if (_submitted)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        if (!_submitted && _inventory) ...[
          if (_items.any((i) => i['_reviewed'] != true))
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Open each product to confirm its identity, quantity and missing information.',
              ),
            ),
          FilledButton(
            onPressed: _busy || _items.isEmpty
                ? null
                : (_catalog ? _submitCatalog : _submit),
            child: Text(
              _attempted
                  ? 'Retry same request'
                  : _catalog
                  ? 'Confirm import'
                  : !widget.owner
                  ? 'Request owner approval'
                  : widget.singleProduct
                  ? (_items.first['product_id'] == null
                        ? 'Add new product'
                        : 'Restock product')
                  : 'Confirm inventory changes',
            ),
          ),
        ],
        if (_attempted && !_submitted)
          const Text(
            'Retry preserves this request. Editing is locked until the result is confirmed.',
          ),
        const SizedBox(height: 16),
        const Center(child: Text('Powered by TREXVEN')),
      ],
    );
    if (widget.singleProduct) {
      return PopScope(
        canPop: !_busy,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE614213D),
                border: Border.all(color: Colors.white.withValues(alpha: .2)),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Theme(
                data: ThemeData.dark(
                  useMaterial3: true,
                ).copyWith(scaffoldBackgroundColor: Colors.transparent),
                child: SafeArea(top: false, child: content),
              ),
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_busy && !(_catalog && _attempted),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review products'),
          actions: [
            if (_inventory && !_catalog)
              IconButton(
                tooltip: 'Inventory requests',
                onPressed: _busy ? null : _history,
                icon: const Icon(Icons.history),
              ),
          ],
        ),
        body: content,
      ),
    );
  }
}

/// Lists use a route; single products stay over the initialized live camera.
Future<void> showAngelProductReview(
  BuildContext context, {
  required AngelScanClient api,
  required Map<String, dynamic> result,
  required bool singleProduct,
  bool owner = false,
  bool Function()? contextIsCurrent,
  Future<bool> Function(Map<String, dynamic>)? onSale,
}) async {
  final screen = ProductReviewScreen(
    api: api,
    owner: owner,
    singleProduct: singleProduct,
    initialItems: (result['items'] as List)
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList(),
    automaticSourceHash: result['document_hash']?.toString(),
    initialDocuments:
        (result['documents'] as List? ??
                [
                  {
                    'supplier': result['supplier'],
                    'document_number': result['document_number'],
                  },
                ])
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList(),
    sourceLabel: '${result['source_label'] ?? 'Product list scanned by Angel'}',
    sourceName: result['source_name']?.toString(),
    contextIsCurrent: contextIsCurrent,
    onSale: onSale,
  );
  if (singleProduct) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      builder: (_) =>
          Theme(data: ThemeData.dark(useMaterial3: true), child: screen),
    );
  } else {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
