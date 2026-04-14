-- 003_storage.sql
-- Supabase Storage bucket for item and bin images

-- Create the bucket (run this in Supabase dashboard if it fails via SQL)
INSERT INTO storage.buckets (id, name, public)
VALUES ('item-images', 'item-images', false)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for the storage bucket
-- Authenticated users can upload to their household path
CREATE POLICY "Household members can upload images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'item-images'
    AND (storage.foldername(name))[1] IN (
        SELECT hm.household_id::text
        FROM public.household_members hm
        WHERE hm.user_id = auth.uid()
    )
);

-- Authenticated users can read from their household path
CREATE POLICY "Household members can read images"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'item-images'
    AND (storage.foldername(name))[1] IN (
        SELECT hm.household_id::text
        FROM public.household_members hm
        WHERE hm.user_id = auth.uid()
    )
);

-- Authenticated users can delete from their household path
CREATE POLICY "Household members can delete images"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'item-images'
    AND (storage.foldername(name))[1] IN (
        SELECT hm.household_id::text
        FROM public.household_members hm
        WHERE hm.user_id = auth.uid()
    )
);
