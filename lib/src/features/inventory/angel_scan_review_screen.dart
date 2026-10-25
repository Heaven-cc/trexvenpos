import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import 'angel_scan_client.dart';

/// Each app owns its copy of this screen. Recognition never commits inventory.
class AngelScanReviewScreen extends StatefulWidget {
  final AngelScanClient api;
  final bool owner;
  final List<Map<String, dynamic>> initialItems;
  final String? existingRequestId;
  final String? automaticSourceHash;
  final Future<String?> Function()? scanBarcode;
  final Future<bool> Function(Map<String, dynamic> product)? onSale;
  final bool Function()? contextIsCurrent;
  const AngelScanReviewScreen({
    super.key,
    required this.api,
    this.owner = false,
    this.onSale,
    this.contextIsCurrent,
    this.initialItems = const [],
    this.existingRequestId,
    this.automaticSourceHash,
    this.scanBarcode,
  });
  @override
  State<AngelScanReviewScreen> createState() => _AngelScanReviewScreenState();
}

class _AngelScanReviewScreenState extends State<AngelScanReviewScreen> {
  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _documents = [];
  final Set<String> _sources = {};
  final Set<String> _sold = {};
  String _request = const Uuid().v4();
  bool _busy = false, _document = false, _research = false, _submitted = false;
  String? _error, _message;
  int _progress = 0;
  String? _user;
  bool get _inventory => widget.api.inventoryMode;
  @override
  void initState() {
    super.initState();
    _user = widget.api.client.auth.currentUser?.id;
    if (widget.automaticSourceHash?.isNotEmpty == true) _sources.add(widget.automaticSourceHash!);
    _items.addAll(
      widget.initialItems.map(
        (i) => {
          ...i,
          '_reviewed': false,
          if (i['product_id'] != null)
            '_selected': <String, dynamic>{
              'product_id': i['product_id'],
              'name': i['name'],
              'unit': i['current_unit'] ?? i['unit'],
            },
        },
      ),
    );
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
      if (mounted)
        setState(
          () => _error = error is StateError ? error.message.toString() : 'Unable to complete this step. Check your connection, image format and current access.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recognize(Uint8List bytes, String source) async {
    _check();
    final result = await widget.api.recognize(
      bytes,
      document: _document,
      research: _research,
    );
    _check();
    if (!mounted) return;
    final found = (result['items'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    if (_items.length + found.length > 500)
      throw StateError('Review up to 500 products at a time.');
    setState(() {
      _items.addAll(
        found.map((row) => {...row, '_reviewed': false, '_source': source}),
      );
      _progress++;
      _documents.add({
        'supplier': result['supplier'],
        'document_number': result['document_number'],
      });
      final research = result['research'];
      _message = [
        if (result['notes'] != null) '${result['notes']}',
        if (result['supplier'] != null) 'Supplier: ${result['supplier']}',
        if (result['document_number'] != null)
          'Document: ${result['document_number']}',
        if (research is Map && research['summary'] != null)
          'Public research (review before use): ${research['summary']}',
      ].join('\n');
    });
  }

  Future<void> _photo(picker.ImageSource source) => _run(() async {
    if (_sources.length >= 20)
      throw StateError('Use at most 20 source documents per review.');
    final image = await picker.ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 3200,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final hash = await AngelScanClient.fingerprint(bytes);
    if (_sources.contains(hash))
      throw StateError('This image is already in your review.');
    await _recognize(bytes, hash);
    _sources.add(hash);
  });
  Future<void> _upload() => _run(() async {
    if (_sources.length >= 20)
      throw StateError('Use at most 20 source documents per review.');
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images and PDF',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 20000000)
      throw StateError('Choose a document smaller than 20 MB.');
    final bytes = await file.readAsBytes();
    final source = await AngelScanClient.fingerprint(bytes);
    if (_sources.contains(source))
      throw StateError('This document is already in your review.');
    if (file.name.toLowerCase().endsWith('.pdf')) {
      if (!_inventory)
        throw StateError('Choose one product image for checkout.');
      if (mounted) setState(() => _document = true);
      final pdf = await PdfDocument.openData(bytes);
      final staged = _items.length;
      final stagedDocuments = _documents.length;
      try {
        if (pdf.pagesCount < 1 || pdf.pagesCount > 20)
          throw StateError('Choose a PDF with 1 to 20 pages.');
        for (var n = 1; n <= pdf.pagesCount; n++) {
          _check();
          if (!mounted) return;
          final page = await pdf.getPage(n);
          try {
            final ratio =
                2200 / (page.width > page.height ? page.width : page.height);
            final image = await page.render(
              width: page.width * ratio,
              height: page.height * ratio,
              format: PdfPageImageFormat.jpeg,
              quality: 88,
              backgroundColor: '#FFFFFF',
            );
            if (image == null) throw StateError('Page $n could not be read.');
            await _recognize(image.bytes, source);
          } finally {
            await page.close();
          }
        }
        _sources.add(source);
      } catch (_) {
        // Failed PDF batches are removed together so retrying cannot duplicate earlier pages.
        if (mounted)
          setState(() {
            _items.removeRange(staged, _items.length);
            _documents.removeRange(stagedDocuments, _documents.length);
          });
        rethrow;
      } finally {
        await pdf.close();
      }
    } else {
      await _recognize(bytes, source);
      _sources.add(source);
    }
  });
  Future<void> _edit(int index) async {
    if (_busy || _submitted) return;
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
          text: '${item[key] ?? (key == 'unit' ? 'piece' : '')}',
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
                              if (context.mounted)
                                update(() {
                                  matches = found;
                                  chosen = null;
                                });
                            } catch (_) {
                              if (context.mounted)
                                update(
                                  () => error =
                                      'Search unavailable. Check access.',
                                );
                            } finally {
                              if (context.mounted)
                                update(() => searching = false);
                            }
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('Search inventory'),
                  ),
                  if (matches.isEmpty)
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
                if ((_inventory &&
                        (fields['name']!.text.trim().isEmpty ||
                            qty == null ||
                            !qty.isFinite ||
                            qty <= 0 ||
                            (costText.isNotEmpty &&
                                (cost == null || !cost.isFinite || cost < 0)) ||
                            (chosen == null &&
                                priceText.isNotEmpty &&
                                (price == null ||
                                    !price.isFinite ||
                                    price < 0)))) ||
                    (!_inventory &&
                        (chosen == null || chosen!['active'] != true))) {
                  update(
                    () => error = _inventory
                        ? 'Review the product, quantity and prices.'
                        : 'Select an active inventory product with a price.',
                  );
                  return;
                }
                setState(() {
                  for (final key in ['name', 'brand', 'sku', 'barcode', 'unit'])
                    item[key] = fields[key]!.text.trim();
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
    if (mounted)
      setState(() {
        if (added) _sold.add(id);
        _message = added
            ? 'Added to checkout'
            : 'Product was not added. Verify current price and branch access.';
      });
  });
  Future<void> _submit() => _run(() async {
    if (_items.isEmpty || _items.any((i) => i['_reviewed'] != true))
      throw StateError('Confirm every product before continuing.');
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
    final hashes = _sources.toList()..sort();
    final documentHash = hashes.length == 1
        ? hashes.single
        : (await Sha256().hash(utf8.encode(hashes.join(':')))).bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
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
            ) as Map,
          )
        : await widget.api.submit(
            requestId: _request,
            documentHash: documentHash,
            items: reviewed,
            metadata: {'sources': hashes, 'documents': _documents},
          );
    _check();
    var result = request;
    if (widget.owner && request['duplicate'] != true)
      result = await widget.api.decide('${request['id']}', true);
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
      if (mounted)
        setState(
          () => _error = 'Request history unavailable. Verify current access.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_inventory ? 'Angel Scan · Inventory' : 'Angel Scan · Sell'),
      actions: [
        if (_inventory)
          IconButton(
            tooltip: 'Inventory requests',
            onPressed: _busy ? null : _history,
            icon: const Icon(Icons.history),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _inventory
              ? 'Scan products, receipts or lists. Review every line before confirmation.'
              : 'Recognize one product, then select its inventory match.',
        ),
        if (!_submitted && widget.existingRequestId == null) ...[
          if (_inventory)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Receipt / product list'),
              value: _document,
              onChanged: _busy ? null : (v) => setState(() => _document = v),
            ),
          if (!_document)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Research public product information'),
              subtitle: const Text(
                'Uses visible product identifiers. Research remains a suggestion.',
              ),
              value: _research,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _research = v == true),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (widget.scanBarcode != null)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final code = await widget.scanBarcode!();
                          if (code == null) return;
                          final matches = await widget.api.search(code);
                          _check();
                          if (matches.isEmpty)
                            throw StateError(
                              'Product Not Found. Use a product photograph to review a new product.',
                            );
                          final source = await AngelScanClient.fingerprint(
                            utf8.encode('barcode:$_request:$code'),
                          );
                          if (_sources.contains(source))
                            throw StateError(
                              'This barcode is already in your review. Edit its quantity.',
                            );
                          if (mounted)
                            setState(() {
                              _sources.add(source);
                              _items.add({
                                'name': matches.first['name'],
                                'barcode': code,
                                'matches': matches,
                                '_reviewed': false,
                              });
                            });
                        }),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Barcode'),
                ),

              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _photo(picker.ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capture'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _photo(picker.ImageSource.gallery),
                icon: const Icon(Icons.photo_outlined),
                label: const Text('Gallery'),
              ),
              if (_inventory)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _upload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Image / PDF'),
                ),
            ],
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          Text('Processing · $_progress pages read'),
        ],
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
        Text(
          '${_items.length} product lines · ${_items.where((i) => i['_reviewed'] == true).length} confirmed',
        ),
        for (var i = 0; i < _items.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _items[i]['_reviewed'] == true
                  ? Icons.check_circle_outline
                  : Icons.edit_outlined,
            ),
            title: Text('${_items[i]['name']}'),
            subtitle: Text(
              '${_items[i]['quantity'] ?? 'Quantity required'} • '
              '${_items[i]['product_id'] == null ? 'New / unmatched' : 'Restock selected product'}',
            ),
            onTap: _busy || _submitted ? null : () => _edit(i),
            trailing: _busy || _submitted
                ? null
                : IconButton(
                    tooltip: 'Remove line',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
          ),
        if (_inventory && !_submitted)
          FilledButton(
            onPressed: _busy || _items.isEmpty ? null : _submit,
            child: Text(
              widget.owner ? 'Review and confirm' : 'Request owner approval',
            ),
          ),
        if (_submitted && widget.existingRequestId == null)
          OutlinedButton(
            onPressed: () => setState(() {
              _items.clear();
              _documents.clear();
              _sources.clear();
              _request = const Uuid().v4();
              _submitted = false;
              _message = null;
            }),
            child: const Text('Scan another document'),
          ),
        const SizedBox(height: 16),
        const Center(child: Text('Powered by TREXVEN')),
      ],
    ),
  );
}
