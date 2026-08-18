/* ==========================================================================
   Rhythm Highway HUD  --  bs_guitarhero
   Joc de ritm sincronizat pe fisierul audio. Ceasul jocului este derivat
   direct din <audio>.currentTime, deci orice schimbare de viteza a melodiei
   (penalizarile pentru note ratate) tine automat si notele sincronizate.
   ========================================================================== */
(function () {
'use strict';

/* ---------------------------------------------------------------- constante */

var LANES = 5;
var LANE_COLORS = ['#35e07f', '#ff3b5c', '#ffd23f', '#3aa0ff', '#ff8a2b'];
var LANE_DIM    = ['#0f3d24', '#3d1019', '#3d3310', '#0f2a3d', '#3d2410'];

var LEAD_IN  = 3.0;   // secunde de numaratoare inainte sa porneasca melodia
var END_PAD  = 2.4;   // cat mai asteptam dupa ultima nota

var JUDGE = [
  { name: 'PERFECT', rel: 0.35, score: 100, color: '#00e5ff' },
  { name: 'GREAT',   rel: 0.65, score: 60,  color: '#35e07f' },
  { name: 'GOOD',    rel: 1.00, score: 30,  color: '#ffd23f' }
];

/* ------------------------------------------------------------------ helpere */

var $ = function (id) { return document.getElementById(id); };
function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
function lerp(a, b, t) { return a + (b - a) * t; }
function post(name, body) {
  if (typeof GetParentResourceName !== 'function') return Promise.resolve();
  return fetch('https://' + GetParentResourceName() + '/' + name, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body || {})
  }).catch(function () {});
}

/* -------------------------------------------------------------------- stare */

var cfg = null;          // payload trimis din Lua
var chart = null;        // chart brut din json
var diff = null;         // dificultatea selectata
var diffIndex = 1;

var el = {};
var cv, ctx, DPR = 1, W = 0, H = 0;

var audio = null;

var S = {
  phase: 'idle',         // idle|loading|ready|lead|playing|paused|failing|results
  notes: [],
  head: 0,               // prima nota nejudecata
  score: 0,
  combo: 0,
  maxCombo: 0,
  hits: 0,
  misses: 0,
  overstrums: 0,
  counts: { PERFECT: 0, GREAT: 0, GOOD: 0, MISS: 0 },
  meter: 55,
  rate: 1,
  rateTarget: 1,
  songTime: -LEAD_IN,
  lastNoteT: 0,
  offsetMs: 0,
  volume: 0.55,
  laneDown: [0, 0, 0, 0, 0],
  laneFlash: [0, 0, 0, 0, 0],
  laneMissFlash: [0, 0, 0, 0, 0],
  particles: [],
  sectionIdx: -1,
  failAt: 0,
  leadStart: 0,
  lastCd: null,
  shake: 0
};

/* -------------------------------------------------------------------- ceas */

var Clock = {
  mode: 'lead',
  ctLast: -1,
  perfAtCt: 0,
  reset: function () { this.mode = 'lead'; this.ctLast = -1; this.perfAtCt = 0; },
  raw: function () {
    if (this.mode === 'lead') {
      return (performance.now() - S.leadStart) / 1000 - LEAD_IN;
    }
    var ct = audio.currentTime;
    var p  = performance.now() / 1000;
    if (ct !== this.ctLast) { this.ctLast = ct; this.perfAtCt = p; }
    var dt = p - this.perfAtCt;
    if (dt > 0.30 || dt < 0) dt = 0;          // audio blocat -> nu extrapolam
    return ct + dt * (audio.playbackRate || 1);
  }
};

function songTime() { return Clock.raw() - S.offsetMs / 1000; }

/* ------------------------------------------------------------------- canvas */

function resize() {
  DPR = clamp(window.devicePixelRatio || 1, 1, 1.5);
  W = window.innerWidth;
  H = window.innerHeight;
  cv.width  = Math.round(W * DPR);
  cv.height = Math.round(H * DPR);
  cv.style.width  = W + 'px';
  cv.style.height = H + 'px';
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
}

/* geometrie: p = 0 la linia de lovire, 1 la orizont */
var K = 0.55;
function geo() {
  var horizonY = H * 0.15;
  var hitY     = H * 0.795;
  return {
    cx: W / 2,
    horizonY: horizonY,
    hitY: hitY,
    halfW: Math.min(W * 0.33, 480),
    depth: hitY - horizonY
  };
}
function scaleAt(p) { return K / (p + K); }            // 1 la p=0
function yAt(g, p)  { return g.hitY - g.depth * (1 + K) * (1 - scaleAt(p)); }
function laneX(g, i, s) { return g.cx + (i - (LANES - 1) / 2) * (g.halfW * 2 / LANES) * s; }

/* --------------------------------------------------------------- incarcare */

function loadChart() {
  setPanel('panelLoading');
  var pct = 10;
  var iv = setInterval(function () {
    pct = Math.min(92, pct + 6);
    el.loadFill.style.width = pct + '%';
  }, 90);

  var chartUrl = cfg.song.chart || 'data/faint.json';
  var audioUrl = cfg.song.audio || 'audio/faint.mp3';

  var pChart = fetch(chartUrl).then(function (r) { return r.json(); });

  var pAudio = new Promise(function (resolve) {
    audio.src = audioUrl;
    audio.load();
    var done = false;
    var ok = function () { if (!done) { done = true; resolve(); } };
    audio.addEventListener('canplaythrough', ok, { once: true });
    audio.addEventListener('loadeddata', ok, { once: true });
    setTimeout(ok, 8000);
  });

  Promise.all([pChart, pAudio]).then(function (res) {
    clearInterval(iv);
    el.loadFill.style.width = '100%';
    chart = res[0];
    buildReady();
  }).catch(function (e) {
    clearInterval(iv);
    console.error('[bs_guitarhero] nu am putut incarca chart/audio', e);
    exitGame();
  });
}

/* ------------------------------------------------------------------- ready */

function buildDiffRow() {
  el.diffRow.innerHTML = '';
  cfg.difficulties.forEach(function (d, i) {
    var n = chart.notes.filter(function (x) { return x.s <= d.maxSub; }).length;
    var b = document.createElement('div');
    b.className = 'diff' + (i === diffIndex ? ' sel' : '');
    b.innerHTML = d.name + '<span class="diff-note">' + n + ' note</span>';
    el.diffRow.appendChild(b);
  });
}

function buildKeyRow(container, big) {
  container.innerHTML = '';
  for (var i = 0; i < LANES; i++) {
    var d = document.createElement('div');
    d.className = big ? 'pk' : 'key-cap';
    d.textContent = keyLabel(cfg.keys[i]);
    if (big) { d.style.background = LANE_COLORS[i]; }
    else { d.style.borderColor = LANE_COLORS[i] + '66'; }
    container.appendChild(d);
  }
}

function keyLabel(code) {
  if (!code) return '?';
  return code.replace('Key', '').replace('Digit', '').replace('Numpad', 'N');
}

function buildReady() {
  diffIndex = Math.max(0, cfg.difficulties.findIndex(function (d) { return d.id === cfg.difficulty; }));
  diff = cfg.difficulties[diffIndex];

  el.songTitle.textContent  = chart.title || cfg.song.title;
  el.songArtist.textContent = chart.artist || cfg.song.artist;
  el.songAlbum.textContent  = chart.album || cfg.song.album || '';
  el.readyNotes.textContent = chart.notes.length;

  buildDiffRow();
  buildKeyRow(el.readyKeys, true);
  buildKeyRow(el.keysRow, false);

  S.phase = 'ready';
  setPanel('panelReady');
}

function selectDiff(i) {
  diffIndex = (i + cfg.difficulties.length) % cfg.difficulties.length;
  diff = cfg.difficulties[diffIndex];
  buildDiffRow();
  post('setDifficulty', { difficulty: diff.id });
}

/* -------------------------------------------------------------------- start */

function startRun() {
  S.notes = chart.notes
    .filter(function (n) { return n.s <= diff.maxSub; })
    .map(function (n) {
      return { t: n.t, l: n.l, d: n.d, k: n.k, judged: false, hitAt: 0, res: null };
    });

  S.head = 0;
  S.score = 0; S.combo = 0; S.maxCombo = 0;
  S.hits = 0; S.misses = 0; S.overstrums = 0;
  S.counts = { PERFECT: 0, GREAT: 0, GOOD: 0, MISS: 0 };
  S.meter = cfg.meter.start;
  S.rate = 1; S.rateTarget = 1;
  S.particles = [];
  S.sectionIdx = -1;
  S.lastCd = null;
  S.shake = 0;
  S.lastNoteT = S.notes.length ? S.notes[S.notes.length - 1].t : 0;

  audio.pause();
  try { audio.currentTime = 0; } catch (e) {}
  audio.playbackRate = 1;
  audio.volume = S.volume;
  if ('preservesPitch' in audio) audio.preservesPitch = false;
  if ('mozPreservesPitch' in audio) audio.mozPreservesPitch = false;
  if ('webkitPreservesPitch' in audio) audio.webkitPreservesPitch = false;

  Clock.reset();
  S.leadStart = performance.now();
  S.phase = 'lead';

  el.failVeil.style.opacity = 0;
  el.rateBadge.classList.add('hidden');
  setPanel('countdown');
  syncHud();
  post('runStarted', { difficulty: diff.id });
}

function beginAudio() {
  Clock.mode = 'audio';
  var pr = audio.play();
  if (pr && pr.catch) pr.catch(function (e) { console.warn('[bs_guitarhero] audio.play()', e); });
  S.phase = 'playing';
  setPanel(null);
}

/* ------------------------------------------------------------------ judging */

function judgeName(absDt, win) {
  for (var i = 0; i < JUDGE.length; i++) {
    if (absDt <= win * JUDGE[i].rel) return JUDGE[i];
  }
  return null;
}

function multiplier() { return clamp(1 + Math.floor(S.combo / 10), 1, 4); }

function pressLane(lane) {
  if (S.phase !== 'playing') return;

  var t = songTime();
  var win = diff.hitWindow;
  var best = -1, bestDt = 1e9;

  for (var i = S.head; i < S.notes.length; i++) {
    var n = S.notes[i];
    if (n.t - t > win) break;
    if (n.judged || n.l !== lane) continue;
    var dt = Math.abs(n.t - t);
    if (dt <= win && dt < bestDt) { bestDt = dt; best = i; }
  }

  if (best < 0) { overstrum(lane); return; }

  var n2 = S.notes[best];
  var j = judgeName(bestDt, win) || JUDGE[JUDGE.length - 1];

  n2.judged = true;
  n2.res = j.name;
  n2.hitAt = t;

  S.hits++;
  S.counts[j.name]++;
  S.combo++;
  S.maxCombo = Math.max(S.maxCombo, S.combo);
  S.score += Math.round(j.score * multiplier());

  var gain = j.name === 'PERFECT' ? cfg.meter.perfect
           : j.name === 'GREAT'   ? cfg.meter.great
           : cfg.meter.good;
  S.meter = clamp(S.meter + gain, 0, cfg.meter.max);

  S.laneFlash[lane] = 1;
  burst(lane, j.color, j.name === 'PERFECT' ? 16 : 9);
  flashJudge(j.name, j.color);
  bumpCombo();
  syncHud();
}

function overstrum(lane) {
  if (songTime() < 0.25) return;
  S.overstrums++;
  S.combo = 0;
  S.meter = clamp(S.meter - cfg.meter.overstrum, 0, cfg.meter.max);
  S.laneMissFlash[lane] = 1;
  flashJudge('OVERSTRUM', '#ff8a2b');
  syncHud();
  checkFail();
}

function missNote(n) {
  n.judged = true;
  n.res = 'MISS';
  S.misses++;
  S.counts.MISS++;
  S.combo = 0;
  S.meter = clamp(S.meter - diff.missPenalty, 0, cfg.meter.max);
  S.laneMissFlash[n.l] = 1;
  S.shake = Math.min(1, S.shake + 0.35);
  flashJudge('MISS', '#ff3b5c');
  syncHud();
  checkFail();
}

function checkFail() {
  if (S.phase !== 'playing') return;
  if (S.meter <= (cfg.meter.failAt || 0)) {
    S.phase = 'failing';
    S.failAt = performance.now();
    el.failVeil.style.opacity = 1;
  }
}

/* --------------------------------------------------------------------- HUD */

function syncHud() {
  el.scoreValue.textContent = S.score.toLocaleString('en-US');

  var m = multiplier();
  el.multValue.textContent = 'x' + m;
  el.multValue.className = 'mult m' + m;

  var total = S.hits + S.misses;
  var acc = total ? (S.hits / total) : 1;
  el.accValue.textContent = (acc * 100).toFixed(1) + '%';

  var pct = clamp(S.meter / cfg.meter.max, 0, 1);
  el.meterFill.style.height = (pct * 100) + '%';
  el.meterFill.classList.toggle('warn', S.meter < cfg.meter.slowFrom);
  el.meterReadout.textContent = Math.round(S.meter) + '%';

  el.comboValue.textContent = S.combo;
  el.comboStack.classList.toggle('on', S.combo >= 5);
}

function bumpCombo() {
  el.comboStack.classList.remove('bump');
  void el.comboStack.offsetWidth;
  el.comboStack.classList.add('bump');
}

function flashJudge(text, color) {
  el.judgeFlash.textContent = text;
  el.judgeFlash.style.color = color;
  el.judgeFlash.style.textShadow = '0 0 26px ' + color + '99';
  el.judgeFlash.classList.remove('show');
  void el.judgeFlash.offsetWidth;
  el.judgeFlash.classList.add('show');
}

function setPanel(id) {
  ['panelReady', 'panelPause', 'panelResults', 'panelLoading', 'countdown'].forEach(function (p) {
    el[p].classList.toggle('hidden', p !== id);
  });
  el.overlay.classList.toggle('hidden', !id);
}

function updateSection(t) {
  if (!chart.sections) return;
  var idx = -1;
  for (var i = 0; i < chart.sections.length; i++) {
    if (t >= chart.sections[i].t) idx = i; else break;
  }
  if (idx !== S.sectionIdx) {
    S.sectionIdx = idx;
    el.sectionChip.textContent = idx >= 0 ? chart.sections[idx].name.toUpperCase() : 'INTRO';
  }
}

/* --------------------------------------------------------------- particule */

function burst(lane, color, n) {
  var g = geo();
  var x = laneX(g, lane, 1), y = g.hitY;
  for (var i = 0; i < n; i++) {
    var a = Math.random() * Math.PI * 2;
    var sp = 90 + Math.random() * 300;
    S.particles.push({
      x: x, y: y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp * 0.6 - 90,
      life: 1, color: color, r: 1.6 + Math.random() * 2.6
    });
  }
  if (S.particles.length > 320) S.particles.splice(0, S.particles.length - 320);
}

/* ----------------------------------------------------------------- update */

var lastFrame = 0;

function update(now) {
  var dt = lastFrame ? Math.min(0.05, (now - lastFrame) / 1000) : 0;
  lastFrame = now;

  for (var i = 0; i < LANES; i++) {
    S.laneFlash[i]     = Math.max(0, S.laneFlash[i] - dt * 4.2);
    S.laneMissFlash[i] = Math.max(0, S.laneMissFlash[i] - dt * 3.2);
  }
  S.shake = Math.max(0, S.shake - dt * 2.4);

  for (var p = S.particles.length - 1; p >= 0; p--) {
    var q = S.particles[p];
    q.life -= dt * 1.7;
    if (q.life <= 0) { S.particles.splice(p, 1); continue; }
    q.x += q.vx * dt; q.y += q.vy * dt; q.vy += 780 * dt;
  }

  if (S.phase === 'lead') {
    S.songTime = Clock.raw();
    var left = Math.ceil(-S.songTime);
    var label = left > 0 ? String(left) : 'GO';
    if (label !== S.lastCd) {
      S.lastCd = label;
      el.countdown.textContent = label;
      el.countdown.classList.toggle('go', label === 'GO');
      el.countdown.classList.remove('tick');
      void el.countdown.offsetWidth;
      el.countdown.classList.add('tick');
    }
    if (S.songTime >= 0) beginAudio();
    return;
  }

  if (S.phase === 'playing' || S.phase === 'failing') {
    S.songTime = songTime();
    updateSection(S.songTime);

    /* --- note ratate --- */
    if (S.phase === 'playing') {
      var win = diff.hitWindow;
      while (S.head < S.notes.length && S.notes[S.head].t < S.songTime - win) {
        var n = S.notes[S.head];
        if (!n.judged) missNote(n);
        S.head++;
      }
    }

    /* --- viteza melodiei in functie de rock meter --- */
    if (S.phase === 'playing') {
      var sf = cfg.meter.slowFrom, mr = cfg.meter.minRate;
      S.rateTarget = S.meter >= sf ? 1 : mr + (1 - mr) * (S.meter / sf);
    } else {
      S.rateTarget = 0.25;                     // se stinge la esec
    }
    S.rate = lerp(S.rate, S.rateTarget, clamp(dt * 2.6, 0, 1));
    var applied = clamp(S.rate, 0.25, 1);
    if (Math.abs(audio.playbackRate - applied) > 0.004) audio.playbackRate = applied;

    var slow = applied < 0.985;
    el.rateBadge.classList.toggle('hidden', !slow);
    if (slow) el.rateText.textContent = 'x' + applied.toFixed(2) + ' SPEED';

    var prog = clamp(S.songTime / (chart.duration || 163), 0, 1);
    el.progressFill.style.width = (prog * 100) + '%';

    /* --- final --- */
    if (S.phase === 'failing' && performance.now() - S.failAt > 1400) {
      finish(true);
    } else if (S.phase === 'playing' &&
               (S.songTime > S.lastNoteT + END_PAD || (audio.ended && S.songTime > 5))) {
      finish(false);
    }
  }
}

/* ---------------------------------------------------------------- rezultate */

function finish(failed) {
  S.phase = 'results';
  audio.pause();
  el.rateBadge.classList.add('hidden');

  var total = S.notes.length;
  var acc = total ? S.hits / total : 0;

  el.resKicker.textContent = failed ? 'SONG FAILED' : 'SONG COMPLETE';
  el.resKicker.classList.toggle('fail', failed);
  el.resTitle.textContent = failed ? 'FAILED' : (chart.title || 'FAINT');

  var stars = failed ? 0 : (acc >= 0.99 ? 5 : acc >= 0.94 ? 4 : acc >= 0.85 ? 3 : acc >= 0.7 ? 2 : acc >= 0.5 ? 1 : 0);
  el.resStars.innerHTML = '';
  for (var i = 0; i < 5; i++) {
    var s = document.createElement('div');
    s.className = 'star' + (i < stars ? ' on' : '');
    el.resStars.appendChild(s);
  }

  el.resScore.textContent = S.score.toLocaleString('en-US');
  el.resAcc.textContent   = (acc * 100).toFixed(1) + '%';
  el.resCombo.textContent = S.maxCombo;
  el.resNotes.textContent = S.hits + '/' + total;

  el.resBreak.innerHTML = '';
  [['PERFECT', '#00e5ff'], ['GREAT', '#35e07f'], ['GOOD', '#ffd23f'], ['MISS', '#ff3b5c']]
    .forEach(function (pair) {
      var d = document.createElement('div');
      d.className = 'rb';
      d.innerHTML = '<i style="background:' + pair[1] + '"></i>' + pair[0] + ' <b>' + S.counts[pair[0]] + '</b>';
      el.resBreak.appendChild(d);
    });
  var ov = document.createElement('div');
  ov.className = 'rb';
  ov.innerHTML = '<i style="background:#ff8a2b"></i>OVERSTRUM <b>' + S.overstrums + '</b>';
  el.resBreak.appendChild(ov);

  setPanel('panelResults');
  el.failVeil.style.opacity = failed ? 1 : 0;

  post('finished', {
    failed: failed,
    score: S.score,
    accuracy: Math.round(acc * 1000) / 1000,
    maxCombo: S.maxCombo,
    notesHit: S.hits,
    notesTotal: total,
    difficulty: diff.id
  });
}

/* -------------------------------------------------------------------- render */

function render() {
  var g = geo();

  ctx.save();
  if (S.shake > 0.01) {
    ctx.translate((Math.random() - 0.5) * 10 * S.shake, (Math.random() - 0.5) * 8 * S.shake);
  }

  ctx.clearRect(-20, -20, W + 40, H + 40);

  /* --- fundal --- */
  var bg = ctx.createRadialGradient(g.cx, g.horizonY, 10, g.cx, g.horizonY, Math.max(W, H) * 0.95);
  var heat = clamp(S.combo / 60, 0, 1);
  bg.addColorStop(0, S.phase === 'failing' ? 'rgba(60,6,16,.95)' : 'rgba(10,16,34,.95)');
  bg.addColorStop(0.42, 'rgba(5,7,16,.97)');
  bg.addColorStop(1, 'rgba(2,3,8,1)');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  /* halo pe orizont, se aprinde cu streak-ul */
  var halo = ctx.createRadialGradient(g.cx, g.horizonY, 0, g.cx, g.horizonY, g.halfW * 1.5);
  halo.addColorStop(0, 'rgba(0,229,255,' + (0.10 + heat * 0.20) + ')');
  halo.addColorStop(1, 'rgba(0,229,255,0)');
  ctx.fillStyle = halo;
  ctx.fillRect(0, 0, W, H);

  var sHor = scaleAt(1);

  /* --- suprafata autostrazii --- */
  ctx.beginPath();
  ctx.moveTo(g.cx - g.halfW, H);
  ctx.lineTo(g.cx - g.halfW * sHor, g.horizonY);
  ctx.lineTo(g.cx + g.halfW * sHor, g.horizonY);
  ctx.lineTo(g.cx + g.halfW, H);
  ctx.closePath();
  var road = ctx.createLinearGradient(0, g.horizonY, 0, H);
  road.addColorStop(0, 'rgba(12,20,40,0)');
  road.addColorStop(0.35, 'rgba(10,16,34,.55)');
  road.addColorStop(1, 'rgba(6,10,22,.92)');
  ctx.fillStyle = road;
  ctx.fill();

  /* --- benzi colorate cand tii tasta apasata --- */
  for (var i = 0; i < LANES; i++) {
    var lit = Math.max(S.laneDown[i] ? 0.16 : 0, S.laneFlash[i] * 0.55);
    if (lit <= 0.01) continue;
    var step = g.halfW * 2 / LANES;
    ctx.beginPath();
    ctx.moveTo(laneX(g, i, 1) - step / 2, H);
    ctx.lineTo(laneX(g, i, sHor) - step * sHor / 2, g.horizonY);
    ctx.lineTo(laneX(g, i, sHor) + step * sHor / 2, g.horizonY);
    ctx.lineTo(laneX(g, i, 1) + step / 2, H);
    ctx.closePath();
    var lg = ctx.createLinearGradient(0, g.horizonY, 0, g.hitY);
    lg.addColorStop(0, 'rgba(0,0,0,0)');
    lg.addColorStop(1, LANE_COLORS[i] + Math.round(lit * 90).toString(16).padStart(2, '0'));
    ctx.fillStyle = lg;
    ctx.fill();
  }

  /* --- linii intre benzi --- */
  ctx.lineWidth = 1;
  for (var d0 = 0; d0 <= LANES; d0++) {
    var xh = g.cx + (d0 - LANES / 2) * (g.halfW * 2 / LANES);
    var xf = g.cx + (d0 - LANES / 2) * (g.halfW * 2 / LANES) * sHor;
    var edge = (d0 === 0 || d0 === LANES);
    ctx.strokeStyle = edge ? 'rgba(0,229,255,.35)' : 'rgba(255,255,255,.09)';
    ctx.beginPath();
    ctx.moveTo(xf, g.horizonY);
    ctx.lineTo(xh, H);
    ctx.stroke();
  }

  /* --- linii de masura / timp --- */
  if (chart && S.phase !== 'ready') {
    var spb = 60 / (chart.bpm || 135);
    var travel = cfg.travel;
    var t0 = S.songTime;
    var firstBeat = Math.floor((t0 - chart.offset) / spb) + 1;
    for (var b = firstBeat; b < firstBeat + Math.ceil(travel / spb) + 2; b++) {
      var bt = chart.offset + b * spb;
      var bp = (bt - t0) / travel;
      if (bp < -0.05 || bp > 1) continue;
      var bs = scaleAt(bp), by = yAt(g, bp);
      var isBar = ((b % 4) + 4) % 4 === 0;
      ctx.strokeStyle = isBar ? 'rgba(255,255,255,' + (0.20 * bs) + ')'
                              : 'rgba(255,255,255,' + (0.07 * bs) + ')';
      ctx.lineWidth = isBar ? 1.6 : 1;
      ctx.beginPath();
      ctx.moveTo(g.cx - g.halfW * bs, by);
      ctx.lineTo(g.cx + g.halfW * bs, by);
      ctx.stroke();
    }
  }

  /* --- bara de lovire --- */
  var hy = g.hitY;
  ctx.save();
  ctx.shadowColor = 'rgba(0,229,255,.85)';
  ctx.shadowBlur = 22;
  ctx.strokeStyle = 'rgba(0,229,255,.9)';
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(g.cx - g.halfW, hy);
  ctx.lineTo(g.cx + g.halfW, hy);
  ctx.stroke();
  ctx.restore();

  /* --- receptori --- */
  var stepW2 = g.halfW * 2 / LANES;
  for (var r = 0; r < LANES; r++) {
    var rx = laneX(g, r, 1);
    var rw = stepW2 * 0.72, rh = Math.min(H * 0.026, 24) * 1.05;
    var down = S.laneDown[r];
    var fl = S.laneFlash[r], mf = S.laneMissFlash[r];

    ctx.save();
    ctx.translate(rx, hy + (down ? 3 : 0));

    if (fl > 0.02) {
      ctx.shadowColor = LANE_COLORS[r];
      ctx.shadowBlur = 34 * fl;
    }
    roundRect(ctx, -rw / 2, -rh / 2, rw, rh, rh * 0.42);
    ctx.fillStyle = mf > 0.02
      ? 'rgba(255,59,92,' + (0.25 + mf * 0.5) + ')'
      : (down ? LANE_COLORS[r] + 'cc' : 'rgba(255,255,255,.05)');
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.lineWidth = 2;
    ctx.strokeStyle = fl > 0.02 ? '#ffffff' : LANE_COLORS[r] + (down ? 'ff' : '99');
    ctx.stroke();

    if (fl > 0.02) {
      ctx.globalAlpha = fl;
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 2;
      roundRect(ctx, -rw / 2 - 12 * fl, -rh / 2 - 9 * fl, rw + 24 * fl, rh + 18 * fl, rh);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
    ctx.restore();
  }

  /* --- note --- */
  if (S.phase !== 'ready' && S.notes.length) {
    var tv = cfg.travel;
    var tNow = S.songTime;
    var gemH = Math.min(H * 0.026, 24);
    var stepW = g.halfW * 2 / LANES;

    /* desenam de la departare spre camera */
    var list = [];
    for (var k = S.head; k < S.notes.length; k++) {
      var nn = S.notes[k];
      var pp = (nn.t - tNow) / tv;
      if (pp > 1.02) break;
      if (pp < -0.12) continue;
      if (nn.judged && nn.res !== 'MISS') continue;
      list.push([pp, nn]);
    }
    /* si notele deja depasite dar inca vizibile */
    for (var k2 = Math.max(0, S.head - 12); k2 < S.head; k2++) {
      var n2 = S.notes[k2];
      if (n2.judged && n2.res !== 'MISS') continue;
      var p2 = (n2.t - tNow) / tv;
      if (p2 > -0.12) list.push([p2, n2]);
    }
    list.sort(function (a, b) { return b[0] - a[0]; });

    for (var m = 0; m < list.length; m++) {
      var p = list[m][0], nt = list[m][1];
      var sc = scaleAt(p), y = yAt(g, p), x = laneX(g, nt.l, sc);
      var w = stepW * 0.72 * sc, h = gemH * sc;
      var col = LANE_COLORS[nt.l];
      var fade = p < 0 ? clamp(1 + p / 0.12, 0, 1) : 1;

      /* coada pentru notele lungi */
      if (nt.d > 0.34) {
        var pEnd = Math.min(1, (nt.t + nt.d - tNow) / tv);
        if (pEnd > p) {
          var yE = yAt(g, pEnd), sE = scaleAt(pEnd);
          ctx.beginPath();
          ctx.moveTo(x - w * 0.20, y);
          ctx.lineTo(laneX(g, nt.l, sE) - stepW * 0.72 * sE * 0.20, yE);
          ctx.lineTo(laneX(g, nt.l, sE) + stepW * 0.72 * sE * 0.20, yE);
          ctx.lineTo(x + w * 0.20, y);
          ctx.closePath();
          ctx.fillStyle = col + '33';
          ctx.fill();
        }
      }

      ctx.globalAlpha = fade;

      /* umbra / glow doar aproape de camera (performanta) */
      if (p < 0.45) {
        ctx.shadowColor = col;
        ctx.shadowBlur = 16 * sc;
      }

      roundRect(ctx, x - w / 2, y - h / 2, w, h, h * 0.42);
      var gg = ctx.createLinearGradient(0, y - h / 2, 0, y + h / 2);
      gg.addColorStop(0, '#ffffff');
      gg.addColorStop(0.32, col);
      gg.addColorStop(1, LANE_DIM[nt.l]);
      ctx.fillStyle = gg;
      ctx.fill();
      ctx.shadowBlur = 0;

      ctx.lineWidth = Math.max(1, 1.4 * sc);
      ctx.strokeStyle = 'rgba(255,255,255,.75)';
      ctx.stroke();

      ctx.globalAlpha = 1;
    }
  }

  /* --- particule --- */
  for (var pi = 0; pi < S.particles.length; pi++) {
    var pa = S.particles[pi];
    ctx.globalAlpha = clamp(pa.life, 0, 1);
    ctx.fillStyle = pa.color;
    ctx.beginPath();
    ctx.arc(pa.x, pa.y, pa.r * pa.life, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;

  ctx.restore();
}

function roundRect(c, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  c.beginPath();
  c.moveTo(x + r, y);
  c.lineTo(x + w - r, y);
  c.quadraticCurveTo(x + w, y, x + w, y + r);
  c.lineTo(x + w, y + h - r);
  c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  c.lineTo(x + r, y + h);
  c.quadraticCurveTo(x, y + h, x, y + h - r);
  c.lineTo(x, y + r);
  c.quadraticCurveTo(x, y, x + r, y);
  c.closePath();
}

/* -------------------------------------------------------------------- loop */

function frame(now) {
  update(now);
  if (S.phase !== 'idle') render();
  requestAnimationFrame(frame);
}

/* ------------------------------------------------------------------- input */

function laneOfKey(code) {
  var i = cfg.keys.indexOf(code);
  if (i >= 0) return i;
  i = (cfg.altKeys || []).indexOf(code);
  return i;
}

function onKeyDown(e) {
  if (S.phase === 'idle') return;
  var code = e.code;

  if (code === 'Escape') {
    e.preventDefault();
    if (S.phase === 'playing') { togglePause(); return; }
    exitGame();
    return;
  }

  if (S.phase === 'ready') {
    if (code === 'ArrowLeft')  { e.preventDefault(); selectDiff(diffIndex - 1); return; }
    if (code === 'ArrowRight') { e.preventDefault(); selectDiff(diffIndex + 1); return; }
    if (code === 'Space' || code === 'Enter') { e.preventDefault(); startRun(); return; }
  }

  if (S.phase === 'results' && (code === 'Space' || code === 'Enter')) {
    e.preventDefault();
    S.phase = 'ready';
    el.failVeil.style.opacity = 0;
    setPanel('panelReady');
    return;
  }

  if (code === 'KeyP' && (S.phase === 'playing' || S.phase === 'paused')) {
    e.preventDefault(); togglePause(); return;
  }

  /* calibrare + volum */
  if (code === 'BracketLeft')  { S.offsetMs -= 5; saveLocal(); el.offsetText.textContent = S.offsetMs + ' ms'; return; }
  if (code === 'BracketRight') { S.offsetMs += 5; saveLocal(); el.offsetText.textContent = S.offsetMs + ' ms'; return; }
  if (code === 'Minus' || code === 'NumpadSubtract') {
    S.volume = clamp(S.volume - 0.05, 0, 1); audio.volume = S.volume; saveLocal();
    el.volText.textContent = Math.round(S.volume * 100) + '%'; return;
  }
  if (code === 'Equal' || code === 'NumpadAdd') {
    S.volume = clamp(S.volume + 0.05, 0, 1); audio.volume = S.volume; saveLocal();
    el.volText.textContent = Math.round(S.volume * 100) + '%'; return;
  }

  var lane = laneOfKey(code);
  if (lane >= 0) {
    e.preventDefault();
    if (S.laneDown[lane]) return;              // ignoram auto-repeat
    S.laneDown[lane] = 1;
    var caps = el.keysRow.children;
    if (caps[lane]) {
      caps[lane].classList.add('down');
      caps[lane].style.background = LANE_COLORS[lane];
      caps[lane].style.color = '#050810';
    }
    pressLane(lane);
  }
}

function onKeyUp(e) {
  if (!cfg) return;
  var lane = laneOfKey(e.code);
  if (lane >= 0) {
    S.laneDown[lane] = 0;
    var caps = el.keysRow.children;
    if (caps[lane]) {
      caps[lane].classList.remove('down');
      caps[lane].style.background = '';
      caps[lane].style.color = '';
    }
  }
}

function togglePause() {
  if (S.phase === 'playing') {
    S.phase = 'paused';
    audio.pause();
    setPanel('panelPause');
  } else if (S.phase === 'paused') {
    S.phase = 'playing';
    Clock.ctLast = -1;
    audio.play();
    setPanel(null);
  }
}

/* --------------------------------------------------------- setari salvate */

function saveLocal() {
  try {
    localStorage.setItem('bs_gh_prefs', JSON.stringify({ offsetMs: S.offsetMs, volume: S.volume }));
  } catch (e) {}
}
function loadLocal() {
  try {
    var raw = localStorage.getItem('bs_gh_prefs');
    if (!raw) return;
    var p = JSON.parse(raw);
    if (typeof p.offsetMs === 'number') S.offsetMs = p.offsetMs;
    if (typeof p.volume === 'number') S.volume = clamp(p.volume, 0, 1);
  } catch (e) {}
}

/* ------------------------------------------------------------- deschidere */

function openGame(data) {
  cfg = data;
  S.offsetMs = cfg.offsetMs || 0;
  S.volume   = typeof cfg.volume === 'number' ? cfg.volume : 0.55;
  loadLocal();

  el.offsetText.textContent = S.offsetMs + ' ms';
  el.volText.textContent = Math.round(S.volume * 100) + '%';
  el.meterSlowTick.style.bottom = (clamp(cfg.meter.slowFrom / cfg.meter.max, 0, 1) * 100) + '%';

  document.getElementById('root').classList.remove('hidden');
  resize();
  S.phase = 'loading';
  loadChart();
}

function closeGame() {
  S.phase = 'idle';
  audio.pause();
  try { audio.currentTime = 0; } catch (e) {}
  document.getElementById('root').classList.add('hidden');
  setPanel(null);
}

function exitGame() {
  closeGame();
  post('exit', {});
}

/* --------------------------------------------------------------------- boot */

window.addEventListener('DOMContentLoaded', function () {
  ['songTitle', 'songArtist', 'songAlbum', 'sectionChip', 'scoreValue', 'multValue', 'accValue',
   'meterFill', 'meterReadout', 'meterSlowTick', 'rateBadge', 'rateText', 'comboStack', 'comboValue',
   'judgeFlash', 'keysRow', 'offsetText', 'volText', 'progressFill', 'overlay', 'panelReady',
   'panelPause', 'panelResults', 'panelLoading', 'countdown', 'diffRow', 'readyKeys', 'readyNotes',
   'resKicker', 'resTitle', 'resStars', 'resScore', 'resAcc', 'resCombo', 'resNotes', 'resBreak',
   'failVeil', 'loadFill'].forEach(function (id) { el[id] = $(id); });

  cv = $('highway');
  ctx = cv.getContext('2d');
  audio = $('track');

  window.addEventListener('resize', resize);
  window.addEventListener('keydown', onKeyDown);
  window.addEventListener('keyup', onKeyUp);
  window.addEventListener('blur', function () { S.laneDown = [0, 0, 0, 0, 0]; });

  window.addEventListener('message', function (ev) {
    var d = ev.data || {};
    if (d.action === 'open') openGame(d.data);
    else if (d.action === 'close') closeGame();
  });

  window.__BSGH = { S: S, geo: geo, cfgRef: function () { return cfg; },
                    diffRef: function () { return diff; }, songTime: songTime };

  resize();
  requestAnimationFrame(frame);
});

})();
