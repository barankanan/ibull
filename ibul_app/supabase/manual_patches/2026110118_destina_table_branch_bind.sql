-- DO NOT APPLY until a named approval is given for this file.
-- Binds Destina's 27 active tables, all currently branch_id NULL, to the one
-- verified active primary branch. Does not delete or rewrite orders.
-- Not in supabase/migrations, so db push does not pick it up.

-- Verified 2026-11-01, read-only:
--   stores.seller_id            7264153b-f493-4508-8402-5fa8cfaabed8  (one name match)
--   store_branches.id           f695479b-6197-4011-af13-c2dc0ab069c3
--   store_id = seller_id, status active, is_primary true, name destina
--   active staff on that branch: 1
--   tables on that branch before: 0
--   active null-branch tables: 27, numbers 1 through 27
-- Column types: store_tables.seller_id uuid, store_tables.branch_id uuid null,
-- store_branches.id uuid, store_branches.store_id uuid.
-- Backup stores md5 of every store_tables column except branch_id and updated_at.
-- Rollback refuses to write if that fingerprint changed. Orders are not part of it.

BEGIN;

DO $$
DECLARE
  v_store uuid := '7264153b-f493-4508-8402-5fa8cfaabed8';
  v_branch uuid := 'f695479b-6197-4011-af13-c2dc0ab069c3';
  v_null integer;
  v_updated integer;
BEGIN
  IF (SELECT count(*) FROM public.stores WHERE seller_id = v_store) <> 1 THEN
    RAISE EXCEPTION 'İşletme kimliği tek satır değil.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.store_branches
    WHERE id = v_branch
      AND store_id = v_store
      AND status = 'active'
      AND is_primary
  ) <> 1 THEN
    RAISE EXCEPTION 'Şube kimliği bu işletmenin aktif birincil şubesi değil.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.store_tables
    WHERE branch_id = v_branch AND seller_id <> v_store
  ) THEN
    RAISE EXCEPTION 'Şube başka işletmenin masasına bağlı.';
  END IF;

  PERFORM 1
  FROM public.store_tables
  WHERE seller_id = v_store
  FOR UPDATE;

  IF (SELECT count(*) FROM public.store_tables WHERE seller_id = v_store) <> 27 THEN
    RAISE EXCEPTION 'Masa sayısı 27 değil.';
  END IF;

  IF (
    SELECT count(DISTINCT table_number)
    FROM public.store_tables
    WHERE seller_id = v_store
  ) <> 27
  OR EXISTS (
    SELECT 1
    FROM public.store_tables
    WHERE seller_id = v_store
      AND table_number NOT BETWEEN 1 AND 27
  ) THEN
    RAISE EXCEPTION 'Masa numaraları 1 ile 27 arasında ve tekil olmak zorunda.';
  END IF;

  SELECT count(*) INTO v_null
  FROM public.store_tables
  WHERE seller_id = v_store
    AND is_active
    AND branch_id IS NULL
    AND table_number BETWEEN 1 AND 27;

  IF v_null <> 27 THEN
    RAISE EXCEPTION 'Şubesiz aktif masa sayısı 27 değil: %', v_null;
  END IF;

  IF to_regclass('public.destina_table_branch_backup_20261101') IS NOT NULL THEN
    IF (SELECT count(*) FROM public.destina_table_branch_backup_20261101) <> 0 THEN
      RAISE EXCEPTION 'Yedek tablo dolu. İkinci çalıştırma yapılmadı.';
    END IF;
  END IF;

  CREATE TABLE IF NOT EXISTS public.destina_table_branch_backup_20261101 (
    table_id uuid PRIMARY KEY,
    seller_id uuid NOT NULL,
    table_number integer NOT NULL,
    old_branch_id uuid,
    new_branch_id uuid NOT NULL,
    row_fingerprint text NOT NULL,
    backed_up_at timestamptz NOT NULL DEFAULT timezone('utc', now())
  );

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'destina_table_branch_backup_20261101'
      AND column_name = 'row_fingerprint'
  ) THEN
    IF (SELECT count(*) FROM public.destina_table_branch_backup_20261101) <> 0 THEN
      RAISE EXCEPTION 'Yedek tabloda satır parmak izi yok. İkinci çalıştırma yapılmadı.';
    END IF;
    ALTER TABLE public.destina_table_branch_backup_20261101
      ADD COLUMN row_fingerprint text;
  END IF;

  ALTER TABLE public.destina_table_branch_backup_20261101 ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON TABLE public.destina_table_branch_backup_20261101 FROM PUBLIC;
  REVOKE ALL ON TABLE public.destina_table_branch_backup_20261101 FROM anon;
  REVOKE ALL ON TABLE public.destina_table_branch_backup_20261101 FROM authenticated;

  INSERT INTO public.destina_table_branch_backup_20261101 (
    table_id, seller_id, table_number, old_branch_id, new_branch_id, row_fingerprint
  )
  SELECT t.id, t.seller_id, t.table_number, t.branch_id, v_branch,
         md5((to_jsonb(t) - 'branch_id' - 'updated_at')::text)
  FROM public.store_tables t
  WHERE t.seller_id = v_store
    AND t.is_active
    AND t.branch_id IS NULL
    AND t.table_number BETWEEN 1 AND 27;

  IF (SELECT count(*) FROM public.destina_table_branch_backup_20261101) <> 27 THEN
    RAISE EXCEPTION 'Yedek satır sayısı 27 değil.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.destina_table_branch_backup_20261101
    WHERE row_fingerprint IS NULL
       OR length(row_fingerprint) <> 32
  ) <> 0
  OR (
    SELECT count(DISTINCT row_fingerprint)
    FROM public.destina_table_branch_backup_20261101
  ) <> 27 THEN
    RAISE EXCEPTION 'Masa parmak izi yazılamadı.';
  END IF;

  ALTER TABLE public.destina_table_branch_backup_20261101
    ALTER COLUMN row_fingerprint SET NOT NULL;

  UPDATE public.store_tables t
  SET branch_id = v_branch,
      updated_at = timezone('utc', now())
  FROM public.destina_table_branch_backup_20261101 b
  WHERE t.id = b.table_id
    AND t.seller_id = v_store
    AND t.branch_id IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 27 THEN
    RAISE EXCEPTION 'Güncellenen masa sayısı 27 değil: %', v_updated;
  END IF;

  IF (
    SELECT count(*)
    FROM public.store_tables
    WHERE seller_id = v_store AND branch_id = v_branch
  ) <> 27 THEN
    RAISE EXCEPTION 'Doğrulama: şubeye bağlı masa 27 değil.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.store_tables
    WHERE seller_id = v_store AND branch_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Doğrulama: şubesiz masa kaldı.';
  END IF;
END $$;

COMMIT;

-- After commit, read-only check:
-- SELECT table_number, branch_id
-- FROM public.store_tables
-- WHERE seller_id = '7264153b-f493-4508-8402-5fa8cfaabed8'
-- ORDER BY table_number;
-- Expect 27 rows, every branch_id = f695479b-6197-4011-af13-c2dc0ab069c3.
-- orders and table_orders row counts must be unchanged.
