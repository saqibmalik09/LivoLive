-- Profile loading fetched EVERY earning_logs row for an agency owner and summed
-- them on the device. earning_logs is 2.44M rows / 431 MB with no index on
-- agency_owner_id, so each profile view ran a full sequential scan and tried to
-- ship up to 420k rows to a phone. It timed out server-side (57014) and is a
-- major contributor to the "app is very slow" reports.
--
-- Run this file WITHOUT wrapping it in a transaction: CREATE INDEX CONCURRENTLY
-- cannot run inside one, and the table is large and live.
--   psql -U postgres -d postgres -f 20260930180000_agency_exp_index_and_rpc.sql

CREATE INDEX CONCURRENTLY IF NOT EXISTS earning_logs_agency_owner_idx
  ON public.earning_logs (agency_owner_id)
  INCLUDE (agency_amount);

-- Sum server-side so the client fetches one number instead of 420k rows.
CREATE OR REPLACE FUNCTION public.agency_total_exp(p_owner_id uuid)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
  SELECT COALESCE(SUM(agency_amount), 0)::bigint
  FROM public.earning_logs
  WHERE agency_owner_id = p_owner_id;
$fn$;

GRANT EXECUTE ON FUNCTION public.agency_total_exp(uuid)
  TO anon, authenticated, service_role;
