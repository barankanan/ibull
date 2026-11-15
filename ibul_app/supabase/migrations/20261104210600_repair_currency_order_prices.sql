-- DO NOT APPLY to production unless the operator names this file and says
-- Bu migration'ı production'a uygula.
-- Rewrites only the six verified orders, and only while their price, quantity,
-- empty line total, status, and table still match the checked snapshot.
-- A changed row is left untouched. Quantity is not edited. Orders and
-- payments are not deleted.

create or replace function public.ibul_repair_currency_order_items(p_items jsonb)
returns jsonb
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_item jsonb;
  v_out jsonb := '[]'::jsonb;
  v_price text;
  v_line text;
  v_qty numeric;
  v_amount numeric;
  v_line_amount numeric;
  v_line_text text;
  v_changed boolean := false;
begin
  if jsonb_typeof(p_items) is distinct from 'array' then
    return null;
  end if;
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_price := btrim(coalesce(v_item->>'price', ''));
    v_line := btrim(coalesce(v_item->>'line_total', ''));
    if v_price ~ '^-?[0-9]+(\.[0-9]+)?$'
       and (v_line = '' or v_line ~ '^-?[0-9]+(\.[0-9]+)?$') then
      v_out := v_out || jsonb_build_array(v_item);
      continue;
    end if;
    if v_price !~ '^₺[0-9]+(\.[0-9]+)?$'
       and v_price !~ '^[0-9]+(\.[0-9]+)? TL$' then
      return null;
    end if;
    if jsonb_typeof(v_item->'quantity') is distinct from 'number' then
      return null;
    end if;
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty <= 0 then
      return null;
    end if;
    if v_price ~ '^₺' then
      v_amount := substr(v_price, 2)::numeric;
    else
      v_amount := btrim(replace(v_price, ' TL', ''))::numeric;
    end if;
    if v_line <> '' then
      if v_line ~ '^-?[0-9]+(\.[0-9]+)?$' then
        v_line_text := v_line;
      elsif v_line ~ '^₺[0-9]+(\.[0-9]+)?$' then
        v_line_text := substr(v_line, 2);
      elsif v_line ~ '^[0-9]+(\.[0-9]+)? TL$' then
        v_line_text := btrim(replace(v_line, ' TL', ''));
      else
        return null;
      end if;
      v_line_amount := v_line_text::numeric;
      if round(v_line_amount, 2) <> round(v_amount * v_qty, 2) then
        return null;
      end if;
    end if;
    v_changed := true;
    v_out := v_out || jsonb_build_array(
      v_item || jsonb_build_object(
        'price', v_amount,
        'line_total', round(v_amount * v_qty, 2)
      )
    );
  end loop;
  if not v_changed then
    return p_items;
  end if;
  return v_out;
end;
$$;

-- The apply predicate is the verified snapshot. A changed price, quantity,
-- line total, status, table, or item count does not match and is left as it is.
update public.table_orders o
set items = repaired.items
from (
  select id, public.ibul_repair_currency_order_items(items) as items
  from public.table_orders
  where id in (
    '2dd80e75-e60c-4e6c-bca4-b560575bcb5a',
    '677c564d-c5af-47d4-9ad6-bd29b549cabd',
    '6eec6632-cec8-4182-bb89-90a80e9e5ef3',
    'e84b7d96-5b35-4e8b-b29d-ae13acc6a895',
    'e98bbe16-fa8c-4805-abb0-bece97f63ba8',
    '7b264555-2214-431e-98b0-82e2add9874d'
  )
) repaired
where o.id = repaired.id
  and repaired.items is not null
  and repaired.items is distinct from o.items
  and (o.id, o.table_number, o.status, coalesce((
    select string_agg(
      btrim(coalesce(item->>'price', '')) || '|' ||
      coalesce(item->>'quantity', '') || '|' ||
      btrim(coalesce(item->>'line_total', '')),
      ',' order by ordinality
    )
    from jsonb_array_elements(o.items) with ordinality as line(item, ordinality)
  ), '')) in (
    ('2dd80e75-e60c-4e6c-bca4-b560575bcb5a'::uuid, 1, 'new', '₺544|2|'),
    ('677c564d-c5af-47d4-9ad6-bd29b549cabd'::uuid, 1, 'new', '₺544|2|'),
    ('6eec6632-cec8-4182-bb89-90a80e9e5ef3'::uuid, 1, 'done', '1500 TL|1|'),
    ('e84b7d96-5b35-4e8b-b29d-ae13acc6a895'::uuid, 1, 'new', '₺544|1|,₺111|1|'),
    ('e98bbe16-fa8c-4805-abb0-bece97f63ba8'::uuid, 1, 'new', '₺544|1|'),
    ('7b264555-2214-431e-98b0-82e2add9874d'::uuid, 7, 'new', '₺544|1|')
  );

drop function public.ibul_repair_currency_order_items(jsonb);
