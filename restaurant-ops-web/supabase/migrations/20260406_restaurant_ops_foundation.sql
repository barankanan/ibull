create extension if not exists pgcrypto;

create schema if not exists restaurant;

do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'restaurant_table_status'
  ) then
    create type restaurant.restaurant_table_status as enum (
      'empty',
      'active',
      'kitchen_sent',
      'preparing',
      'ready',
      'served',
      'payment_pending',
      'completed'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_check_status'
  ) then
    create type restaurant.restaurant_check_status as enum (
      'draft',
      'kitchen_sent',
      'preparing',
      'ready',
      'served',
      'payment_pending',
      'completed'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_payment_method'
  ) then
    create type restaurant.restaurant_payment_method as enum (
      'cash',
      'card',
      'meal_card',
      'qr',
      'voucher'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_split_mode'
  ) then
    create type restaurant.restaurant_split_mode as enum (
      'product',
      'person',
      'amount'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_log_status'
  ) then
    create type restaurant.restaurant_log_status as enum (
      'pending',
      'committed',
      'rolled_back'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_log_severity'
  ) then
    create type restaurant.restaurant_log_severity as enum (
      'info',
      'success',
      'warning',
      'error'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_print_type'
  ) then
    create type restaurant.restaurant_print_type as enum (
      'adisyon',
      'mutfak'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'restaurant_print_job_status'
  ) then
    create type restaurant.restaurant_print_job_status as enum (
      'pending',
      'printed',
      'failed'
    );
  end if;
end
$$;

create table if not exists restaurant.venues (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  code text not null unique,
  timezone text not null default 'Europe/Istanbul',
  created_at timestamptz not null default now()
);

create table if not exists restaurant.customers (
  id text primary key default gen_random_uuid()::text,
  venue_id text not null references restaurant.venues(id) on delete cascade,
  name text not null,
  phone text not null,
  company text,
  loyalty_tier text not null default 'Yeni',
  visit_count integer not null default 0,
  average_spend numeric(12,2) not null default 0,
  favorite_product_ids text[] not null default '{}',
  notes text[] not null default '{}',
  last_visit_at timestamptz,
  revision bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists restaurant.product_categories (
  id text primary key default gen_random_uuid()::text,
  venue_id text not null references restaurant.venues(id) on delete cascade,
  name text not null,
  description text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists restaurant.products (
  id text primary key default gen_random_uuid()::text,
  venue_id text not null references restaurant.venues(id) on delete cascade,
  category_id text not null references restaurant.product_categories(id) on delete restrict,
  sku text,
  name text not null,
  description text not null default '',
  base_price numeric(12,2) not null default 0,
  kind text not null default 'standard',
  stock_state text not null default 'in_stock',
  stock_label text not null default 'Stokta',
  prep_minutes integer not null default 0,
  visual_tone text not null default 'plum',
  quick_weight_options integer[],
  suggestion_ids text[],
  tags text[],
  is_favorite boolean not null default false,
  is_popular boolean not null default false,
  revision bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists restaurant.tables (
  id text primary key default gen_random_uuid()::text,
  venue_id text not null references restaurant.venues(id) on delete cascade,
  active_session_id text,
  name text not null,
  zone text not null,
  seat_count integer not null default 0,
  guest_count integer not null default 0,
  status restaurant.restaurant_table_status not null default 'empty',
  opened_at timestamptz not null default now(),
  last_action_at timestamptz not null default now(),
  current_customer_id text references restaurant.customers(id) on delete set null,
  reservation_payload jsonb,
  reference_code text,
  barcode text,
  timed_billing_enabled boolean not null default false,
  timed_billing_started_at timestamptz,
  timed_billing_rate_per_hour numeric(12,2),
  revision bigint not null default 0,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, name)
);

create table if not exists restaurant.table_drafts (
  id text primary key default gen_random_uuid()::text,
  table_id text not null unique references restaurant.tables(id) on delete cascade,
  editing_check_id text,
  updated_at timestamptz not null default now(),
  revision bigint not null default 0
);

create table if not exists restaurant.draft_items (
  id text primary key,
  draft_id text not null references restaurant.table_drafts(id) on delete cascade,
  product_id text not null,
  name text not null,
  kind text not null,
  quantity numeric(12,3) not null default 1,
  unit_price numeric(12,2) not null default 0,
  total_price numeric(12,2) not null default 0,
  status restaurant.restaurant_check_status not null default 'draft',
  customizations_payload jsonb not null default '{}'::jsonb,
  service_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0
);

create table if not exists restaurant.checks (
  id text primary key default gen_random_uuid()::text,
  table_id text not null references restaurant.tables(id) on delete cascade,
  label text not null,
  status restaurant.restaurant_check_status not null default 'draft',
  note text,
  source text not null default 'waiter',
  total_amount numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0
);

create table if not exists restaurant.check_items (
  id text primary key,
  check_id text not null references restaurant.checks(id) on delete cascade,
  product_id text not null,
  name text not null,
  kind text not null,
  quantity numeric(12,3) not null default 1,
  unit_price numeric(12,2) not null default 0,
  total_price numeric(12,2) not null default 0,
  status restaurant.restaurant_check_status not null default 'draft',
  customizations_payload jsonb not null default '{}'::jsonb,
  service_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0
);

create table if not exists restaurant.partial_payments (
  id text primary key default gen_random_uuid()::text,
  table_id text not null references restaurant.tables(id) on delete cascade,
  amount numeric(12,2) not null,
  method restaurant.restaurant_payment_method not null,
  kind text not null default 'partial',
  note text,
  remaining_after_payment numeric(12,2),
  created_at timestamptz not null default now(),
  revision bigint not null default 0
);

create table if not exists restaurant.split_plans (
  id text primary key default gen_random_uuid()::text,
  table_id text not null references restaurant.tables(id) on delete cascade,
  mode restaurant.restaurant_split_mode not null,
  note text,
  created_at timestamptz not null default now(),
  revision bigint not null default 0
);

create table if not exists restaurant.split_plan_parts (
  id text primary key default gen_random_uuid()::text,
  split_plan_id text not null references restaurant.split_plans(id) on delete cascade,
  label text not null,
  amount numeric(12,2) not null,
  line_item_ids text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists restaurant.operation_logs (
  id text primary key default gen_random_uuid()::text,
  venue_id text not null references restaurant.venues(id) on delete cascade,
  table_id text references restaurant.tables(id) on delete set null,
  operation_key text not null,
  type text not null,
  title text not null,
  description text not null,
  status restaurant.restaurant_log_status not null default 'committed',
  severity restaurant.restaurant_log_severity not null default 'info',
  actor_user_id text,
  actor_name text,
  client_mutation_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists restaurant.print_logs (
  id text primary key default gen_random_uuid()::text,
  venue_id text not null references restaurant.venues(id) on delete cascade,
  table_id text not null references restaurant.tables(id) on delete cascade,
  table_name text not null,
  check_id text references restaurant.checks(id) on delete set null,
  order_reference text,
  print_type restaurant.restaurant_print_type not null,
  printer_target text,
  requested_by text,
  status restaurant.restaurant_print_job_status not null default 'pending',
  total_amount numeric(12,2) not null default 0,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  printed_at timestamptz
);

do $$
declare
  v_default_venue_id text;
begin
  alter table restaurant.venues
    add column if not exists code text;
  alter table restaurant.venues
    add column if not exists timezone text not null default 'Europe/Istanbul';
  alter table restaurant.venues
    add column if not exists created_at timestamptz not null default now();
  update restaurant.venues
  set code = coalesce(code, id),
      timezone = coalesce(timezone, 'Europe/Istanbul'),
      created_at = coalesce(created_at, now())
  where code is null
     or timezone is null
     or created_at is null;

  if not exists (
    select 1
    from restaurant.venues
    where id = 'venue-demo'
       or code = 'venue-demo'
  ) then
    insert into restaurant.venues (id, name, code, timezone)
    values ('venue-demo', 'Demo Venue', 'venue-demo', 'Europe/Istanbul');
  end if;

  select id
  into v_default_venue_id
  from restaurant.venues
  where id = 'venue-demo'
  limit 1;

  if v_default_venue_id is null then
    select id
    into v_default_venue_id
    from restaurant.venues
    order by created_at
    limit 1;
  end if;

  if v_default_venue_id is null then
    raise exception 'DEFAULT_VENUE_NOT_FOUND';
  end if;

  alter table restaurant.customers
    add column if not exists venue_id text references restaurant.venues(id) on delete cascade;
  alter table restaurant.customers
    add column if not exists company text;
  alter table restaurant.customers
    add column if not exists loyalty_tier text not null default 'Yeni';
  alter table restaurant.customers
    add column if not exists visit_count integer not null default 0;
  alter table restaurant.customers
    add column if not exists average_spend numeric(12,2) not null default 0;
  alter table restaurant.customers
    add column if not exists favorite_product_ids text[] not null default '{}';
  alter table restaurant.customers
    add column if not exists notes text[] not null default '{}';
  alter table restaurant.customers
    add column if not exists last_visit_at timestamptz;
  alter table restaurant.customers
    add column if not exists revision bigint not null default 0;
  alter table restaurant.customers
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.customers
    add column if not exists updated_at timestamptz not null default now();
  update restaurant.customers
  set venue_id = coalesce(venue_id, v_default_venue_id)
  where venue_id is null;

  alter table restaurant.product_categories
    add column if not exists venue_id text references restaurant.venues(id) on delete cascade;
  alter table restaurant.product_categories
    add column if not exists description text not null default '';
  alter table restaurant.product_categories
    add column if not exists sort_order integer not null default 0;
  alter table restaurant.product_categories
    add column if not exists created_at timestamptz not null default now();
  update restaurant.product_categories
  set venue_id = coalesce(venue_id, v_default_venue_id)
  where venue_id is null;

  alter table restaurant.products
    add column if not exists venue_id text references restaurant.venues(id) on delete cascade;
  alter table restaurant.products
    add column if not exists sku text;
  alter table restaurant.products
    add column if not exists description text not null default '';
  alter table restaurant.products
    add column if not exists prep_minutes integer not null default 0;
  alter table restaurant.products
    add column if not exists visual_tone text not null default 'plum';
  alter table restaurant.products
    add column if not exists quick_weight_options integer[];
  alter table restaurant.products
    add column if not exists suggestion_ids text[];
  alter table restaurant.products
    add column if not exists tags text[];
  alter table restaurant.products
    add column if not exists is_favorite boolean not null default false;
  alter table restaurant.products
    add column if not exists is_popular boolean not null default false;
  alter table restaurant.products
    add column if not exists revision bigint not null default 0;
  alter table restaurant.products
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.products
    add column if not exists updated_at timestamptz not null default now();
  update restaurant.products
  set venue_id = coalesce(venue_id, v_default_venue_id)
  where venue_id is null;

  alter table restaurant.tables
    add column if not exists venue_id text references restaurant.venues(id) on delete cascade;
  alter table restaurant.tables
    add column if not exists active_session_id text;
  alter table restaurant.tables
    add column if not exists opened_at timestamptz not null default now();
  alter table restaurant.tables
    add column if not exists last_action_at timestamptz not null default now();
  alter table restaurant.tables
    add column if not exists current_customer_id text references restaurant.customers(id) on delete set null;
  alter table restaurant.tables
    add column if not exists reservation_payload jsonb;
  alter table restaurant.tables
    add column if not exists reference_code text;
  alter table restaurant.tables
    add column if not exists barcode text;
  alter table restaurant.tables
    add column if not exists timed_billing_enabled boolean not null default false;
  alter table restaurant.tables
    add column if not exists timed_billing_started_at timestamptz;
  alter table restaurant.tables
    add column if not exists timed_billing_rate_per_hour numeric(12,2);
  alter table restaurant.tables
    add column if not exists revision bigint not null default 0;
  alter table restaurant.tables
    add column if not exists updated_by text;
  alter table restaurant.tables
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.tables
    add column if not exists updated_at timestamptz not null default now();
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'tables'
      and column_name = 'status'
      and udt_name <> 'restaurant_table_status'
  ) then
    alter table restaurant.tables
      alter column status drop default,
      alter column status type restaurant.restaurant_table_status
      using (
        case lower(coalesce(status::text, 'empty'))
          when 'empty' then 'empty'
          when 'active' then 'active'
          when 'kitchen_sent' then 'kitchen_sent'
          when 'preparing' then 'preparing'
          when 'ready' then 'ready'
          when 'served' then 'served'
          when 'payment_pending' then 'payment_pending'
          when 'completed' then 'completed'
          else 'empty'
        end
      )::restaurant.restaurant_table_status,
      alter column status set default 'empty';
  end if;
  update restaurant.tables
  set venue_id = coalesce(venue_id, v_default_venue_id)
  where venue_id is null;

  alter table restaurant.table_drafts
    add column if not exists editing_check_id text;
  alter table restaurant.table_drafts
    add column if not exists updated_at timestamptz not null default now();
  alter table restaurant.table_drafts
    add column if not exists revision bigint not null default 0;

  alter table restaurant.draft_items
    add column if not exists status restaurant.restaurant_check_status not null default 'draft';
  alter table restaurant.draft_items
    add column if not exists customizations_payload jsonb not null default '{}'::jsonb;
  alter table restaurant.draft_items
    add column if not exists service_payload jsonb;
  alter table restaurant.draft_items
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.draft_items
    add column if not exists updated_at timestamptz not null default now();
  alter table restaurant.draft_items
    add column if not exists revision bigint not null default 0;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'draft_items'
      and column_name = 'status'
      and udt_name <> 'restaurant_check_status'
  ) then
    alter table restaurant.draft_items
      alter column status drop default,
      alter column status type restaurant.restaurant_check_status
      using (
        case lower(coalesce(status::text, 'draft'))
          when 'draft' then 'draft'
          when 'kitchen_sent' then 'kitchen_sent'
          when 'preparing' then 'preparing'
          when 'ready' then 'ready'
          when 'served' then 'served'
          when 'payment_pending' then 'payment_pending'
          when 'completed' then 'completed'
          else 'draft'
        end
      )::restaurant.restaurant_check_status,
      alter column status set default 'draft';
  end if;

  alter table restaurant.checks
    add column if not exists note text;
  alter table restaurant.checks
    add column if not exists source text not null default 'waiter';
  alter table restaurant.checks
    add column if not exists total_amount numeric(12,2) not null default 0;
  alter table restaurant.checks
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.checks
    add column if not exists updated_at timestamptz not null default now();
  alter table restaurant.checks
    add column if not exists revision bigint not null default 0;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'checks'
      and column_name = 'status'
      and udt_name <> 'restaurant_check_status'
  ) then
    alter table restaurant.checks
      alter column status drop default,
      alter column status type restaurant.restaurant_check_status
      using (
        case lower(coalesce(status::text, 'draft'))
          when 'draft' then 'draft'
          when 'kitchen_sent' then 'kitchen_sent'
          when 'preparing' then 'preparing'
          when 'ready' then 'ready'
          when 'served' then 'served'
          when 'payment_pending' then 'payment_pending'
          when 'completed' then 'completed'
          else 'draft'
        end
      )::restaurant.restaurant_check_status,
      alter column status set default 'draft';
  end if;

  alter table restaurant.check_items
    add column if not exists status restaurant.restaurant_check_status not null default 'draft';
  alter table restaurant.check_items
    add column if not exists customizations_payload jsonb not null default '{}'::jsonb;
  alter table restaurant.check_items
    add column if not exists service_payload jsonb;
  alter table restaurant.check_items
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.check_items
    add column if not exists updated_at timestamptz not null default now();
  alter table restaurant.check_items
    add column if not exists revision bigint not null default 0;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'check_items'
      and column_name = 'status'
      and udt_name <> 'restaurant_check_status'
  ) then
    alter table restaurant.check_items
      alter column status drop default,
      alter column status type restaurant.restaurant_check_status
      using (
        case lower(coalesce(status::text, 'draft'))
          when 'draft' then 'draft'
          when 'kitchen_sent' then 'kitchen_sent'
          when 'preparing' then 'preparing'
          when 'ready' then 'ready'
          when 'served' then 'served'
          when 'payment_pending' then 'payment_pending'
          when 'completed' then 'completed'
          else 'draft'
        end
      )::restaurant.restaurant_check_status,
      alter column status set default 'draft';
  end if;

  alter table restaurant.partial_payments
    add column if not exists kind text not null default 'partial';
  alter table restaurant.partial_payments
    add column if not exists note text;
  alter table restaurant.partial_payments
    add column if not exists remaining_after_payment numeric(12,2);
  alter table restaurant.partial_payments
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.partial_payments
    add column if not exists revision bigint not null default 0;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'partial_payments'
      and column_name = 'method'
      and udt_name <> 'restaurant_payment_method'
  ) then
    alter table restaurant.partial_payments
      alter column method type restaurant.restaurant_payment_method
      using (
        case lower(coalesce(method::text, 'cash'))
          when 'cash' then 'cash'
          when 'card' then 'card'
          when 'meal_card' then 'meal_card'
          when 'qr' then 'qr'
          when 'voucher' then 'voucher'
          else 'cash'
        end
      )::restaurant.restaurant_payment_method;
  end if;

  alter table restaurant.split_plans
    add column if not exists note text;
  alter table restaurant.split_plans
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.split_plans
    add column if not exists revision bigint not null default 0;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'split_plans'
      and column_name = 'mode'
      and udt_name <> 'restaurant_split_mode'
  ) then
    alter table restaurant.split_plans
      alter column mode type restaurant.restaurant_split_mode
      using (
        case lower(coalesce(mode::text, 'product'))
          when 'product' then 'product'
          when 'person' then 'person'
          when 'amount' then 'amount'
          else 'product'
        end
      )::restaurant.restaurant_split_mode;
  end if;

  alter table restaurant.split_plan_parts
    add column if not exists created_at timestamptz not null default now();

  alter table restaurant.operation_logs
    add column if not exists venue_id text references restaurant.venues(id) on delete cascade;
  alter table restaurant.operation_logs
    add column if not exists table_id text references restaurant.tables(id) on delete set null;
  alter table restaurant.operation_logs
    add column if not exists operation_key text;
  alter table restaurant.operation_logs
    add column if not exists type text;
  alter table restaurant.operation_logs
    add column if not exists title text;
  alter table restaurant.operation_logs
    add column if not exists description text;
  alter table restaurant.operation_logs
    add column if not exists status restaurant.restaurant_log_status not null default 'committed';
  alter table restaurant.operation_logs
    add column if not exists severity restaurant.restaurant_log_severity not null default 'info';
  alter table restaurant.operation_logs
    add column if not exists actor_user_id text;
  alter table restaurant.operation_logs
    add column if not exists actor_name text;
  alter table restaurant.operation_logs
    add column if not exists client_mutation_id text;
  alter table restaurant.operation_logs
    add column if not exists payload jsonb not null default '{}'::jsonb;
  alter table restaurant.operation_logs
    add column if not exists created_at timestamptz not null default now();
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'operation_logs'
      and column_name = 'status'
      and udt_name <> 'restaurant_log_status'
  ) then
    alter table restaurant.operation_logs
      alter column status drop default,
      alter column status type restaurant.restaurant_log_status
      using (
        case lower(coalesce(status::text, 'committed'))
          when 'pending' then 'pending'
          when 'committed' then 'committed'
          when 'rolled_back' then 'rolled_back'
          else 'committed'
        end
      )::restaurant.restaurant_log_status,
      alter column status set default 'committed';
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'operation_logs'
      and column_name = 'severity'
      and udt_name <> 'restaurant_log_severity'
  ) then
    alter table restaurant.operation_logs
      alter column severity drop default,
      alter column severity type restaurant.restaurant_log_severity
      using (
        case lower(coalesce(severity::text, 'info'))
          when 'info' then 'info'
          when 'success' then 'success'
          when 'warning' then 'warning'
          when 'error' then 'error'
          else 'info'
        end
      )::restaurant.restaurant_log_severity,
      alter column severity set default 'info';
  end if;
  update restaurant.operation_logs ol
  set venue_id = coalesce(ol.venue_id, t.venue_id, v_default_venue_id)
  from restaurant.tables t
  where ol.table_id = t.id
    and ol.venue_id is null;
  update restaurant.operation_logs
  set venue_id = coalesce(venue_id, v_default_venue_id),
      operation_key = coalesce(operation_key, type, 'legacy_operation'),
      type = coalesce(type, operation_key, 'legacy_operation'),
      title = coalesce(title, 'Legacy Operation'),
      description = coalesce(description, 'Legacy operation migrated into restaurant.operation_logs.'),
      status = coalesce(status, 'committed'::restaurant.restaurant_log_status),
      severity = coalesce(severity, 'info'::restaurant.restaurant_log_severity),
      payload = coalesce(payload, '{}'::jsonb),
      created_at = coalesce(created_at, now())
  where venue_id is null
     or operation_key is null
     or type is null
     or title is null
     or description is null
     or status is null
     or severity is null
     or payload is null
     or created_at is null;

  alter table restaurant.print_logs
    add column if not exists venue_id text references restaurant.venues(id) on delete cascade;
  alter table restaurant.print_logs
    add column if not exists table_id text references restaurant.tables(id) on delete cascade;
  alter table restaurant.print_logs
    add column if not exists table_name text;
  alter table restaurant.print_logs
    add column if not exists check_id text references restaurant.checks(id) on delete set null;
  alter table restaurant.print_logs
    add column if not exists order_reference text;
  alter table restaurant.print_logs
    add column if not exists print_type restaurant.restaurant_print_type not null default 'adisyon';
  alter table restaurant.print_logs
    add column if not exists printer_target text;
  alter table restaurant.print_logs
    add column if not exists requested_by text;
  alter table restaurant.print_logs
    add column if not exists status restaurant.restaurant_print_job_status not null default 'pending';
  alter table restaurant.print_logs
    add column if not exists total_amount numeric(12,2) not null default 0;
  alter table restaurant.print_logs
    add column if not exists payload jsonb not null default '{}'::jsonb;
  alter table restaurant.print_logs
    add column if not exists created_at timestamptz not null default now();
  alter table restaurant.print_logs
    add column if not exists printed_at timestamptz;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'print_logs'
      and column_name = 'printer_name'
  ) then
    update restaurant.print_logs
    set printer_target = coalesce(printer_target, printer_name)
    where printer_target is null;
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'print_logs'
      and column_name = 'print_type'
      and udt_name <> 'restaurant_print_type'
  ) then
    alter table restaurant.print_logs
      alter column print_type drop default,
      alter column print_type type restaurant.restaurant_print_type
      using (
        case lower(coalesce(print_type::text, 'adisyon'))
          when 'adisyon' then 'adisyon'
          when 'receipt' then 'adisyon'
          when 'check' then 'adisyon'
          when 'mutfak' then 'mutfak'
          when 'kitchen' then 'mutfak'
          else 'adisyon'
        end
      )::restaurant.restaurant_print_type,
      alter column print_type set default 'adisyon';
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'restaurant'
      and table_name = 'print_logs'
      and column_name = 'status'
      and udt_name <> 'restaurant_print_job_status'
  ) then
    alter table restaurant.print_logs
      alter column status drop default,
      alter column status type restaurant.restaurant_print_job_status
      using (
        case lower(coalesce(status::text, 'pending'))
          when 'pending' then 'pending'
          when 'queued' then 'pending'
          when 'printing' then 'pending'
          when 'printed' then 'printed'
          when 'failed' then 'failed'
          else 'pending'
        end
      )::restaurant.restaurant_print_job_status,
      alter column status set default 'pending';
  end if;
  update restaurant.print_logs pl
  set venue_id = coalesce(pl.venue_id, t.venue_id, v_default_venue_id),
      table_name = coalesce(pl.table_name, t.name)
  from restaurant.tables t
  where pl.table_id = t.id
    and (pl.venue_id is null or pl.table_name is null);
  update restaurant.print_logs pl
  set order_reference = coalesce(pl.order_reference, c.label),
      total_amount = coalesce(pl.total_amount, c.total_amount, 0)
  from restaurant.checks c
  where pl.check_id = c.id
    and (pl.order_reference is null or pl.total_amount is null);
  update restaurant.print_logs
  set venue_id = coalesce(venue_id, v_default_venue_id),
      table_name = coalesce(table_name, 'Masa'),
      print_type = coalesce(print_type, 'adisyon'),
      status = coalesce(status, 'pending'),
      total_amount = coalesce(total_amount, 0),
      payload = coalesce(payload, '{}'::jsonb),
      created_at = coalesce(created_at, now())
  where venue_id is null
     or table_name is null
     or print_type is null
     or status is null
     or total_amount is null
     or payload is null
     or created_at is null;
end
$$;

create index if not exists idx_restaurant_tables_venue_status
  on restaurant.tables (venue_id, status);
create index if not exists idx_restaurant_checks_table_status
  on restaurant.checks (table_id, status);
create index if not exists idx_restaurant_logs_table_created
  on restaurant.operation_logs (table_id, created_at desc);
create index if not exists idx_restaurant_print_logs_venue_created
  on restaurant.print_logs (venue_id, created_at desc);

create or replace function restaurant.create_operation_log(
  p_venue_id text,
  p_table_id text,
  p_operation_key text,
  p_type text,
  p_title text,
  p_description text,
  p_status restaurant.restaurant_log_status,
  p_severity restaurant.restaurant_log_severity,
  p_actor_name text,
  p_client_mutation_id text,
  p_payload jsonb
)
returns text
language plpgsql
security definer
as $$
declare
  v_log_id text;
begin
  insert into restaurant.operation_logs (
    venue_id,
    table_id,
    operation_key,
    type,
    title,
    description,
    status,
    severity,
    actor_name,
    client_mutation_id,
    payload
  )
  values (
    p_venue_id,
    p_table_id,
    p_operation_key,
    p_type,
    p_title,
    p_description,
    p_status,
    p_severity,
    p_actor_name,
    p_client_mutation_id,
    coalesce(p_payload, '{}'::jsonb)
  )
  returning id into v_log_id;

  return v_log_id;
end;
$$;

create or replace function restaurant.create_print_job(
  p_venue_id text,
  p_table_id text,
  p_table_name text,
  p_check_id text,
  p_order_reference text,
  p_print_type restaurant.restaurant_print_type,
  p_printer_target text,
  p_requested_by text,
  p_payload jsonb,
  p_total_amount numeric,
  p_status restaurant.restaurant_print_job_status default 'pending'
)
returns text
language plpgsql
security definer
as $$
declare
  v_print_id text;
begin
  insert into restaurant.print_logs (
    venue_id,
    table_id,
    table_name,
    check_id,
    order_reference,
    print_type,
    printer_target,
    requested_by,
    status,
    total_amount,
    payload,
    created_at
  )
  values (
    p_venue_id,
    p_table_id,
    p_table_name,
    p_check_id,
    p_order_reference,
    p_print_type,
    p_printer_target,
    p_requested_by,
    p_status,
    coalesce(p_total_amount, 0),
    coalesce(p_payload, '{}'::jsonb),
    now()
  )
  returning id into v_print_id;

  return v_print_id;
end;
$$;

create or replace function restaurant.assert_table_revision(
  p_table_id text,
  p_expected_revision bigint
)
returns restaurant.tables
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
begin
  select *
  into v_table
  from restaurant.tables
  where id = p_table_id
  for update;

  if not found then
    raise exception 'TABLE_NOT_FOUND';
  end if;

  if v_table.revision <> p_expected_revision then
    raise exception 'TABLE_VERSION_CONFLICT';
  end if;

  return v_table;
end;
$$;

create or replace function restaurant.compute_table_status(
  p_table_id text
)
returns restaurant.restaurant_table_status
language plpgsql
security definer
as $$
begin
  if not exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
  )
  and not exists (
    select 1
    from restaurant.draft_items di
    join restaurant.table_drafts td on td.id = di.draft_id
    where td.table_id = p_table_id
  )
  and not exists (
    select 1
    from restaurant.partial_payments
    where table_id = p_table_id
  ) then
    return 'empty';
  end if;

  if exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
  )
  and not exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
      and status <> 'completed'
  ) then
    return 'completed';
  end if;

  if exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
      and status = 'payment_pending'
  ) then
    return 'payment_pending';
  end if;

  if exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
      and status = 'served'
  ) then
    return 'served';
  end if;

  if exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
      and status = 'ready'
  ) then
    return 'ready';
  end if;

  if exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
      and status = 'preparing'
  ) then
    return 'preparing';
  end if;

  if exists (
    select 1
    from restaurant.checks
    where table_id = p_table_id
      and status = 'kitchen_sent'
  ) then
    return 'kitchen_sent';
  end if;

  if exists (
    select 1
    from restaurant.draft_items di
    join restaurant.table_drafts td on td.id = di.draft_id
    where td.table_id = p_table_id
  ) then
    return 'active';
  end if;

  return 'active';
end;
$$;

create or replace function restaurant.refresh_check_total(
  p_check_id text
)
returns numeric
language plpgsql
security definer
as $$
declare
  v_total numeric(12,2);
begin
  select coalesce(sum(total_price), 0)
  into v_total
  from restaurant.check_items
  where check_id = p_check_id;

  update restaurant.checks
  set total_amount = v_total,
      updated_at = now()
  where id = p_check_id;

  return v_total;
end;
$$;

create or replace function restaurant.replace_draft_items(
  p_table_id text,
  p_expected_revision bigint,
  p_editing_check_id text,
  p_items jsonb,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_draft restaurant.table_drafts%rowtype;
  v_item jsonb;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  insert into restaurant.table_drafts (table_id, editing_check_id, updated_at, revision)
  values (p_table_id, p_editing_check_id, now(), 0)
  on conflict (table_id) do update
    set editing_check_id = excluded.editing_check_id,
        updated_at = now()
  returning * into v_draft;

  delete from restaurant.draft_items where draft_id = v_draft.id;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    insert into restaurant.draft_items (
      id,
      draft_id,
      product_id,
      name,
      kind,
      quantity,
      unit_price,
      total_price,
      status,
      customizations_payload,
      service_payload,
      created_at,
      updated_at,
      revision
    )
    values (
      coalesce(v_item->>'id', gen_random_uuid()::text),
      v_draft.id,
      coalesce(v_item->>'productId', ''),
      coalesce(v_item->>'name', ''),
      coalesce(v_item->>'kind', 'standard'),
      coalesce((v_item->>'quantity')::numeric, 1),
      coalesce((v_item->>'unitPrice')::numeric, 0),
      coalesce((v_item->>'totalPrice')::numeric, 0),
      'draft',
      coalesce(v_item->'customizations', '{}'::jsonb),
      v_item->'service',
      coalesce((v_item->>'createdAt')::timestamptz, now()),
      now(),
      0
    );
  end loop;

  update restaurant.table_drafts
  set updated_at = now(),
      revision = revision + 1
  where id = v_draft.id;

  update restaurant.tables
  set last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now(),
      status = case
        when coalesce(jsonb_array_length(p_items), 0) > 0 then 'active'
        when status = 'completed' then 'completed'
        else status
      end
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'replace_draft_items',
    'replace_draft_items',
    'Taslak senkronize edildi',
    'Yerel draft backend workspace ile hizalandi.',
    'committed',
    'info',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('editing_check_id', p_editing_check_id, 'item_count', coalesce(jsonb_array_length(p_items), 0))
  );

  return jsonb_build_object(
    'operation_log_ids', jsonb_build_array(v_log_id),
    'table_id', p_table_id
  );
end;
$$;

create or replace function restaurant.upsert_check_from_draft(
  p_table_id text,
  p_expected_revision bigint,
  p_editing_check_id text,
  p_items jsonb,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_draft restaurant.table_drafts%rowtype;
  v_check_id text;
  v_log_id text;
  v_print_id text;
  v_item jsonb;
  v_total numeric(12,2);
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  insert into restaurant.table_drafts (table_id, editing_check_id, updated_at, revision)
  values (p_table_id, p_editing_check_id, now(), 0)
  on conflict (table_id) do update
    set editing_check_id = excluded.editing_check_id,
        updated_at = now()
  returning * into v_draft;

  delete from restaurant.draft_items where draft_id = v_draft.id;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    insert into restaurant.draft_items (
      id, draft_id, product_id, name, kind, quantity, unit_price, total_price,
      status, customizations_payload, service_payload, created_at, updated_at, revision
    )
    values (
      coalesce(v_item->>'id', gen_random_uuid()::text),
      v_draft.id,
      coalesce(v_item->>'productId', ''),
      coalesce(v_item->>'name', ''),
      coalesce(v_item->>'kind', 'standard'),
      coalesce((v_item->>'quantity')::numeric, 1),
      coalesce((v_item->>'unitPrice')::numeric, 0),
      coalesce((v_item->>'totalPrice')::numeric, 0),
      'draft',
      coalesce(v_item->'customizations', '{}'::jsonb),
      v_item->'service',
      coalesce((v_item->>'createdAt')::timestamptz, now()),
      now(),
      0
    );
  end loop;

  v_check_id := coalesce(p_editing_check_id, gen_random_uuid()::text);

  insert into restaurant.checks (
    id, table_id, label, status, source, total_amount, created_at, updated_at, revision
  )
  values (
    v_check_id,
    p_table_id,
    case when p_editing_check_id is null then 'Yeni Fis' else 'Guncellenen Fis' end,
    'kitchen_sent',
    'waiter',
    0,
    now(),
    now(),
    0
  )
  on conflict (id) do update
    set status = 'kitchen_sent',
        updated_at = now(),
        revision = restaurant.checks.revision + 1;

  delete from restaurant.check_items where check_id = v_check_id;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    insert into restaurant.check_items (
      id, check_id, product_id, name, kind, quantity, unit_price, total_price,
      status, customizations_payload, service_payload, created_at, updated_at, revision
    )
    values (
      coalesce(v_item->>'id', gen_random_uuid()::text),
      v_check_id,
      coalesce(v_item->>'productId', ''),
      coalesce(v_item->>'name', ''),
      coalesce(v_item->>'kind', 'standard'),
      coalesce((v_item->>'quantity')::numeric, 1),
      coalesce((v_item->>'unitPrice')::numeric, 0),
      coalesce((v_item->>'totalPrice')::numeric, 0),
      'kitchen_sent',
      coalesce(v_item->'customizations', '{}'::jsonb),
      v_item->'service',
      coalesce((v_item->>'createdAt')::timestamptz, now()),
      now(),
      0
    );
  end loop;

  select coalesce(sum(total_price), 0)
  into v_total
  from restaurant.check_items
  where check_id = v_check_id;

  update restaurant.checks
  set total_amount = v_total,
      updated_at = now()
  where id = v_check_id;

  delete from restaurant.draft_items where draft_id = v_draft.id;
  update restaurant.table_drafts
  set editing_check_id = null,
      updated_at = now(),
      revision = revision + 1
  where id = v_draft.id;

  update restaurant.tables
  set status = 'kitchen_sent',
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_print_id := restaurant.create_print_job(
    v_table.venue_id,
    p_table_id,
    v_table.name,
    v_check_id,
    case when p_editing_check_id is null then 'Yeni Fis' else 'Guncellenen Fis' end,
    'adisyon',
    'Kasa Adisyon Yazicisi',
    p_actor_name,
    jsonb_build_object(
      'source', 'auto_on_submit',
      'items', coalesce(p_items, '[]'::jsonb)
    ),
    v_total
  );

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'upsert_check_from_draft',
    'upsert_check_from_draft',
    case when p_editing_check_id is null then 'Siparis gonderildi' else 'Siparis guncellendi' end,
    'Taslak tek transaction icinde fis haline getirildi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object(
      'check_id', v_check_id,
      'item_count', coalesce(jsonb_array_length(p_items), 0),
      'print_job_id', v_print_id
    )
  );

  return jsonb_build_object(
    'check_id', v_check_id,
    'operation_log_ids', jsonb_build_array(v_log_id)
  );
end;
$$;

create or replace function restaurant.advance_check_status(
  p_table_id text,
  p_check_id text,
  p_expected_revision bigint,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_check restaurant.checks%rowtype;
  v_next_status restaurant.restaurant_check_status;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  select * into v_check
  from restaurant.checks
  where id = p_check_id and table_id = p_table_id
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  v_next_status := case v_check.status
    when 'draft' then 'kitchen_sent'
    when 'kitchen_sent' then 'preparing'
    when 'preparing' then 'ready'
    when 'ready' then 'served'
    when 'served' then 'payment_pending'
    when 'payment_pending' then 'completed'
    else 'completed'
  end;

  update restaurant.checks
  set status = v_next_status,
      updated_at = now(),
      revision = revision + 1
  where id = v_check.id;

  update restaurant.check_items
  set status = v_next_status,
      updated_at = now(),
      revision = revision + 1
  where check_id = v_check.id;

  update restaurant.tables
  set status = case
        when v_next_status = 'completed' then 'completed'
        when v_next_status = 'payment_pending' then 'payment_pending'
        else v_next_status::text::restaurant.restaurant_table_status
      end,
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'advance_check_status',
    'advance_check_status',
    'Siparis durumu ilerletildi',
    'Siparis bir sonraki operasyon adimina ilerledi.',
    'committed',
    'info',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('check_id', p_check_id, 'next_status', v_next_status)
  );

  return jsonb_build_object('operation_log_ids', jsonb_build_array(v_log_id));
end;
$$;

create or replace function restaurant.update_check_item(
  p_table_id text,
  p_check_id text,
  p_item_id text,
  p_expected_revision bigint,
  p_updates jsonb,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_check restaurant.checks%rowtype;
  v_item restaurant.check_items%rowtype;
  v_quantity numeric(12,3);
  v_unit_price numeric(12,2);
  v_total_price numeric(12,2);
  v_customizations jsonb;
  v_service jsonb;
  v_grams numeric(12,3);
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  select * into v_check
  from restaurant.checks
  where id = p_check_id and table_id = p_table_id
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  select * into v_item
  from restaurant.check_items
  where id = p_item_id and check_id = p_check_id
  for update;

  if not found then
    raise exception 'ORDER_ITEM_NOT_FOUND';
  end if;

  v_quantity := coalesce((p_updates->>'quantity')::numeric, v_item.quantity);
  v_unit_price := coalesce((p_updates->>'unitPrice')::numeric, v_item.unit_price);
  v_customizations := coalesce(p_updates->'customizations', v_item.customizations_payload, '{}'::jsonb);
  v_service := coalesce(p_updates->'service', v_item.service_payload);
  v_grams := nullif(v_customizations->>'grams', '')::numeric;

  if v_quantity <= 0 then
    raise exception 'INVALID_ITEM_QUANTITY';
  end if;

  v_total_price := coalesce(
    (p_updates->>'totalPrice')::numeric,
    case
      when coalesce(p_updates->>'kind', v_item.kind) = 'service' then coalesce((
        select round(coalesce(sum((child->>'totalPrice')::numeric), 0)::numeric, 2)
        from jsonb_array_elements(coalesce(v_service->'items', '[]'::jsonb)) as child
      ), v_item.total_price)
      when coalesce(p_updates->>'kind', v_item.kind) = 'weighted' and v_grams is not null then round((v_unit_price * (v_grams / 1000) * v_quantity)::numeric, 2)
      else round((v_unit_price * v_quantity)::numeric, 2)
    end
  );

  update restaurant.check_items
  set name = coalesce(p_updates->>'name', v_item.name),
      kind = coalesce(p_updates->>'kind', v_item.kind),
      quantity = v_quantity,
      unit_price = v_unit_price,
      total_price = v_total_price,
      customizations_payload = v_customizations,
      service_payload = v_service,
      updated_at = now(),
      revision = revision + 1
  where id = p_item_id;

  perform restaurant.refresh_check_total(p_check_id);

  update restaurant.tables
  set status = restaurant.compute_table_status(p_table_id),
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'update_check_item',
    'update_check_item',
    'Aktif siparis satiri guncellendi',
    'Secili siparis satiri transaction icinde guncellendi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('check_id', p_check_id, 'item_id', p_item_id)
  );

  return jsonb_build_object('operation_log_ids', jsonb_build_array(v_log_id));
end;
$$;

create or replace function restaurant.remove_check_item(
  p_table_id text,
  p_check_id text,
  p_item_id text,
  p_expected_revision bigint,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  if not exists (
    select 1
    from restaurant.checks
    where id = p_check_id and table_id = p_table_id
    for update
  ) then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  delete from restaurant.check_items
  where id = p_item_id
    and check_id = p_check_id;

  if not found then
    raise exception 'ORDER_ITEM_NOT_FOUND';
  end if;

  if exists (
    select 1
    from restaurant.check_items
    where check_id = p_check_id
  ) then
    perform restaurant.refresh_check_total(p_check_id);
  else
    delete from restaurant.checks where id = p_check_id;
  end if;

  update restaurant.tables
  set status = restaurant.compute_table_status(p_table_id),
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'remove_check_item',
    'remove_check_item',
    'Aktif siparis satiri silindi',
    'Secili siparis satiri transaction icinde kaldirildi.',
    'committed',
    'warning',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('check_id', p_check_id, 'item_id', p_item_id)
  );

  return jsonb_build_object('operation_log_ids', jsonb_build_array(v_log_id));
end;
$$;

create or replace function restaurant.move_check_items(
  p_source_table_id text,
  p_target_table_id text,
  p_item_ids text[],
  p_expected_source_revision bigint,
  p_expected_target_revision bigint,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_source restaurant.tables%rowtype;
  v_target restaurant.tables%rowtype;
  v_target_draft restaurant.table_drafts%rowtype;
  v_item record;
  v_source_log text;
  v_target_log text;
  v_affected_check_id text;
  v_moved_count integer := 0;
begin
  if p_source_table_id = p_target_table_id then
    raise exception 'INVALID_TRANSFER';
  end if;

  if coalesce(array_length(p_item_ids, 1), 0) = 0 then
    raise exception 'MOVE_ITEMS_EMPTY';
  end if;

  if p_source_table_id < p_target_table_id then
    v_source := restaurant.assert_table_revision(p_source_table_id, p_expected_source_revision);
    v_target := restaurant.assert_table_revision(p_target_table_id, p_expected_target_revision);
  else
    v_target := restaurant.assert_table_revision(p_target_table_id, p_expected_target_revision);
    v_source := restaurant.assert_table_revision(p_source_table_id, p_expected_source_revision);
  end if;

  insert into restaurant.table_drafts (table_id, updated_at, revision)
  values (p_target_table_id, now(), 0)
  on conflict (table_id) do update set updated_at = now()
  returning * into v_target_draft;

  for v_item in
    select ci.*
    from restaurant.check_items ci
    join restaurant.checks c on c.id = ci.check_id
    where c.table_id = p_source_table_id
      and ci.id = any(p_item_ids)
    for update
  loop
    insert into restaurant.draft_items (
      id,
      draft_id,
      product_id,
      name,
      kind,
      quantity,
      unit_price,
      total_price,
      status,
      customizations_payload,
      service_payload,
      created_at,
      updated_at,
      revision
    )
    values (
      v_item.id,
      v_target_draft.id,
      v_item.product_id,
      v_item.name,
      v_item.kind,
      v_item.quantity,
      v_item.unit_price,
      v_item.total_price,
      'draft',
      coalesce(v_item.customizations_payload, '{}'::jsonb),
      v_item.service_payload,
      v_item.created_at,
      now(),
      0
    )
    on conflict (id) do update
      set draft_id = excluded.draft_id,
          quantity = excluded.quantity,
          unit_price = excluded.unit_price,
          total_price = excluded.total_price,
          customizations_payload = excluded.customizations_payload,
          service_payload = excluded.service_payload,
          updated_at = now(),
          revision = restaurant.draft_items.revision + 1;

    v_affected_check_id := v_item.check_id;
    v_moved_count := v_moved_count + 1;

    delete from restaurant.check_items
    where id = v_item.id;
  end loop;

  if v_moved_count = 0 then
    raise exception 'MOVE_ITEMS_EMPTY';
  end if;

  for v_affected_check_id in
    select distinct c.id
    from restaurant.checks c
    where c.table_id = p_source_table_id
  loop
    if exists (
      select 1
      from restaurant.check_items
      where check_id = v_affected_check_id
    ) then
      perform restaurant.refresh_check_total(v_affected_check_id);
    else
      delete from restaurant.checks where id = v_affected_check_id;
    end if;
  end loop;

  update restaurant.table_drafts
  set updated_at = now(),
      revision = revision + 1
  where id = v_target_draft.id;

  update restaurant.tables
  set status = restaurant.compute_table_status(p_source_table_id),
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_source_table_id;

  update restaurant.tables
  set status = restaurant.compute_table_status(p_target_table_id),
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_target_table_id;

  v_source_log := restaurant.create_operation_log(
    v_source.venue_id,
    p_source_table_id,
    'move_check_items_source',
    'move_check_items',
    'Hareket aktarildi',
    'Secili siparis satirlari diger masaya tasindi.',
    'committed',
    'warning',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('target_table_id', p_target_table_id, 'item_ids', p_item_ids)
  );

  v_target_log := restaurant.create_operation_log(
    v_target.venue_id,
    p_target_table_id,
    'move_check_items_target',
    'move_check_items',
    'Aktarilan hareketler taslaga alindi',
    'Gelen siparis satirlari hedef masa taslagina eklendi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('source_table_id', p_source_table_id, 'item_ids', p_item_ids)
  );

  return jsonb_build_object(
    'operation_log_ids', jsonb_build_array(v_source_log, v_target_log)
  );
end;
$$;

create or replace function restaurant.take_partial_payment(
  p_table_id text,
  p_expected_revision bigint,
  p_amount numeric,
  p_method restaurant.restaurant_payment_method,
  p_kind text,
  p_note text,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_open_total numeric(12,2);
  v_paid_total numeric(12,2);
  v_remaining numeric(12,2);
  v_after_payment numeric(12,2);
  v_payment_id text;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  select coalesce(sum(total_amount), 0)
  into v_open_total
  from restaurant.checks
  where table_id = p_table_id
    and status <> 'completed';

  select coalesce(sum(amount), 0)
  into v_paid_total
  from restaurant.partial_payments
  where table_id = p_table_id;

  v_remaining := greatest(v_open_total - v_paid_total, 0);

  if p_amount <= 0 then
    raise exception 'INVALID_PAYMENT_AMOUNT';
  end if;

  if p_amount > v_remaining then
    raise exception 'PAYMENT_EXCEEDS_BALANCE';
  end if;

  v_after_payment := greatest(v_remaining - p_amount, 0);

  insert into restaurant.partial_payments (
    table_id, amount, method, kind, note, remaining_after_payment, revision
  )
  values (
    p_table_id, p_amount, p_method, p_kind, p_note, v_after_payment, 0
  )
  returning id into v_payment_id;

  if p_kind = 'closing' or v_after_payment = 0 then
    update restaurant.checks
    set status = 'completed',
        updated_at = now(),
        revision = revision + 1
    where table_id = p_table_id
      and status <> 'completed';

    update restaurant.check_items
    set status = 'completed',
        updated_at = now(),
        revision = revision + 1
    where check_id in (
      select id from restaurant.checks where table_id = p_table_id
    );
  else
    update restaurant.checks
    set status = 'payment_pending',
        updated_at = now(),
        revision = revision + 1
    where table_id = p_table_id
      and status in ('served', 'ready', 'preparing', 'kitchen_sent');
  end if;

  update restaurant.tables
  set status = case
        when v_after_payment = 0 then 'completed'
        else 'payment_pending'
      end,
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'take_partial_payment',
    'take_partial_payment',
    case when p_kind = 'closing' or v_after_payment = 0 then 'Hesap kapatildi' else 'Ara odeme alindi' end,
    'Odeme transaction icinde kaydedildi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('payment_id', v_payment_id, 'remaining_after_payment', v_after_payment)
  );

  return jsonb_build_object(
    'payment_id', v_payment_id,
    'remaining_after_payment', v_after_payment,
    'operation_log_ids', jsonb_build_array(v_log_id)
  );
end;
$$;

create or replace function restaurant.create_split_plan(
  p_table_id text,
  p_expected_revision bigint,
  p_mode restaurant.restaurant_split_mode,
  p_parts jsonb,
  p_note text,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_plan_id text;
  v_part jsonb;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  insert into restaurant.split_plans (table_id, mode, note, revision)
  values (p_table_id, p_mode, p_note, 0)
  returning id into v_plan_id;

  for v_part in
    select value from jsonb_array_elements(coalesce(p_parts, '[]'::jsonb))
  loop
    insert into restaurant.split_plan_parts (
      id, split_plan_id, label, amount, line_item_ids
    )
    values (
      coalesce(v_part->>'id', gen_random_uuid()::text),
      v_plan_id,
      coalesce(v_part->>'label', 'Parca'),
      coalesce((v_part->>'amount')::numeric, 0),
      coalesce(array(select jsonb_array_elements_text(coalesce(v_part->'lineItemIds', '[]'::jsonb))), '{}')
    );
  end loop;

  update restaurant.tables
  set last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'create_split_plan',
    'create_split_plan',
    'Fis bolme plani olusturuldu',
    'Bolunmus odeme plani kaydedildi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('split_plan_id', v_plan_id)
  );

  return jsonb_build_object('split_plan_id', v_plan_id, 'operation_log_ids', jsonb_build_array(v_log_id));
end;
$$;

create or replace function restaurant.assign_customer(
  p_table_id text,
  p_expected_revision bigint,
  p_customer_id text,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  update restaurant.tables
  set current_customer_id = p_customer_id,
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'assign_customer',
    'assign_customer',
    'Musteri baglantisi guncellendi',
    'Masa uzerindeki musteri baglantisi degisti.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('customer_id', p_customer_id)
  );

  return jsonb_build_object('operation_log_ids', jsonb_build_array(v_log_id));
end;
$$;

create or replace function restaurant.create_customer_and_assign(
  p_table_id text,
  p_expected_revision bigint,
  p_customer_payload jsonb,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_customer_id text;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  insert into restaurant.customers (
    venue_id,
    name,
    phone,
    company,
    loyalty_tier,
    favorite_product_ids,
    notes,
    visit_count,
    average_spend,
    last_visit_at,
    revision
  )
  values (
    v_table.venue_id,
    coalesce(p_customer_payload->>'name', ''),
    coalesce(p_customer_payload->>'phone', ''),
    p_customer_payload->>'company',
    coalesce(p_customer_payload->>'loyaltyTier', 'Yeni'),
    '{}',
    '{}',
    1,
    0,
    now(),
    0
  )
  returning id into v_customer_id;

  update restaurant.tables
  set current_customer_id = v_customer_id,
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'create_customer_and_assign',
    'create_customer_and_assign',
    'Yeni musteri olusturuldu',
    'Yeni musteri transaction icinde olusturulup masaya baglandi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('customer_id', v_customer_id)
  );

  return jsonb_build_object(
    'customer_id', v_customer_id,
    'operation_log_ids', jsonb_build_array(v_log_id)
  );
end;
$$;

create or replace function restaurant.register_print_log(
  p_table_id text,
  p_expected_revision bigint,
  p_print_type text,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_check restaurant.checks%rowtype;
  v_log_id text;
  v_print_id text;
  v_total numeric(12,2);
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  select *
  into v_check
  from restaurant.checks
  where table_id = p_table_id
  order by updated_at desc
  limit 1;

  v_total := coalesce(v_check.total_amount, 0);

  v_print_id := restaurant.create_print_job(
    v_table.venue_id,
    p_table_id,
    v_table.name,
    v_check.id,
    v_check.label,
    p_print_type::restaurant.restaurant_print_type,
    case
      when p_print_type = 'mutfak' then 'Mutfak Yazicisi'
      else 'Kasa Adisyon Yazicisi'
    end,
    p_actor_name,
    jsonb_build_object(
      'source', 'manual_action',
      'items', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'name', ci.name,
            'quantity', ci.quantity,
            'totalPrice', ci.total_price
          )
        )
        from restaurant.check_items ci
        where ci.check_id = v_check.id
      ), '[]'::jsonb)
    ),
    v_total
  );

  update restaurant.tables
  set last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'register_print_log',
    'register_print_log',
    'Yazdirma kaydi acildi',
    'Adisyon veya mutfak cikti istegi kuyruga alindi.',
    'committed',
    'info',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('print_id', v_print_id, 'print_type', p_print_type)
  );

  return jsonb_build_object(
    'print_id', v_print_id,
    'operation_log_ids', jsonb_build_array(v_log_id)
  );
end;
$$;

create or replace function restaurant.reset_table_for_new_bill(
  p_table_id text,
  p_expected_revision bigint,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_table restaurant.tables%rowtype;
  v_draft_id text;
  v_log_id text;
begin
  v_table := restaurant.assert_table_revision(p_table_id, p_expected_revision);

  select id into v_draft_id
  from restaurant.table_drafts
  where table_id = p_table_id;

  if v_draft_id is not null then
    delete from restaurant.draft_items where draft_id = v_draft_id;
    update restaurant.table_drafts
    set editing_check_id = null,
        updated_at = now(),
        revision = revision + 1
    where id = v_draft_id;
  end if;

  delete from restaurant.check_items
  where check_id in (select id from restaurant.checks where table_id = p_table_id);
  delete from restaurant.checks where table_id = p_table_id;
  delete from restaurant.partial_payments where table_id = p_table_id;
  delete from restaurant.split_plan_parts
  where split_plan_id in (select id from restaurant.split_plans where table_id = p_table_id);
  delete from restaurant.split_plans where table_id = p_table_id;

  update restaurant.tables
  set guest_count = 0,
      current_customer_id = null,
      reference_code = null,
      barcode = null,
      timed_billing_enabled = false,
      timed_billing_started_at = null,
      timed_billing_rate_per_hour = null,
      status = 'empty',
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_table_id;

  v_log_id := restaurant.create_operation_log(
    v_table.venue_id,
    p_table_id,
    'reset_table_for_new_bill',
    'reset_table_for_new_bill',
    'Yeni fis acildi',
    'Masa mevcut operasyon verisinden temizlendi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    '{}'::jsonb
  );

  return jsonb_build_object('operation_log_ids', jsonb_build_array(v_log_id));
end;
$$;

create or replace function restaurant.transfer_table(
  p_source_table_id text,
  p_target_table_id text,
  p_expected_source_revision bigint,
  p_expected_target_revision bigint,
  p_mode text,
  p_client_mutation_id text,
  p_actor_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_source restaurant.tables%rowtype;
  v_target restaurant.tables%rowtype;
  v_source_draft restaurant.table_drafts%rowtype;
  v_target_draft restaurant.table_drafts%rowtype;
  v_source_log text;
  v_target_log text;
begin
  if p_source_table_id = p_target_table_id then
    raise exception 'INVALID_TRANSFER';
  end if;

  if p_mode = 'all' and (
    exists (
      select 1
      from restaurant.checks
      where table_id = p_target_table_id
        and status <> 'completed'
    )
    or exists (
      select 1
      from restaurant.draft_items di
      join restaurant.table_drafts td on td.id = di.draft_id
      where td.table_id = p_target_table_id
    )
  ) then
    raise exception 'TARGET_OCCUPIED';
  end if;

  if p_source_table_id < p_target_table_id then
    v_source := restaurant.assert_table_revision(p_source_table_id, p_expected_source_revision);
    v_target := restaurant.assert_table_revision(p_target_table_id, p_expected_target_revision);
  else
    v_target := restaurant.assert_table_revision(p_target_table_id, p_expected_target_revision);
    v_source := restaurant.assert_table_revision(p_source_table_id, p_expected_source_revision);
  end if;

  insert into restaurant.table_drafts (table_id, updated_at, revision)
  values (p_source_table_id, now(), 0)
  on conflict (table_id) do update set updated_at = now()
  returning * into v_source_draft;

  insert into restaurant.table_drafts (table_id, updated_at, revision)
  values (p_target_table_id, now(), 0)
  on conflict (table_id) do update set updated_at = now()
  returning * into v_target_draft;

  if p_mode = 'draft-only' then
    update restaurant.draft_items
    set draft_id = v_target_draft.id,
        updated_at = now(),
        revision = revision + 1
    where draft_id = v_source_draft.id;
  elsif p_mode = 'merge' then
    update restaurant.checks
    set table_id = p_target_table_id,
        updated_at = now(),
        revision = revision + 1
    where table_id = p_source_table_id;

    update restaurant.partial_payments
    set table_id = p_target_table_id,
        revision = revision + 1
    where table_id = p_source_table_id;

    update restaurant.split_plans
    set table_id = p_target_table_id,
        revision = revision + 1
    where table_id = p_source_table_id;

    update restaurant.draft_items
    set draft_id = v_target_draft.id,
        updated_at = now(),
        revision = revision + 1
    where draft_id = v_source_draft.id;
  else
    update restaurant.checks
    set table_id = p_target_table_id,
        updated_at = now(),
        revision = revision + 1
    where table_id = p_source_table_id;

    update restaurant.partial_payments
    set table_id = p_target_table_id,
        revision = revision + 1
    where table_id = p_source_table_id;

    update restaurant.split_plans
    set table_id = p_target_table_id,
        revision = revision + 1
    where table_id = p_source_table_id;

    update restaurant.draft_items
    set draft_id = v_target_draft.id,
        updated_at = now(),
        revision = revision + 1
    where draft_id = v_source_draft.id;
  end if;

  update restaurant.table_drafts
  set editing_check_id = v_source_draft.editing_check_id,
      updated_at = now(),
      revision = revision + 1
  where id = v_target_draft.id
    and editing_check_id is null
    and v_source_draft.editing_check_id is not null;

  update restaurant.table_drafts
  set editing_check_id = null,
      updated_at = now(),
      revision = revision + 1
  where id = v_source_draft.id;

  update restaurant.tables
  set guest_count = case
        when p_mode in ('all', 'merge') then coalesce(v_target.guest_count, 0) + coalesce(v_source.guest_count, 0)
        else guest_count
      end,
      current_customer_id = coalesce(current_customer_id, v_source.current_customer_id),
      reference_code = coalesce(reference_code, v_source.reference_code),
      barcode = coalesce(barcode, v_source.barcode),
      status = restaurant.compute_table_status(p_target_table_id),
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_target_table_id;

  update restaurant.tables
  set guest_count = case when p_mode = 'draft-only' then guest_count else 0 end,
      current_customer_id = case when p_mode = 'draft-only' then current_customer_id else null end,
      status = restaurant.compute_table_status(p_source_table_id),
      reference_code = case when p_mode = 'draft-only' then reference_code else null end,
      barcode = case when p_mode = 'draft-only' then barcode else null end,
      last_action_at = now(),
      updated_by = p_actor_name,
      revision = revision + 1,
      updated_at = now()
  where id = p_source_table_id;

  v_source_log := restaurant.create_operation_log(
    v_source.venue_id,
    p_source_table_id,
    'transfer_table_source',
    'transfer_table',
    'Masa aktarildi',
    'Kaynak masa verisi hedef masaya tasindi.',
    'committed',
    'warning',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('mode', p_mode, 'target_table_id', p_target_table_id)
  );

  v_target_log := restaurant.create_operation_log(
    v_target.venue_id,
    p_target_table_id,
    'transfer_table_target',
    'transfer_table',
    'Masa aktarimi tamamlandi',
    'Hedef masa kaynak masadan veri aldi.',
    'committed',
    'success',
    p_actor_name,
    p_client_mutation_id,
    jsonb_build_object('mode', p_mode, 'source_table_id', p_source_table_id)
  );

  return jsonb_build_object(
    'operation_log_ids', jsonb_build_array(v_source_log, v_target_log)
  );
end;
$$;
