# al_atheer

A new Flutter project.

## Accounts and password recovery

The sign-in screen supports reader account registration and sign-in. New accounts
are regular readers; only accounts whose `profiles.is_admin` value is explicitly
set to `true` can open the publishing dashboard or see the Archive.org S3
settings. S3 credentials are saved on the current app installation and remain
available between launches; administrators can edit them from Settings.

The app includes a password recovery screen at `/password-recovery`. On web,
the recovery email returns to the same origin that sent the request, and the
Supabase Flutter client opens that screen after it processes the recovery
session. A request sent while running at `localhost` will therefore link back
to `localhost`; send reset emails from the deployed app when testing production
links.

To enable password-reset links:

1. In Supabase **Authentication → URL Configuration**, add
   `al-atheer://reset-password` to the redirect URL allow list.
2. Set Supabase **Site URL** to the deployed web app origin and add that exact
   origin to the redirect URL allow list. Keep local development origins there
   only for local testing.
3. Configure the Supabase recovery email template to use its normal recovery
   confirmation link (`{{ .ConfirmationURL }}`), which returns the recovery
   session to the redirect URL requested by the app.

The Android app registers the `al-atheer://reset-password` callback. This client
route check is not a substitute for Supabase authorization: keep Row Level
Security enabled and ensure insert, update, and delete policies for publishing
tables require an administrator role. S3 credentials are client-side credentials;
for stronger protection than hiding their controls in the UI, proxy uploads
through a trusted server or Supabase Edge Function rather than distributing
credentials to a client app.

## Supabase reset and setup

Before using photo uploads or mixed-media posts, run the non-destructive
[`supabase_resource_attachments.sql`](./supabase_resource_attachments.sql)
migration in the Supabase SQL Editor. It adds a JSONB attachment list to
`public.resources` and allows the `image` and `post` resource types. Each
attachment is uploaded to Internet Archive and stored with its media type,
filename, and direct URL.

[`supabase_reset_setup.sql`](./supabase_reset_setup.sql) is a **destructive
reset** for this app's database objects. It deletes existing rows and recreates
`public.profiles`, `public.admin_email_invites`, `public.categories`, and
`public.resources`, along with the required policies, signup trigger, and
admin/profile RPCs. Back up any records you need before running it in the
Supabase SQL Editor.

The script does not delete Supabase Auth users, Storage buckets/files, or
unrelated tables. After running it, create/sign in to the first account in the
app and promote it by running the script's final commented SQL statement with
that account's email. That first administrator can then add other administrators
from Settings. The SQL must be run manually in your Supabase project.

If the app reports that the profile update RPC is missing when saving a name,
run the non-destructive [`supabase_profile_update.sql`](./supabase_profile_update.sql)
in the Supabase SQL Editor. It only replaces the name update function and its
permissions; it does not reset tables or delete data.

To share Archive.org S3 credentials between administrator sign-ins/devices,
run [`supabase_archive_credentials.sql`](./supabase_archive_credentials.sql)
once in the Supabase SQL Editor. It creates an admin-only table. The app keeps
an installation cache for offline uploads, while Supabase is the shared source
after the migration is installed.

In **إدارة درر اليوم**, administrators select the curated quotes used by the
daily quote card. To enable date scheduling, run
[`supabase_daily_quote_schedule.sql`](./supabase_daily_quote_schedule.sql)
once in the Supabase SQL Editor. A scheduled quote takes precedence on its
date; unscheduled dates use the checked quotes, without repeating a quote
until the current random cycle is exhausted. Text resources published in the
library are not used as daily quotes.

## Categories, Azkar, and scheduled reminders

The admin category manager supports renaming a category and updates the
category value on all library resources and Azkar in the same database
transaction. Existing posts remain editable and deletable from the resource
list; their text, metadata, cover, and attachment links can also be edited.

Administrators can create and manage Azkar reminders from the dashboard and
assign them to an existing category. Each reminder includes its content,
source/details, repetition count, category, and scheduled date/time. The
Supabase project must provide the `azkar` and `web_push_subscriptions` tables,
their required row-level security policies, and the protected
`rename_category` function. Their SQL setup is not included in this repository.

On Android and iOS, users must enable reminders on the Azkar page and grant
notification permission. Upcoming reminders are scheduled locally on that
device. The app synchronizes the schedule when it is opened; a new reminder
added after a device has gone offline will be scheduled the next time that app
opens. The sound toggle in Settings updates pending local reminders.

Closed-tab web push additionally requires:

1. Enable Push API support by generating VAPID keys (for example with
   `npx web-push generate-vapid-keys`), then deploy
   `supabase/functions/dispatch-azkar` with the `VAPID_PUBLIC_KEY`,
   `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, and a strong `DISPATCH_SECRET`
   configured as Supabase function secrets.
2. Build the Flutter web app with the public key:
   `--dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=<VAPID_PUBLIC_KEY>`.
3. Configure a trusted scheduler to invoke the Edge Function every minute.
4. Signed-in web users must opt in to notifications on the Azkar page. Web
   notifications use the browser/operating-system notification sound; the
   Settings sound toggle marks web pushes silent when sound is disabled.

The browser must support Web Push and the deployed site must use HTTPS. The
Edge Function setup is required for delivery while the website is closed; the
Flutter app itself cannot wake a closed browser tab.

## App and website branding

Run [`supabase/app_branding_setup.sql`](./supabase/app_branding_setup.sql) in
the Supabase SQL Editor. It creates the public branding record and a public
logo bucket with administrator-only writes. Administrators can edit the Arabic
and English app names and upload a PNG, JPEG, or WebP logo (up to 5 MB) from
Settings. The branding updates in the app and website; the website tab title,
favicon, and manifest are updated when the app loads. The installed Android/iOS
launcher name and icon remain build-time platform settings and do not change
from an admin upload.

## Writer biography sections

Run [`supabase_writer_sections.sql`](./supabase_writer_sections.sql) in the
Supabase SQL Editor before using the dynamic writer page. It adds an ordered
JSONB sections field to the publicly readable writer profile and an
administrator-only save function. Each section has an admin-defined title and
body; existing biography text is retained and displayed as a legacy section.
