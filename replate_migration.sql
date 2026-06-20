-- Replate Database Migration
-- This script adds the necessary columns for images, extra info, and meal estimates.
-- It also includes instructions for the uniquely named storage bucket.

-- 1. Add extra_info and image_url to food_listings
ALTER TABLE public.food_listings 
ADD COLUMN IF NOT EXISTS extra_info TEXT,
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2. Add estimated_meals_fed to food_claims
ALTER TABLE public.food_claims
ADD COLUMN IF NOT EXISTS estimated_meals_fed INTEGER DEFAULT 0;

-- 3. Create the unique storage bucket for photos
-- Run this in your Supabase SQL Editor to create the bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('epic_food_visual_assets_vault_v1', 'epic_food_visual_assets_vault_v1', true)
ON CONFLICT (id) DO NOTHING;

-- 4. Set up Storage Policies for the bucket (allow public read, authenticated insert)
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'epic_food_visual_assets_vault_v1');

CREATE POLICY "Authenticated Insert" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'epic_food_visual_assets_vault_v1' 
    AND auth.role() = 'authenticated'
);

-- Note: In the Supabase dashboard, you might need to manually ensure the bucket is Public if the SQL insert doesn't set it in the UI perfectly.
