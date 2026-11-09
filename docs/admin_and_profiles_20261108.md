# FastRide admin and profile update

## Supabase setup

Open `supabase/fast_ride_admin_setup.sql` locally and run the entire file in the
Supabase SQL Editor as the database owner. It includes shared profile photos,
driver applications, protected administration and request cleanup. The existing
FastRide `profiles`, `rides`, and `deliveries` tables must already exist.

The combined file contains a private salted PIN verifier and is ignored by Git.
Do not publish it. Public migration files contain no configured PIN/verifier.
Re-running the combined file preserves the verifier and existing accounts.
Sign in using the verified administrator email supplied by the owner. The Admin
Dashboard entry appears only for that account; PIN entry is verified on the server.
The entry is also in its passenger profile so the owner can review applications
without first needing to approve their own driver account.

The script schedules `fastride-expire-unaccepted` using Supabase Cron. Check that
this job is active under Integrations > Cron after running the SQL. The SQL enables
pg_cron; if the project requires enabling it from the dashboard, enable that module
and rerun the file. Supabase's [Cron quickstart](https://supabase.com/docs/guides/cron/quickstart)
documents second-based intervals and the job history view.

## Administration

- Verified allowlisted account, four-digit PIN, five failed attempts followed by
  a 15-minute lockout, and 15-minute unlock bound to the current auth session.
- Every read and mutation checks the server unlock. The email visibility check
  grants no permissions. The PIN is not compiled into the Flutter app.
- Review applications and private uploaded documents; approve or reject with a
  reason. Approval changes trusted auth metadata and shared vehicle information.
  Drivers refresh their session from the application-status screen to enter mode.
- Suspend/restore approved driver access with a reason. Active jobs must first be
  finished or cancelled. Triggers check current server approval, including when
  an older token is used. No driver application is approved automatically.
- Review/cancel rides and deliveries with a reason. Overview shows actual records
  and recorded completed fares. Cash is the only connected payment option.
- Add/edit/pause bus companies and departures: ordinary/executive class, times,
  duration, capacity 1–80. Existing bookings prevent changes to their ticket's
  route/times/capacity. Pausing a booked departure remains possible.
- Reply to support requests, update their status, and inspect the audit trail.
  This dashboard does not process refunds or payment settlements.

## Profiles, artwork and pickup

Driver Profile contains its shared editable photo, name/email, Settings, restricted
admin entry, a prominent passenger-switch button and logout. The helper text below
the picture is removed. Personal and vehicle information are accessible through
Settings. The passenger switch is absent from Settings. Language, Help/Security
and About entries are removed from profile menus. Driver Settings also no longer
contains the activity-update preference. Active-trip safety controls remain.

Ocean-blue UI and Asap remain. Original full-colour cartoon assets
(`illustrated_*.png`) are bundled; uploaded photos are not tinted. Ocean recolours
remain on disk as unused alternatives. Home allows typing a pickup; late GPS
results cannot overwrite it. Manual pickup works without GPS permissions.

## Unaccepted requests

Cancelled requests with no accepted driver/courier are deleted immediately.
Unaccepted live requests expire three minutes after creation. Scheduled ride search
windows begin at scheduled pickup. Waiting screens ask the server to remove their
expired requests at the deadline. A server sweep removes abandoned requests within
ten seconds after the deadline even when the app is closed. Expired requests cannot
be accepted. Accepted/started/completed history is preserved. Offline cleanup
retries and does not pretend that deletion succeeded.

## Deployment limits

Database permissions/workflows were checked in isolated PostgreSQL; production
records were not changed. Live approvals, private document review and cleanup
require running the supplied SQL and checking real signed-in accounts. Local
database checks do not emulate Supabase Realtime, Storage signing or pg_cron.

The saved database checks are in `test/database`: run `npm install`, then
`npm test` there. They use a separate in-memory database and a dummy test PIN.
They never connect to the configured Supabase project. Flutter checks use
`flutter test` and `flutter analyze` from the app directory.
