"use strict";
// Interfata Roulette Lab. Fara framework si fara dependinte externe:
// tot ce vezi aici ruleaza offline, direct din biblioteca standard Python.

let state = null;
const $ = (id) => document.getElementById(id);
const PALETTE = ["#4f9cf9", "#f85149", "#3fb950", "#d29922", "#a371f7", "#db61a2"];

// ---------------------------------------------------------------- utilitare
function toast(message, isError) {
  const el = $("toast");
  el.textContent = message;
  el.className = "toast show" + (isError ? " err" : "");
  clearTimeout(el._t);
  el._t = setTimeout(() => { el.className = "toast"; }, 3600);
}

async function api(path, options) {
  const response = await fetch(path, options);
  const data = await response.json().catch(() => ({ error: "raspuns invalid de la server" }));
  if (!response.ok || data.error) throw new Error(data.error || `HTTP ${response.status}`);
  return data;
}

const post = (path, body) => api(path, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body || {}),
});

function busy(button, running) {
  button.disabled = running;
  if (running) {
    button._label = button.textContent;
    button.innerHTML = '<span class="spin"></span> se calculeaza...';
  } else if (button._label) {
    button.textContent = button._label;
  }
}

const esc = (s) => String(s).replace(/[&<>"]/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const pct = (x, d = 1) => (x * 100).toFixed(d) + "%";
const colorOf = (sym) => (state.colors && state.colors[sym]) ||
  PALETTE[state.symbols.indexOf(sym) % PALETTE.length];

// Culoarea unui simbol poate fi prea inchisa pentru text pe fundal inchis
// (ex. Negru = #2b2f3a devine ilizibil). Pentru TEXT, ridicam luminanta pana la
// un prag lizibil, pastrand nuanta. Pentru pastile si buline nu e nevoie,
// pentru ca acolo culoarea este fundalul, nu textul.
function textColorOf(sym) {
  const hex = colorOf(sym).replace("#", "");
  if (hex.length !== 6) return colorOf(sym);
  let [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16));
  const dark = !window.matchMedia("(prefers-color-scheme: light)").matches;
  const lum = () => (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  for (let i = 0; i < 24 && (dark ? lum() < 0.45 : lum() > 0.55); i++) {
    if (dark) { r = Math.min(255, r + 12); g = Math.min(255, g + 12); b = Math.min(255, b + 12); }
    else { r = Math.max(0, r - 12); g = Math.max(0, g - 12); b = Math.max(0, b - 12); }
  }
  return `rgb(${r},${g},${b})`;
}

function barList(entries, cap) {
  const max = cap || Math.max(...entries.map((e) => e[1]), 1e-9);
  return '<div class="bars">' + entries.map(([label, value, text, color]) =>
    `<div class="b"><span class="lab">${esc(label)}</span>
     <span class="track"><span class="fill" style="width:${Math.max(0, Math.min(100, value / max * 100))}%${color ? ";background:" + color : ""}"></span></span>
     <span class="val">${esc(text)}</span></div>`).join("") + "</div>";
}

// ---------------------------------------------------------------- randare date
function renderState(data) {
  state = data;
  $("kpiN").textContent = data.n;
  $("kpiFp").textContent = data.fingerprint ? data.fingerprint.slice(0, 10) : "—";

  // butoane de intrare, generate din alfabetul curent
  $("entryButtons").innerHTML = data.symbols.map((s) =>
    `<button data-sym="${esc(s)}" style="background:${colorOf(s)}">${esc(data.labels[s] || s)}</button>`
  ).join("");
  $("entryButtons").querySelectorAll("button").forEach((b) => {
    b.onclick = () => addSpin(b.dataset.sym);
  });
  $("entryHint").innerHTML = "Scurtaturi: " + data.symbols.map((s, i) =>
    `<code>${esc(s[0].toUpperCase())}</code> ${esc(data.labels[s] || s)}`).join(", ") +
    ", <code>Ctrl+Z</code> undo. Alfabet: " + esc(data.preset_name);

  if (data.live !== undefined) renderLive(data.live);
  renderDots(data);
  renderSequenceChart(data);
  renderStats(data);
  renderTable(data);
  renderPredictionHistory(data);
}

function renderDots(data) {
  const tail = data.spins.slice(-120);
  $("dots").innerHTML = tail.length
    ? tail.map((s, i) => `<span class="dot${i === tail.length - 1 ? " last" : ""}"
        style="background:${colorOf(s.value)}" title="#${s.index + 1} ${esc(s.value)}">${esc(s.value[0])}</span>`).join("")
    : '<span class="hint">Nicio rotire inregistrata inca.</span>';
}

// Grafic: frecventa cumulata a fiecarui simbol pe masura ce creste esantionul.
// Arata direct de ce esantioanele mici insala: la inceput liniile sar violent,
// apoi se aseaza. Este cel mai onest grafic pe care il putem desena.
function renderSequenceChart(data) {
  const n = data.spins.length;
  if (n < 5) { $("seqChart").innerHTML = ""; return; }
  const W = 900, H = 210, PAD = 34;
  const running = {}, series = {};
  data.symbols.forEach((s) => { running[s] = 0; series[s] = []; });
  data.spins.forEach((spin, i) => {
    running[spin.value] = (running[spin.value] || 0) + 1;
    data.symbols.forEach((s) => series[s].push(running[s] / (i + 1)));
  });
  const x = (i) => PAD + i / Math.max(1, n - 1) * (W - PAD - 10);
  const y = (v) => H - PAD - v * (H - PAD - 12);
  let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Frecventa cumulata">`;
  [0, 0.25, 0.5, 0.75, 1].forEach((v) => {
    svg += `<line x1="${PAD}" y1="${y(v)}" x2="${W - 10}" y2="${y(v)}" stroke="#2a3342" stroke-width="1"/>
            <text x="4" y="${y(v) + 4}" fill="#8b98a9" font-size="10">${(v * 100).toFixed(0)}%</text>`;
  });
  data.symbols.forEach((s) => {
    const path = series[s].map((v, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join("");
    svg += `<path d="${path}" fill="none" stroke="${colorOf(s)}" stroke-width="2"/>`;
  });
  svg += `<text x="${PAD}" y="${H - 8}" fill="#8b98a9" font-size="10">rotirea 1</text>
          <text x="${W - 60}" y="${H - 8}" fill="#8b98a9" font-size="10">rotirea ${n}</text></svg>
    <p class="hint">Frecventa cumulata a fiecarui simbol. Oscilatiile mari de la inceput sunt
    normale si sunt exact motivul pentru care esantioanele mici produc "tipare" iluzorii.</p>`;
  $("seqChart").innerHTML = svg;
}

function renderStats(data) {
  if (!data.n) { $("stats").innerHTML = '<p class="hint">Fara date.</p>'; return; }
  // interval de incredere Wilson 95% pentru fiecare proportie
  const z = 1.959964, n = data.n;
  const rows = data.symbols.map((s) => {
    const k = data.counts[s] || 0, p = k / n;
    const denom = 1 + z * z / n;
    const centre = (p + z * z / (2 * n)) / denom;
    const half = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom;
    return [data.labels[s] || s, p, `${k} · ${pct(p)}`, colorOf(s),
            Math.max(0, centre - half), Math.min(1, centre + half)];
  });
  $("stats").innerHTML = barList(rows.map((r) => [r[0], r[1], r[2], r[3]]), 1) +
    '<table style="margin-top:.6rem"><tr><th>Simbol</th><th class="num">Nr.</th>' +
    '<th class="num">Proportie</th><th class="num">IC 95% (Wilson)</th></tr>' +
    rows.map((r, i) => `<tr><td>${esc(r[0])}</td><td class="num">${data.counts[data.symbols[i]] || 0}</td>
      <td class="num">${pct(r[1])}</td><td class="num">${pct(r[4])} – ${pct(r[5])}</td></tr>`).join("") +
    "</table>" +
    `<p class="hint">Intervalele de incredere spun cat de putin stim de fapt: cu ${n} rotiri,
     adevarata probabilitate poate fi oriunde in interval.</p>`;
}

function renderTable(data) {
  const spins = data.spins.slice().reverse();
  const hasMeta = spins.some((s) => s.meta && Object.keys(s.meta).length);
  $("spinTable").innerHTML =
    "<tr><th class='num'>#</th><th>Rezultat</th><th>Timp</th><th>Sesiune</th>" +
    (hasMeta ? "<th>Extra</th>" : "") + "</tr>" +
    (spins.length ? spins.map((s) => `<tr>
      <td class="num">${s.index + 1}</td>
      <td><span class="badge" style="background:${colorOf(s.value)};color:#fff">${esc(data.labels[s.value] || s.value)}</span></td>
      <td>${s.ts ? esc(new Date(s.ts * 1000).toLocaleString("ro-RO")) : "—"}</td>
      <td>${esc(s.session || "—")}</td>
      ${hasMeta ? `<td>${esc(JSON.stringify(s.meta || {}))}</td>` : ""}</tr>`).join("")
      : '<tr><td colspan="5" class="hint">Fara rotiri.</td></tr>');
}

function renderPredictionHistory(data) {
  const resolved = (data.predictions || []).filter((p) => p.actual && p.predicted);
  const acc = data.prediction_accuracy;
  if (!resolved.length) {
    $("predHistory").innerHTML = '<p class="hint">Nicio predictie evaluata inca. ' +
      'Predictiile se evalueaza automat cand adaugi rotirea urmatoare.</p>';
    return;
  }
  let head = "";
  if (acc) {
    head = `<p>Total evaluate: <strong>${acc.correct}/${acc.total}</strong>
      (${pct(acc.correct / acc.total)}). Dintre acestea, ${acc.gated_total} au trecut poarta
      de evidenta: <strong>${acc.gated_correct}/${acc.gated_total || 0}</strong>.</p>
      <p class="hint">Compara mereu cu baseline-ul: a ghici mereu simbolul cel mai frecvent
      ar da ${pct(Math.max(...state.symbols.map((s) => (state.counts[s] || 0) / state.n)))}.</p>`;
  }
  $("predHistory").innerHTML = head +
    '<div class="tablewrap"><table><tr><th class="num">La rotirea</th><th>Prezis</th>' +
    '<th>Real</th><th>Corect</th><th>Incredere</th><th>Poarta</th><th>Model</th></tr>' +
    resolved.slice().reverse().map((p) => `<tr>
      <td class="num">${p.at_index}</td>
      <td>${esc(p.predicted)}</td><td>${esc(p.actual)}</td>
      <td><span class="badge ${p.correct ? "b-ok" : "b-fail"}">${p.correct ? "da" : "nu"}</span></td>
      <td class="num">${p.confidence ? pct(p.confidence) : "—"}</td>
      <td><span class="badge ${p.gated ? "b-ok" : "b-insuficient"}">${p.gated ? "trecuta" : "blocata"}</span></td>
      <td>${esc(p.model)}</td></tr>`).join("") + "</table></div>";
}

// ---------------------------------------------------------------- actiuni date
async function addSpin(symbol) {
  try {
    const session = $("sessionInput").value.trim();
    renderState(await post("/api/spins", { values: [symbol], session: session || null }));
  } catch (e) { toast(e.message, true); }
}

async function refresh() {
  try {
    const data = await api("/api/state");
    renderState(data);
    if (data.n) renderLive(await api("/api/live"));
  } catch (e) { toast(e.message, true); }
}

// --- panoul live: raspunsul apare imediat ce introduci o culoare ------------
// Motorul invata incremental, deci acest randare costa sub o milisecunda chiar
// si dupa mii de rotiri. Acuratetea afisata este masurata din predictii facute
// INAINTE de a fi cunoscut rezultatul -- nu poate fi umflata.
function renderLive(live) {
  if (!live) {
    $("liveBody").innerHTML = '<p class="hint">Introdu primul rezultat ca sa porneasca motorul.</p>';
    $("liveModel").textContent = "";
    $("contextEvidence").innerHTML = "";
    return;
  }
  const cls = { avantaj: "ok", fara_avantaj: "bad", prea_putine_date: "wait" }[live.status];
  const entries = Object.entries(live.probabilities).sort((a, b) => b[1] - a[1]);
  $("liveModel").textContent = `model castigator: ${live.model} · ${live.n_evaluated} predictii evaluate`;
  $("liveBody").innerHTML = `
    <div class="live-main">
      <div class="live-pick" style="color:${textColorOf(live.symbol)}">${esc(live.label)}</div>
      <div class="live-probs">${entries.map(([s, p]) => `
        <div class="b"><span class="lab">${esc(state.labels[s] || s)}</span>
        <span class="track"><span class="fill" style="width:${p * 100}%;background:${colorOf(s)}"></span></span>
        <span class="val">${pct(p, 1)}</span></div>`).join("")}</div>
    </div>
    <div class="live-truth ${cls}">${esc(live.verdict)}</div>
    <div class="live-scores">
      <div><span>modelul</span><span class="track"><span class="fill"
        style="width:${live.accuracy * 100}%;background:${cls === "ok" ? "var(--ok)" : "var(--dim)"}"></span></span>
        <b>${pct(live.accuracy)}</b></div>
      <div><span>mereu aceeasi culoare</span><span class="track"><span class="fill"
        style="width:${live.baseline_accuracy * 100}%;background:var(--dim)"></span></span>
        <b>${pct(live.baseline_accuracy)}</b></div>
    </div>
    <details class="live-details"><summary>Cum se descurca fiecare model (${live.n_evaluated} predictii)</summary>
      <table><tr><th>Model</th><th class="num">Acuratete</th><th class="num">Log-loss</th><th class="num">Corecte</th></tr>
      ${live.leaderboard.map((r) => `<tr${r.is_baseline ? ' class="baseline-row"' : ""}>
        <td>${esc(r.name)}${r.is_baseline ? " <span class=\"q\">(referinta)</span>" : ""}</td>
        <td class="num">${r.n ? pct(r.accuracy) : "—"}</td>
        <td class="num">${r.n ? r.log_loss.toFixed(4) : "—"}</td>
        <td class="num">${r.correct}/${r.n}</td></tr>`).join("")}</table>
      <p class="hint">Modelul recomandat este cel cu cel mai mic log-loss real. Daca invingatorul
      este "Frecventa empirica", inseamna ca memoria combinatiilor nu a ajutat cu nimic.</p>
    </details>`;
  renderContext(live.context);
}

function renderContext(context) {
  if (!context || !context.length) { $("contextEvidence").innerHTML = ""; return; }
  $("contextEvidence").innerHTML =
    '<table><tr><th>Combinatia recenta</th><th class="num">De cate ori a mai aparut</th>' +
    '<th>Ce a urmat</th><th class="num">Cel mai des</th><th>Verdict</th></tr>' +
    context.map((c) => {
      const following = Object.entries(c.following || {})
        .sort((a, b) => b[1] - a[1])
        .map(([s, k]) => `${esc(state.labels[s] || s)}: ${k}`).join(" · ") || "—";
      const strong = c.p_value !== undefined && c.p_value < 0.05 && c.occurrences >= 20;
      return `<tr>
        <td><code>${c.context.map(esc).join("")}</code></td>
        <td class="num">${c.occurrences}</td>
        <td class="q">${following}</td>
        <td class="num">${c.top ? esc(c.top) + " " + pct(c.top_rate, 0) : "—"}</td>
        <td><span class="badge ${strong ? "b-ok" : "b-fara_dovada"}">${esc(c.note)}</span></td>
      </tr>`;
    }).join("") + "</table>" +
    '<p class="hint">Aceasta este dovada bruta pentru "combinatiile se repeta". Coloana care ' +
    'conteaza este a doua: un context vazut de 3 ori nu spune nimic, oricat de convingator ' +
    'ar arata procentul de langa el.</p>';
}

// ---------------------------------------------------------------- analiza
function renderAnalysis(report) {
  const counts = report.counts;
  let html = `<div class="verdict ${counts.evidence ? "" : "no"}">
    <strong>${esc(report.summary)}</strong></div>
    <p class="hint">Verdicte: ${counts.evidence} dovada · ${counts.weak} slabe ·
     ${counts.no_evidence} fara dovada · ${counts.insufficient} date insuficiente.</p>`;
  html += report.results.map((r) => {
    const q = r.q_value === null ? "—" : r.q_value.toFixed(4);
    const stats = r.applicable
      ? `${esc(r.statistic_name)} = ${r.statistic.toFixed(3)} · p = ${r.p_value.toFixed(4)}
         (${esc(r.p_method)}) · q(BH) = ${q} · ${esc(r.effect_name)} = ${r.effect.toFixed(4)}`
      : "netestat";
    return `<div class="result">
      <div class="top"><strong>${esc(r.title)}</strong>
        <span class="badge b-${r.verdict}">${esc(r.verdict_label)}</span></div>
      <div class="q">${esc(r.question)}</div>
      <div class="q" style="margin-top:.3rem">${stats}</div>
      <p>${esc(r.explanation)}</p>
      ${r.warnings.map((w) => `<div class="warn">⚠ ${esc(w)}</div>`).join("")}
      ${detailExtra(r)}
    </div>`;
  }).join("");
  $("analysisOut").innerHTML = html;
}

// Grafice mici, doar acolo unde chiar lamuresc ceva.
function detailExtra(r) {
  if (r.key === "autocorrelation" && r.detail.profile) {
    const p = r.detail.profile, base = r.detail.baseline;
    const W = 820, H = 120, bw = (W - 30) / p.length;
    const scale = Math.max(0.02, ...p.map((v) => Math.abs(v - base))) * 1.25;
    let svg = `<svg viewBox="0 0 ${W} ${H}"><line x1="28" y1="${H / 2}" x2="${W}" y2="${H / 2}" stroke="#8b98a9"/>`;
    p.forEach((v, i) => {
      const d = (v - base) / scale * (H / 2 - 10);
      svg += `<rect x="${28 + i * bw}" y="${d >= 0 ? H / 2 - d : H / 2}" width="${Math.max(1, bw - 2)}"
        height="${Math.abs(d)}" fill="${i + 1 === r.detail.best_lag ? "#d29922" : "#4f9cf9"}"/>`;
    });
    svg += `<text x="0" y="${H / 2 + 4}" fill="#8b98a9" font-size="10">0</text></svg>`;
    return svg + `<p class="hint">Abaterea ratei de coincidenta fata de nivelul hazardului
      (${pct(base)}), pentru decalajele 1..${p.length}. Bara evidentiata este maximul.</p>`;
  }
  if (r.key === "markov" && r.detail.transition_rates) {
    const rates = r.detail.transition_rates, syms = Object.keys(rates);
    return '<table style="margin-top:.5rem"><tr><th>de la \\ la</th>' +
      syms.map((s) => `<th class="num">${esc(s)}</th>`).join("") + "</tr>" +
      syms.map((a) => `<tr><td><strong>${esc(a)}</strong></td>` +
        syms.map((b) => `<td class="num">${pct(rates[a][b])} <span class="q">(${r.detail.transition_counts[a][b]})</span></td>`).join("") +
        "</tr>").join("") + "</table>" +
      `<p class="hint">Matricea de tranzitie, cu numarul brut de observatii in paranteze.
       Procentele bazate pe putine observatii nu inseamna nimic.</p>`;
  }
  if (r.key === "repeats" && r.detail.fragment) {
    return `<p class="hint">Fragment: <code>${esc(r.detail.fragment.join(""))}</code> ·
      media hazardului: ${r.detail.null_mean.toFixed(1)} · pragul 95%: ${r.detail.null_p95}</p>`;
  }
  if (r.key === "wheel_model" && r.detail.models) {
    return '<table style="margin-top:.5rem"><tr><th>Model de roata</th><th class="num">hi-patrat</th><th class="num">p</th></tr>' +
      Object.entries(r.detail.models).map(([name, v]) =>
        `<tr><td>${esc(name)}</td><td class="num">${v.chi2.toFixed(2)}</td>
         <td class="num">${v.p.toFixed(4)}</td></tr>`).join("") + "</table>";
  }
  return "";
}

// ---------------------------------------------------------------- PRNG
function renderPrng(data) {
  const b = data.budget;
  let html = `<div class="verdict ${data.verdict === "generator_identificat" ? "yes" : "no"}">
    <strong>${esc(data.summary)}</strong></div>
    <p>Informatie colectata: <strong>${b.total_bits_collected.toFixed(0)} biti</strong>
    (${b.bits_per_spin_observed.toFixed(2)} biti/rotire din ${b.bits_per_spin_max.toFixed(2)} maximi
    — eficienta ${pct(b.efficiency, 0)}).</p>`;
  html += '<h3>Buget informational pe generator</h3><table><tr><th>Generator</th>' +
    '<th class="num">Stare (biti)</th><th class="num">Rotiri minime</th><th>Avem destul?</th>' +
    '<th>Fezabilitate practica</th></tr>' +
    b.rows.map((r) => `<tr><td>${esc(r.name)}<div class="q">${esc(r.where_used)}</div></td>
      <td class="num">${r.state_bits}</td><td class="num">${r.min_spins_information}</td>
      <td><span class="badge ${r.sufficient_information ? "b-ok" : "b-fail"}">${r.sufficient_information ? "da" : "nu"}</span></td>
      <td class="q">${esc(r.status)}</td></tr>`).join("") + "</table>";
  if (data.attacks && data.attacks.length) {
    html += "<h3>Atacuri rulate</h3>" + data.attacks.map((a) => `<div class="result">
      <div class="top"><strong>${esc(a.attack)} · ${esc(a.generator)}</strong>
      <span class="badge ${a.success ? "b-ok" : "b-fara_dovada"}">${a.success ? "reusit" : "esuat"}</span></div>
      <p>${esc(a.reason)}</p>
      <div class="q">${a.tried} incercari · ${a.elapsed_s}s${a.seed !== null && a.seed !== undefined ? " · seed " + a.seed : ""}</div>
      ${a.predicted_next && a.predicted_next.length ? `<p>Urmatoarele rezultate implicate:
        <code>${esc(a.predicted_next.join(" "))}</code></p>` : ""}
    </div>`).join("");
  }
  html += "<h3>Note metodologice</h3>" +
    data.notes.map((n) => `<p class="hint">• ${esc(n)}</p>`).join("");
  $("prngOut").innerHTML = html;
}

// ---------------------------------------------------------------- backtest
function renderBacktest(bt) {
  const base = bt.runs[bt.baseline_key];
  let html = `<p>Invatare pe primele <strong>${bt.warmup}</strong> rotiri; evaluate
    <strong>${bt.n_evaluated}</strong> rotiri nevazute. Durata: ${bt.elapsed_s}s.</p>
    <table><tr><th>Model</th><th class="num">Log-loss (biti)</th><th class="num">Perplexitate</th>
    <th class="num">Acuratete</th><th class="num">Brier</th><th class="num">Eroare calibrare</th>
    <th class="num">Biti castigati</th><th class="num">p corectat</th></tr>`;
  Object.entries(bt.runs).forEach(([key, run]) => {
    const c = bt.comparisons[key];
    const isBase = key === bt.baseline_key;
    const gain = isBase ? "<em>baseline</em>" : (c ? (c.mean_bits_saved >= 0 ? "+" : "") + c.mean_bits_saved.toFixed(4) : "—");
    const p = isBase ? "—" : (c ? c.p_value_corrected.toFixed(4) : "—");
    const good = c && c.p_value_corrected < 0.01 && c.mean_bits_saved > 0.01;
    html += `<tr${key === bt.best_key ? ' style="font-weight:600"' : ""}>
      <td>${esc(run.name)}</td><td class="num">${run.log_loss_bits.toFixed(4)}</td>
      <td class="num">${run.perplexity.toFixed(3)}</td>
      <td class="num">${pct(run.accuracy)}</td><td class="num">${run.brier.toFixed(4)}</td>
      <td class="num">${(run.calibration_error * 100).toFixed(1)}pp</td>
      <td class="num" ${good ? 'style="color:var(--ok)"' : ""}>${gain}</td>
      <td class="num">${p}</td></tr>`;
  });
  html += `</table><p class="hint">Metrica decisiva este log-loss-ul, nu acuratetea: un model
    care spune mereu simbolul cel mai frecvent obtine o acuratete inselator de buna
    (${pct(base.accuracy)} aici) fara sa fi invatat nimic.</p>`;

  html += "<h3>Precizie / recall pe simbol (cel mai bun model)</h3>";
  const best = bt.runs[bt.best_key];
  html += '<table><tr><th>Simbol</th><th class="num">Suport</th><th class="num">Prezis de</th>' +
    '<th class="num">Precizie</th><th class="num">Recall</th><th class="num">F1</th></tr>' +
    Object.entries(best.per_class).map(([sym, v]) => `<tr><td>${esc(sym)}</td>
      <td class="num">${v.support}</td><td class="num">${v.predicted_count}</td>
      <td class="num">${pct(v.precision)}</td><td class="num">${pct(v.recall)}</td>
      <td class="num">${v.f1.toFixed(3)}</td></tr>`).join("") + "</table>";

  html += "<h3>Calibrare</h3>" +
    '<table><tr><th>Increderea afisata</th><th class="num">Cazuri</th>' +
    '<th class="num">Medie prezisa</th><th class="num">Realitate</th></tr>' +
    best.calibration_bins.filter((b) => b.n > 0).map((b) => `<tr>
      <td>${pct(b.lo, 0)} – ${pct(b.hi, 0)}</td><td class="num">${b.n}</td>
      <td class="num">${pct(b.mean_predicted)}</td><td class="num">${pct(b.observed)}</td></tr>`).join("") +
    "</table><p class=\"hint\">Un model calibrat corect nimereste realitatea aproape de media prezisa. " +
    "Daca afiseaza 80% dar realitatea e 50%, numarul de incredere este o minciuna.</p>";
  $("backtestOut").innerHTML = html;
}

// ---------------------------------------------------------------- predictie
function renderDecision(d) {
  let html = "";
  // Ghicitura vine prima, pentru ca asta cauta oricine deschide pagina --
  // dar niciodata fara acuratetea ei reala scrisa dedesubt.
  if (d.guess) {
    const g = d.guess;
    const good = g.beats_baseline_significantly;
    html += `<div class="guess" style="border-color:${colorOf(g.symbol)}">
      <div class="guess-label">Cea mai probabila culoare</div>
      <div class="guess-symbol" style="color:${textColorOf(g.symbol)}">${esc(g.label)}</div>
      <div class="guess-conf">increderea modelului: ${pct(g.model_confidence, 1)} · ${esc(g.model)}</div>
      <div class="guess-truth ${good ? "ok" : ""}">
        <strong>${good ? "Avantaj real, confirmat statistic" : "Fara avantaj demonstrat"}</strong><br>
        ${esc(g.honesty)}
      </div>
      <div class="guess-meter">
        <div><span>ghicitura modelului</span><span class="track"><span class="fill"
          style="width:${g.measured_accuracy * 100}%;background:${good ? "var(--ok)" : "var(--dim)"}"></span></span>
          <b>${pct(g.measured_accuracy)}</b></div>
        <div><span>apasat mereu pe aceeasi culoare</span><span class="track"><span class="fill"
          style="width:${g.baseline_accuracy * 100}%;background:var(--dim)"></span></span>
          <b>${pct(g.baseline_accuracy)}</b></div>
      </div>
      <div class="q">Masurat pe ${g.evaluated_on} rotiri pe care modelul nu le vazuse la antrenare.</div>
    </div>`;
  }
  html += `<div class="verdict ${d.allowed ? "yes" : "no"}">
    <strong>${esc(d.message)}</strong></div>`;
  if (d.allowed) {
    const entries = Object.entries(d.probabilities).sort((a, b) => b[1] - a[1]);
    html += `<h3>Probabilitati estimate</h3>` +
      barList(entries.map(([s, p]) => [state.labels[s] || s, p, pct(p, 2), colorOf(s)]), 1) +
      `<p>Predictie: <strong style="color:${textColorOf(d.prediction)}">
       ${esc(state.labels[d.prediction] || d.prediction)}</strong> · incredere
       ${pct(d.confidence, 1)} · model ${esc(d.model_name)}</p>`;
  }
  html += "<h3>Conditiile portii de evidenta</h3><table><tr><th>Conditie</th><th>Rezultat</th>" +
    "<th>Cerut</th><th>Obtinut</th></tr>" +
    d.checks.map((c) => `<tr><td>${esc(c.name)}<div class="q">${esc(c.detail)}</div></td>
      <td><span class="badge ${c.passed ? "b-ok" : "b-fail"}">${c.passed ? "trece" : "pica"}</span></td>
      <td class="q">${esc(c.required)}</td><td class="q">${esc(c.observed)}</td></tr>`).join("") +
    "</table>";
  html += "<h3>Transparenta</h3><table>" +
    Object.entries(d.transparency).map(([k, v]) => `<tr><td style="width:14rem"><strong>${esc(k)}</strong></td>
      <td>${esc(typeof v === "object" ? JSON.stringify(v) : v)}</td></tr>`).join("") + "</table>";
  $("predictOut").innerHTML = html;
}

// ---------------------------------------------------------------- pornire
document.addEventListener("DOMContentLoaded", () => {
  $("tabs").querySelectorAll("button").forEach((b) => {
    b.onclick = () => {
      $("tabs").querySelectorAll("button").forEach((x) => x.classList.remove("active"));
      document.querySelectorAll(".tab").forEach((x) => x.classList.remove("active"));
      b.classList.add("active");
      $("tab-" + b.dataset.tab).classList.add("active");
    };
  });

  $("undoBtn").onclick = async () => {
    try { renderState(await post("/api/undo")); toast("Ultima rotire a fost stearsa."); }
    catch (e) { toast(e.message, true); }
  };
  $("clearBtn").onclick = async () => {
    if (!confirm("Sterg toate datele? Exporta-le intai daca vrei sa le pastrezi.")) return;
    try { renderState(await post("/api/clear")); toast("Date sterse."); }
    catch (e) { toast(e.message, true); }
  };

  $("importBtn").onclick = async () => {
    const file = $("fileInput").files[0];
    const append = $("appendChk").checked;
    try {
      let text, filename;
      if (file) { text = await file.text(); filename = file.name; }
      else { text = $("pasteArea").value.trim(); filename = "lipit.txt"; }
      if (!text) return toast("Alege un fisier sau lipeste rezultate.", true);
      const data = await post("/api/import", { text, filename, append });
      renderState(data);
      $("pasteArea").value = "";
      toast(`Importate ${data.imported} rotiri.`);
    } catch (e) { toast(e.message, true); }
  };

  const runner = (buttonId, url, render) => {
    $(buttonId).onclick = async () => {
      const b = $(buttonId);
      busy(b, true);
      try { render(await api(typeof url === "function" ? url() : url)); }
      catch (e) { toast(e.message, true); }
      finally { busy(b, false); }
    };
  };
  runner("runAnalysis", "/api/analyze", renderAnalysis);
  runner("runPrng", "/api/prng?max_seeds=20000", renderPrng);
  runner("runBacktest", () => {
    const w = $("warmupInput").value;
    return "/api/backtest" + (w ? `?warmup=${encodeURIComponent(w)}` : "");
  }, renderBacktest);

  $("runPredict").onclick = async () => {
    const b = $("runPredict");
    busy(b, true);
    try {
      const data = await post("/api/predict", { log: $("logPred").checked });
      renderDecision(data.decision);
      renderState(data.state);
    } catch (e) { toast(e.message, true); }
    finally { busy(b, false); }
  };

  $("previewReport").onclick = async () => {
    const b = $("previewReport");
    busy(b, true);
    try {
      const response = await fetch("/api/report?format=md");
      $("reportPreview").textContent = await response.text();
    } catch (e) { toast(e.message, true); }
    finally { busy(b, false); }
  };

  document.addEventListener("keydown", (e) => {
    if (/^(INPUT|TEXTAREA)$/.test(e.target.tagName)) return;
    if (e.ctrlKey && e.key.toLowerCase() === "z") { e.preventDefault(); return $("undoBtn").click(); }
    if (e.ctrlKey || e.metaKey || e.altKey || !state) return;
    const hit = state.symbols.find((s) => s[0].toUpperCase() === e.key.toUpperCase());
    if (hit) { e.preventDefault(); addSpin(hit); }
  });

  refresh();
});
