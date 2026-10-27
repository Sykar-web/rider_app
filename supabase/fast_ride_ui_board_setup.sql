-- FastRide UI Board: ONE complete, re-runnable setup for an existing FastRide database.
-- Run all of this file as the project owner in Supabase SQL Editor.
-- Existing ride, profile and delivery tables must already exist. No demo money is created.

begin;

-- FastRide booking setup: car/van details plus Arua bus companies, schedules,
-- individual seat tickets, multiple seats, and whole-bus reservations.
-- Run this entire file once in Supabase Dashboard → SQL Editor.

alter table public.rides
  add column if not exists booking_details jsonb not null default '{}'::jsonb,
  add column if not exists booking_reference text,
  add column if not exists reservation_type text,
  add column if not exists seat_number text;

create unique index if not exists rides_booking_reference_unique
  on public.rides (booking_reference)
  where booking_reference is not null;

alter table public.rides drop constraint if exists rides_bus_reservation_details;
alter table public.rides add constraint rides_bus_reservation_details
  check (
    vehicle_type is distinct from 'bus'
    or reservation_type is null
    or (reservation_type = 'whole_bus' and seat_number is null)
    or (reservation_type = 'individual' and seat_number is not null)
  ) not valid;

create table if not exists public.bus_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.bus_schedules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.bus_companies(id) on delete cascade,
  origin text not null default 'Arua',
  destination text not null default 'Kampala',
  departure_time time not null,
  arrival_time time not null,
  duration_minutes integer not null check (duration_minutes > 0),
  service_class text not null check (service_class in ('ordinary', 'executive')),
  total_seats integer not null default 45 check (total_seats between 1 and 80),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, origin, destination, departure_time, service_class)
);

alter table public.rides
  add column if not exists bus_schedule_id uuid references public.bus_schedules(id),
  add column if not exists travel_date date,
  add column if not exists travel_class text,
  add column if not exists seat_numbers text[];

create or replace function public.prevent_bus_reservation_conflicts()
returns trigger language plpgsql as $$
begin
  if new.vehicle_type <> 'bus' or new.bus_schedule_id is null or new.travel_date is null then return new; end if;
  if new.reservation_type = 'individual' and (new.seat_numbers is null or cardinality(new.seat_numbers) = 0) then
    new.seat_numbers := array[new.seat_number];
  end if;
  if new.reservation_type = 'whole_bus' and exists (
    select 1 from public.rides r where r.bus_schedule_id = new.bus_schedule_id
      and r.travel_date = new.travel_date and r.status not in ('cancelled', 'completed') and r.id is distinct from new.id
  ) then raise exception 'This bus already has passenger reservations for that departure.'; end if;
  if new.reservation_type = 'individual' and exists (
    select 1 from public.rides r where r.bus_schedule_id = new.bus_schedule_id
      and r.travel_date = new.travel_date and r.reservation_type = 'whole_bus'
      and r.status not in ('cancelled', 'completed') and r.id is distinct from new.id
  ) then raise exception 'This departure has been reserved as a whole bus.'; end if;
  if new.reservation_type = 'individual' and exists (
    select 1 from public.rides r, unnest(coalesce(r.seat_numbers, array[r.seat_number])) reserved_seat
    where r.bus_schedule_id = new.bus_schedule_id and r.travel_date = new.travel_date
      and r.reservation_type = 'individual' and r.status not in ('cancelled', 'completed')
      and r.id is distinct from new.id and reserved_seat = any(new.seat_numbers)
  ) then raise exception 'One or more selected seats are no longer available.'; end if;
  return new;
end;
$$;

drop trigger if exists rides_bus_reservation_conflicts on public.rides;
create trigger rides_bus_reservation_conflicts before insert or update on public.rides
  for each row execute function public.prevent_bus_reservation_conflicts();

insert into public.bus_companies (name) values
  ('YY Coaches'), ('Nile Star'), ('Nile Coach'), ('Gaagaa Coaches'),
  ('Baby Coach'), ('KK Travelers'), ('Zawadi Coaches'), ('Friends Bus')
on conflict (name) do nothing;

-- Editable starter schedules. Confirm operator details before production.
insert into public.bus_schedules (company_id, departure_time, arrival_time, duration_minutes, service_class)
select c.id, s.departure_time, s.arrival_time, s.duration_minutes, s.service_class
from (values
  ('YY Coaches', time '06:00', time '14:00', 480, 'ordinary'),
  ('YY Coaches', time '12:00', time '20:00', 480, 'ordinary'),
  ('Nile Star', time '07:00', time '15:00', 480, 'ordinary'),
  ('Nile Star', time '08:00', time '16:00', 480, 'ordinary'),
  ('Nile Star', time '13:00', time '21:00', 480, 'executive'),
  ('Nile Star', time '16:00', time '00:00', 480, 'executive'),
  ('Nile Star', time '17:00', time '01:00', 480, 'ordinary')
) as s(company_name, departure_time, arrival_time, duration_minutes, service_class)
join public.bus_companies c on c.name = s.company_name
on conflict (company_id, origin, destination, departure_time, service_class) do nothing;

alter table public.bus_companies enable row level security;
alter table public.bus_schedules enable row level security;
drop policy if exists "authenticated users can read bus companies" on public.bus_companies;
create policy "authenticated users can read bus companies" on public.bus_companies for select to authenticated using (true);
drop policy if exists "authenticated users can read bus schedules" on public.bus_schedules;
create policy "authenticated users can read bus schedules" on public.bus_schedules for select to authenticated using (true);


-- Run AFTER fast_ride_booking_setup.sql. No changes to fares or timetables.
-- Serialize reservations against the same schedule and check all passengers'
-- reservations privately, without exposing their profile or booking data.

create or replace function public.prevent_bus_reservation_conflicts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  schedule public.bus_schedules%rowtype;
  selected_seat text;
  seat_index integer;
begin
  if new.vehicle_type::text is distinct from 'bus'
      or new.status::text = 'cancelled' then
    return new;
  end if;

  -- Legacy bookings can still receive status updates. New bus bookings must
  -- always identify a specific schedule and travel date.
  if new.bus_schedule_id is null or new.travel_date is null then
    if TG_OP = 'INSERT' then
      raise exception 'Select a bus departure and travel date.';
    end if;
    return new;
  end if;

  select s.* into schedule from public.bus_schedules s
    where s.id = new.bus_schedule_id for update;
  if not found then raise exception 'The selected departure does not exist.'; end if;

  if TG_OP = 'INSERT' then
    if not schedule.is_active or not exists (
      select 1 from public.bus_companies c where c.id = schedule.company_id and c.is_active
    ) then raise exception 'This departure is no longer available.'; end if;
    if (new.travel_date + schedule.departure_time) <= (now() at time zone 'Africa/Kampala') then
      raise exception 'Choose a departure that has not left yet.';
    end if;
  end if;

  new.travel_class := schedule.service_class;
  if new.reservation_type = 'whole_bus' then
    new.seat_number := null;
    new.seat_numbers := null;
  elsif new.reservation_type = 'individual' then
    new.seat_numbers := coalesce(new.seat_numbers, array[new.seat_number]);
    if cardinality(new.seat_numbers) = 0 or array_position(new.seat_numbers, null) is not null then
      raise exception 'Select at least one valid seat.';
    end if;
    if cardinality(new.seat_numbers) <> (select count(distinct seat) from unnest(new.seat_numbers) seat) then
      raise exception 'A seat cannot be selected more than once.';
    end if;
    foreach selected_seat in array new.seat_numbers loop
      if selected_seat !~ '^([1-9]|1[0-9]|20)[ABCD]$' then
        raise exception 'Invalid seat selection.';
      end if;
      seat_index := (substring(selected_seat from '^[0-9]+')::integer - 1) * 4
        + strpos('ABCD', right(selected_seat, 1));
      if seat_index > schedule.total_seats then
        raise exception 'Selected seat exceeds this bus capacity.';
      end if;
    end loop;
    new.seat_number := new.seat_numbers[1];
    new.booking_details := jsonb_set(coalesce(new.booking_details, '{}'::jsonb),
      '{passenger_count}', to_jsonb(cardinality(new.seat_numbers)));
  else
    raise exception 'Choose seats or a whole-bus reservation.';
  end if;

  if exists (
    select 1 from public.rides r
    where r.bus_schedule_id = new.bus_schedule_id and r.travel_date = new.travel_date
      and r.id is distinct from new.id and r.status::text <> 'cancelled'
      and (new.reservation_type = 'whole_bus' or r.reservation_type = 'whole_bus'
        or coalesce(r.seat_numbers, array[r.seat_number]) && new.seat_numbers)
  ) then
    raise exception 'These seats or this bus are no longer available. Choose another reservation.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_bus_reservation_conflicts() from public, anon, authenticated;
drop trigger if exists rides_bus_reservation_conflicts on public.rides;
create trigger rides_bus_reservation_conflicts before insert or update on public.rides
  for each row execute function public.prevent_bus_reservation_conflicts();

grant select on public.bus_companies, public.bus_schedules to authenticated;


-- FastRide UI board: additive customer features. Run as the project owner in
-- Supabase SQL Editor. Existing rides/profiles/deliveries must already exist.
-- This migration deliberately does not seed money, prices, drivers or ratings.

alter table public.rides
  add column if not exists scheduled_at timestamptz,
  add column if not exists request_type text not null default 'private',
  add column if not exists payment_method text not null default 'cash',
  add column if not exists fare_ugx numeric(12,0),
  add column if not exists distance_km numeric(10,3),
  add column if not exists estimated_duration_minutes numeric(10,2);

alter table public.deliveries
  add column if not exists package_type text,
  add column if not exists package_notes text;

create table if not exists public.customer_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 200),
  kind text not null check (kind in ('home','work','favourite','recent')),
  address text not null,
  place_id text,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  created_at timestamptz not null default now(),
  unique (user_id,label,kind)
);

-- A recent search must not replace a saved favourite with the same name.
alter table public.customer_places drop constraint if exists customer_places_user_id_label_key;
create unique index if not exists customer_places_user_label_kind_unique
  on public.customer_places(user_id,label,kind);

create table if not exists public.customer_preferences (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  trip_updates boolean not null default true,
  offers boolean not null default false
);

create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category text not null check (category in ('ride_issue','lost_item','general','privacy')),
  message text not null check (char_length(message) between 10 and 2000),
  status text not null default 'open' check (status in ('open','in_review','resolved')),
  response text,
  created_at timestamptz not null default now()
);

create table if not exists public.ride_reviews (
  ride_id uuid primary key references public.rides(id) on delete cascade,
  passenger_id uuid not null references auth.users(id) on delete cascade,
  driver_id uuid references auth.users(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 500),
  created_at timestamptz not null default now()
);

-- Read-only to customers. A trusted payment backend must write both ledger
-- and balances atomically after verifying provider callbacks. The app cannot
-- credit itself, top up, withdraw or use wallet funds with this schema alone.
create table if not exists public.wallet_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance_ugx numeric(14,0) not null default 0 check (balance_ugx >= 0),
  is_active boolean not null default false
);
create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_reference text unique,
  description text not null,
  amount_ugx numeric(14,0) not null check (amount_ugx <> 0),
  created_at timestamptz not null default now()
);

alter table public.customer_places enable row level security;
alter table public.customer_preferences enable row level security;
alter table public.support_requests enable row level security;
alter table public.ride_reviews enable row level security;
alter table public.wallet_accounts enable row level security;
alter table public.wallet_transactions enable row level security;

drop policy if exists customer_places_owner on public.customer_places;
create policy customer_places_owner on public.customer_places for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists customer_preferences_owner on public.customer_preferences;
create policy customer_preferences_owner on public.customer_preferences for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists support_requests_read_own on public.support_requests;
create policy support_requests_read_own on public.support_requests for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists support_requests_insert_own on public.support_requests;
create policy support_requests_insert_own on public.support_requests for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'open' and response is null);
drop policy if exists ride_reviews_read_own on public.ride_reviews;
create policy ride_reviews_read_own on public.ride_reviews for select to authenticated
  using (passenger_id = (select auth.uid()));
drop policy if exists wallet_accounts_read_own on public.wallet_accounts;
create policy wallet_accounts_read_own on public.wallet_accounts for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists wallet_transactions_read_own on public.wallet_transactions;
create policy wallet_transactions_read_own on public.wallet_transactions for select to authenticated
  using (user_id = (select auth.uid()));

grant select,insert,update,delete on public.customer_places,public.customer_preferences to authenticated;
grant select,insert on public.support_requests to authenticated;
revoke update,delete on public.support_requests from authenticated;
grant select on public.ride_reviews,public.wallet_accounts,public.wallet_transactions to authenticated;
revoke insert,update,delete on public.ride_reviews,public.wallet_accounts,public.wallet_transactions from authenticated,anon;
grant all on public.customer_places,public.customer_preferences,public.support_requests,public.ride_reviews,public.wallet_accounts,public.wallet_transactions to service_role;

create or replace function public.submit_ride_review(p_ride_id uuid,p_rating integer,p_comment text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare selected_ride public.rides%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in to rate your trip.'; end if;
  if p_rating is null or p_rating not between 1 and 5 or char_length(coalesce(p_comment,'')) > 500 then
    raise exception 'Enter a rating from 1 to 5 and a comment of at most 500 characters.';
  end if;
  select r.* into selected_ride from public.rides r
    where r.id = p_ride_id and r.passenger_id = auth.uid() and r.status::text = 'completed';
  if not found then raise exception 'You can only rate your own completed ride.'; end if;
  insert into public.ride_reviews(ride_id,passenger_id,driver_id,rating,comment)
    values (p_ride_id,auth.uid(),selected_ride.driver_id,p_rating,coalesce(p_comment,''))
    on conflict (ride_id) do update set rating = excluded.rating,comment = excluded.comment;
end;
$$;
revoke all on function public.submit_ride_review(uuid,integer,text) from public,anon;
grant execute on function public.submit_ride_review(uuid,integer,text) to authenticated;

create index if not exists customer_places_user_created_idx on public.customer_places(user_id,created_at desc);
create index if not exists support_requests_user_created_idx on public.support_requests(user_id,created_at desc);
create index if not exists wallet_transactions_user_created_idx on public.wallet_transactions(user_id,created_at desc);
create index if not exists rides_passenger_requested_idx on public.rides(passenger_id,requested_at desc);
create index if not exists deliveries_sender_requested_idx on public.deliveries(sender_id,requested_at desc);


-- FastRide: private, user-owned profile pictures. Safe to run again.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_path text;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_avatar_own_folder' AND conrelid = 'public.profiles'::regclass) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_avatar_own_folder
      CHECK (avatar_path IS NULL OR split_part(avatar_path, '/', 1) = id::text);
  END IF;
END $$;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-photos', 'profile-photos', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "FastRide own profile photo read" ON storage.objects;
CREATE POLICY "FastRide own profile photo read" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
DROP POLICY IF EXISTS "FastRide own profile photo upload" ON storage.objects;
CREATE POLICY "FastRide own profile photo upload" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
DROP POLICY IF EXISTS "FastRide own profile photo delete" ON storage.objects;
CREATE POLICY "FastRide own profile photo delete" ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);


COMMIT;

