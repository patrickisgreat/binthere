-- 004_delete_account.sql
-- Full account deletion. Apple App Store policy requires that any app
-- offering account creation also offer in-app account deletion that
-- fully removes the user's account and personal data — not just sign out.
--
-- This RPC runs as SECURITY DEFINER so it can delete the auth.users row,
-- which a regular client role cannot do. It only ever operates on the
-- caller (auth.uid()), so there's no privilege escalation risk.

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    uid UUID := auth.uid();
    household_record RECORD;
    remaining_members INTEGER;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- For each household the user belongs to, decide whether to drop the
    -- whole household (if the user was the sole remaining member) or
    -- just remove their membership.
    FOR household_record IN
        SELECT household_id
        FROM household_members
        WHERE user_id = uid
    LOOP
        SELECT COUNT(*) INTO remaining_members
        FROM household_members
        WHERE household_id = household_record.household_id
          AND user_id <> uid;

        IF remaining_members = 0 THEN
            -- Sole member: delete the household. ON DELETE CASCADE on
            -- household_id columns will clean up zones, bins, items,
            -- checkout_records, custom_attributes, invitations, and the
            -- household_members row itself.
            DELETE FROM households WHERE id = household_record.household_id;
        ELSE
            -- Other members remain: just remove this user's membership.
            DELETE FROM household_members
            WHERE household_id = household_record.household_id
              AND user_id = uid;
        END IF;
    END LOOP;

    -- Null out audit pointers on records that survive (other members'
    -- households where this user created bins/items/checkouts).
    UPDATE items SET created_by = NULL WHERE created_by = uid;
    UPDATE checkout_records SET checked_out_by = NULL WHERE checked_out_by = uid;

    -- Finally, delete the auth user. This invalidates all their sessions.
    DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
