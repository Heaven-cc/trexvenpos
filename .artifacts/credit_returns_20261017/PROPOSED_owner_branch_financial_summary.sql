-- PROPOSAL ONLY: NOT EXECUTED. Separate explicit production approval required.
-- Target: shared TREXVEN project ufehcfrlygqvminfjumf.
-- Minimum correction: permit the verified owner to read the existing
-- business-wide summary when branches are enabled. Keep the three arguments,
-- JSON return shape, all aggregation formulas and non-owner checks unchanged.
-- No RLS, grants, tables, ledger rows, stock or RPC overloads are changed.
-- Source-reviewed only; no SQL execution, builds or tests were performed.
begin;
do $guard$
begin
 if md5(pg_get_functiondef('public.get_trexven_financial_summary(uuid,timestamptz,timestamptz)'::regprocedure))
    <> 'bedf583408f7fa5a146e1eae7b740cd8' then
  raise exception 'Deployed summary function changed. Re-audit before applying this proposal.';
 end if;
end;
$guard$;
CREATE OR REPLACE FUNCTION public.get_trexven_financial_summary(p_business_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 -- Lock before checking ownership so concurrent ownership changes cannot
 -- authorize a stale owner. Normal owner/staff checks are unchanged below.
 perform b.id from public.businesses b where b.id=p_business_id for share;
 if public.user_owns_business(p_business_id) is not true
    or not exists(select 1 from public.businesses b where b.id=p_business_id and b.branches_enabled is true) then
  perform private.operations_context(p_business_id,'view_finance',null,true);
 end if;
 -- Only a verified owner of a branch-enabled business takes the business-wide
 -- read path. No manager or employee gains a business-wide branch summary.
 if p_start is null or p_end is null or p_end<=p_start then raise exception 'Valid reporting interval required';end if;
 select jsonb_build_object('gross_sales',coalesce((select sum(total) from public.sales where business_id=p_business_id and status='completed' and coalesce(sold_at,created_at)>=p_start and coalesce(sold_at,created_at)<p_end),0),
 'sale_collections',coalesce((select sum(p.amount) from public.sale_payments p where p.business_id=p_business_id and p.confirmed_at>=p_start and p.confirmed_at<p_end),0)+coalesce((select sum(s.total) from public.sales s where s.business_id=p_business_id and s.status='completed' and s.payment_method in('cash','bank_transfer','card') and s.created_at>=p_start and s.created_at<p_end and not exists(select 1 from public.sale_payments p where p.sale_id=s.id)),0),
 'repayment_collections',coalesce((select -sum(amount) from public.credit_entries where business_id=p_business_id and kind in('repayment','repayment_reversal') and created_at>=p_start and created_at<p_end),0),
 'refunds',coalesce((select sum(refund_amount) from public.sale_returns where business_id=p_business_id and status='approved' and approved_at>=p_start and approved_at<p_end),0),
 'receivables',coalesce((select sum(outstanding) from public.credit_accounts where business_id=p_business_id),0),
 'overdue',coalesce((select sum(outstanding) from public.credit_accounts where business_id=p_business_id and due_date<(public.get_trexven_business_day(p_business_id)->>'local_date')::date),0)) into result;
 result:=result||jsonb_build_object('net_collected',((result->>'sale_collections')::numeric+(result->>'repayment_collections')::numeric-(result->>'refunds')::numeric)::text);
 select jsonb_object_agg(key,to_jsonb(value#>>'{}')) into result from jsonb_each(result);
 return result;
end $function$;
commit;

