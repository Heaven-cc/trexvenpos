import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product.dart';
import '../../models/price_levels.dart';

class DuplicateBarcode extends StateError {
  DuplicateBarcode():super('Multiple products use this barcode. Ask the owner to resolve the duplicate.');
}

class ProductRepository {
  static const catalogProductColumns = 'id,business_id,name,barcode,sku,brand,category,image_url,selling_price,is_active,active,quantity,low_stock_threshold,description,unit,catalog_group_id,variant_attributes';
  static const productColumns = 'id,business_id,name,barcode,sku,brand,category,image_url,selling_price,is_active,active,quantity,low_stock_threshold,description,unit';
  final SupabaseClient _supabase;
  bool _legacyProjection = false;

  ProductRepository(this._supabase);

  Future<T> _projection<T>(Future<T> Function(String) load) async {
    if(_legacyProjection) return await load(productColumns);
    try { return await load(catalogProductColumns); }
    on PostgrestException catch(e) {
      if ((e.code == '42703' || e.code == 'PGRST204') &&
          (e.message.contains('catalog_group_id') || e.message.contains('variant_attributes'))) {
        _legacyProjection = true;
        return await load(productColumns);
      }
      rethrow;
    }
  }

  /// Find a product by barcode inside the active business.
  ///
  /// The business ID is required so one business cannot
  /// accidentally retrieve another business's product.
  Future<Product?> findProductByBarcode(
      String barcode,
      String businessId,
      ) async {
    final cleanBarcode = barcode.trim();

    if (cleanBarcode.isEmpty || businessId.trim().isEmpty) {
      return null;
    }

    final response = await _projection((columns) => _supabase
        .from('products')
        .select(columns)
        .eq('barcode', cleanBarcode)
        .eq('business_id', businessId)
        .limit(2));

    if (response.isEmpty) {
      return null;
    }
    if(response.length > 1) throw DuplicateBarcode();
    return Product.fromJson(response.single);
  }

  /// Search products belonging only to the active business.
  Future<List<Product>> searchProducts(
      String query,
      String businessId,
      ) async {
    final cleanQuery = query.trim().replaceAll(RegExp(r'[,%()\\]'), ' ');
    final cleanBusinessId = businessId.trim();

    if (cleanBusinessId.isEmpty) {
      return [];
    }

    if (cleanQuery.isEmpty) {
      final response = await _projection((columns) => _supabase
          .from('products')
          .select(columns)
          .eq('business_id', cleanBusinessId)
          .limit(20));

      return (response as List)
          .map(
            (json) => Product.fromJson(
          Map<String, dynamic>.from(json),
        ),
      )
          .toList();
    }

    final response = await _projection((columns) => _supabase
        .from('products')
        .select(columns)
        .eq('business_id', cleanBusinessId)
        .or(
      'name.ilike.%$cleanQuery%,'
          'barcode.ilike.%$cleanQuery%,'
          'sku.ilike.%$cleanQuery%',
    )
        .limit(20));

    return (response as List)
        .map(
          (json) => Product.fromJson(
        Map<String, dynamic>.from(json),
      ),
    )
        .toList();
  }

  /// Get the price levels configured for a product.
  Future<PriceLevels?> getPriceLevels(
      String productId,
      ) async {
    final response = await _supabase
        .from('products')
        .select('id,selling_price,is_active,active')
        .eq('id', productId)
        .maybeSingle();

    if (response == null || response['is_active'] == false || response['active'] == false || response['selling_price'] == null) {
      return null;
    }

    final price = (response['selling_price'] as num).toDouble();
    return PriceLevels(productId: productId, budget: price, standard: price,
      premium: price, market: price);
  }

  /// Add a new product to the inventory.
  Future<Product> quickAddProduct(Product product) async {
    final id = await _supabase.rpc('save_trexven_catalog_product',params:{
      'p_business_id':product.businessId,'p_product_id':null,'p_request_id':product.id,
      'p_fields':{'name':product.name,'barcode':product.barcode,'sku':product.partNumber,
        'brand':product.brand,'category':product.category,'image_url':product.imageUrl,'active':false},
    });
    return product.copyWith(id:id as String);
  }
  Future<String> saveCatalogProduct(String business,String product,Map<String,dynamic> fields,String request) async =>
      await _supabase.rpc('save_trexven_catalog_product',params:{'p_business_id':business,
        'p_product_id':product,'p_fields':fields,'p_request_id':request}) as String;
  Future<num> adjustStock(String business,String product,num delta,String reason,String request) async =>
      await _supabase.rpc('adjust_trexven_catalog_stock',params:{'p_business_id':business,
        'p_product_id':product,'p_delta':delta.toString(),'p_reason':reason,'p_request_id':request}) as num;
  Future<List<Map<String,dynamic>>> groups(String business) async => await _supabase
    .from('product_groups').select('id,name').eq('business_id',business).order('name');
  Future<List<Map<String,dynamic>>> movements(String business,String product) async => await _supabase
    .from('inventory_movements').select('movement_type,quantity,previous_quantity,new_quantity,reason,created_at')
    .eq('business_id',business).eq('product_id',product).order('created_at',ascending:false);
}
