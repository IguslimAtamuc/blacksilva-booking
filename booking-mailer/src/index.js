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
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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
function giftBlock(b){
  if(!b.redeemCode) return "";
  const exp = b.redeemExpiry ? new Date(b.redeemExpiry) : new Date(Date.now()+14*86400000);
  const expLabel = exp.toLocaleDateString("en-GB",{day:"2-digit",month:"short",year:"numeric"});
  return '<div style="margin:22px 0; padding:22px; background:#0a0806; color:#f4ecdc; border:1px solid #d8b878; border-radius:14px; text-align:center">' +
    '<p style="font-size:11px; letter-spacing:.34em; text-transform:uppercase; color:#a0826a; margin:0">Gift this haircut</p>' +
    '<p style="font-size:32px; letter-spacing:.22em; font-weight:700; margin:10px 0 6px; font-family:Courier,monospace; color:#e8c478">' + esc2(b.redeemCode) + '</p>' +
    '<p style="font-size:13px; color:#cfc1a0; line-height:1.5; margin:0">Share this code with a friend. <b style="color:#f4ecdc">Single use</b> — valid until <b style="color:#f4ecdc">' + esc2(expLabel) + '</b>.</p>' +
  '</div>';
}
function supportBlock(){
  return '<div style="margin:22px 0 4px; padding:18px 20px; background:#f7f5f0; border:1px solid #e7e2d4; border-radius:14px">' +
    '<p style="font-size:11px; letter-spacing:.3em; text-transform:uppercase; color:#888; margin:0">Contact support</p>' +
    '<p style="margin:8px 0 14px; font-size:13.5px; color:#444; line-height:1.55">For a <b>faster reply we recommend Instagram</b> — email may take a little longer.</p>' +
    '<a href="https://www.instagram.com/blacksilvahd/?hl=da" style="display:inline-block; padding:11px 18px; background:#16161a; color:#fff; text-decoration:none; border-radius:10px; font-weight:700; font-size:13px; margin:0 8px 6px 0">Open Instagram (fastest)</a>' +
    '<a href="mailto:blacksilvahd@gmail.com" style="display:inline-block; padding:11px 18px; background:transparent; color:#16161a; text-decoration:none; border:1px solid #16161a; border-radius:10px; font-weight:700; font-size:13px">Email us</a>' +
  '</div>';
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
    giftBlock(b) +
    supportBlock() +
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

/* ============================================================
 * Reviews API (stored in the REVIEWS KV namespace, shared by all visitors)
 *   GET  /reviews         -> { threads: [...] }
 *   POST /reviews         -> add a visit to a guest's thread (keyed by email)
 *   POST /reviews/reply   -> salon reply (needs the OWNER_KEY passcode)
 * Raw emails are never stored — only a hash that lets a returning guest
 * continue the same thread.
 * ============================================================ */
function rhash(s){ s=String(s||"").trim().toLowerCase(); let h=5381; for(let i=0;i<s.length;i++){ h=((h<<5)+h)+s.charCodeAt(i); h|=0; } return "c"+(h>>>0).toString(36); }
function ruid(){ return Date.now().toString(36)+Math.random().toString(36).slice(2,7); }
function clip(s,n){ return String(s==null?"":s).slice(0,n); }
async function loadThreads(env){ if(!env.REVIEWS) return []; try{ const s=await env.REVIEWS.get("all"); return s?JSON.parse(s):[]; }catch(e){ return []; } }
async function saveThreads(env,arr){ await env.REVIEWS.put("all", JSON.stringify(arr)); }

async function listReviews(env){ const t=await loadThreads(env); return json({ threads:t }); }
async function addReview(request,env){
  if(!env.REVIEWS) return json({ error:"Reviews storage (KV namespace REVIEWS) is not configured." }, 500);
  let p; try{ p=await request.json(); }catch(e){ return json({ error:"invalid JSON" }, 400); }
  if(!p.email || String(p.email).indexOf("@")<1) return json({ error:"email required" }, 400);
  if(!p.rating) return json({ error:"rating required" }, 400);
  const all=await loadThreads(env), eh=rhash(p.email), now=Date.now();
  let th=all.find(t=>t.emailHash===eh);
  if(!th) th={ id:ruid(), name:clip(p.name,40)||"Guest", emailHash:eh, created:now, posts:[] };
  const visit=th.posts.filter(x=>x.role==="client").length+1;
  th.posts.push({ role:"client", visit, rating:Math.max(1,Math.min(5,+p.rating||0)), service:clip(p.service,60), stylist:clip(p.stylist,40),
    experience:clip(p.experience,800), recommend:(p.recommend==="no"?"no":"yes"), compare:clip(p.compare,800), text:clip(p.text,800), ts:now });
  th.name=clip(p.name,40)||th.name; th.updated=now;
  const rest=all.filter(t=>t.id!==th.id); rest.unshift(th);
  await saveThreads(env, rest.slice(0,500));
  return json({ ok:true, thread:th, visit });
}
async function replyReview(request,env){
  if(!env.REVIEWS) return json({ error:"Reviews storage is not configured." }, 500);
  let p; try{ p=await request.json(); }catch(e){ return json({ error:"invalid JSON" }, 400); }
  if(!env.OWNER_KEY || p.passcode!==env.OWNER_KEY) return json({ error:"Wrong staff passcode." }, 403);
  const all=await loadThreads(env), th=all.find(t=>t.id===p.threadId);
  if(!th) return json({ error:"thread not found" }, 404);
  th.posts.push({ role:"salon", text:clip(p.text,800), ts:Date.now() }); th.updated=Date.now();
  await saveThreads(env, all);
  return json({ ok:true, thread:th });
}

/* ============================================================
 * Redeem codes (gift-this-haircut)
 *   POST /codes/issue   { code, email, name, expiresAt }   -> persist
 *   POST /codes/redeem  { code }                            -> verify + mark used
 * Stored in CODES KV namespace (one entry per code).
 * ============================================================ */
async function codeIssue(request,env){
  if(!env.CODES) return json({ error:"CODES KV namespace not configured." }, 500);
  let p; try{ p=await request.json(); }catch(e){ return json({ error:"invalid JSON" }, 400); }
  const code=String(p.code||"").toUpperCase().replace(/[^A-Z0-9-]/g,"").slice(0,12);
  if(!code) return json({ error:"code required" }, 400);
  const exp = +p.expiresAt || (Date.now()+14*86400000);
  await env.CODES.put(code, JSON.stringify({ code, email:clip(p.email,80), name:clip(p.name,40), issuedAt:Date.now(), expiresAt:exp, used:false }), { expirationTtl: Math.max(60, Math.ceil((exp-Date.now())/1000)+86400) });
  return json({ ok:true, code });
}
async function codeRedeem(request,env){
  if(!env.CODES) return json({ error:"CODES KV namespace not configured." }, 500);
  let p; try{ p=await request.json(); }catch(e){ return json({ error:"invalid JSON" }, 400); }
  const code=String(p.code||"").toUpperCase().replace(/[^A-Z0-9-]/g,"").slice(0,12);
  if(!code) return json({ error:"code required" }, 400);
  const raw=await env.CODES.get(code); if(!raw) return json({ error:"Code not found" }, 404);
  let rec; try{ rec=JSON.parse(raw); }catch(e){ return json({ error:"corrupt record" }, 500); }
  if(rec.used) return json({ error:"Code already redeemed", at:rec.usedAt }, 409);
  if(Date.now()>rec.expiresAt) return json({ error:"Code expired" }, 410);
  rec.used=true; rec.usedAt=Date.now();
  await env.CODES.put(code, JSON.stringify(rec));
  return json({ ok:true, code:rec.code, issuedBy:rec.name||"", expiresAt:rec.expiresAt });
}

/* ============================================================
 * Stripe — create a PaymentIntent server-side (REAL card payments)
 *   POST /stripe/intent  { haircut, daysAhead, promo, service, email, name, when, stylist }
 * The amount is computed HERE from the same price rules as the site, so a
 * tampered browser can't change what it pays. The Stripe SECRET key lives only
 * as a Worker secret:   wrangler secret put STRIPE_SECRET
 * ============================================================ */
const PRICE_STEPS = [500, 450, 400, 375];   // short hair, by tier
const LONG_STEPS  = [650, 550, 450, 450];   // long hair, by tier
const PROMOS = { "BSV20-7421":20, "BSV20-3856":20, "BSV20-9134":20, "BSV20-5208":20, "BSV20-6677":20, "NEWBLACK100":100 };
function priceTier(d){ d = +d || 0; if (d < 7) return 0; if (d < 14) return 1; if (d < 21) return 2; return 3; }
function calcAmount(haircut, daysAhead, promo){
  const base = (haircut === "lady" ? LONG_STEPS : PRICE_STEPS)[priceTier(daysAhead)];
  const pct = PROMOS[String(promo || "").toUpperCase().replace(/\s+/g, "")] || 0;
  return Math.max(0, Math.round(base * (100 - pct) / 100));   // DKK (major units)
}
async function createIntent(request, env){
  if (!env.STRIPE_SECRET) return json({ error: "STRIPE_SECRET secret is not set on the Worker." }, 500);
  let p; try { p = await request.json(); } catch (e) { return json({ error: "invalid JSON" }, 400); }
  const amount = calcAmount(p.haircut, p.daysAhead, p.promo);
  if (amount <= 0) return json({ free: true, amount: 0 });        // 100%-off voucher → nothing to charge
  const body = new URLSearchParams();
  body.set("amount", String(amount * 100));                      // minor units (øre)
  body.set("currency", "dkk");
  body.set("automatic_payment_methods[enabled]", "true");
  body.set("description", (p.service || "Haircut") + " — Black Silva");
  if (p.email) body.set("receipt_email", p.email);
  body.set("metadata[stylist]", p.stylist || "");
  body.set("metadata[when]", p.when || "");
  body.set("metadata[client]", p.name || "");
  if (p.promo) body.set("metadata[promo]", String(p.promo));
  const r = await fetch("https://api.stripe.com/v1/payment_intents", {
    method: "POST",
    headers: { "Authorization": "Bearer " + env.STRIPE_SECRET, "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  let d = {}; try { d = await r.json(); } catch (e) {}
  if (!r.ok || !d.client_secret) return json({ error: (d && d.error && d.error.message) || "Stripe error" }, 502);
  return json({ client_secret: d.client_secret, amount });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: cors() });

    // ---- Stripe (real card payments) ----
    if (url.pathname === "/stripe/intent" && request.method === "POST") return createIntent(request, env);

    // ---- Reviews API ----
    if (url.pathname === "/reviews" && request.method === "GET")  return listReviews(env);
    if (url.pathname === "/reviews" && request.method === "POST") return addReview(request, env);
    if (url.pathname === "/reviews/reply" && request.method === "POST") return replyReview(request, env);

    // ---- Redeem-code API ----
    if (url.pathname === "/codes/issue" && request.method === "POST") return codeIssue(request, env);
    if (url.pathname === "/codes/redeem" && request.method === "POST") return codeRedeem(request, env);

    // ---- Booking mailer (default) ----
    if (request.method !== "POST") return json({ error: "POST only" }, 405);
    if (!env.RESEND_API_KEY) return json({ error: "RESEND_API_KEY secret is not set" }, 500);

    let b;
    try { b = await request.json(); } catch (e) { return json({ error: "invalid JSON" }, 400); }
    if (!b.startISO) b.startISO = new Date().toISOString();
    /* if the site didn't carry a code, mint one now and persist it */
    if (!b.redeemCode) {
      const A="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; let s="";
      const buf = new Uint8Array(8); crypto.getRandomValues(buf);
      for (let i=0;i<8;i++) s += A[buf[i]%A.length];
      b.redeemCode = s.slice(0,4)+"-"+s.slice(4,8);
      b.redeemExpiry = Date.now()+14*86400000;
      if (env.CODES) { try{ await env.CODES.put(b.redeemCode, JSON.stringify({ code:b.redeemCode, email:b.email||"", name:b.name||"", issuedAt:Date.now(), expiresAt:b.redeemExpiry, used:false }), { expirationTtl: 15*86400 }); }catch(e){} }
    }

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
