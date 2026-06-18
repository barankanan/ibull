-- Customer support extension for support_tickets + messages + attachments
-- Safe to run multiple times on existing SUPABASE_SUPPORT_TICKETS.sql schema.

create extension if not exists pgcrypto;

-- Extend support_tickets
alter table public.support_tickets
  add column if not exists subcategory text,
  add column if not exists user_email text,
  add column if not exists user_phone text,
  add column if not exists contact_preference text default 'in_app',
  add column if not exists related_order_id uuid,
  add column if not exists related_store_id uuid,
  add column if not exists related_product_id uuid,
  add column if not exists related_reference text,
  add column if not exists closed_at timestamptz,
  add column if not exists ticket_number text;

update public.support_tickets
set ticket_number = coalesce(ticket_number, upper(substr(replace(id::text, '-', ''), 1, 8)))
where ticket_number is null;

create unique index if not exists idx_support_tickets_ticket_number
  on public.support_tickets(ticket_number)
  where ticket_number is not null;

-- Drop legacy checks BEFORE normalizing values (reviewing/normal are invalid on old schema)
alter table public.support_tickets drop constraint if exists support_tickets_status_check;
alter table public.support_tickets drop constraint if exists support_tickets_priority_check;

-- Normalize legacy statuses / priorities
update public.support_tickets set status = 'reviewing' where status = 'in_progress';
update public.support_tickets set priority = 'normal' where priority = 'medium';

-- Re-apply expanded status/priority checks
alter table public.support_tickets
  add constraint support_tickets_status_check
  check (status in (
    'open', 'reviewing', 'answered', 'waiting_user',
    'resolved', 'closed', 'rejected'
  ));

alter table public.support_tickets
  add constraint support_tickets_priority_check
  check (priority in ('low', 'normal', 'high'));

alter table public.support_tickets drop constraint if exists support_tickets_contact_preference_check;
alter table public.support_tickets
  add constraint support_tickets_contact_preference_check
  check (contact_preference in ('in_app', 'email', 'phone'));

-- Messages
create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_type text not null,
  sender_id uuid references auth.users(id) on delete set null,
  message text not null,
  created_at timestamptz not null default timezone('utc', now()),
  is_internal_note boolean not null default false,
  constraint support_ticket_messages_sender_type_check
    check (sender_type in ('user', 'admin', 'system'))
);

create index if not exists idx_support_ticket_messages_ticket_id
  on public.support_ticket_messages(ticket_id, created_at asc);

-- Attachments
create table if not exists public.support_ticket_attachments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  message_id uuid references public.support_ticket_messages(id) on delete set null,
  file_url text not null,
  file_name text not null,
  file_type text,
  file_size bigint,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_support_ticket_attachments_ticket_id
  on public.support_ticket_attachments(ticket_id, created_at asc);

-- RLS: messages
alter table public.support_ticket_messages enable row level security;

drop policy if exists "support_ticket_messages_select" on public.support_ticket_messages;
create policy "support_ticket_messages_select"
on public.support_ticket_messages for select to authenticated
using (
  exists (
    select 1 from public.support_tickets t
    where t.id = ticket_id
      and (
        t.user_id = auth.uid()
        or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
        or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
      )
  )
  and (
    is_internal_note = false
    or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
    or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
  )
);

drop policy if exists "support_ticket_messages_insert" on public.support_ticket_messages;
create policy "support_ticket_messages_insert"
on public.support_ticket_messages for insert to authenticated
with check (
  exists (
    select 1 from public.support_tickets t
    where t.id = ticket_id
      and (
        (t.user_id = auth.uid() and sender_type = 'user' and sender_id = auth.uid())
        or (
          (coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
           or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin'))
          and sender_type in ('admin', 'system')
        )
      )
  )
);

-- RLS: attachments
alter table public.support_ticket_attachments enable row level security;

drop policy if exists "support_ticket_attachments_select" on public.support_ticket_attachments;
create policy "support_ticket_attachments_select"
on public.support_ticket_attachments for select to authenticated
using (
  exists (
    select 1 from public.support_tickets t
    where t.id = ticket_id
      and (
        t.user_id = auth.uid()
        or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
        or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
      )
  )
);

drop policy if exists "support_ticket_attachments_insert" on public.support_ticket_attachments;
create policy "support_ticket_attachments_insert"
on public.support_ticket_attachments for insert to authenticated
with check (
  exists (
    select 1 from public.support_tickets t
    where t.id = ticket_id
      and (
        t.user_id = auth.uid()
        or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
        or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
      )
  )
);

-- User can update own ticket when waiting_user (e.g. feedback)
drop policy if exists "support_tickets_update_own_waiting" on public.support_tickets;
create policy "support_tickets_update_own_waiting"
on public.support_tickets for update to authenticated
using (auth.uid() = user_id and status = 'waiting_user')
with check (auth.uid() = user_id);

-- Storage bucket (run in Supabase dashboard if bucket creation via SQL is restricted)
-- insert into storage.buckets (id, name, public) values ('support-attachments', 'support-attachments', true)
-- on conflict do nothing;
