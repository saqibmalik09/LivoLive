-- STEP5 is admin certification only (no role package screen).
-- Users submit for review after steps 1–4; step5 green tick = status approved.

CREATE OR REPLACE FUNCTION public.submit_real_name_for_review()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_row FROM public.real_name_applications WHERE user_id = v_uid;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'No application');
  END IF;

  IF v_row.status IN ('pending', 'approved') THEN
    RETURN json_build_object('success', true, 'application', row_to_json(v_row));
  END IF;

  IF NOT (v_row.step1_done AND v_row.step2_done AND v_row.step3_done
           AND v_row.step4_done) THEN
    RETURN json_build_object('success', false, 'message', 'Complete steps 1–4 first');
  END IF;

  UPDATE public.real_name_applications SET
    status = 'pending',
    reject_reason = null,
    updated_at = now()
  WHERE user_id = v_uid
  RETURNING * INTO v_row;

  RETURN json_build_object('success', true, 'application', row_to_json(v_row));
END;
$$;

-- When admin approves, mark step5_done so DB stays consistent with UI.
CREATE OR REPLACE FUNCTION public.review_real_name_application(
  p_application_id uuid,
  p_approve boolean,
  p_reject_reason text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
BEGIN
  IF p_approve THEN
    UPDATE public.real_name_applications SET
      status = 'approved',
      step5_done = true,
      reviewed_by = v_uid,
      reviewed_at = now(),
      reject_reason = null,
      updated_at = now()
    WHERE id = p_application_id
    RETURNING * INTO v_row;
  ELSE
    UPDATE public.real_name_applications SET
      status = 'rejected',
      step5_done = false,
      reviewed_by = v_uid,
      reviewed_at = now(),
      reject_reason = COALESCE(p_reject_reason, 'Rejected'),
      updated_at = now()
    WHERE id = p_application_id
    RETURNING * INTO v_row;
  END IF;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Not found');
  END IF;

  RETURN json_build_object('success', true, 'application', row_to_json(v_row));
END;
$$;
