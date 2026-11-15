-- DO NOT APPLY unless 2026110118_destina_table_branch_bind.sql was committed
-- and must be reversed. Restores the saved NULL branch_id values.
-- Does not delete orders, payments, or staff rows.
-- Aborts with no writes if any backed-up table changed in a column other than
-- branch_id or updated_at. A new order is not such a change.

BEGIN;

DO $$
DECLARE
  v_store uuid := '7264153b-f493-4508-8402-5fa8cfaabed8';
  v_branch uuid := 'f695479b-6197-4011-af13-c2dc0ab069c3';
  v_updated integer;
BEGIN
  IF to_regclass('public.destina_table_branch_backup_20261101') IS NULL THEN
    RAISE EXCEPTION 'Yedek tablo yok. Masa şubesi değiştirilmedi.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.destina_table_branch_backup_20261101
    WHERE seller_id = v_store
      AND new_branch_id = v_branch
      AND old_branch_id IS NULL
  ) <> 27
  OR (
    SELECT count(*) FROM public.destina_table_branch_backup_20261101
  ) <> 27 THEN
    RAISE EXCEPTION 'Yedek 27 boş şube satırı değil.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'destina_table_branch_backup_20261101'
      AND column_name = 'row_fingerprint'
  ) THEN
    RAISE EXCEPTION 'Yedekte satır parmak izi yok. Geri alma yapılmadı.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.destina_table_branch_backup_20261101
    WHERE row_fingerprint IS NULL
       OR length(row_fingerprint) <> 32
  ) THEN
    RAISE EXCEPTION 'Yedekteki parmak izi eksik. Geri alma yapılmadı.';
  END IF;

  PERFORM 1
  FROM public.store_tables t
  JOIN public.destina_table_branch_backup_20261101 b ON b.table_id = t.id
  WHERE t.seller_id = v_store
  FOR UPDATE OF t;

  IF (
    SELECT count(*)
    FROM public.destina_table_branch_backup_20261101 b
    JOIN public.store_tables t ON t.id = b.table_id
    WHERE t.seller_id = v_store
      AND t.branch_id = v_branch
      AND b.old_branch_id IS NULL
  ) <> 27 THEN
    RAISE EXCEPTION 'Yedekteki masalardan biri artık hedef şubede değil. Geri alma yapılmadı.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.destina_table_branch_backup_20261101 b
    JOIN public.store_tables t ON t.id = b.table_id
    WHERE md5((to_jsonb(t) - 'branch_id' - 'updated_at')::text)
          IS DISTINCT FROM b.row_fingerprint
  ) THEN
    RAISE EXCEPTION 'Yedekteki masalardan birinin şube ve güncelleme zamanı dışındaki alanları değişmiş. Geri alma yapılmadı.';
  END IF;

  UPDATE public.store_tables t
  SET branch_id = b.old_branch_id,
      updated_at = timezone('utc', now())
  FROM public.destina_table_branch_backup_20261101 b
  WHERE t.id = b.table_id
    AND t.seller_id = v_store
    AND t.branch_id = v_branch
    AND b.old_branch_id IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 27 THEN
    RAISE EXCEPTION 'Geri alınan masa sayısı 27 değil: %', v_updated;
  END IF;
END $$;

COMMIT;
