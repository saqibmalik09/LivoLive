-- Fix notification mark-as-read + broadcast read tracking

CREATE TABLE IF NOT EXISTS public.user_notification_reads (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    notification_id uuid NOT NULL REFERENCES public.system_notifications(id) ON DELETE CASCADE,
    read_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, notification_id)
);

CREATE INDEX IF NOT EXISTS user_notification_reads_user_idx
    ON public.user_notification_reads(user_id, read_at DESC);

ALTER TABLE public.user_notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own notification read state" ON public.user_notification_reads;
CREATE POLICY "Users read own notification read state" ON public.user_notification_reads
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users insert own notification read state" ON public.user_notification_reads;
CREATE POLICY "Users insert own notification read state" ON public.user_notification_reads
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

ALTER TABLE public.system_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own system notifications" ON public.system_notifications;
CREATE POLICY "Users can view their own system notifications" ON public.system_notifications
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can mark own notifications read" ON public.system_notifications;
CREATE POLICY "Users can mark own notifications read" ON public.system_notifications
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_row public.system_notifications%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    SELECT * INTO v_row
    FROM public.system_notifications
    WHERE id = p_notification_id;

    IF v_row.id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Notification not found');
    END IF;

    IF v_row.user_id IS NULL THEN
        INSERT INTO public.user_notification_reads (user_id, notification_id)
        VALUES (v_uid, p_notification_id)
        ON CONFLICT (user_id, notification_id) DO NOTHING;
    ELSIF v_row.user_id = v_uid THEN
        UPDATE public.system_notifications
        SET is_read = true
        WHERE id = p_notification_id;
    ELSE
        RETURN json_build_object('success', false, 'message', 'Not authorized');
    END IF;

    RETURN json_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_personal int;
    v_broadcast int;
BEGIN
    IF v_uid IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE public.system_notifications
    SET is_read = true
    WHERE user_id = v_uid
      AND is_read = false;
    GET DIAGNOSTICS v_personal = ROW_COUNT;

    INSERT INTO public.user_notification_reads (user_id, notification_id)
    SELECT v_uid, sn.id
    FROM public.system_notifications sn
    WHERE sn.user_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM public.user_notification_reads unr
          WHERE unr.user_id = v_uid AND unr.notification_id = sn.id
      );
    GET DIAGNOSTICS v_broadcast = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'personal_updated', v_personal,
        'broadcast_marked', v_broadcast
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;
