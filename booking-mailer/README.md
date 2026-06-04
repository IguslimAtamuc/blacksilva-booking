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
npx wrangler deploy
```

`wrangler deploy` prints a URL like:

```
https://blacksilva-mailer.<your-account>.workers.dev
```

## Connect it to the website

Open `polished/index.html`, find this line near the booking code:

```js
var BOOKING_API="";
```

and paste the Worker URL:

```js
var BOOKING_API="https://blacksilva-mailer.<your-account>.workers.dev";
```

Commit + push. From then on, every confirmed + paid booking emails both of you
automatically.

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
