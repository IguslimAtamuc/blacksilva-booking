/*
 * Black Silva — booking mailer (Cloudflare Worker)
 *
 * Receives a booking from the static site and sends TWO confirmation emails
 * through Resend, each with an .ics calendar attachment:
 *   1. the salon owner  (blacksilvahd@gmail.com)
 *   2. the client       (the email they booked with)
 *
 * The Resend API key is read from the RESEND_API_KEY secret — it is NEVER
 * stored in the repository or sent to the browser.
 *   wrangler secret put RESEND_API_KEY
 */

const OWNER = "blacksilvahd@gmail.com";
// With an unverified domain Resend only delivers from this address AND only to
// the Resend account owner. To email real clients, verify a domain at
// https://resend.com/domains and change FROM to e.g. "Black Silva <booking@yourdomain.com>".
const FROM = "Black Silva <onboarding@resend.dev>";
const SALON = "Black Silva Hairdresser, Badstuestræde 16, Copenhagen";
const ALLOW = "*"; // tighten to "https://iguslimatamuc.github.io" once it works

function cors(extra = {}) {
  return Object.assign({
    "Access-Control-Allow-Origin": ALLOW,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  }, extra);
}
function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: cors({ "Content-Type": "application/json" }) });
}

function pad(n) { return String(n).padStart(2, "0"); }
function icsStamp(d) {
  return d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) +
    "T" + pad(d.getUTCHours()) + pad(d.getUTCMinutes()) + "00Z";
}
function esc(s) {
  return String(s || "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
}
function b64(str) { return btoa(unescape(encodeURIComponent(str))); }

function addons(b) { return (b.addons && b.addons.length) ? b.addons.join(", ") : "None"; }
function total(b) { return (b.price != null ? b.price : "") + " " + (b.currency || "DKK"); }
function when(b) { return (b.dateLabel || "") + " · " + (b.time || ""); }

function buildICS(b) {
  const start = new Date(b.startISO);
  const end = new Date(start.getTime() + (b.durationMin || 60) * 60000);
  const desc = "Stylist: " + b.stylist + "\nExtras: " + addons(b) + "\nTotal: " + total(b);
  return [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Black Silva//Booking//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    "UID:" + Date.now() + "@blacksilva",
    "DTSTAMP:" + icsStamp(new Date()),
    "DTSTART:" + icsStamp(start),
    "DTEND:" + icsStamp(end),
    "SUMMARY:" + esc((b.service || "Haircut") + " — Black Silva"),
    "DESCRIPTION:" + esc(desc),
    "LOCATION:" + esc(b.location || SALON),
    "STATUS:CONFIRMED",
    "BEGIN:VALARM", "TRIGGER:-PT2H", "ACTION:DISPLAY", "DESCRIPTION:Black Silva appointment", "END:VALARM",
    "END:VEVENT", "END:VCALENDAR",
  ].join("\r\n");
}

function gcalLink(b) {
  const s = new Date(b.startISO);
  const e = new Date(s.getTime() + (b.durationMin || 60) * 60000);
  const text = encodeURIComponent((b.service || "Haircut") + " — Black Silva");
  const details = encodeURIComponent("Stylist: " + b.stylist + "\nExtras: " + addons(b) + "\nTotal: " + total(b));
  const loc = encodeURIComponent(b.location || SALON);
  return "https://www.google.com/calendar/render?action=TEMPLATE&text=" + text +
    "&dates=" + icsStamp(s) + "/" + icsStamp(e) + "&details=" + details + "&location=" + loc;
}

function row(label, value) {
  return '<tr><td style="padding:6px 14px 6px 0;color:#777;white-space:nowrap">' + label +
    '</td><td style="padding:6px 0;color:#16161a;font-weight:600">' + value + "</td></tr>";
}
function shell(title, intro, b, glink) {
  return '<div style="font-family:Arial,Helvetica,sans-serif;max-width:540px;margin:0 auto;color:#16161a">' +
    '<h2 style="font-family:Georgia,serif;font-weight:600;margin:0 0 4px">' + title + "</h2>" +
    '<p style="color:#444;line-height:1.5">' + intro + "</p>" +
    '<table style="border-collapse:collapse;margin:14px 0;font-size:15px">' +
      row("Service", esc2(b.service)) +
      row("Extras", esc2(addons(b))) +
      row("Stylist", esc2(b.stylist)) +
      row("When", esc2(when(b))) +
      row("Client", esc2((b.name || "Guest") + (b.email ? " · " + b.email : ""))) +
      row("Total", esc2(total(b))) +
    "</table>" +
    '<a href="' + glink + '" style="display:inline-block;background:#16161a;color:#fff;text-decoration:none;' +
      'padding:12px 20px;border-radius:10px;font-weight:700;font-size:14px">Add to Google Calendar</a>' +
    '<p style="color:#888;font-size:13px;margin-top:16px">A calendar file (.ics) is attached — open it on your ' +
      'phone to add the appointment to your calendar.</p>' +
    '<p style="color:#aaa;font-size:12px;margin-top:18px">Black Silva Hairdresser · ' + SALON + "</p>" +
    "</div>";
}
function esc2(s) { return String(s == null ? "" : s).replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

async function send(env, to, subject, html, ics) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": "Bearer " + env.RESEND_API_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: FROM,
      to: [to],
      subject,
      html,
      attachments: [{ filename: "black-silva-booking.ics", content: b64(ics) }],
    }),
  });
  let data = {};
  try { data = await res.json(); } catch (e) { /* ignore */ }
  return { ok: res.ok, status: res.status, data };
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: cors() });
    if (request.method !== "POST") return json({ error: "POST only" }, 405);
    if (!env.RESEND_API_KEY) return json({ error: "RESEND_API_KEY secret is not set" }, 500);

    let b;
    try { b = await request.json(); } catch (e) { return json({ error: "invalid JSON" }, 400); }
    if (!b.startISO) b.startISO = new Date().toISOString();

    const ics = buildICS(b);
    const glink = gcalLink(b);
    const results = {};

    results.owner = await send(
      env, OWNER,
      "New booking — " + (b.name || "Guest") + " · " + when(b),
      shell("New booking · Black Silva",
        "<b>" + esc2(b.name || "A guest") + "</b> just booked an appointment with you.", b, glink),
      ics
    );

    if (b.email && b.email.indexOf("@") > 0) {
      results.client = await send(
        env, b.email,
        "Your Black Silva booking is confirmed",
        shell("Booking confirmed",
          "Thank you, <b>" + esc2(b.name || "guest") + "</b>! Your appointment at Black Silva is set. " +
          "We look forward to seeing you.", b, glink),
        ics
      );
    }

    const ok = results.owner.ok && (!results.client || results.client.ok);
    return json({ ok, results }, ok ? 200 : 502);
  },
};
