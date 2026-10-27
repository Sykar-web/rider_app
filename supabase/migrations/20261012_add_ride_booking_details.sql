-- FastRide: store the extra details collected for car, van, and bus bookings.
-- Run this in Supabase SQL Editor before releasing the updated app.

alter table public.rides
  add column if not exists booking_details jsonb not null default '{}'::jsonb,
  add column if not exists booking_reference text,
  add column if not exists reservation_type text,
  add column if not exists seat_number text;

create unique index if not exists rides_booking_reference_unique
  on public.rides (booking_reference)
  where booking_reference is not null;

-- Existing bus rows may not have a reservation type, so this is not validated
-- against historical data. New FastRide clients send either an individual
-- seat or a whole-bus reservation.
alter table public.rides
  drop constraint if exists rides_bus_reservation_details;

alter table public.rides
  add constraint rides_bus_reservation_details
  check (
    vehicle_type is distinct from 'bus'
    or reservation_type is null
    or (
      reservation_type = 'whole_bus' and seat_number is null
    )
    or (
      reservation_type = 'individual' and seat_number is not null
    )
  ) not valid;
