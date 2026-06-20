-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('restaurant', 'ngo')) NOT NULL,
  name TEXT,
  phone TEXT,
  address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create Food Listings Table
CREATE TABLE IF NOT EXISTS food_listings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  restaurant_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL, 
  quantity_info TEXT NOT NULL, 
  food_type TEXT CHECK (food_type IN ('veg', 'non-veg', 'vegan', 'mixed')) NOT NULL,
  address TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  contact_phone TEXT NOT NULL,
  expiry_time TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT CHECK (status IN ('available', 'partially_claimed', 'claimed', 'picked_up')) DEFAULT 'available',
  claimed_by UUID REFERENCES profiles(id) ON DELETE SET NULL, 
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create Claims Table (for partial claiming)
CREATE TABLE IF NOT EXISTS food_claims (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  listing_id UUID REFERENCES food_listings(id) ON DELETE CASCADE NOT NULL,
  ngo_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  ngo_name TEXT NOT NULL,
  ngo_phone TEXT NOT NULL,
  claimed_quantity TEXT NOT NULL,
  claim_type TEXT CHECK (claim_type IN ('full', 'partial')) NOT NULL DEFAULT 'full',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Disable Row Level Security (RLS) for testing purposes
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE food_listings DISABLE ROW LEVEL SECURITY;
ALTER TABLE food_claims DISABLE ROW LEVEL SECURITY;

-- 5. Optional: Function and Trigger to automatically handle profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, role, name, phone, address)
  VALUES (
    new.id, 
    COALESCE(new.raw_user_meta_data->>'role', 'ngo'),
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'address'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists, then recreate it to avoid conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ==========================================
-- UPDATE SCRIPT FOR EXISTING DATABASE
-- ==========================================
DO $$ 
BEGIN 
    BEGIN
        ALTER TABLE food_listings ADD COLUMN title TEXT DEFAULT 'Surplus Food';
    EXCEPTION WHEN duplicate_column THEN null; END;
    BEGIN
        ALTER TABLE food_listings ADD COLUMN quantity_info TEXT DEFAULT 'Unspecified';
    EXCEPTION WHEN duplicate_column THEN null; END;
    BEGIN
        ALTER TABLE food_listings ADD COLUMN contact_name TEXT DEFAULT 'Unknown';
    EXCEPTION WHEN duplicate_column THEN null; END;
    BEGIN
        ALTER TABLE food_listings ADD COLUMN contact_phone TEXT DEFAULT 'Unknown';
    EXCEPTION WHEN duplicate_column THEN null; END;
    BEGIN
        ALTER TABLE food_listings ADD COLUMN expiry_time TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '24 hours');
    EXCEPTION WHEN duplicate_column THEN null; END;
    BEGIN
        ALTER TABLE food_listings ADD COLUMN claimed_by UUID REFERENCES profiles(id) ON DELETE SET NULL;
    EXCEPTION WHEN duplicate_column THEN null; END;
END $$;

ALTER TABLE food_listings DROP CONSTRAINT IF EXISTS food_listings_food_type_check;
ALTER TABLE food_listings ADD CONSTRAINT food_listings_food_type_check CHECK (food_type IN ('veg', 'non-veg', 'vegan', 'mixed'));

ALTER TABLE food_listings DROP CONSTRAINT IF EXISTS food_listings_status_check;
ALTER TABLE food_listings ADD CONSTRAINT food_listings_status_check CHECK (status IN ('available', 'partially_claimed', 'claimed', 'picked_up'));
