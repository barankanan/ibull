create table if not exists public.admin_auth_login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users (id) on delete set null,
  email text,
  provider text not null,
  auth_area text not null default 'user',
  status text not null,
  error_code text,
  error_message text,
  platform text not null default 'unknown',
  device_label text,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  attempted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  constraint admin_auth_login_events_provider_check check (
    provider in ('password', 'google')
  ),
  constraint admin_auth_login_events_area_check check (
    auth_area in ('user', 'seller', 'admin', 'unknown')
  ),
  constraint admin_auth_login_events_status_check check (
    status in ('success', 'failed', 'cancelled')
  )
);

create index if not exists idx_admin_auth_login_events_attempted_at
  on public.admin_auth_login_events (attempted_at desc);

create index if not exists idx_admin_auth_login_events_status
  on public.admin_auth_login_events (status, attempted_at desc);

create index if not exists idx_admin_auth_login_events_email
  on public.admin_auth_login_events (lower(email));

create index if not exists idx_admin_auth_login_events_user_id
  on public.admin_auth_login_events (user_id, attempted_at desc);

alter table public.admin_auth_login_events enable row level security;

revoke all on public.admin_auth_login_events from anon, authenticated;
grant select on public.admin_auth_login_events to authenticated;

drop policy if exists "admin_auth_login_events_select" on public.admin_auth_login_events;
create policy "admin_auth_login_events_select"
on public.admin_auth_login_events
for select
to authenticated
using (
  auth.uid() = user_id
  or public.current_admin_has_module('security_logs')
  or public.current_user_role() = 'super_admin'
);

create or replace function public.record_auth_login_attempt(
  p_email text default null,
  p_provider text default 'password',
  p_status text default 'failed',
  p_auth_area text default 'user',
  p_error_code text default null,
  p_error_message text default null,
  p_user_id uuid default null,
  p_platform text default 'unknown',
  p_device_label text default null,
  p_user_agent text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  event_id uuid;
  normalized_provider text := lower(coalesce(nullif(trim(p_provider), ''), 'password'));
  normalized_status text := lower(coalesce(nullif(trim(p_status), ''), 'failed'));
  normalized_area text := lower(coalesce(nullif(trim(p_auth_area), ''), 'unknown'));
  normalized_email text := nullif(lower(trim(coalesce(p_email, ''))), '');
  normalized_platform text := coalesce(nullif(trim(p_platform), ''), 'unknown');
begin
  if normalized_provider not in ('password', 'google') then
    raise exception 'Unsupported auth provider: %', normalized_provider;
  end if;

  if normalized_status not in ('success', 'failed', 'cancelled') then
    raise exception 'Unsupported auth status: %', normalized_status;
  end if;

  if normalized_area not in ('user', 'seller', 'admin', 'unknown') then
    raise exception 'Unsupported auth area: %', normalized_area;
  end if;

  insert into public.admin_auth_login_events (
    user_id,
    email,
    provider,
    auth_area,
    status,
    error_code,
    error_message,
    platform,
    device_label,
    user_agent,
    metadata,
    attempted_at,
    created_at
  )
  values (
    coalesce(p_user_id, auth.uid()),
    normalized_email,
    normalized_provider,
    normalized_area,
    normalized_status,
    nullif(trim(coalesce(p_error_code, '')), ''),
    nullif(trim(coalesce(p_error_message, '')), ''),
    normalized_platform,
    nullif(trim(coalesce(p_device_label, '')), ''),
    nullif(trim(coalesce(p_user_agent, '')), ''),
    coalesce(p_metadata, '{}'::jsonb),
    timezone('utc', now()),
    timezone('utc', now())
  )
  returning id into event_id;

  return event_id;
end;
$$;

revoke all on function public.record_auth_login_attempt(
  text,
  text,
  text,
  text,
  text,
  text,
  uuid,
  text,
  text,
  text,
  jsonb
) from public;

grant execute on function public.record_auth_login_attempt(
  text,
  text,
  text,
  text,
  text,
  text,
  uuid,
  text,
  text,
  text,
  jsonb
) to anon, authenticated;
