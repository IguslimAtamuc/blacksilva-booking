/* ============================================================================
   BLACK SILVA — KEYS / SETTINGS  (edit this one file, nothing else)
   ----------------------------------------------------------------------------
   Put your keys between the quotes. Leave a value as '' to keep it off.
   After editing, just re-upload this file to your host (public_html).

   WHERE TO GET EACH KEY:
   • STRIPE_PK   — Stripe Dashboard → Developers → API keys → "Publishable key".
                   Starts with pk_live_... (real) or pk_test_... (testing).
                   This key is SAFE to put here (it is public by design).
   • RESEND_KEY  — Resend.com → API Keys. Used to send the booking / cancel
                   emails. Starts with re_...
   • RESEND_FROM — the "From" address Resend is allowed to send from
                   (e.g. 'Black Silva <booking@your-domain.com>').
   • OWNER_EMAIL — where YOU receive the "new booking" notifications.
   • BOOKING_API — leave '' unless you run the optional Cloudflare Worker.

   ⚠️ IMPORTANT — Stripe SECRET key (sk_live_…):
   NEVER put the Stripe SECRET key in this file. Anyone could read it and take
   money from your account. The secret key belongs on a server only. Tell me
   when you want real card payments and I'll set up the tiny secure endpoint.
   ============================================================================ */
window.BS_CONFIG = {
  STRIPE_PK   : '',   // pk_live_... or pk_test_...  (leave '' to keep the built-in test key)
  RESEND_KEY  : '',   // re_...                      (leave '' to keep the built-in test key)
  RESEND_FROM : '',   // 'Black Silva <booking@your-domain.com>'
  OWNER_EMAIL : '',   // 'you@your-domain.com'
  BOOKING_API : ''    // optional Cloudflare Worker URL
};
