-- Agency applications must be routed to a BD staff member
-- Reject legacy pending agency requests that have no assigned staff
UPDATE public.user_applications
SET status = 'rejected', updated_at = now()
WHERE type = 'agency'
  AND target_staff_id IS NULL
  AND status = 'pending';

ALTER TABLE public.user_applications
    DROP CONSTRAINT IF EXISTS user_applications_agency_requires_staff;

-- NOT VALID: enforce on new rows; older approved rows may lack target_staff_id
ALTER TABLE public.user_applications
    ADD CONSTRAINT user_applications_agency_requires_staff
    CHECK (type <> 'agency' OR target_staff_id IS NOT NULL)
    NOT VALID;
