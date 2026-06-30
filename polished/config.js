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
   • BOOKING_API — your Cloudflare Worker URL. Setting this turns on REAL card
                   payments + automatic emails (see booking-mailer/README.md).
                   When set, the Worker sends the emails, so you can leave
                   RESEND_KEY blank here.

   ⚠️ STRIPE: put ONLY the publishable key (pk_...) here — it is public/safe.
   The Stripe SECRET key (sk_...) goes on the Worker, never in this file:
       wrangler secret put STRIPE_SECRET
   Use matching modes: pk_live_ with sk_live_ (real money), or pk_test_ with
   sk_test_ (testing with card 4242 4242 4242 4242).
   ============================================================================ */
window.BS_CONFIG = {
  STRIPE_PK   : '',   // pk_live_... (real) or pk_test_...  — publishable key only
  // ⚠️ RESEND_KEY here does NOT send emails on a live website — browsers block
  //    direct calls to Resend (CORS). Emails are sent ONLY by the Worker. Put
  //    your Resend key on the Worker instead:  wrangler secret put RESEND_API_KEY
  RESEND_KEY  : '',   // leave '' — not used in the browser
  RESEND_FROM : '',   // (optional)
  OWNER_EMAIL : '',   // 'you@your-domain.com'
  BOOKING_API : ''    // ← THE IMPORTANT ONE: your Worker URL. Enables emails + real payments.
};
