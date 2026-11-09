# FastRide design integration — 8 November 2026

The active project is rider_app; lib/fast_driver is the driver mode in the same app.
The older fast_driver/ standalone project was not changed by this integration.

## Integrated behavior

- Shared sky-blue/white surfaces, blue actions, rounded cards and matching dialogs.
- Passenger tabs: Home, Activity, Payments, Profile. Help & safety is in Profile.
- Cartoon artwork on authentication and home; cartoon vehicles on all selection,
  scheduling and booking screens. Original image files remain on disk, but are
  excluded from the Flutter asset bundle. User-uploaded photos remain real photos.
- Driver Home is a dashboard. Trips holds rides, deliveries and history; Earnings
  and Profile have their own tabs. Active trips prevent mode switching, and the
  driver goes offline before returning to passenger mode.
- Profile → Become a Driver opens an application with the existing session;
  no second signup. Existing photo, name, phone and email are reused. Missing
  personal information, ID front/back, driving licence and vehicle information
  are collected. Uploads and drafts are saved; review precedes submission.
- Pending applicants can view their application and continue as passengers.
  Check approval status refreshes their session. Approval is server-controlled.

## Database setup

Run supabase/fast_ride_design_integration.sql in Supabase SQL Editor. It combines
the existing profile-photo setup and the new driver application migration. No
live database was modified by this code integration.

Applications are in public.driver_applications. For a reviewed pending applicant,
a trusted administrator can use SQL Editor:

```sql
select public.review_driver_application('APPLICANT-UUID'::uuid, true);
```

Use false to reject a pending application. The function is inaccessible to normal
app accounts. Approval copies vehicle type/plate to the shared profile and grants
the server-owned driver approval claim. The user then checks approval status.

## Artwork provenance

Generated with the built-in image generation tool. Project assets:
assets/branding/illustrated_{hero,bus,van,local}.png and
assets/vehicles/illustrated_{car,motorcycle,van,bus,tuktuk,bicycle}.png.

Prompt set: professional flat 2D cartoon Ugandan mobility illustrations, electric
blue/sky blue/navy with mint and orange, simplified expressive characters, no
photographic textures, no photo imitation, no text or logos. Hero: passenger,
driver, car and courier; service boards: family boarding bus, friends at a van,
helmeted motorcycle taxi driver/passenger with tuk-tuk and bicycle. Vehicle
template: single [vehicle], three-quarter side view, rounded cartoon proportions,
blue body/navy wheels/light-blue windows, tiny orange accent, fully visible and
centered on white, no rider, no lettering. The source generation prompts are also
recorded in this chat.

## Validation and limits

Validation completed: 30 Flutter tests passed; Dart analysis of lib and test
reported no issues; Android release APK and web release both built successfully.
The build outputs are build/app/outputs/flutter-apk/app-release.apk and build/web.

Widget tests use fake maps/backend data; they do not prove Google key restrictions,
real dispatch, or live database policies. Production checks still require the SQL
deployment, real passenger/driver accounts and devices. No real fares, reviews,
drivers or earnings were seeded by this work. Cash remains the payment method.
