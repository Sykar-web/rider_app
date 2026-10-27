-- FastRide UI board: additive customer features. Run as the project owner in
-- Supabase SQL Editor. Existing rides/profiles/deliveries must already exist.
-- This migration deliberately does not seed money, prices, drivers or ratings.
begin;

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
commit;
