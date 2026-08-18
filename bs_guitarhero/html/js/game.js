/* ==========================================================================
   Rhythm Highway HUD  --  bs_guitarhero
   Overlay transparent peste joc. Geometria, culorile si constantele de timing
   sunt cele din designul "Rhythm Highway HUD.dc.html".

   Ceasul jocului vine direct din <audio>.currentTime, deci cand melodia
   incetineste (penalizare pentru note ratate) incetinesc si notele.
   ========================================================================== */
(function () {
'use strict';

/* ------------------------------------------------------- constante design */

var NLANES  = 4;
var KEYS    = ['ArrowLeft', 'ArrowDown', 'ArrowUp', 'ArrowRight'];
var GLYPHS  = ['←', '↓', '↑', '→'];

var LEAD    = 1.9;     // secunde vizibile pe autostrada
var HEADH   = 30;      // inaltimea capului notei, px
var PERFW   = 0.055;   // fereastra PERFECT
var GOODW   = 0.115;   // fereastra GOOD
var HITW    = 0.165;   // fereastra maxima de lovire
var MISSW   = 0.16;    // dupa atat o nota nelovita e ratata

var LEADIN  = 3.0;     // numaratoarea 3-2-1 dinainte de melodie
var END_PAD = 2.6;
var POOL    = 56;      // cate elemente de nota reciclam

/* ------------------------------------------------------------------ utile */

var $ = function (id) { return document.getElementById(id); };
function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
function lerp(a, b, k) { return a + (b - a) * k; }
function mmss(s) {
  s = Math.max(0, s);
  return Math.floor(s / 60) + ':' + String(Math.floor(s % 60)).padStart(2, '0');
}
function post(name, body) {
  if (typeof GetParentResourceName !== 'function') return Promise.resolve();
  return fetch('https://' + GetParentResourceName() + '/' + name, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body || {})
  }).catch(function () {});
}

/* ------------------------------------------------------------------ stare */

var cfg = null, chart = null, el = {}, audio = null;
var recs = [], lines = [], pool = [], free = [];

var S = {
  phase: 'idle',        // idle | loading | lead | playing | paused | failing | results
  notes: [], head: 0,
  score: 0, combo: 0, best: 0, hits: 0, misses: 0, overstrums: 0,
  counts: { PERFECT: 0, GOOD: 0, MISS: 0 },
  meter: 65, rate: 1, rateTarget: 1,
  t: 0, lastNoteT: 0, startAt: 0, songEnd: 0,
  offsetMs: 0, volume: 0.55,
  down: [0, 0, 0, 0], flash: [0, 0, 0, 0], missFlash: [0, 0, 0, 0],
  judgeAge: 99, sectionIdx: -1, leadStart: 0, lastCd: null,
  H: 400, failAt: 0
};

/* ------------------------------------------------------------------- ceas */

var Clock = {
  mode: 'lead', ctLast: -1, perfAtCt: 0,
  reset: function () { this.mode = 'lead'; this.ctLast = -1; this.perfAtCt = 0; },
  raw: function () {
    if (this.mode === 'lead') {
      return S.startAt - LEADIN + (performance.now() - S.leadStart) / 1000;
    }
    var ct = audio.currentTime, p = performance.now() / 1000;
    if (ct !== this.ctLast) { this.ctLast = ct; this.perfAtCt = p; }
    var d = p - this.perfAtCt;
    if (d > 0.30 || d < 0) d = 0;
    return ct + d * (audio.playbackRate || 1);
  }
};
function songTime() { return Clock.raw() - S.offsetMs / 1000; }

/* -------------------------------------------------------------- constructie */

function buildRecs() {
  el.recs.innerHTML = '';
  recs = [];
  for (var i = 0; i < NLANES; i++) {
    var slot = document.createElement('div');
    slot.className = 'rec-slot';
    var r = document.createElement('div');
    r.className = 'rec l' + i;
    r.innerHTML = '<div class="glow"></div><div class="ring"></div>' +
                  '<div class="core"></div><div class="fill"></div>' +
                  '<span class="gl">' + GLYPHS[i] + '</span>';
    slot.appendChild(r);
    el.recs.appendChild(slot);
    recs.push({ box: r, glow: r.children[0], fill: r.children[3] });
  }
}

function buildLines() {
  el.beats.innerHTML = '';
  lines = [];
  var n = Math.ceil(LEAD / (60 / (chart.bpm || 128))) + 3;
  for (var i = 0; i < n; i++) {
    var d = document.createElement('i');
    el.beats.appendChild(d);
    lines.push(d);
  }
}

function buildPool() {
  el.notes.innerHTML = '';
  pool = []; free = [];
  for (var i = 0; i < POOL; i++) {
    var d = document.createElement('div');
    d.className = 'note';
    d.innerHTML = '<div class="tail"></div><div class="head"><span></span></div>';
    d.style.opacity = '0';
    d.style.transform = 'translate3d(-50%,-500px,0)';
    el.notes.appendChild(d);
    pool.push(d); free.push(d);
  }
}

function takeEl(lane) {
  var d = free.pop();
  if (!d) return null;
  d.className = 'note n' + lane + ' l' + lane;
  d.querySelector('.head span').textContent = GLYPHS[lane];
  return d;
}
function giveEl(d) {
  if (!d) return;
  d.style.opacity = '0';
  d.style.transform = 'translate3d(-50%,-500px,0)';
  free.push(d);
}

/* ------------------------------------------------------------- incarcare */

function load() {
  S.phase = 'loading';
  showOverlay('SE INCARCA', 'ICH WILL', '');
  var pChart = fetch(cfg.song.chart).then(function (r) { return r.json(); });
  var pAudio = new Promise(function (res) {
    audio.src = cfg.song.audio;
    audio.load();
    var done = false, ok = function () { if (!done) { done = true; res(); } };
    audio.addEventListener('canplaythrough', ok, { once: true });
    audio.addEventListener('loadeddata', ok, { once: true });
    setTimeout(ok, 12000);
  });
  Promise.all([pChart, pAudio]).then(function (r) {
    chart = r[0];
    el.trackLabel.textContent = (chart.title + ' · ' + chart.artist).toUpperCase();
    buildRecs(); buildLines(); buildPool();
    startRun();
  }).catch(function (e) {
    console.error('[bs_guitarhero]', e);
    exitGame();
  });
}

/* ----------------------------------------------------------------- start */

function startRun() {
  S.startAt = typeof cfg.song.startAt === 'number' ? cfg.song.startAt : 0;
  S.notes = chart.notes.map(function (n) {
    return { t: n.t, l: n.l, d: n.d, st: 0, el: null };
  });
  S.head = 0;
  S.score = 0; S.combo = 0; S.best = 0; S.hits = 0; S.misses = 0; S.overstrums = 0;
  S.counts = { PERFECT: 0, GOOD: 0, MISS: 0 };
  S.meter = cfg.meter.start;
  S.rate = 1; S.rateTarget = 1;
  S.judgeAge = 99; S.sectionIdx = -1; S.lastCd = null;
  S.down = [0, 0, 0, 0]; S.flash = [0, 0, 0, 0]; S.missFlash = [0, 0, 0, 0];
  S.lastNoteT = S.notes.length ? S.notes[S.notes.length - 1].t : 0;
  S.songEnd = Math.max(chart.songEnd || 0, S.lastNoteT) + END_PAD;

  for (var i = 0; i < pool.length; i++) giveEl(pool[i]);
  free = pool.slice();

  audio.pause();
  try { audio.currentTime = S.startAt; } catch (e) {}
  audio.playbackRate = 1;
  audio.volume = 0;
  if ('preservesPitch' in audio) audio.preservesPitch = false;
  if ('mozPreservesPitch' in audio) audio.mozPreservesPitch = false;
  if ('webkitPreservesPitch' in audio) audio.webkitPreservesPitch = false;

  Clock.reset();
  S.leadStart = performance.now();
  S.phase = 'lead';
  el.rateChip.classList.add('hidden');
  paintHud();
}

function beginAudio() {
  /* daca fisierul nu era inca cautabil cand am cerut startAt, reincercam acum */
  if (S.startAt > 0 && Math.abs(audio.currentTime - S.startAt) > 0.4) {
    try { audio.currentTime = S.startAt; } catch (e) {}
  }
  Clock.mode = 'audio';
  var pr = audio.play();
  if (pr && pr.catch) pr.catch(function (e) { console.warn('[bs_guitarhero] play()', e); });
  S.phase = 'playing';
  hideOverlay();
}

/* --------------------------------------------------------------- judecata */

function multiplier() { return clamp(1 + Math.floor(S.combo / 10), 1, 4); }

function judge(text, color) {
  S.judgeAge = 0;
  el.judge.textContent = text;
  el.judge.style.color = color;
}

function press(lane) {
  if (S.phase !== 'playing') return;
  var t = songTime();
  S.flash[lane] = 1;

  var best = -1, bd = 9;
  for (var i = S.head; i < S.notes.length; i++) {
    var n = S.notes[i];
    if (n.t - t > HITW) break;
    if (n.st || n.l !== lane) continue;
    var dt = Math.abs(n.t - t);
    if (dt <= HITW && dt < bd) { bd = dt; best = i; }
  }

  if (best < 0) { overstrum(lane); return; }

  var n2 = S.notes[best];
  var perfect = bd <= PERFW;
  n2.st = 1;
  S.hits++;
  S.counts[perfect ? 'PERFECT' : 'GOOD']++;
  S.combo++;
  S.best = Math.max(S.best, S.combo);
  S.score += Math.round((perfect ? 100 : 55) * multiplier());
  S.meter = clamp(S.meter + (perfect ? cfg.meter.perfect : cfg.meter.good), 0, cfg.meter.max);
  judge(perfect ? 'PERFECT' : 'GOOD', perfect ? '#ffffff' : 'var(--accent)');
  paintHud();
}

function overstrum(lane) {
  if (songTime() < S.startAt + 0.3) return;
  S.overstrums++;
  S.combo = 0;
  S.meter = clamp(S.meter - cfg.meter.overstrum, 0, cfg.meter.max);
  S.missFlash[lane] = 1;
  judge('OVERSTRUM', '#ffb26b');
  paintHud();
  checkFail();
}

function missNote(n) {
  n.st = 2;
  S.misses++;
  S.counts.MISS++;
  S.combo = 0;
  S.meter = clamp(S.meter - cfg.meter.miss, 0, cfg.meter.max);
  S.missFlash[n.l] = 1;
  if (n.el) n.el.classList.add('miss');
  judge('MISS', '#ff5a63');
  paintHud();
  checkFail();
}

function checkFail() {
  if (S.phase !== 'playing') return;
  if (S.meter <= (cfg.meter.failAt || 0)) {
    S.phase = 'failing';
    S.failAt = performance.now();
  }
}

/* -------------------------------------------------------------------- HUD */

function paintHud() {
  el.scoreText.textContent = String(S.score).padStart(5, '0');
  var tot = S.hits + S.misses;
  el.accText.textContent = (tot ? (S.hits / tot) * 100 : 100).toFixed(1) + '%';

  var pct = clamp(S.meter / cfg.meter.max, 0, 1);
  el.meterFill.style.width = (pct * 100) + '%';
  el.meterVal.textContent = Math.round(S.meter) + '%';
  el.meterChip.classList.toggle('warn', S.meter < cfg.meter.slowFrom);
}

function showOverlay(kicker, title, sub, opts) {
  el.ovKicker.textContent = kicker;
  el.ovKicker.classList.toggle('fail', !!(opts && opts.fail));
  el.ovTitle.textContent = title;
  el.ovTitle.className = 'ov-title' + (opts && opts.count ? ' count' : '');
  if (opts && opts.pop) {
    void el.ovTitle.offsetWidth;
    el.ovTitle.classList.add('pop');
  }
  el.ovSub.textContent = sub || '';
  el.overlay.classList.remove('hidden');
}
function hideOverlay() { el.overlay.classList.add('hidden'); }

function updateSection(t) {
  if (!chart.sections) return;
  var idx = -1;
  for (var i = 0; i < chart.sections.length; i++) {
    if (t >= chart.sections[i].t) idx = i; else break;
  }
  if (idx !== S.sectionIdx) {
    S.sectionIdx = idx;
    el.trackLabel.textContent =
      (chart.title + ' · ' + chart.artist +
       (idx >= 0 ? ' · ' + chart.sections[idx].name : '')).toUpperCase();
  }
}

/* ----------------------------------------------------------------- cadru */

var lastFrame = 0;

function frame(now) {
  var dt = lastFrame ? Math.min(0.05, (now - lastFrame) / 1000) : 0;
  lastFrame = now;
  if (S.phase === 'idle') { requestAnimationFrame(frame); return; }

  if (S.phase === 'lead') {
    S.t = Clock.raw();
    var left = Math.ceil(S.startAt - S.t);
    var label = left > 0 ? String(left) : 'GO';
    if (label !== S.lastCd) {
      S.lastCd = label;
      showOverlay((chart.artist + ' · ' + chart.title).toUpperCase(), label,
                  '←  ↓  ↑  →', { count: true, pop: true });
    }
    if (S.t >= S.startAt) beginAudio();
  } else if (S.phase === 'playing' || S.phase === 'failing') {
    S.t = songTime();
    updateSection(S.t);

    if (S.phase === 'playing') {
      while (S.head < S.notes.length && S.notes[S.head].t < S.t - MISSW) {
        var n0 = S.notes[S.head];
        if (!n0.st) missNote(n0);
        S.head++;
      }
      var sf = cfg.meter.slowFrom, mr = cfg.meter.minRate;
      S.rateTarget = S.meter >= sf ? 1 : mr + (1 - mr) * (S.meter / sf);
    } else {
      S.rateTarget = 0.25;
    }

    S.rate = lerp(S.rate, S.rateTarget, clamp(dt * 2.6, 0, 1));
    var ap = clamp(S.rate, 0.25, 1);
    if (Math.abs(audio.playbackRate - ap) > 0.004) audio.playbackRate = ap;
    var slow = ap < 0.985;
    el.rateChip.classList.toggle('hidden', !slow);
    if (slow) el.rateText.textContent = 'x' + ap.toFixed(2) + ' SPEED';

    /* fade-in la inceput ca sa nu intre brusc in mijlocul intro-ului */
    if (audio.volume < S.volume) audio.volume = Math.min(S.volume, audio.volume + dt / 0.7 * S.volume);

    if (S.phase === 'failing' && performance.now() - S.failAt > 1500) finish(true);
    else if (S.phase === 'playing' && (S.t > S.lastNoteT + END_PAD || (audio.ended && S.t > S.startAt + 5))) finish(false);
  }

  render(dt);
  requestAnimationFrame(frame);
}

/* --------------------------------------------------------------- randare */

function render(dt) {
  var H = S.H, t = S.t, playing = S.phase !== 'lead';

  /* --- linii de masura --- */
  if (chart && lines.length) {
    var spb = 60 / (chart.bpm || 128);
    var B0 = Math.floor((t - chart.offset) / spb);
    for (var j = 0; j < lines.length; j++) {
      var B = B0 + j;
      var y = (1 - (chart.offset + B * spb - t) / LEAD) * H;
      var ln = lines[j];
      ln.style.transform = 'translate3d(0,' + y.toFixed(1) + 'px,0)';
      var bar = ((B % 4) + 4) % 4 === 0;
      if ((ln.dataset.bar === '1') !== bar) {
        ln.dataset.bar = bar ? '1' : '0';
        ln.classList.toggle('bar', bar);
      }
    }
  }

  /* --- note --- */
  if (S.notes.length) {
    var first = Math.max(0, S.head - 8);
    for (var i = first; i < S.notes.length; i++) {
      var n = S.notes[i];
      if (n.t - t > LEAD * 1.05) break;

      var y = (1 - (n.t - t) / LEAD) * H;
      var tail = n.d > 0.42 ? (n.d / LEAD) * H : 0;
      var gone = n.st === 1 || (n.st === 2 && y > H + 70) || y < -60 || y > H + 130;

      if (gone) { if (n.el) { giveEl(n.el); n.el = null; } continue; }
      if (!n.el) { n.el = takeEl(n.l); if (!n.el) continue; if (n.st === 2) n.el.classList.add('miss'); }

      var fade = n.st === 2 ? Math.max(0, 1 - (y - H) / 70) * 0.55
                            : Math.min(1, Math.max(0, y / (H * 0.22)));
      n.el.style.height = (HEADH + tail) + 'px';
      n.el.style.opacity = fade.toFixed(3);
      n.el.style.transform = 'translate3d(-50%,' + (y - HEADH / 2 - tail).toFixed(1) + 'px,0)';
    }
  }

  /* --- receptori --- */
  for (var l = 0; l < NLANES; l++) {
    var near = 0;
    if (playing) {
      for (var k = S.head; k < S.notes.length; k++) {
        var nn = S.notes[k];
        var d0 = nn.t - t;
        if (d0 > 0.28) break;
        if (nn.st || nn.l !== l) continue;
        if (d0 > -0.05) near = Math.max(near, 1 - d0 / 0.28);
      }
    }
    S.flash[l] = Math.max(0, S.flash[l] - dt * 4.5);
    S.missFlash[l] = Math.max(0, S.missFlash[l] - dt * 3);
    var held = S.down[l] ? 0.35 : 0;
    var r = recs[l];
    if (!r) continue;
    r.glow.style.opacity = Math.min(1, S.flash[l] + near * 0.35 + held).toFixed(3);
    r.fill.style.opacity = Math.min(0.9, S.flash[l] * 0.85 + held * 0.4).toFixed(3);
    r.box.style.transform = 'scale(' + (1 + S.flash[l] * 0.12 + near * 0.05).toFixed(3) + ')';
    if (S.missFlash[l] > 0.01) {
      r.fill.style.background = 'rgba(255,70,80,' + S.missFlash[l].toFixed(2) + ')';
      r.fill.dataset.red = '1';
    } else if (r.fill.dataset.red === '1') {
      r.fill.dataset.red = '0';
      r.fill.style.background = '';
    }
  }

  /* --- judecata / combo --- */
  S.judgeAge += dt;
  var a = S.judgeAge < 0.5 ? 1 : Math.max(0, 1 - (S.judgeAge - 0.5) / 0.35);
  var pop = S.judgeAge < 0.12 ? 1 + (0.12 - S.judgeAge) * 1.6 : 1;
  el.judge.style.opacity = a.toFixed(2);
  el.judge.style.transform = 'translate3d(0,' + (6 - a * 6).toFixed(1) + 'px,0) scale(' + pop.toFixed(3) + ')';

  var on = S.combo >= 2;
  el.comboBox.style.opacity = on ? '1' : '0';
  el.comboBox.style.transform = 'scale(' + (on ? (S.judgeAge < 0.1 ? 1.06 : 1) : 0.9) + ')';
  if (el.comboText.textContent !== 'x' + S.combo) el.comboText.textContent = 'x' + S.combo;

  /* --- progres --- */
  if (chart) {
    var span = S.songEnd - S.startAt;
    var done = clamp(t - S.startAt, 0, span);
    el.progressFill.style.width = (done / span * 100).toFixed(2) + '%';
    el.timeText.textContent = mmss(done) + ' / ' + mmss(span);
  }
}

/* ------------------------------------------------------------- rezultate */

function finish(failed) {
  S.phase = 'results';
  audio.pause();
  el.rateChip.classList.add('hidden');

  var total = S.notes.length;
  var acc = total ? S.hits / total : 0;

  showOverlay(
    failed ? 'SONG FAILED' : 'TRACK COMPLETE',
    failed ? 'FAILED' : String(S.score).padStart(5, '0'),
    (acc * 100).toFixed(1) + '% ACURATETE  ·  BEST COMBO x' + S.best +
    '\nPERFECT ' + S.counts.PERFECT + '   GOOD ' + S.counts.GOOD + '   MISS ' + S.counts.MISS +
    '\nSPACE = inca o tura   ·   ESC = lasi chitara jos',
    { fail: failed }
  );
  el.ovSub.style.whiteSpace = 'pre-line';

  post('finished', {
    failed: failed,
    score: S.score,
    accuracy: Math.round(acc * 1000) / 1000,
    maxCombo: S.best,
    notesHit: S.hits,
    notesTotal: total
  });
}

/* ----------------------------------------------------------------- input */

function onKeyDown(e) {
  if (S.phase === 'idle') return;
  var c = e.code;

  if (c === 'Escape') { e.preventDefault(); exitGame(); return; }

  if (c === 'KeyP' && (S.phase === 'playing' || S.phase === 'paused')) {
    e.preventDefault(); togglePause(); return;
  }

  if (c === 'Space' && S.phase === 'results') {
    e.preventDefault();
    el.ovSub.style.whiteSpace = '';
    startRun();
    post('runStarted', {});
    return;
  }

  if (c === 'BracketLeft')  { S.offsetMs -= 5; savePrefs(); el.offsetText.textContent = S.offsetMs + ' ms'; return; }
  if (c === 'BracketRight') { S.offsetMs += 5; savePrefs(); el.offsetText.textContent = S.offsetMs + ' ms'; return; }
  if (c === 'Minus' || c === 'NumpadSubtract') {
    S.volume = clamp(S.volume - 0.05, 0, 1); audio.volume = S.volume; savePrefs();
    el.volText.textContent = Math.round(S.volume * 100) + '%'; return;
  }
  if (c === 'Equal' || c === 'NumpadAdd') {
    S.volume = clamp(S.volume + 0.05, 0, 1); audio.volume = S.volume; savePrefs();
    el.volText.textContent = Math.round(S.volume * 100) + '%'; return;
  }

  var lane = KEYS.indexOf(c);
  if (lane < 0) return;
  e.preventDefault();
  if (S.down[lane]) return;
  S.down[lane] = 1;
  press(lane);
}

function onKeyUp(e) {
  var lane = KEYS.indexOf(e.code);
  if (lane >= 0) S.down[lane] = 0;
}

function togglePause() {
  if (S.phase === 'playing') {
    S.phase = 'paused';
    audio.pause();
    showOverlay('PAUZA', 'PAUSED', 'P = continui  ·  ESC = iesi');
  } else if (S.phase === 'paused') {
    S.phase = 'playing';
    Clock.ctLast = -1;
    audio.play();
    hideOverlay();
  }
}

/* ------------------------------------------------------------- preferinte */

function savePrefs() {
  try { localStorage.setItem('bs_gh_prefs', JSON.stringify({ offsetMs: S.offsetMs, volume: S.volume })); } catch (e) {}
}
function loadPrefs() {
  try {
    var p = JSON.parse(localStorage.getItem('bs_gh_prefs') || '{}');
    if (typeof p.offsetMs === 'number') S.offsetMs = p.offsetMs;
    if (typeof p.volume === 'number') S.volume = clamp(p.volume, 0, 1);
  } catch (e) {}
}

/* ---------------------------------------------------------------- masura */

function measure() {
  S.H = (el.highway && el.highway.clientHeight) || 400;
}

/* -------------------------------------------------------------- deschidere */

function openGame(data) {
  cfg = data;
  S.offsetMs = cfg.offsetMs || 0;
  S.volume = typeof cfg.volume === 'number' ? cfg.volume : 0.55;
  loadPrefs();
  el.offsetText.textContent = S.offsetMs + ' ms';
  el.volText.textContent = Math.round(S.volume * 100) + '%';
  el.hints.classList.toggle('hidden', cfg.hud && cfg.hud.hints === false);

  var hud = cfg.hud || {};
  document.documentElement.style.setProperty('--hud-scale', hud.scale || 1);
  document.documentElement.style.setProperty('--highway-vh', hud.highwayVh || 30);
  el.stage.classList.toggle('center', hud.anchor === 'center');
  el.root.style.opacity = hud.opacity != null ? hud.opacity : 1;

  el.root.classList.remove('hidden');
  measure();
  load();
}

function closeGame() {
  S.phase = 'idle';
  audio.pause();
  el.root.classList.add('hidden');
  hideOverlay();
}

function exitGame() { closeGame(); post('exit', {}); }

/* ------------------------------------------------------------------- boot */

window.addEventListener('DOMContentLoaded', function () {
  ['root', 'stage', 'hud', 'meterChip', 'meterFill', 'meterVal', 'rateChip', 'rateText',
   'trackLabel', 'timeText', 'progressFill', 'scoreText', 'accText', 'comboBox', 'comboText',
   'judge', 'highway', 'beats', 'notes', 'recs', 'hints', 'offsetText', 'volText',
   'overlay', 'ovKicker', 'ovTitle', 'ovSub'].forEach(function (id) { el[id] = $(id); });

  audio = $('track');

  window.addEventListener('resize', measure);
  window.addEventListener('keydown', onKeyDown);
  window.addEventListener('keyup', onKeyUp);
  window.addEventListener('blur', function () { S.down = [0, 0, 0, 0]; });
  if (window.ResizeObserver) new ResizeObserver(measure).observe(el.highway);

  window.addEventListener('message', function (ev) {
    var d = ev.data || {};
    if (d.action === 'open') openGame(d.data);
    else if (d.action === 'close') closeGame();
  });

  window.__BSGH = { S: S, cfg: function () { return cfg; }, songTime: songTime };

  requestAnimationFrame(frame);
});

})();
