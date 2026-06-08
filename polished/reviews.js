/* Black Silva — reviews data layer.
   Shared by the salon hero teaser and the full reviews.html feed.

   STORAGE:
   - If a Worker URL is set below (DEFAULT_API) the reviews are stored on the
     server (Cloudflare Worker + KV) and shared with EVERY visitor.
   - Until then it falls back to this browser's localStorage, so the feature
     works immediately for you to try — but reviews only live on this device.

   To go global: deploy the Worker (see booking-mailer/README) and paste its
   URL into DEFAULT_API below, e.g.
     var DEFAULT_API = 'https://blacksilva-mailer.<your-account>.workers.dev'; */
(function(){
  var DEFAULT_API = '';                              // <-- paste your Worker URL here to share reviews globally
  var API = (localStorage.getItem('bs_reviews_api') || DEFAULT_API || '').replace(/\/+$/,'');
  var LS_KEY = 'bs_reviews_v1';

  function hash(s){ s=String(s||'').trim().toLowerCase(); var h=5381; for(var i=0;i<s.length;i++){ h=((h<<5)+h)+s.charCodeAt(i); h|=0; } return 'c'+(h>>>0).toString(36); }
  function uid(){ return Date.now().toString(36)+Math.random().toString(36).slice(2,7); }
  function localAll(){ try{ return JSON.parse(localStorage.getItem(LS_KEY)||'[]'); }catch(e){ return []; } }
  function localSave(a){ try{ localStorage.setItem(LS_KEY, JSON.stringify(a)); }catch(e){} }

  /* seed a couple of example threads the very first time, so the feed isn't empty */
  function seed(){
    if(localStorage.getItem(LS_KEY)) return;
    var now=Date.now(), day=86400000;
    localSave([
      { id:uid(), name:'Mette K.', emailHash:hash('mette@example.com'), created:now-120*day, updated:now-2*day, posts:[
        { role:'client', visit:1, rating:5, service:'Ladies cut & style', stylist:'Elena', experience:'Calm, unhurried, and Elena really listened before touching the scissors.', recommend:'yes', compare:'', text:'Walked out feeling like myself again.', ts:now-120*day },
        { role:'salon', text:'Thank you Mette — it was a joy. See you next season! — Black Silva', ts:now-119*day },
        { role:'client', visit:2, rating:5, service:'Ladies cut & style', stylist:'Elena', experience:'Even better than the first time.', recommend:'yes', compare:'Second visit was sharper — she remembered exactly how I like my layers from last time.', text:'Consistency is real here.', ts:now-2*day }
      ]},
      { id:uid(), name:'Andrei P.', emailHash:hash('andrei@example.com'), created:now-40*day, updated:now-40*day, posts:[
        { role:'client', visit:1, rating:5, service:'Skin fade', stylist:'Eduard', experience:'Clean lines, great chat, coffee was a nice touch.', recommend:'yes', compare:'', text:'Best fade I have had in Copenhagen.', ts:now-40*day }
      ]}
    ]);
  }
  seed();

  function list(){
    if(API) return fetch(API+'/reviews').then(function(r){return r.json();}).then(function(d){ return d.threads||[]; }).catch(function(){ return localAll(); });
    return Promise.resolve(localAll());
  }
  /* p: {name,email,service,stylist,rating,experience,recommend,compare,text} */
  function add(p){
    if(API) return fetch(API+'/reviews',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)}).then(function(r){return r.json();});
    var all=localAll(), eh=hash(p.email), now=Date.now();
    var th=all.filter(function(t){return t.emailHash===eh;})[0];
    if(!th){ th={id:uid(),name:p.name||'Guest',emailHash:eh,created:now,posts:[]}; }
    var visit=th.posts.filter(function(x){return x.role==='client';}).length+1;
    th.posts.push({role:'client',visit:visit,rating:+p.rating||0,service:p.service||'',stylist:p.stylist||'',experience:p.experience||'',recommend:p.recommend||'',compare:p.compare||'',text:p.text||'',ts:now});
    th.name=p.name||th.name; th.updated=now;
    all=all.filter(function(t){return t.id!==th.id;}); all.unshift(th); localSave(all);
    return Promise.resolve({ok:true,thread:th,visit:visit});
  }
  function reply(threadId,text,passcode){
    if(API) return fetch(API+'/reviews/reply',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({threadId:threadId,text:text,passcode:passcode})}).then(function(r){return r.json();});
    var all=localAll(), th=all.filter(function(t){return t.id===threadId;})[0]; if(!th) return Promise.resolve({error:'not found'});
    th.posts.push({role:'salon',text:text,ts:Date.now()}); th.updated=Date.now(); localSave(all);
    return Promise.resolve({ok:true,thread:th});
  }
  /* find an existing thread for an email (to continue it) */
  function findByEmail(email){ var eh=hash(email); return list().then(function(ts){ return ts.filter(function(t){return t.emailHash===eh;})[0]||null; }); }

  function clientPosts(th){ return th.posts.filter(function(p){return p.role==='client';}); }
  function avg(th){ var cs=clientPosts(th).filter(function(p){return p.rating;}); if(!cs.length) return 0; return cs.reduce(function(s,p){return s+(+p.rating||0);},0)/cs.length; }
  function stars(n){ n=Math.max(0,Math.min(5,Math.round(n))); var s=''; for(var i=1;i<=5;i++) s+=(i<=n?'★':'☆'); return s; }
  function timeAgo(ts){ var d=Math.floor((Date.now()-ts)/1000);
    if(d<60) return 'just now'; if(d<3600) return Math.floor(d/60)+'m ago'; if(d<86400) return Math.floor(d/3600)+'h ago';
    var days=Math.floor(d/86400); if(days<30) return days+'d ago'; if(days<365) return Math.floor(days/30)+'mo ago'; return Math.floor(days/365)+'y ago'; }

  function summary(){ return list().then(function(ts){
    var total=0,count=0,visits=0;
    ts.forEach(function(t){ clientPosts(t).forEach(function(p){ visits++; if(p.rating){ total+=+p.rating; count++; } }); });
    return { threads:ts.length, visits:visits, avg: count?total/count:0, latest: ts[0]||null };
  }); }

  window.BSReviews={ list:list, add:add, reply:reply, findByEmail:findByEmail, summary:summary,
    avg:avg, stars:stars, timeAgo:timeAgo, clientPosts:clientPosts, hash:hash, hasAPI:!!API };
})();
