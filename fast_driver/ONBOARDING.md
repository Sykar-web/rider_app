# Driver onboarding (screens 1–7)

Implemented: branded splash; welcome; email signup with phone and password confirmation;
login and password reset; Google/Apple OAuth launch; required document selection;
vehicle form; editable review and submission; pending-review screen.

## Setup

1. Restore/install a Flutter SDK compatible with pubspec.yaml. The saved SDK path
   C:\Users\USER\Desktop\flutter is missing on this machine.
2. Run flutter pub get, dart format lib test, flutter analyze, and flutter test.
   The new file_picker dependency is in pubspec.yaml; the lockfile is not regenerated yet.
3. Run supabase/driver_documents.sql once in your existing Supabase project's SQL editor.
   This creates a private storage bucket and access policies for each driver's folder.
4. Enable Google and Apple providers if you want social login, and configure permitted
   web/mobile redirect URLs. Existing mobile callback: io.supabase.fastdriver://login-callback.
   Configure password recovery redirects to return to the app as well.
5. Test with a new email account. Confirm email if required, log in, attach three files,
   fill vehicle details, edit the review, submit, and restart to verify the pending state.

## Behavior and limits

Email remains required: the existing auth service uses email/password; phone is contact
information. This differs from the reference's optional email and phone-login label.
The illustration and vehicle art use local Flutter vectors rather than the exact photo art.
Documents stay in memory until submission; leaving/restarting before submission discards
that draft. Successfully submitted applications persist in user metadata and private storage.
Personal details on review start from the signed-in account and can be edited. Vehicle and document details
can be edited before submission. Client application data is not trusted authorization.

New email accounts and social sign-ins go through onboarding. Existing email accounts
without the onboarding flag keep their current home access. A trusted administrator may
set app_metadata.driver_approved = true to allow a reviewed driver into the home screen.
A full admin approval interface and server enforcement of ride eligibility are outside
this UI change. Never grant approval using editable user_metadata.

No live backend changes, document uploads, or account registrations were performed.
Flutter analyze, tests, and device visual checks could not run because no Flutter/Dart
executable is available. The UI should be reviewed on a device after setup.

