-- READ ONLY. Run immediately before approved deployment and after it.
-- Compare counts/digests and unrelated-function/table-grant hashes.
-- New nullable branch columns are excluded from old-row digests.
select now() captured_at,current_database() database_name,
 (select jsonb_agg(to_jsonb(snapshot) order by relation) from (select 'businesses' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.businesses record_row
union all
select 'branches' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.branches record_row
union all
select 'products' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.products record_row
union all
select 'inventory' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.inventory record_row
union all
select 'inventory_movements' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.inventory_movements record_row
union all
select 'stocktake_sessions' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.stocktake_sessions record_row
union all
select 'stocktake_counts' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.stocktake_counts record_row
union all
select 'stock_condition_entries' relation,count(*) rows,md5(coalesce(string_agg(md5((to_jsonb(record_row)-'branch_id')::text),'' order by md5((to_jsonb(record_row)-'branch_id')::text)),'')) digest from public.stock_condition_entries record_row
union all
select 'supplier_stock_returns' relation,count(*) rows,md5(coalesce(string_agg(md5((to_jsonb(record_row)-'branch_id')::text),'' order by md5((to_jsonb(record_row)-'branch_id')::text)),'')) digest from public.supplier_stock_returns record_row
union all
select 'inventory_reconciliation_reviews' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.inventory_reconciliation_reviews record_row
union all
select 'audit_logs' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.audit_logs record_row
union all
select 'sales' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.sales record_row
union all
select 'sale_items' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.sale_items record_row
union all
select 'sale_payments' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.sale_payments record_row
union all
select 'credit_accounts' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.credit_accounts record_row
union all
select 'credit_entries' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.credit_entries record_row
union all
select 'sale_returns' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.sale_returns record_row
union all
select 'return_items' relation,count(*) rows,md5(coalesce(string_agg(md5(to_jsonb(record_row)::text),'' order by md5(to_jsonb(record_row)::text)),'')) digest from public.return_items record_row) snapshot) records,
 (select md5(string_agg(pg_get_functiondef(p.oid)||p.proowner::text||coalesce(p.proacl::text,''),'' order by n.nspname,p.proname,p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('public','private') and p.prokind in('f','p')
  and p.proname not in('count_trexven_stock','approve_trexven_stocktake','manage_trexven_stocktake','acknowledge_trexven_supplier_return','review_trexven_inventory_discrepancy','capture_return_condition_stock','start_trexven_stocktake','process_trexven_sale','get_trexven_inventory_capabilities','start_trexven_branch_stocktake','classify_trexven_branch_stock','resolve_trexven_branch_condition_stock','dispatch_trexven_branch_supplier_return','branch_inventory_context','apply_branch_inventory_delta')) unrelated_functions,
 (select md5(string_agg(jsonb_build_array(n.nspname,c.relname,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity)::text,'' order by n.nspname,c.relname))
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in('public','private') and c.relkind in('r','p')) table_security,
 jsonb_build_object(
  'negative_credit',(select count(*) from public.credit_accounts where outstanding<0),
  'credit_ledger_mismatch',(select count(*) from public.credit_accounts a where a.outstanding is distinct from coalesce((select sum(amount) from public.credit_entries e where e.sale_id=a.sale_id),0)),
  'return_allocation_mismatch',(select count(*) from public.sale_returns where status='approved' and value is distinct from debt_reduction+refund_amount),
  'invalid_branch_inventory',(select count(*) from public.inventory i where branch_id is not null and (not private.valid_stock_quantity(i.product_id,i.quantity,true) or reserved_quantity is null or reserved_quantity::text in('NaN','Infinity','-Infinity') or reserved_quantity<0 or reserved_quantity>quantity)),
  'overlapping_active_scopes',(select count(*) from (select business_id,branch_id from public.stocktake_sessions where status in('open','review') group by business_id,branch_id having count(*)>1) duplicates),
  'invalid_closed_count_delta',(select count(*) from public.stocktake_counts c join public.stocktake_sessions s on s.id=c.session_id where s.status='closed' and (c.applied_delta is distinct from c.counted-c.expected_at_count or c.stock_after<0)),
  'negative_condition_balance',(select count(*) from (select business_id,product_id,condition,to_jsonb(e)->>'branch_id' branch from public.stock_condition_entries e group by business_id,product_id,condition,to_jsonb(e)->>'branch_id' having sum(quantity)<0) invalid),
  'duplicate_branch_movements',(select count(*) from (select business_id,branch_id,product_id,reference_id,movement_type,source,quantity,previous_quantity,new_quantity from public.inventory_movements where source in('stocktake','stock_classification','stock_restoration','branch_checkout','customer_return') group by business_id,branch_id,product_id,reference_id,movement_type,source,quantity,previous_quantity,new_quantity having count(*)>1) duplicates),
  'invalid_branch_movement_delta',(select count(*) from public.inventory_movements where source in('stocktake','stock_classification','stock_restoration','branch_checkout','customer_return') and new_quantity is distinct from previous_quantity+quantity)
 ) integrity;

select n.nspname schema,p.proname,pg_get_function_arguments(p.oid) arguments,
 pg_get_function_result(p.oid) result,md5(pg_get_functiondef(p.oid)) hash,
 pg_get_userbyid(p.proowner) owner,p.proacl acl,p.prosecdef security_definer,p.proconfig config,
 has_function_privilege('anon',p.oid,'execute') anon_execute,
 has_function_privilege('authenticated',p.oid,'execute') authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in('public','private') and p.proname in('count_trexven_stock','approve_trexven_stocktake','manage_trexven_stocktake','acknowledge_trexven_supplier_return','review_trexven_inventory_discrepancy','capture_return_condition_stock','start_trexven_stocktake','process_trexven_sale','get_trexven_inventory_capabilities','start_trexven_branch_stocktake','classify_trexven_branch_stock','resolve_trexven_branch_condition_stock','dispatch_trexven_branch_supplier_return','branch_inventory_context','apply_branch_inventory_delta')
order by n.nspname,p.proname,arguments;

select * from pg_policies where schemaname='public' and tablename in(
 'stocktake_sessions','stocktake_counts','stock_condition_entries','supplier_stock_returns','inventory_reconciliation_reviews')
order by tablename,policyname;
