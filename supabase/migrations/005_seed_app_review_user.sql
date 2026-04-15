-- 005_seed_app_review_user.sql
-- Seeds a stable, pre-confirmed test account for Apple App Review.
-- The reviewer signs in with these credentials (also documented in
-- docs/app-store-listing.md under "App Review Information") and lands
-- in a household pre-populated with one zone, one bin, and a few items
-- so they can immediately exercise the app without setup friction.
--
-- Idempotent: re-running this migration is a no-op. The user, household,
-- and seed data all use fixed UUIDs and ON CONFLICT DO NOTHING.

DO $$
DECLARE
    review_user_id  UUID := '00000000-0000-0000-0000-000000000001';
    review_email    TEXT := 'appreview@binthere.app';
    review_password TEXT := 'BinThereReview2026!';
    household_id    UUID := '00000000-0000-0000-0000-000000000010';
    zone_id         UUID := '00000000-0000-0000-0000-000000000020';
    bin_id          UUID := '00000000-0000-0000-0000-000000000030';
BEGIN
    -- Create the auth user with a bcrypt-hashed password and a
    -- confirmed email so no verification email is required.
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_sso_user
    )
    VALUES (
        review_user_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        review_email,
        crypt(review_password, gen_salt('bf')),
        now(),
        now(),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{}'::jsonb,
        false
    )
    ON CONFLICT (id) DO NOTHING;

    -- Identity row Supabase expects alongside auth.users for email logins.
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    )
    VALUES (
        gen_random_uuid(),
        review_user_id,
        jsonb_build_object('sub', review_user_id::text, 'email', review_email),
        'email',
        review_user_id::text,
        now(),
        now(),
        now()
    )
    ON CONFLICT (provider, provider_id) DO NOTHING;

    -- Pre-populated household so the reviewer sees data immediately.
    INSERT INTO households (id, name, created_by, created_at)
    VALUES (household_id, 'Review Household', review_user_id, now())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO household_members (household_id, user_id, role, display_name)
    VALUES (household_id, review_user_id, 'owner', 'App Reviewer')
    ON CONFLICT (household_id, user_id) DO NOTHING;

    INSERT INTO zones (id, household_id, name, location_description, color, icon)
    VALUES (zone_id, household_id, 'Garage', 'Two-car garage', 'orange', 'car.fill')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO bins (id, household_id, zone_id, code, name, bin_description, location, color)
    VALUES (
        bin_id,
        household_id,
        zone_id,
        'BIN-001',
        'Holiday Decorations',
        'Christmas lights, ornaments, and tree skirt',
        'Top shelf, left side',
        'red'
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO items (id, household_id, bin_id, name, item_description, tags, color, value, value_source, created_by)
    VALUES
        ('00000000-0000-0000-0000-000000000040', household_id, bin_id,
         'String Lights', '50ft warm white LED string lights',
         ARRAY['lights','christmas']::text[], 'yellow', 24.99, 'manual', review_user_id),
        ('00000000-0000-0000-0000-000000000041', household_id, bin_id,
         'Glass Ornaments', 'Box of 24 assorted red and gold glass ornaments',
         ARRAY['ornaments','fragile']::text[], 'red', 35.00, 'manual', review_user_id),
        ('00000000-0000-0000-0000-000000000042', household_id, bin_id,
         'Tree Skirt', 'Embroidered red velvet tree skirt',
         ARRAY['skirt']::text[], 'red', 45.00, 'manual', review_user_id)
    ON CONFLICT (id) DO NOTHING;
END $$;
