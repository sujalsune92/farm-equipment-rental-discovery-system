-- ═══════════════════════════════════════════════════════════════════════════
-- KisanYantra — Complete Supabase Database Setup
-- Run this entire script in: Supabase Dashboard → SQL Editor → New Query
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1 · USERS TABLE
-- Mirrors auth.users — stores role, profile, location, ratings
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT        NOT NULL,
  email             TEXT        NOT NULL UNIQUE,
  phone             TEXT        NOT NULL DEFAULT '',
  role              TEXT        NOT NULL DEFAULT 'farmer'
                      CHECK (role IN ('farmer')),
  profile_image_url TEXT,
  address           TEXT,
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  skills            TEXT[]      NOT NULL DEFAULT '{}',
  current_job       TEXT,
  past_experience_years INT     NOT NULL DEFAULT 0,
  experience_details TEXT,
  gender            TEXT,
  bio               TEXT,
  average_rating    DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_reviews     INT          NOT NULL DEFAULT 0,
  is_verified       BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Ensure role constraints are updated even on existing databases
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_allowed_check;
UPDATE public.users
SET role = 'farmer'
WHERE role NOT IN ('farmer');
ALTER TABLE public.users
  ADD CONSTRAINT users_role_allowed_check
  CHECK (role IN ('farmer'));
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS skills TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS current_job TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS past_experience_years INT NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS experience_details TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_gender_allowed_check;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_experience_years_positive_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_gender_allowed_check
  CHECK (gender IS NULL OR gender IN ('male', 'female', 'other', 'prefer_not_to_say'));
ALTER TABLE public.users
  ADD CONSTRAINT users_experience_years_positive_check
  CHECK (past_experience_years >= 0);
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_latitude_range_check;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_longitude_range_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_latitude_range_check
  CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90));
ALTER TABLE public.users
  ADD CONSTRAINT users_longitude_range_check
  CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180));

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2 · LISTINGS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.listings (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID         NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_name      TEXT         NOT NULL DEFAULT '',
  owner_phone     TEXT         NOT NULL DEFAULT '',
  owner_rating    DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  name            TEXT         NOT NULL,
  description     TEXT         NOT NULL DEFAULT '',
  type            TEXT         NOT NULL,
  price_per_day   DOUBLE PRECISION NOT NULL CHECK (price_per_day >= 0),
  image_urls      TEXT[]       NOT NULL DEFAULT '{}',
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  address         TEXT         NOT NULL DEFAULT '',
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  average_rating  DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_bookings  INT          NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_latitude_range_check;
ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_longitude_range_check;
ALTER TABLE public.listings
  ADD CONSTRAINT listings_latitude_range_check
  CHECK (latitude BETWEEN -90 AND 90);
ALTER TABLE public.listings
  ADD CONSTRAINT listings_longitude_range_check
  CHECK (longitude BETWEEN -180 AND 180);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3 · BOOKINGS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bookings (
  id                UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id        UUID  NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  listing_name      TEXT  NOT NULL DEFAULT '',
  listing_type      TEXT  NOT NULL DEFAULT '',
  listing_image_url TEXT  NOT NULL DEFAULT '',
  farmer_id         UUID  NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farmer_name       TEXT  NOT NULL DEFAULT '',
  farmer_phone      TEXT  NOT NULL DEFAULT '',
  owner_id          UUID  NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_name        TEXT  NOT NULL DEFAULT '',
  start_date        DATE  NOT NULL,
  end_date          DATE  NOT NULL,
  price_per_day     DOUBLE PRECISION NOT NULL,
  total_price       DOUBLE PRECISION NOT NULL,
  status            TEXT  NOT NULL DEFAULT 'Pending'
                      CHECK (status IN ('Pending','Approved','In Use','Declined','Completed')),
  usage_details     TEXT,
  decline_reason    TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ,
  CONSTRAINT no_overlap_check CHECK (end_date >= start_date)
);

-- Ensure status constraints are updated even on existing databases
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_allowed_check;
ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_status_allowed_check
  CHECK (status IN ('Pending','Approved','In Use','Declined','Completed'));

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4 · REVIEWS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  listing_id  UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  farmer_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farmer_name TEXT NOT NULL DEFAULT '',
  owner_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rating      DOUBLE PRECISION NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (booking_id) -- one review per booking
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5 · NOTIFICATIONS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  type         TEXT NOT NULL, -- booking_request | booking_update | review
  reference_id TEXT,          -- booking id or listing id
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5B · FARMER-WORKER CONNECTIVITY TABLES
-- Worker registration, job posting, matching/applications, and communication
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.worker_profiles (
  user_id       UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL DEFAULT '',
  phone         TEXT NOT NULL DEFAULT '',
  skills        TEXT[] NOT NULL DEFAULT '{}',
  village       TEXT NOT NULL DEFAULT '',
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  hourly_rate   DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (hourly_rate >= 0),
  experience_years INT NOT NULL DEFAULT 0,
  primary_work_type TEXT NOT NULL DEFAULT 'General Farm Work',
  preferred_radius_km DOUBLE PRECISION NOT NULL DEFAULT 25,
  identity_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_available  BOOLEAN NOT NULL DEFAULT TRUE,
  bio           TEXT NOT NULL DEFAULT '',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.worker_job_posts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farmer_name     TEXT NOT NULL DEFAULT '',
  title           TEXT NOT NULL,
  description     TEXT NOT NULL DEFAULT '',
  village         TEXT NOT NULL DEFAULT '',
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  work_date       TEXT NOT NULL DEFAULT '',
  wage_type       TEXT NOT NULL DEFAULT 'day' CHECK (wage_type IN ('hour','day')),
  wage_amount     DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (wage_amount >= 0),
  required_skills TEXT[] NOT NULL DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.worker_profiles ADD COLUMN IF NOT EXISTS experience_years INT NOT NULL DEFAULT 0;
ALTER TABLE public.worker_profiles ADD COLUMN IF NOT EXISTS primary_work_type TEXT NOT NULL DEFAULT 'General Farm Work';
ALTER TABLE public.worker_profiles ADD COLUMN IF NOT EXISTS preferred_radius_km DOUBLE PRECISION NOT NULL DEFAULT 25;
ALTER TABLE public.worker_profiles ADD COLUMN IF NOT EXISTS identity_verified BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.worker_profiles DROP CONSTRAINT IF EXISTS worker_profiles_latitude_range_check;
ALTER TABLE public.worker_profiles DROP CONSTRAINT IF EXISTS worker_profiles_longitude_range_check;
ALTER TABLE public.worker_profiles DROP CONSTRAINT IF EXISTS worker_profiles_preferred_radius_positive_check;
ALTER TABLE public.worker_profiles
  ADD CONSTRAINT worker_profiles_latitude_range_check
  CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90));
ALTER TABLE public.worker_profiles
  ADD CONSTRAINT worker_profiles_longitude_range_check
  CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180));
ALTER TABLE public.worker_profiles
  ADD CONSTRAINT worker_profiles_preferred_radius_positive_check
  CHECK (preferred_radius_km >= 0);

ALTER TABLE public.worker_job_posts ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.worker_job_posts ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

ALTER TABLE public.worker_job_posts DROP CONSTRAINT IF EXISTS worker_job_posts_latitude_range_check;
ALTER TABLE public.worker_job_posts DROP CONSTRAINT IF EXISTS worker_job_posts_longitude_range_check;
ALTER TABLE public.worker_job_posts
  ADD CONSTRAINT worker_job_posts_latitude_range_check
  CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90));
ALTER TABLE public.worker_job_posts
  ADD CONSTRAINT worker_job_posts_longitude_range_check
  CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180));

CREATE TABLE IF NOT EXISTS public.worker_applications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        UUID NOT NULL REFERENCES public.worker_job_posts(id) ON DELETE CASCADE,
  worker_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  worker_name   TEXT NOT NULL DEFAULT '',
  status        TEXT NOT NULL DEFAULT 'applied' CHECK (status IN ('applied','accepted','rejected')),
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (job_id, worker_id)
);

CREATE TABLE IF NOT EXISTS public.worker_messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id       UUID NOT NULL REFERENCES public.worker_job_posts(id) ON DELETE CASCADE,
  sender_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body         TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6 · INDEXES for performance
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_listings_owner     ON public.listings(owner_id);
CREATE INDEX IF NOT EXISTS idx_listings_type      ON public.listings(type);
CREATE INDEX IF NOT EXISTS idx_listings_active    ON public.listings(is_active);
CREATE INDEX IF NOT EXISTS idx_listings_location  ON public.listings(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_bookings_farmer    ON public.bookings(farmer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_owner     ON public.bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_listing   ON public.bookings(listing_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status    ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_dates     ON public.bookings(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_reviews_listing    ON public.reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_reviews_owner      ON public.reviews(owner_id);
CREATE INDEX IF NOT EXISTS idx_notif_user         ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_read         ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_worker_profiles_village ON public.worker_profiles(village);
CREATE INDEX IF NOT EXISTS idx_worker_profiles_available ON public.worker_profiles(is_available);
CREATE INDEX IF NOT EXISTS idx_worker_jobs_farmer  ON public.worker_job_posts(farmer_id);
CREATE INDEX IF NOT EXISTS idx_worker_jobs_status  ON public.worker_job_posts(status);
CREATE INDEX IF NOT EXISTS idx_worker_jobs_village ON public.worker_job_posts(village);
CREATE INDEX IF NOT EXISTS idx_worker_jobs_latlng  ON public.worker_job_posts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_worker_apps_job     ON public.worker_applications(job_id);
CREATE INDEX IF NOT EXISTS idx_worker_apps_worker  ON public.worker_applications(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_msgs_job     ON public.worker_messages(job_id);
CREATE INDEX IF NOT EXISTS idx_worker_msgs_sender  ON public.worker_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_worker_msgs_receiver ON public.worker_messages(receiver_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 7 · HELPER FUNCTIONS (called after submitting a review)
-- ─────────────────────────────────────────────────────────────────────────────

-- Recalculate and update owner average rating
CREATE OR REPLACE FUNCTION update_owner_rating(owner_uuid UUID)
RETURNS VOID AS $$
DECLARE
  avg_r DOUBLE PRECISION;
  total_r INT;
BEGIN
  SELECT AVG(rating), COUNT(*) INTO avg_r, total_r
  FROM public.reviews WHERE owner_id = owner_uuid;
  UPDATE public.users
  SET average_rating = COALESCE(avg_r, 0),
      total_reviews  = COALESCE(total_r, 0)
  WHERE id = owner_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recalculate and update listing average rating
CREATE OR REPLACE FUNCTION update_listing_rating(listing_uuid UUID)
RETURNS VOID AS $$
DECLARE
  avg_r DOUBLE PRECISION;
BEGIN
  SELECT AVG(rating) INTO avg_r
  FROM public.reviews WHERE listing_id = listing_uuid;
  UPDATE public.listings
  SET average_rating = COALESCE(avg_r, 0)
  WHERE id = listing_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generic updated_at trigger for mutable tables
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bookings_set_updated_at ON public.bookings;
CREATE TRIGGER trg_bookings_set_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_worker_profiles_set_updated_at ON public.worker_profiles;
CREATE TRIGGER trg_worker_profiles_set_updated_at
  BEFORE UPDATE ON public.worker_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 8 · AUTO-SYNC USER ON SIGNUP (trigger on auth.users insert)
-- Creates a minimal users row automatically when someone signs up.
-- The Flutter app will then UPDATE it with name/phone/role.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name',''), NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 9 · ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_job_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_messages ENABLE ROW LEVEL SECURITY;

-- Re-create policies safely so this script can be re-run without failures.
DROP POLICY IF EXISTS "users: read all" ON public.users;
DROP POLICY IF EXISTS "users: insert own" ON public.users;
DROP POLICY IF EXISTS "users: update own" ON public.users;
DROP POLICY IF EXISTS "listings: read active" ON public.listings;
DROP POLICY IF EXISTS "listings: owner insert" ON public.listings;
DROP POLICY IF EXISTS "listings: owner update" ON public.listings;
DROP POLICY IF EXISTS "bookings: farmer or owner read" ON public.bookings;
DROP POLICY IF EXISTS "bookings: farmer insert" ON public.bookings;
DROP POLICY IF EXISTS "bookings: owner update status" ON public.bookings;
DROP POLICY IF EXISTS "reviews: read all" ON public.reviews;
DROP POLICY IF EXISTS "reviews: farmer insert" ON public.reviews;
DROP POLICY IF EXISTS "notif: own only" ON public.notifications;
DROP POLICY IF EXISTS "notif: insert authenticated" ON public.notifications;
DROP POLICY IF EXISTS "notif: own update" ON public.notifications;
DROP POLICY IF EXISTS "worker_profiles: read authenticated" ON public.worker_profiles;
DROP POLICY IF EXISTS "worker_profiles: upsert own" ON public.worker_profiles;
DROP POLICY IF EXISTS "worker_profiles: update own" ON public.worker_profiles;
DROP POLICY IF EXISTS "worker_jobs: read authenticated" ON public.worker_job_posts;
DROP POLICY IF EXISTS "worker_jobs: farmer insert" ON public.worker_job_posts;
DROP POLICY IF EXISTS "worker_jobs: farmer update" ON public.worker_job_posts;
DROP POLICY IF EXISTS "worker_apps: read participants" ON public.worker_applications;
DROP POLICY IF EXISTS "worker_apps: worker insert own" ON public.worker_applications;
DROP POLICY IF EXISTS "worker_apps: farmer update status" ON public.worker_applications;
DROP POLICY IF EXISTS "worker_messages: read sender or receiver" ON public.worker_messages;
DROP POLICY IF EXISTS "worker_messages: send own" ON public.worker_messages;

-- ── USERS policies ──────────────────────────────────────────────────────────
-- Any signed-in user can read all profiles
CREATE POLICY "users: read all"
  ON public.users FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Users can insert and update only their own row
CREATE POLICY "users: insert own"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users: update own"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

-- ── LISTINGS policies ────────────────────────────────────────────────────────
-- Any signed-in user can read active listings
CREATE POLICY "listings: read active"
  ON public.listings FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only owners can create listings (enforced by role check in Flutter)
CREATE POLICY "listings: owner insert"
  ON public.listings FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- Only the listing owner can update
CREATE POLICY "listings: owner update"
  ON public.listings FOR UPDATE
  USING (auth.uid() = owner_id);

-- ── BOOKINGS policies ────────────────────────────────────────────────────────
CREATE POLICY "bookings: farmer or owner read"
  ON public.bookings FOR SELECT
  USING (auth.uid() = farmer_id OR auth.uid() = owner_id);

CREATE POLICY "bookings: farmer insert"
  ON public.bookings FOR INSERT
  WITH CHECK (auth.uid() = farmer_id);

CREATE POLICY "bookings: owner update status"
  ON public.bookings FOR UPDATE
  USING (auth.uid() = owner_id OR auth.uid() = farmer_id);

-- ── REVIEWS policies ─────────────────────────────────────────────────────────
CREATE POLICY "reviews: read all"
  ON public.reviews FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "reviews: farmer insert"
  ON public.reviews FOR INSERT
  WITH CHECK (auth.uid() = farmer_id);

-- ── NOTIFICATIONS policies ───────────────────────────────────────────────────
CREATE POLICY "notif: own only"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "notif: insert authenticated"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "notif: own update"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- ── WORKER PROFILES policies ─────────────────────────────────────────────────
CREATE POLICY "worker_profiles: read authenticated"
  ON public.worker_profiles FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "worker_profiles: upsert own"
  ON public.worker_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "worker_profiles: update own"
  ON public.worker_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- ── WORKER JOB POSTS policies ────────────────────────────────────────────────
CREATE POLICY "worker_jobs: read authenticated"
  ON public.worker_job_posts FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "worker_jobs: farmer insert"
  ON public.worker_job_posts FOR INSERT
  WITH CHECK (auth.uid() = farmer_id);

CREATE POLICY "worker_jobs: farmer update"
  ON public.worker_job_posts FOR UPDATE
  USING (auth.uid() = farmer_id);

-- ── WORKER APPLICATIONS policies ─────────────────────────────────────────────
CREATE POLICY "worker_apps: read participants"
  ON public.worker_applications FOR SELECT
  USING (
    auth.uid() = worker_id OR
    EXISTS (
      SELECT 1
      FROM public.worker_job_posts j
      WHERE j.id = worker_applications.job_id AND j.farmer_id = auth.uid()
    )
  );

CREATE POLICY "worker_apps: worker insert own"
  ON public.worker_applications FOR INSERT
  WITH CHECK (auth.uid() = worker_id);

CREATE POLICY "worker_apps: farmer update status"
  ON public.worker_applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.worker_job_posts j
      WHERE j.id = worker_applications.job_id AND j.farmer_id = auth.uid()
    )
  );

-- ── WORKER MESSAGES policies ─────────────────────────────────────────────────
CREATE POLICY "worker_messages: read sender or receiver"
  ON public.worker_messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "worker_messages: send own"
  ON public.worker_messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 10 · REALTIME  (enable for live booking/notification updates)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  t TEXT;
  tables_to_add TEXT[] := ARRAY[
    'bookings',
    'notifications',
    'listings',
    'worker_job_posts',
    'worker_applications',
    'worker_messages'
  ];
BEGIN
  FOREACH t IN ARRAY tables_to_add LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Done! ✅  All tables, RLS, triggers, and functions are ready.
-- ─────────────────────────────────────────────────────────────────────────────
