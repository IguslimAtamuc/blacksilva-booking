# Black Silva — booking mailer

A tiny Cloudflare Worker that sends two confirmation emails (with an `.ics`
calendar attachment) every time a client confirms and pays on the website:

1. **You** (`blacksilvahd@gmail.com`) — "New booking from …" + add to calendar
2. **The client** — "Your Black Silva booking is confirmed" + add to calendar

The Resend API key lives **only** as a Worker secret. It is never committed to
the repo and never sent to the browser.

---

## One-time deploy (≈ 3 minutes)

You need [Node.js](https://nodejs.org) installed.

```bash
cd booking-mailer
npm install                       # installs wrangler locally
npx wrangler login                # opens the browser, log into Cloudflare (free)
npx wrangler secret put RESEND_API_KEY
# → paste your NEW Resend key when prompted (the old one was shared in chat — rotate it!)
npx wrangler secret put STRIPE_SECRET
# → paste your Stripe SECRET key: sk_live_... for REAL money, or sk_test_... to test
npx wrangler deploy
```

`wrangler deploy` prints a URL like:

```
https://blacksilva-mailer.<your-account>.workers.dev
```

## Connect it to the website

Open **`config.js`** (next to `index.html`) and paste the Worker URL +
your Stripe **publishable** key:

```js
window.BS_CONFIG = {
  STRIPE_PK   : 'pk_live_...',   // Stripe → Developers → API keys → Publishable key
  BOOKING_API : 'https://blacksilva-mailer.<your-account>.workers.dev',
  // RESEND_KEY left blank — the Worker sends the emails now
};
```

Re-upload `config.js`. From then on:
* every confirmed booking emails you + the client automatically, and
* **real card payments** go through the Worker (the Stripe secret never touches
  the website). The amount is recomputed on the server, so it can't be tampered.

> Use matching modes: `pk_live_` ↔ `sk_live_` for real money, or
> `pk_test_` ↔ `sk_test_` to test with card `4242 4242 4242 4242`.

---

## Emailing real clients (important)

With the default `from: onboarding@resend.dev`, Resend will only deliver to the
email address that owns the Resend account (so it can email you fine for
testing). To email **any** client:

1. Add and verify your domain at <https://resend.com/domains>.
2. In `src/index.js` change `FROM` to e.g. `Black Silva <booking@yourdomain.com>`.
3. `npx wrangler deploy` again.

## Test it

`curl` a fake booking (replace the URL):

```bash
curl -X POST https://blacksilva-mailer.<your-account>.workers.dev \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test Client","email":"blacksilvahd@gmail.com","service":"Gentleman'\''s Haircut","addons":["Hair Wash"],"stylist":"Eduard","dateLabel":"Thursday 4 Jun","time":"13:00","startISO":"2026-06-04T11:00:00.000Z","durationMin":70,"price":500,"currency":"DKK"}'
```

You should receive the email within a few seconds.
