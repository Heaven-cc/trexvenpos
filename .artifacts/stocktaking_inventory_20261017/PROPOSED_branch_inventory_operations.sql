-- PROPOSAL ONLY. NOT DEPLOYED. Separate production approval is required.
-- Target: TREXVEN production ufehcfrlygqvminfjumf; PostgreSQL 17.
-- Adds branch inventory operations without enabling branches or allocating stock.
-- Existing non-branch RPC signatures and paths are retained.
-- No customer/sales/credit/billing data is rewritten. No test transactions.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $baseline$
begin
 if (select pg_get_userbyid(proowner) from pg_proc where oid='private.capture_return_condition_stock()'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='private.capture_return_condition_stock()'::regprocedure) is distinct from '{postgres=X/postgres}' then
  raise exception 'Function owner or ACL changed: private.capture_return_condition_stock()';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid)'::regprocedure) is distinct from '{postgres=X/postgres}' then
  raise exception 'Function owner or ACL changed: private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid)';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='public.acknowledge_trexven_supplier_return(uuid,uuid,numeric,numeric,text)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='public.acknowledge_trexven_supplier_return(uuid,uuid,numeric,numeric,text)'::regprocedure) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
  raise exception 'Function owner or ACL changed: public.acknowledge_trexven_supplier_return(uuid,uuid,numeric,numeric,text)';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='public.approve_trexven_stocktake(uuid,uuid,text)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='public.approve_trexven_stocktake(uuid,uuid,text)'::regprocedure) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
  raise exception 'Function owner or ACL changed: public.approve_trexven_stocktake(uuid,uuid,text)';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='public.count_trexven_stock(uuid,uuid,jsonb)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='public.count_trexven_stock(uuid,uuid,jsonb)'::regprocedure) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
  raise exception 'Function owner or ACL changed: public.count_trexven_stock(uuid,uuid,jsonb)';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='public.manage_trexven_stocktake(uuid,uuid,text,uuid,uuid,text)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='public.manage_trexven_stocktake(uuid,uuid,text,uuid,uuid,text)'::regprocedure) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
  raise exception 'Function owner or ACL changed: public.manage_trexven_stocktake(uuid,uuid,text,uuid,uuid,text)';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='public.review_trexven_inventory_discrepancy(uuid,uuid,text)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='public.review_trexven_inventory_discrepancy(uuid,uuid,text)'::regprocedure) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
  raise exception 'Function owner or ACL changed: public.review_trexven_inventory_discrepancy(uuid,uuid,text)';
 end if;
 if (select pg_get_userbyid(proowner) from pg_proc where oid='public.start_trexven_stocktake(uuid,uuid,text)'::regprocedure) is distinct from 'postgres'
 or (select proacl::text from pg_proc where oid='public.start_trexven_stocktake(uuid,uuid,text)'::regprocedure) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
  raise exception 'Function owner or ACL changed: public.start_trexven_stocktake(uuid,uuid,text)';
 end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='public' and p.proname in('get_trexven_inventory_capabilities','start_trexven_branch_stocktake','classify_trexven_branch_stock','resolve_trexven_branch_condition_stock','dispatch_trexven_branch_supplier_return'))
  or (n.nspname='private' and p.proname in('branch_inventory_context','apply_branch_inventory_delta'))) then
  raise exception 'A proposed API name already exists. Re-audit overloads before deployment.';
 end if;
 if to_regprocedure('private.branch_inventory_context(uuid,text,uuid,boolean)') is not null then raise exception 'Unexpected existing API: private.branch_inventory_context(uuid,text,uuid,boolean)'; end if;
 if to_regprocedure('private.apply_branch_inventory_delta(uuid,uuid,uuid,numeric,uuid,text,text,text,uuid)') is not null then raise exception 'Unexpected existing API: private.apply_branch_inventory_delta(uuid,uuid,uuid,numeric,uuid,text,text,text,uuid)'; end if;
 if to_regprocedure('public.get_trexven_inventory_capabilities(uuid)') is not null then raise exception 'Unexpected existing API: public.get_trexven_inventory_capabilities(uuid)'; end if;
 if to_regprocedure('public.start_trexven_branch_stocktake(uuid,uuid,uuid,text)') is not null then raise exception 'Unexpected existing API: public.start_trexven_branch_stocktake(uuid,uuid,uuid,text)'; end if;
 if to_regprocedure('public.classify_trexven_branch_stock(uuid,uuid,uuid,uuid,numeric,text,text)') is not null then raise exception 'Unexpected existing API: public.classify_trexven_branch_stock(uuid,uuid,uuid,uuid,numeric,text,text)'; end if;
 if to_regprocedure('public.resolve_trexven_branch_condition_stock(uuid,uuid,uuid,uuid,numeric,text,text,text)') is not null then raise exception 'Unexpected existing API: public.resolve_trexven_branch_condition_stock(uuid,uuid,uuid,uuid,numeric,text,text,text)'; end if;
 if to_regprocedure('public.dispatch_trexven_branch_supplier_return(uuid,uuid,uuid,uuid,numeric,text,text,text)') is not null then raise exception 'Unexpected existing API: public.dispatch_trexven_branch_supplier_return(uuid,uuid,uuid,uuid,numeric,text,text,text)'; end if;
 if md5(pg_get_functiondef('private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid)'::regprocedure)) <> 'abecb0287dfddf51db67c6525e2e70c7' then raise exception 'Dependency changed: private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.valid_stock_quantity(uuid,numeric,boolean)'::regprocedure)) <> 'acc4fdee07a91193ce9e27eb7b9624b6' then raise exception 'Dependency changed: private.valid_stock_quantity(uuid,numeric,boolean). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.has_business_permission(uuid,text)'::regprocedure)) <> '389a3276aa5e2f90907a70d8e4aced52' then raise exception 'Dependency changed: private.has_business_permission(uuid,text). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.subscription_entitled(uuid,text)'::regprocedure)) <> '06cba9fe748439a5b320b9764d8fba08' then raise exception 'Dependency changed: private.subscription_entitled(uuid,text). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.catalog_stock_events()'::regprocedure)) <> 'caba2001b92f22a0870695f201533e37' then raise exception 'Dependency changed: private.catalog_stock_events(). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.guard_stocktake_count_entitlement()'::regprocedure)) <> '360dd6d5e645a754fc30c1286bbdcbc8' then raise exception 'Dependency changed: private.guard_stocktake_count_entitlement(). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.guard_advanced_inventory_session()'::regprocedure)) <> 'c929ab08876aeb5b2f5bb8ec1af721e1' then raise exception 'Dependency changed: private.guard_advanced_inventory_session(). Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.branch_record_access(uuid,uuid)'::regprocedure)) <> '3b5aacf7ef9dc0b0463a7a4cc8b20ef7' then raise exception 'Baseline changed: private.branch_record_access. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.capture_return_condition_stock()'::regprocedure)) <> 'f0e26dba277d982e632175aeeaca0e56' then raise exception 'Baseline changed: private.capture_return_condition_stock. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.catalog_context(uuid,text)'::regprocedure)) <> 'd561da2eca5768a65fb47220f3d881cd' then raise exception 'Baseline changed: private.catalog_context. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.guard_legacy_stock()'::regprocedure)) <> '78f1ded7b2ae08990626211fd4ac8869' then raise exception 'Baseline changed: private.guard_legacy_stock. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.has_branch_access(uuid,uuid)'::regprocedure)) <> '35d67be2f824bcad706cd2aaa7eb195e' then raise exception 'Baseline changed: private.has_branch_access. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.operation_replay(uuid,uuid,jsonb)'::regprocedure)) <> '8ca176af0ee1a4095f9cdae6d216ec0b' then raise exception 'Baseline changed: private.operation_replay. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.operation_save(uuid,uuid,jsonb,jsonb)'::regprocedure)) <> '0e907a14435ddc5cbae0576b05e70bbf' then raise exception 'Baseline changed: private.operation_save. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('private.operations_context(uuid,text,uuid,boolean)'::regprocedure)) <> 'd3131624a3abfea5e3ec4da88306f75d' then raise exception 'Baseline changed: private.operations_context. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.acknowledge_trexven_supplier_return(uuid,uuid,numeric,numeric,text)'::regprocedure)) <> '1e2726e8807865546d06624b97aa6979' then raise exception 'Baseline changed: public.acknowledge_trexven_supplier_return. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.approve_trexven_return(uuid,uuid,text,boolean,text,uuid)'::regprocedure)) <> 'bf89f7e2b1ffd95161b4a35d251101e2' then raise exception 'Baseline changed: public.approve_trexven_return. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.approve_trexven_stocktake(uuid,uuid,text)'::regprocedure)) <> 'b086813d7b9a6944a49a1ebb2ecd7873' then raise exception 'Baseline changed: public.approve_trexven_stocktake. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.classify_trexven_stock(uuid,uuid,uuid,numeric,text,text)'::regprocedure)) <> '3fc7495a02b2aade8a11bdd1bf89da99' then raise exception 'Baseline changed: public.classify_trexven_stock. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.count_trexven_stock(uuid,uuid,jsonb)'::regprocedure)) <> '289bab1f691f9b81281f639facf08137' then raise exception 'Baseline changed: public.count_trexven_stock. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.dispatch_trexven_supplier_return(uuid,uuid,uuid,numeric,text,text,text)'::regprocedure)) <> 'ce403e07b4b542b5cd53bcbb4e736ac7' then raise exception 'Baseline changed: public.dispatch_trexven_supplier_return. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.manage_trexven_stocktake(uuid,uuid,text,uuid,uuid,text)'::regprocedure)) <> 'bfd2658a7ae0e7ffdfb0165081dd8506' then raise exception 'Baseline changed: public.manage_trexven_stocktake. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.resolve_trexven_condition_stock(uuid,uuid,uuid,numeric,text,text,text)'::regprocedure)) <> '2cd8c5ebe12b2067f5add87a69a159ba' then raise exception 'Baseline changed: public.resolve_trexven_condition_stock. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.review_trexven_inventory_discrepancy(uuid,uuid,text)'::regprocedure)) <> '77ccc5e2d60ca82e34c01d2ce2b27523' then raise exception 'Baseline changed: public.review_trexven_inventory_discrepancy. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.start_trexven_stocktake(uuid,uuid,text)'::regprocedure)) <> '3fac5212d02546c3e2437dd0a82e91c0' then raise exception 'Baseline changed: public.start_trexven_stocktake. Re-audit before deployment.'; end if;
 if md5(pg_get_functiondef('public.submit_trexven_stocktake(uuid,uuid)'::regprocedure)) <> 'f93cbe024c3a7e12d60734d60a5adf6e' then raise exception 'Baseline changed: public.submit_trexven_stocktake. Re-audit before deployment.'; end if;
 if (select md5(jsonb_build_object(
'columns',(select jsonb_agg(jsonb_build_array(a.attrelid,a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attacl,pg_get_expr(d.adbin,d.adrelid)) order by a.attrelid,a.attnum) from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where n.nspname='public' and c.relname in('inventory','inventory_movements','stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews','supplier_stock_returns') and a.attnum>0 and not a.attisdropped),
'relations',(select jsonb_agg(jsonb_build_array(c.oid,c.relname,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity) order by c.oid) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('inventory','inventory_movements','stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews','supplier_stock_returns')),
'constraints',(select jsonb_agg(jsonb_build_array(c.conrelid,c.conname,pg_get_constraintdef(c.oid)) order by c.conrelid,c.conname) from pg_constraint c where c.conrelid in(select t.oid from pg_class t join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname in('inventory','inventory_movements','stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews','supplier_stock_returns'))),
'indexes',(select jsonb_agg(indexdef order by tablename,indexname) from pg_indexes where schemaname='public' and tablename in('inventory','inventory_movements','stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews','supplier_stock_returns')),
'policies',(select jsonb_agg(to_jsonb(p) order by tablename,policyname) from pg_policies p where schemaname='public' and tablename in('inventory','inventory_movements','stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews','supplier_stock_returns')),
'triggers',(select jsonb_agg(pg_get_triggerdef(t.oid)||t.tgenabled::text order by t.tgrelid,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('inventory','inventory_movements','stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews','supplier_stock_returns'))
)::text) hash) <> '1bc022e15c813bff34322efc95547e5c' then
  raise exception 'Inventory schema, triggers, grants or policies changed. Re-audit before deployment.';
 end if;
 if exists(select 1 from public.stocktake_sessions where branch_id is not null and status in('open','review')
   group by business_id,branch_id having count(*)>1) then
  raise exception 'Existing overlapping branch sessions require manual review; no records were changed.';
 end if;
 if exists(select 1 from public.stocktake_sessions where branch_id is null and status in('open','review')
   group by business_id having count(*)>1) then
  raise exception 'Existing overlapping global sessions require manual review; no records were changed.';
 end if;
 if exists(select 1 from public.inventory i where branch_id is not null and (
   not private.valid_stock_quantity(i.product_id,i.quantity,true) or i.reserved_quantity is null
   or i.reserved_quantity::text in('NaN','Infinity','-Infinity') or i.reserved_quantity<0
   or i.reserved_quantity>i.quantity)) then
  raise exception 'Existing branch quantities or reservations require review; no records were changed.';
 end if;
end;
$baseline$;

alter table public.stock_condition_entries add column branch_id uuid;
alter table public.supplier_stock_returns add column branch_id uuid;
alter table public.stock_condition_entries
 add constraint branch_ops_condition_branch foreign key(branch_id,business_id) references public.branches(id,business_id),
 add constraint branch_ops_condition_product foreign key(product_id,business_id) references public.products(id,business_id);
alter table public.supplier_stock_returns
 add constraint branch_ops_supplier_branch foreign key(branch_id,business_id) references public.branches(id,business_id),
 add constraint branch_ops_supplier_product foreign key(product_id,business_id) references public.products(id,business_id);
alter table public.stocktake_sessions
 add constraint branch_ops_session_branch foreign key(branch_id,business_id) references public.branches(id,business_id);
create unique index inventory_ops_active_global_session on public.stocktake_sessions(business_id)
 where branch_id is null and status in('open','review');
create index branch_ops_condition_balance on public.stock_condition_entries(business_id,branch_id,product_id,condition);
create index branch_ops_supplier_scope on public.supplier_stock_returns(business_id,branch_id,status);
-- New branch sessions count the branch as a whole. Prevent overlapping counts
-- from applying the same physical discrepancy twice. Global behavior is unchanged.
create unique index branch_ops_active_session on public.stocktake_sessions(business_id,branch_id)
 where branch_id is not null and status in('open','review');

-- Owners retain historical session access after a branch is deactivated.
-- Staff still need their original inventory permission and branch assignment.
alter policy "Stocktake read" on public.stocktake_sessions using(
 private.has_business_permission(business_id,'view_inventory')
 and (public.user_owns_business(business_id) or branch_id is null
  or private.has_branch_access(business_id,branch_id)));

-- Additional restrictive SELECT policies intersect the existing permission,
-- closed-account and suspended-business policies; no policy is weakened.
create policy "Branch inventory condition scope" on public.stock_condition_entries
 as restrictive for select to authenticated using(private.branch_record_access(business_id,branch_id));
create policy "Branch inventory supplier scope" on public.supplier_stock_returns
 as restrictive for select to authenticated using(private.branch_record_access(business_id,branch_id));
create policy "Branch inventory session scope" on public.stocktake_sessions
 as restrictive for select to authenticated using(private.branch_record_access(business_id,branch_id));
create policy "Branch inventory review scope" on public.inventory_reconciliation_reviews
 as restrictive for select to authenticated using(exists(
  select 1 from public.stocktake_sessions s where s.id=session_id
  and s.business_id=inventory_reconciliation_reviews.business_id
  and private.branch_record_access(s.business_id,s.branch_id)));

-- Private helpers have no client EXECUTE privilege. Public RPCs authorize first.
create function private.branch_inventory_context(
 p_business uuid,p_permission text,p_branch uuid,p_sensitive boolean default false)
returns void language plpgsql security invoker set search_path='' as $function$
begin
 if p_branch is null then raise exception 'Select an authorized branch' using errcode='42501'; end if;
 perform private.operations_context(p_business,p_permission,p_branch,p_sensitive);
 -- Match checkout: keep branch activation and this caller's assignments stable
 -- throughout the transaction, then recheck after waiting for those locks.
 perform b.id from public.branches b where b.id=p_branch and b.business_id=p_business
  and b.is_active for share;
 if not found then raise exception 'Active branch required' using errcode='42501'; end if;
 perform a.employee_id from public.employee_branch_assignments a
 join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
 where a.business_id=p_business and a.branch_id=p_branch and a.is_active
 and e.user_id=auth.uid() for share of a;
 if not private.has_branch_access(p_business,p_branch) then
  raise exception 'Branch access denied' using errcode='42501';
 end if;
end;
$function$;
revoke all on function private.branch_inventory_context(uuid,text,uuid,boolean) from public,anon,authenticated,service_role;

create function private.apply_branch_inventory_delta(
 p_business uuid,p_branch uuid,p_product uuid,p_delta numeric,p_request uuid,
 p_reason text,p_source text,p_kind text,p_reference uuid)
returns numeric language plpgsql security invoker set search_path='' as $function$
declare previous_qty numeric; reserved_qty numeric; next_qty numeric; member uuid;
begin
 if auth.uid() is null or p_branch is null or p_request is null
 or not private.has_branch_access(p_business,p_branch)
 or p_delta is null or p_delta::text in('NaN','Infinity','-Infinity')
 or scale(p_delta)>3 or nullif(btrim(p_reason),'') is null
 or p_kind is null or p_kind not in('adjustment','damage','loss') then
  raise exception 'Authorized branch adjustment context required' using errcode='42501';
 end if;
 -- Product-before-inventory is the existing checkout/return lock order.
 perform p.id from public.products p where p.id=p_product and p.business_id=p_business for update;
 if not found then raise exception 'Product unavailable' using errcode='42501'; end if;
 select i.quantity,i.reserved_quantity into previous_qty,reserved_qty
 from public.inventory i where i.business_id=p_business and i.branch_id=p_branch
 and i.product_id=p_product for update;
 if not found then raise exception 'Original branch inventory row is unavailable'; end if;
 if private.subscription_entitled(p_business,'inventory') is not true then
  raise exception 'Subscription inventory access expired';
 end if;
 if not private.valid_stock_quantity(p_product,previous_qty,true) then
  raise exception 'Original branch inventory quantity is invalid';
 end if;
 next_qty:=previous_qty+p_delta;
 if not private.valid_stock_quantity(p_product,next_qty,true)
 or reserved_qty is null or reserved_qty::text in('NaN','Infinity','-Infinity')
 or reserved_qty<0 or next_qty<reserved_qty then
  raise exception 'Recount or resolve reservations; branch stock cannot become negative or reserved stock be consumed';
 end if;
 if p_delta=0 then return previous_qty; end if;
 update public.inventory set quantity=next_qty,updated_at=now()
 where business_id=p_business and branch_id=p_branch and product_id=p_product;
 select m.id into member from public.business_members m
 where m.business_id=p_business and m.user_id=auth.uid() and m.status='active';
 insert into public.inventory_movements(
  business_id,branch_id,product_id,employee_id,movement_type,quantity,
  previous_quantity,new_quantity,reference_id,reason,source,notes)
 values(p_business,p_branch,p_product,member,p_kind,p_delta,
  previous_qty,next_qty,p_reference,p_reason,p_source,'Operation request: '||p_request::text);
 return next_qty;
end;
$function$;
revoke all on function private.apply_branch_inventory_delta(uuid,uuid,uuid,numeric,uuid,text,text,text,uuid)
 from public,anon,authenticated,service_role;

create function public.get_trexven_inventory_capabilities(p_business_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $function$
begin
 if auth.uid() is null or private.has_business_permission(p_business_id,'view_inventory') is not true then
  raise exception 'Inventory access denied' using errcode='42501';
 end if;
 return jsonb_build_object('branch_inventory_version',1);
end;
$function$;

create function public.start_trexven_branch_stocktake(
 p_business_id uuid,p_branch_id uuid,p_request_id uuid,p_name text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare payload jsonb; prior jsonb; result jsonb; session uuid;
begin
 perform private.branch_inventory_context(p_business_id,'stocktake',p_branch_id);
 if not private.has_business_permission(p_business_id,'view_inventory') then
  raise exception 'Inventory access denied' using errcode='42501';
 end if;
 payload:=jsonb_build_object('operation','branch_start_stocktake','branch',p_branch_id,'name',p_name);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);
 if prior is not null then return prior; end if;
 if nullif(btrim(p_name),'') is null then raise exception 'Count name required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||':branch_stocktake:'||p_branch_id::text,0));
 if exists(select 1 from public.stocktake_sessions where business_id=p_business_id
  and branch_id=p_branch_id and status in('open','review')) then
  raise exception 'Resume or finish the existing branch stocktake';
 end if;
 if not exists(select 1 from public.inventory i join public.products p
  on p.id=i.product_id and p.business_id=i.business_id where i.business_id=p_business_id
  and i.branch_id=p_branch_id and p.active and p.is_active) then
  raise exception 'No active branch inventory is available to count';
 end if;
 insert into public.stocktake_sessions(business_id,branch_id,name,created_by)
 values(p_business_id,p_branch_id,p_name,auth.uid()) returning id into session;
 insert into public.stocktake_counts(session_id,product_id)
 select session,p.id from public.products p join public.inventory i
 on i.product_id=p.id and i.business_id=p.business_id
 where p.business_id=p_business_id and i.branch_id=p_branch_id and p.active and p.is_active
 order by p.id;
 result:=jsonb_build_object('id',session);
 perform private.operation_save(p_business_id,p_request_id,payload,result);
 return result;
end;
$function$;

create function public.classify_trexven_branch_stock(
 p_business_id uuid,p_branch_id uuid,p_product_id uuid,p_request_id uuid,
 p_quantity numeric,p_condition text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare product public.products%rowtype; payload jsonb; prior jsonb; result jsonb; remaining numeric;
begin
 perform private.branch_inventory_context(p_business_id,'dispose_stock',p_branch_id);
 if private.has_business_permission(p_business_id,'adjust_stock') is not true then
  raise exception 'Stock adjustment permission required' using errcode='42501';
 end if;
 payload:=jsonb_build_object('operation','branch_classify_stock','branch',p_branch_id,
  'product',p_product_id,'quantity',p_quantity,'condition',p_condition,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);
 if prior is not null then return prior; end if;
 select * into product from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found or not private.valid_stock_quantity(p_product_id,p_quantity)
  or p_condition is null or p_condition not in('damaged','expired','defective','lost')
  or nullif(btrim(p_reason),'') is null then raise exception 'Valid stock, condition and reason required'; end if;
 remaining:=private.apply_branch_inventory_delta(p_business_id,p_branch_id,p_product_id,-p_quantity,
  p_request_id,p_condition||': '||p_reason,'stock_classification',
  case when p_condition='lost' then 'loss' else 'damage' end,p_request_id);
 if p_condition<>'lost' then
  insert into public.stock_condition_entries(
   business_id,branch_id,product_id,condition,quantity,kind,request_id,actor_id,reason)
  values(p_business_id,p_branch_id,p_product_id,p_condition,p_quantity,'classify',p_request_id,auth.uid(),p_reason);
 end if;
 result:=jsonb_build_object('product_id',p_product_id,'remaining',remaining,'condition',p_condition);
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(p_business_id,auth.uid(),'stock_classified',result||jsonb_build_object(
  'branch_id',p_branch_id,'quantity',p_quantity,'reason',p_reason));
 perform private.operation_save(p_business_id,p_request_id,payload,result);
 return result;
end;
$function$;

create function public.resolve_trexven_branch_condition_stock(
 p_business_id uuid,p_branch_id uuid,p_product_id uuid,p_request_id uuid,
 p_quantity numeric,p_condition text,p_action text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare product public.products%rowtype; balance numeric; payload jsonb; prior jsonb; result jsonb;
begin
 if p_action is null or p_action not in('restore','writeoff') then
  raise exception 'Inspected restore or write-off required';
 end if;
 perform private.branch_inventory_context(p_business_id,
  case when p_action='restore' then 'restore_stock' else 'writeoff_stock' end,p_branch_id,true);
 if private.has_business_permission(p_business_id,'adjust_stock') is not true then
  raise exception 'Stock adjustment permission required' using errcode='42501';
 end if;
 payload:=jsonb_build_object('operation','branch_resolve_stock','branch',p_branch_id,
  'product',p_product_id,'quantity',p_quantity,'condition',p_condition,'action',p_action,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);
 if prior is not null then return prior; end if;
 select * into product from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product unavailable' using errcode='42501'; end if;
 select coalesce(sum(quantity),0) into balance from public.stock_condition_entries
 where business_id=p_business_id and branch_id=p_branch_id and product_id=p_product_id and condition=p_condition;
 if not private.valid_stock_quantity(p_product_id,p_quantity) or p_quantity>balance
  or p_condition is null or p_condition not in('damaged','expired','defective')
  or nullif(btrim(p_reason),'') is null then raise exception 'Inspected available condition stock and reason required'; end if;
 insert into public.stock_condition_entries(
  business_id,branch_id,product_id,condition,quantity,kind,request_id,actor_id,reason)
 values(p_business_id,p_branch_id,p_product_id,p_condition,-p_quantity,p_action,p_request_id,auth.uid(),p_reason);
 if p_action='restore' then
  perform private.apply_branch_inventory_delta(p_business_id,p_branch_id,p_product_id,p_quantity,
   p_request_id,'Inspected restoration: '||p_reason,'stock_restoration','adjustment',p_request_id);
 end if;
 result:=jsonb_build_object('product_id',p_product_id,'condition_remaining',balance-p_quantity,'action',p_action);
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(p_business_id,auth.uid(),'condition_stock_resolved',result||jsonb_build_object('branch_id',p_branch_id,'reason',p_reason));
 perform private.operation_save(p_business_id,p_request_id,payload,result);
 return result;
end;
$function$;

create function public.dispatch_trexven_branch_supplier_return(
 p_business_id uuid,p_branch_id uuid,p_request_id uuid,p_product_id uuid,
 p_quantity numeric,p_condition text,p_supplier_name text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare product public.products%rowtype; balance numeric; payload jsonb; prior jsonb; result jsonb; return_id uuid;
begin
 perform private.branch_inventory_context(p_business_id,'supplier_returns',p_branch_id);
 if private.has_business_permission(p_business_id,'view_inventory') is not true then
  raise exception 'Inventory access denied' using errcode='42501';
 end if;
 payload:=jsonb_build_object('operation','branch_supplier_dispatch','branch',p_branch_id,
  'product',p_product_id,'quantity',p_quantity,'condition',p_condition,'supplier',p_supplier_name,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);
 if prior is not null then return prior; end if;
 select * into product from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product unavailable' using errcode='42501'; end if;
 select coalesce(sum(quantity),0) into balance from public.stock_condition_entries
 where business_id=p_business_id and branch_id=p_branch_id and product_id=p_product_id and condition=p_condition;
 if not private.valid_stock_quantity(p_product_id,p_quantity) or p_quantity>balance
  or p_condition is null or p_condition not in('damaged','expired','defective')
  or nullif(btrim(p_supplier_name),'') is null or nullif(btrim(p_reason),'') is null then
  raise exception 'Available condition stock, supplier and reason required';
 end if;
 insert into public.supplier_stock_returns(
  business_id,branch_id,product_id,supplier_name,condition,quantity,reason,request_id,created_by)
 values(p_business_id,p_branch_id,p_product_id,p_supplier_name,p_condition,p_quantity,p_reason,p_request_id,auth.uid())
 returning id into return_id;
 insert into public.stock_condition_entries(
  business_id,branch_id,product_id,condition,quantity,kind,request_id,actor_id,reason)
 values(p_business_id,p_branch_id,p_product_id,p_condition,-p_quantity,'supplier_dispatch',p_request_id,auth.uid(),p_reason);
 result:=jsonb_build_object('id',return_id,'status','dispatched');
 perform private.operation_save(p_business_id,p_request_id,payload,result);
 return result;
end;
$function$;

-- Existing contracts retain their exact signatures and ACLs.
CREATE OR REPLACE FUNCTION public.start_trexven_stocktake(p_business_id uuid, p_request_id uuid, p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare payload jsonb; prior jsonb; result jsonb; session uuid;
begin
 perform private.operations_context(p_business_id,'stocktake');perform private.catalog_context(p_business_id,'view_inventory');
 payload:=jsonb_build_object('operation','start_stocktake','name',p_name);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if nullif(btrim(p_name),'') is null then raise exception 'Count name required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||':global_stocktake',0));
 if exists(select 1 from public.stocktake_sessions where business_id=p_business_id
  and branch_id is null and status in('open','review')) then
  raise exception 'Resume or finish the existing stocktake';
 end if;
 insert into public.stocktake_sessions(business_id,name,created_by) values(p_business_id,p_name,auth.uid()) returning id into session;
 insert into public.stocktake_counts(session_id,product_id) select session,id from public.products where business_id=p_business_id and active and is_active;
 result:=jsonb_build_object('id',session);perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION public.count_trexven_stock(p_session_id uuid, p_request_id uuid, p_counts jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.stocktake_sessions%rowtype; c public.stocktake_counts%rowtype; line jsonb; p public.products%rowtype; payload jsonb; prior jsonb; result jsonb; source_quantity numeric;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;
 if not found then raise exception 'Count session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'stocktake',s.branch_id);
 if s.branch_id is not null then perform private.branch_inventory_context(s.business_id,'stocktake',s.branch_id); end if;
 payload:=jsonb_build_object('operation','count_stock','session',p_session_id,'counts',p_counts);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status<>'open' or jsonb_typeof(p_counts)<>'array' or jsonb_array_length(p_counts)=0 then raise exception 'Open online session and counts required';end if;
 if exists(select 1 from jsonb_array_elements(p_counts) x group by x->>'product_id' having count(*)>1) then raise exception 'Duplicate count';end if;
 if s.branch_id is not null then
  perform product_row.id from public.products product_row where product_row.business_id=s.business_id
   and product_row.id in(select (x->>'product_id')::uuid from jsonb_array_elements(p_counts) x)
   order by product_row.id for update;
 end if;
 for line in select * from jsonb_array_elements(p_counts) order by value->>'product_id' loop
  select * into c from public.stocktake_counts where session_id=s.id and product_id=(line->>'product_id')::uuid for update;
  if not found or (line->>'version')::integer is distinct from c.version or (c.counted_by is not null and c.counted_by<>auth.uid()) then raise exception 'Count changed or belongs to another counter; refresh or request reassignment';end if;
  select * into p from public.products where id=c.product_id and business_id=s.business_id for update;
  if not found or not private.valid_stock_quantity(p.id,(line->>'quantity')::numeric,true) then raise exception 'Invalid physical quantity';end if;
  source_quantity:=coalesce(p.quantity,0);
  if s.branch_id is not null then
   select i.quantity into source_quantity from public.inventory i where i.business_id=s.business_id
    and i.branch_id=s.branch_id and i.product_id=c.product_id for update;
   if not found or not private.valid_stock_quantity(c.product_id,source_quantity,true) then
    raise exception 'Original branch inventory row is unavailable or invalid';
   end if;
  end if;
  update public.stocktake_counts set counted=(line->>'quantity')::numeric,expected_at_count=source_quantity,counted_by=auth.uid(),counted_at=clock_timestamp(),version=version+1 where id=c.id;
 end loop;
 result:=jsonb_build_object('counted',jsonb_array_length(p_counts));perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION public.approve_trexven_stocktake(p_session_id uuid, p_request_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.stocktake_sessions%rowtype; c public.stocktake_counts%rowtype; p public.products%rowtype; delta numeric; payload jsonb; prior jsonb; result jsonb; branch_after numeric;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;if not found then raise exception 'Session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'approve_stocktake',s.branch_id,true);
 if s.branch_id is not null then perform private.branch_inventory_context(s.business_id,'approve_stocktake',s.branch_id,true); end if;
 payload:=jsonb_build_object('operation','approve_stocktake','session',s.id,'reason',p_reason);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status<>'review' or nullif(btrim(p_reason),'') is null then raise exception 'Reviewed complete session and reason required';end if;
 perform set_config('trexven.catalog_request',p_request_id::text,true);perform set_config('trexven.catalog_reason','Stocktake: '||p_reason,true);
 if s.branch_id is not null then
  -- Lock every product first, in checkout order; inventory locks follow.
  perform product_row.id from public.products product_row where product_row.business_id=s.business_id
   and product_row.id in(select count_row.product_id from public.stocktake_counts count_row where count_row.session_id=s.id)
   order by product_row.id for update;
  for c in select * from public.stocktake_counts where session_id=s.id order by product_id loop
   if not private.valid_stock_quantity(c.product_id,c.counted,true)
    or not private.valid_stock_quantity(c.product_id,c.expected_at_count,true) then
    raise exception 'Complete valid branch counts are required';
   end if;
   delta:=c.counted-c.expected_at_count;
   -- Apply the physical difference to CURRENT branch stock, never a saved total.
   branch_after:=private.apply_branch_inventory_delta(s.business_id,s.branch_id,c.product_id,
    delta,p_request_id,'Stocktake: '||p_reason,'stocktake','adjustment',s.id);
   update public.stocktake_counts set applied_delta=delta,stock_after=branch_after where id=c.id;
  end loop;
 else
 for c in select * from public.stocktake_counts where session_id=s.id order by product_id loop
  select * into p from public.products where id=c.product_id and business_id=s.business_id for update;
  delta:=c.counted-c.expected_at_count;
  if c.counted is null or coalesce(p.quantity,0)+delta<0 then raise exception 'Later movements require recount; no negative stock reconciliation';end if;
  update public.products set quantity=coalesce(quantity,0)+delta,updated_at=now() where id=p.id;
  update public.stocktake_counts set applied_delta=delta,stock_after=coalesce(p.quantity,0)+delta where id=c.id;
 end loop;
 end if;
 perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 update public.stocktake_sessions set status='closed',closed_at=clock_timestamp(),approved_by=auth.uid(),reason=p_reason where id=s.id;
 result:=jsonb_build_object('id',s.id,'status','closed');insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'stocktake_approved',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION public.manage_trexven_stocktake(p_session_id uuid, p_request_id uuid, p_action text, p_product_id uuid DEFAULT NULL::uuid, p_counter_id uuid DEFAULT NULL::uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.stocktake_sessions%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;if not found then raise exception 'Session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'approve_stocktake',s.branch_id,true);
 if s.branch_id is not null then perform private.branch_inventory_context(s.business_id,'approve_stocktake',s.branch_id,true); end if;
 payload:=jsonb_build_object('operation','manage_stocktake','session',s.id,'action',p_action,'product',p_product_id,'counter',p_counter_id,'reason',p_reason);
 prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status not in('open','review') or nullif(btrim(p_reason),'') is null then raise exception 'Active session and reason required';end if;
 if p_action='reopen' then update public.stocktake_sessions set status='open' where id=s.id;
 elsif p_action='cancel' then update public.stocktake_sessions set status='cancelled',reason=p_reason,closed_at=clock_timestamp() where id=s.id;
 elsif p_action='reassign' then
  if s.status<>'open' or p_product_id is null or (p_counter_id is not null and not exists(select 1 from public.business_members where business_id=s.business_id and user_id=p_counter_id and status='active')) then raise exception 'Open session and active assigned counter required';end if;
  if s.branch_id is not null and p_counter_id is not null then
   perform e.id from public.employees e where e.business_id=s.business_id and e.user_id=p_counter_id for share;
   perform m.id from public.business_members m where m.business_id=s.business_id and m.user_id=p_counter_id for share;
   perform a.employee_id from public.employee_branch_assignments a
    join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
    where a.business_id=s.business_id and a.branch_id=s.branch_id and a.is_active
    and e.user_id=p_counter_id for share of a;
   if not exists(select 1 from public.businesses b where b.id=s.business_id and b.owner_id=p_counter_id)
    and not exists(select 1 from public.employee_branch_assignments a join public.employees e
     on e.id=a.employee_id and e.business_id=a.business_id where a.business_id=s.business_id
     and a.branch_id=s.branch_id and a.is_active and e.user_id=p_counter_id and e.status='active') then
    raise exception 'The counter must have active access to this branch' using errcode='42501';
   end if;
  end if;
  update public.stocktake_counts set counted_by=p_counter_id,version=version+1 where session_id=s.id and product_id=p_product_id;
  if not found then raise exception 'Product not in session';end if;
 else raise exception 'Unknown session action';end if;
 result:=jsonb_build_object('id',s.id,'action',p_action);insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'stocktake_managed',payload);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION public.acknowledge_trexven_supplier_return(p_return_id uuid, p_request_id uuid, p_accepted numeric, p_returned numeric, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.supplier_stock_returns%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.supplier_stock_returns where id=p_return_id;if not found then raise exception 'Return unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_supplier_returns',r.branch_id,true);
 if r.branch_id is not null then perform private.branch_inventory_context(r.business_id,'approve_supplier_returns',r.branch_id,true); end if;
 payload:=jsonb_build_object('operation','supplier_ack','return',r.id,'accepted',p_accepted,'returned',p_returned,'reason',p_reason);
 prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.supplier_stock_returns where id=p_return_id for update;
 perform id from public.products where id=r.product_id and business_id=r.business_id for update;
 if r.status<>'dispatched' or not private.valid_stock_quantity(r.product_id,p_accepted,true) or not private.valid_stock_quantity(r.product_id,p_returned,true)
 or p_accepted+p_returned>r.quantity or nullif(btrim(p_reason),'') is null then raise exception 'Actual supplier quantities and discrepancy explanation required';end if;
 if p_returned>0 then insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason,branch_id) values(r.business_id,r.product_id,r.condition,p_returned,'supplier_restore',p_request_id,auth.uid(),p_reason,r.branch_id);end if;
 update public.supplier_stock_returns set status='acknowledged',accepted=p_accepted,returned=p_returned,acknowledgment=p_reason,reviewed_by=auth.uid() where id=r.id;
 result:=jsonb_build_object('id',r.id,'accepted',p_accepted,'returned_nonsellable',p_returned,'unaccounted',r.quantity-p_accepted-p_returned);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'supplier_return_acknowledged',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION public.review_trexven_inventory_discrepancy(p_review_id uuid, p_request_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.inventory_reconciliation_reviews%rowtype; payload jsonb; prior jsonb; result jsonb; original_branch uuid;
begin
 select * into r from public.inventory_reconciliation_reviews where id=p_review_id;if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 select s.branch_id into original_branch from public.stocktake_sessions s
  where s.id=r.session_id and s.business_id=r.business_id;
 if not found then raise exception 'Original stocktake session unavailable' using errcode='42501'; end if;
 perform private.operations_context(r.business_id,'approve_stocktake',original_branch,true);
 if original_branch is not null then perform private.branch_inventory_context(r.business_id,'approve_stocktake',original_branch,true); end if;
 payload:=jsonb_build_object('operation','review_inventory','review',r.id,'reason',p_reason);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.inventory_reconciliation_reviews where id=p_review_id for update;
 if r.status<>'pending' or nullif(btrim(p_reason),'') is null then raise exception 'Pending review and reconciliation explanation required';end if;
 -- No quantity changes here. Any independently approved adjustment has its own ledger entry.
 update public.inventory_reconciliation_reviews set status='resolved',reason=p_reason,reviewed_by=auth.uid(),reviewed_at=now() where id=r.id;
 result:=jsonb_build_object('id',r.id,'status','resolved');insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'late_inventory_reviewed',payload);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $function$;

CREATE OR REPLACE FUNCTION private.capture_return_condition_stock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if new.status='approved' and old.status<>'approved' then
  insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason,branch_id)
  select new.business_id,s.product_id,i.condition,sum(i.quantity),'customer_return',new.id,auth.uid(),new.reason,new.branch_id
  from public.return_items i join public.sale_items s on s.id=i.sale_item_id where i.return_id=new.id and i.condition in('damaged','defective') group by s.product_id,i.condition;
 end if;return new;
end $function$;

CREATE OR REPLACE FUNCTION private.process_trexven_sale(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.businesses%rowtype; item jsonb; product public.products%rowtype;
 member uuid; sale uuid; branch uuid; qty numeric; price numeric; v_discount numeric; v_total numeric:=0; branch_after numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into b from public.businesses where id=p_business_id for share;
 if not found then raise exception 'Business access denied' using errcode='42501'; end if;
 if b.pos_writes_paused then raise exception 'Sale writes are temporarily paused for recovery.' using errcode='42501'; end if;
 -- Lock trusted authorization rows so revocation is ordered against the sale.
 perform id from public.employees where business_id=b.id and user_id=auth.uid() for share;
 select id into member from public.business_members where business_id=b.id and user_id=auth.uid() and status='active' for share;
 if not public.is_business_member(b.id) or not private.has_business_permission(b.id,'complete_sales')
 or not private.has_business_permission(b.id,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 if p_quick is null or (not p_quick and p_employee_id is distinct from member)
 or (p_quick and p_employee_id is not null) then raise exception 'Employee does not match session' using errcode='42501'; end if;
 if p_payment_method<>'cash' and coalesce(current_setting('trexven.transaction_contract',true),'')<>'v2' then raise exception 'Use confirmed payment-line checkout; legacy receipt replay remains supported'; end if;
 if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','mobile_money','other') then raise exception 'Invalid payment method'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Items required'; end if;
 if p_quick and jsonb_array_length(p_items)<>1 then raise exception 'Invalid quick sale'; end if;
 branch:=p_branch_id;
 if b.branches_enabled then
   if branch is null then
     branch:=b.compatibility_branch_id;
     if not public.user_owns_business(b.id) and (select count(*) from public.employee_branch_assignments a
       join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
       join public.branches br on br.id=a.branch_id and br.business_id=a.business_id
       where a.business_id=b.id and e.user_id=auth.uid() and a.is_active and br.is_active)<>1 then
       raise exception 'Explicit branch context required' using errcode='42501'; end if;
   end if;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
   perform id from public.branches where id=branch and business_id=b.id and is_active for share;
   perform a.employee_id from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id
     where a.branch_id=branch and a.business_id=b.id and e.user_id=auth.uid() and a.is_active for share of a;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
 elsif branch is not null then
   raise exception 'Branch operations not activated' using errcode='42501';
 end if;
 perform id from public.products where business_id=b.id and id in
 (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by id for update;
 if branch is not null then
   perform product_id from public.inventory where business_id=b.id and branch_id=branch and product_id in
   (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by product_id for update;
 end if;
 insert into public.sales(business_id,employee_id,total,payment_method,status,branch_id)
 values(b.id,member,0,p_payment_method,'completed',branch) returning id into sale;
 for item in select * from jsonb_array_elements(p_items) loop
   qty:=(item->>'quantity')::numeric; price:=(item->>'unit_price')::numeric;
   v_discount:=coalesce((item->>'discount')::numeric,0);
   if scale(price)>2 or scale(v_discount)>2 then raise exception 'Money supports two decimal places'; end if;
   if qty is null or qty<=0 or scale(qty)>3 or qty::text in ('NaN','Infinity','-Infinity') or price is null or price<0 or price::text in ('NaN','Infinity','-Infinity')
   or v_discount::text in ('NaN','Infinity','-Infinity') or v_discount<0 or v_discount>qty*price then raise exception 'Invalid sale item'; end if;
   if v_discount>0 and (p_quick or not private.has_business_permission(b.id,'apply_discount')) then
     raise exception 'Discount permission denied' using errcode='42501'; end if;
   select * into product from public.products where id=(item->>'product_id')::uuid and business_id=b.id;
   if not found then raise exception 'Product not found in this business'; end if;
   if product.selling_price is null or product.is_active is not true or product.active is false then
     raise exception 'Product is pending or inactive'; end if;
   if lower(btrim(coalesce(product.unit,'piece'))) not in('kg','g','litre','ml','metre','cm') and qty<>trunc(qty) then raise exception 'Countable units require whole quantities'; end if;
   if price is distinct from product.selling_price and not private.has_business_permission(b.id,'override_price') then raise exception 'Price override permission required' using errcode='42501'; end if;
   if branch is null then
     if coalesce(product.quantity,0)<qty then raise exception 'Insufficient stock'; end if;
     perform set_config('trexven.catalog_operation','sale',true);
     perform set_config('trexven.catalog_request',sale::text,true);
     perform set_config('trexven.catalog_reason','Confirmed checkout stock deduction',true);
     update public.products set quantity=quantity-qty where id=product.id and business_id=b.id;
     perform set_config('trexven.catalog_operation','',true);
     perform set_config('trexven.catalog_request','',true);
     perform set_config('trexven.catalog_reason','',true);
   else
     update public.inventory set quantity=quantity-qty where business_id=b.id and branch_id=branch and product_id=product.id
       and quantity-coalesce(reserved_quantity,0)>=qty returning quantity into branch_after;
     if not found then raise exception 'Insufficient branch stock'; end if;
     insert into public.inventory_movements(business_id,branch_id,product_id,employee_id,
      movement_type,quantity,previous_quantity,new_quantity,reference_id,reason,source)
     values(b.id,branch,product.id,member,'sale',-qty,branch_after+qty,branch_after,sale,
      'Confirmed checkout stock deduction','branch_checkout');
   end if;
   insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
   values(sale,product.id,product.name,qty,price,v_discount,round(qty*price-v_discount,2));
   v_total:=v_total+round(qty*price-v_discount,2);
 end loop;
 if v_total is distinct from p_total then raise exception 'Sale total does not match items'; end if;
 update public.sales set total=v_total,total_amount=v_total,
 subtotal=(select sum(round(quantity*unit_price,2)) from public.sale_items where sale_id=sale),
 discount=(select sum(i.discount) from public.sale_items i where i.sale_id=sale) where id=sale;
 -- Preserve the legacy single-product quick-sale columns.
 if p_quick then update public.sales set product_id=product.id,quantity=qty,unit_price=price where id=sale; end if;
 return sale;
end $function$;

-- Only these new public entry points gain authenticated EXECUTE. Existing
-- function ACLs and all table/column grants remain unchanged.
revoke all on function public.get_trexven_inventory_capabilities(uuid) from public,anon;
grant execute on function public.get_trexven_inventory_capabilities(uuid) to authenticated;
revoke all on function public.start_trexven_branch_stocktake(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.start_trexven_branch_stocktake(uuid,uuid,uuid,text) to authenticated;
revoke all on function public.classify_trexven_branch_stock(uuid,uuid,uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.classify_trexven_branch_stock(uuid,uuid,uuid,uuid,numeric,text,text) to authenticated;
revoke all on function public.resolve_trexven_branch_condition_stock(uuid,uuid,uuid,uuid,numeric,text,text,text) from public,anon;
grant execute on function public.resolve_trexven_branch_condition_stock(uuid,uuid,uuid,uuid,numeric,text,text,text) to authenticated;
revoke all on function public.dispatch_trexven_branch_supplier_return(uuid,uuid,uuid,uuid,numeric,text,text,text) from public,anon;
grant execute on function public.dispatch_trexven_branch_supplier_return(uuid,uuid,uuid,uuid,numeric,text,text,text) to authenticated;

-- Make the new RPCs visible after the atomic migration commits.
notify pgrst, 'reload schema';
commit;
