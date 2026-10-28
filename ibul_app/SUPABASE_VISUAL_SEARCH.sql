-- Kamera ile Keşfet / görsel arama iskeleti.
-- Uygulama önce yerel kayda yazar; giriş yapmış kullanıcıda bu tablolara da yazar.
-- Analiz modeli bağlanana kadar istemci mock sonuç üretir ve aynı JSON sözleşmesini doldurur.

create extension if not exists pgcrypto;

create table if not exists public.visual_search_jobs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text,
  file_name text,
  job_type text not null check (
    job_type in (
      'visual_search',
      'damage_analysis',
      'missing_parts_analysis',
      'combined'
    )
  ),
  status text not null default 'pending' check (
    status in ('pending', 'processing', 'completed', 'failed')
  ),
  analysis_result_json jsonb,
  error_message text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.damage_reports (
  id uuid primary key,
  job_id uuid not null references public.visual_search_jobs(id) on delete cascade,
  label text not null,
  confidence numeric not null default 0,
  bbox_json jsonb not null default '{}'::jsonb,
  description text
);

create table if not exists public.missing_parts_reports (
  id uuid primary key,
  job_id uuid not null references public.visual_search_jobs(id) on delete cascade,
  part_name text not null,
  confidence numeric not null default 0,
  bbox_json jsonb not null default '{}'::jsonb,
  details text
);

create table if not exists public.product_matches (
  id uuid primary key,
  job_id uuid not null references public.visual_search_jobs(id) on delete cascade,
  product_id text,
  similarity_score numeric not null default 0,
  match_type text not null check (
    match_type in ('exact', 'similar', 'alternative')
  ),
  metadata_json jsonb not null default '{}'::jsonb
);

create table if not exists public.visual_search_history (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null unique references public.visual_search_jobs(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_visual_feedback (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.visual_search_jobs(id) on delete cascade,
  feedback_type text not null,
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

-- İleride pgvector ile değiştirilebilir. Şimdilik istemci erişimi yok.
create table if not exists public.product_visual_embeddings (
  product_id text primary key,
  embedding double precision[] not null default '{}',
  model text not null default 'pending',
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_visual_search_jobs_user_created
  on public.visual_search_jobs (user_id, created_at desc);

create index if not exists idx_visual_search_jobs_type
  on public.visual_search_jobs (user_id, job_type);

create index if not exists idx_damage_reports_job
  on public.damage_reports (job_id);

create index if not exists idx_missing_parts_reports_job
  on public.missing_parts_reports (job_id);

create index if not exists idx_product_matches_job
  on public.product_matches (job_id);

create index if not exists idx_visual_search_history_user
  on public.visual_search_history (user_id, created_at desc);

create or replace function public.touch_visual_search_job()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_touch_visual_search_job on public.visual_search_jobs;
create trigger trg_touch_visual_search_job
before update on public.visual_search_jobs
for each row execute function public.touch_visual_search_job();

alter table public.visual_search_jobs enable row level security;
alter table public.damage_reports enable row level security;
alter table public.missing_parts_reports enable row level security;
alter table public.product_matches enable row level security;
alter table public.visual_search_history enable row level security;
alter table public.user_visual_feedback enable row level security;
alter table public.product_visual_embeddings enable row level security;

grant select, insert, update, delete on public.visual_search_jobs to authenticated;
grant select, insert, update, delete on public.damage_reports to authenticated;
grant select, insert, update, delete on public.missing_parts_reports to authenticated;
grant select, insert, update, delete on public.product_matches to authenticated;
grant select, insert, update, delete on public.visual_search_history to authenticated;
grant select, insert, delete on public.user_visual_feedback to authenticated;

drop policy if exists visual_search_jobs_owner on public.visual_search_jobs;
create policy visual_search_jobs_owner
on public.visual_search_jobs
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists damage_reports_owner on public.damage_reports;
create policy damage_reports_owner
on public.damage_reports
for all
to authenticated
using (
  exists (
    select 1 from public.visual_search_jobs j
    where j.id = job_id and j.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.visual_search_jobs j
    where j.id = job_id and j.user_id = auth.uid()
  )
);

drop policy if exists missing_parts_reports_owner on public.missing_parts_reports;
create policy missing_parts_reports_owner
on public.missing_parts_reports
for all
to authenticated
using (
  exists (
    select 1 from public.visual_search_jobs j
    where j.id = job_id and j.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.visual_search_jobs j
    where j.id = job_id and j.user_id = auth.uid()
  )
);

drop policy if exists product_matches_owner on public.product_matches;
create policy product_matches_owner
on public.product_matches
for all
to authenticated
using (
  exists (
    select 1 from public.visual_search_jobs j
    where j.id = job_id and j.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.visual_search_jobs j
    where j.id = job_id and j.user_id = auth.uid()
  )
);

drop policy if exists visual_search_history_owner on public.visual_search_history;
create policy visual_search_history_owner
on public.visual_search_history
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists user_visual_feedback_owner on public.user_visual_feedback;
create policy user_visual_feedback_owner
on public.user_visual_feedback
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'visual-search-uploads',
  'visual-search-uploads',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists visual_search_uploads_owner_select on storage.objects;
create policy visual_search_uploads_owner_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'visual-search-uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists visual_search_uploads_owner_insert on storage.objects;
create policy visual_search_uploads_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'visual-search-uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists visual_search_uploads_owner_update on storage.objects;
create policy visual_search_uploads_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'visual-search-uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'visual-search-uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists visual_search_uploads_owner_delete on storage.objects;
create policy visual_search_uploads_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'visual-search-uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
);
