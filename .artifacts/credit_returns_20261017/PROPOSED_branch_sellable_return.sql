-- PROPOSAL ONLY: NOT EXECUTED. Separate production approval is required.
-- Target: shared TREXVEN project ufehcfrlygqvminfjumf.
-- Preserves the deployed function's authorization, locks, monetary allocation,
-- idempotency, inspection and audit behavior. Adds original-branch restocking
-- with a corresponding inventory movement. Missing inventory rows fail closed.
-- Not validated by automated tests, per user instruction.
begin;
do $guard$
begin
 if md5(pg_get_functiondef('public.approve_trexven_return(uuid,uuid,text,boolean,text,uuid)'::regprocedure))
    <> '0cb313369c223034a260e8f110fafa7f' then
  raise exception 'Deployed return function changed. Re-audit and regenerate this proposal.';
 end if;
end;
$guard$;
CREATE OR REPLACE FUNCTION public.approve_trexven_return(p_return_id uuid, p_request_id uuid, p_method text, p_confirmed boolean, p_evidence text DEFAULT NULL::text, p_shift_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.sale_returns%rowtype; s public.sales%rowtype; a public.credit_accounts%rowtype; x record;
 returned numeric; consumed numeric; v_value numeric:=0; reduction numeric:=0; refund numeric; available numeric; member uuid; payload jsonb; previous jsonb; result jsonb; branch_previous numeric; branch_new numeric;
begin
 select * into r from public.sale_returns where id=p_return_id;
 if not found then raise exception 'Return not found' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_refund',r.branch_id,true);
 payload:=jsonb_build_object('operation','return_approval','return',p_return_id,'method',p_method,'confirmed',p_confirmed,'evidence',p_evidence,'shift',p_shift_id);
 previous:=private.operation_replay(r.business_id,p_request_id,payload);if previous is not null then return previous;end if;
 select * into s from public.sales where id=r.sale_id for update;
 select * into r from public.sale_returns where id=p_return_id for update;
 if r.status<>'inspected' then raise exception 'Separate condition inspection required';end if;
 for x in select i.*,si.product_id,si.quantity sold_qty,si.total sold_value from public.return_items i join public.sale_items si on si.id=i.sale_item_id where i.return_id=r.id order by si.product_id,i.sale_item_id loop
  select coalesce(sum(i.quantity),0),coalesce(sum(i.value),0) into returned,consumed from public.return_items i join public.sale_returns old on old.id=i.return_id where i.sale_item_id=x.sale_item_id and old.status='approved';
  if returned+x.quantity>x.sold_qty then raise exception 'Return exceeds remaining original quantity';end if;
  if x.quantity+returned=x.sold_qty then available:=x.sold_value-consumed;else available:=least(x.sold_value-consumed,round(x.sold_value*x.quantity/x.sold_qty,2));end if;
  update public.return_items set value=available where id=x.id;v_value:=v_value+available;
 end loop;
 select * into a from public.credit_accounts where sale_id=r.sale_id for update;
 if found then reduction:=least(a.outstanding,v_value);end if;
 refund:=v_value-reduction;
 if refund>0 then
  if p_method not in('cash','bank_transfer','card') or p_confirmed is distinct from true or (p_method<>'cash' and nullif(btrim(p_evidence),'')is null) then raise exception 'Confirm actual refund and external reference';end if;
  select coalesce(sum(amount),0) into available from public.sale_payments where sale_id=r.sale_id and method=p_method;
  if not exists(select 1 from public.sale_payments where sale_id=r.sale_id) and s.payment_method=p_method then available:=s.total;end if;
  available:=available+coalesce((select -sum(amount) from public.credit_entries where sale_id=r.sale_id and kind in('repayment','repayment_reversal') and method=p_method),0)-coalesce((select sum(refund_amount) from public.sale_returns where sale_id=r.sale_id and status='approved' and refund_method=p_method),0);
  if refund>available then raise exception 'Refund exceeds money actually collected by this method';end if;
 end if;
 select id into member from public.business_members where business_id=r.business_id and user_id=auth.uid() and status='active';
 perform p.id from public.products p where p.business_id=r.business_id and p.id in(select si.product_id from public.return_items ri join public.sale_items si on si.id=ri.sale_item_id where ri.return_id=r.id) order by p.id for update;
 if refund>0 and p_method='cash' then perform private.validate_operational_shift(r.business_id,member,p_shift_id,r.branch_id);end if;
 if reduction>0 then
  update public.credit_accounts set outstanding=outstanding-reduction where sale_id=r.sale_id;
  insert into public.credit_entries(business_id,sale_id,request_id,actor_id,kind,amount,reason,reference_id) values(r.business_id,r.sale_id,p_request_id,auth.uid(),'return',-reduction,r.reason,r.id);
 end if;
 for x in select i.*,si.product_id from public.return_items i join public.sale_items si on si.id=i.sale_item_id where i.return_id=r.id order by si.product_id loop
  if x.condition='sellable' then
   -- Inspection is independently authorized above; refund approval may restock
   -- only the exact inspected quantity and original product, never a price field.
   perform set_config('trexven.catalog_reason','Inspected sellable return: '||r.reason,true);
   perform set_config('trexven.catalog_request',r.id::text,true);
   perform set_config('trexven.catalog_operation','return',true);
   if r.branch_id is null then
    update public.products set quantity=coalesce(quantity,0)+x.quantity,updated_at=now() where id=x.product_id and business_id=r.business_id;
   else
    -- The original branch is authorized by operations_context above. Products
    -- are already locked in the established product-before-inventory order.
    select quantity into branch_previous from public.inventory
     where business_id=r.business_id and branch_id=r.branch_id and product_id=x.product_id for update;
    if not found then raise exception 'Original branch inventory row is unavailable';end if;
    update public.inventory set quantity=coalesce(quantity,0)+x.quantity,updated_at=now()
     where business_id=r.business_id and branch_id=r.branch_id and product_id=x.product_id
     returning quantity into branch_new;
    insert into public.inventory_movements(business_id,product_id,branch_id,movement_type,quantity,previous_quantity,new_quantity,reference_id,reason,source,notes)
     values(r.business_id,x.product_id,r.branch_id,'return',x.quantity,coalesce(branch_previous,0),branch_new,r.id,r.reason,'customer_return','Inspected sellable return to original branch');
   end if;
  end if;
 end loop;
 perform set_config('trexven.catalog_operation','',true);perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 update public.sale_returns set status='approved',approved_by=auth.uid(),value=v_value,debt_reduction=reduction,refund_amount=refund,refund_method=case when refund>0 then p_method end,refund_evidence=p_evidence,approved_at=now() where id=r.id;
 if refund>0 and p_method='cash' then perform private.record_operational_cash(r.business_id,member,-refund,'refund',r.id,p_shift_id);end if;
 result:=jsonb_build_object('return_id',r.id,'value',v_value,'debt_reduction',reduction,'refund',refund);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'sale_return_approved',result);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $function$;

commit;

