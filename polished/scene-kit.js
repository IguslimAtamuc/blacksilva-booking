/* Black Silva — shared 3D scene kit (Three.js r128).
   A small reusable toolkit: the same procedural character rig + poses + helpers
   that the salon uses, factored out so the Shop and Masterclass buildings can
   share one identical little person and the same walk/dance animations. */
(function(){
  var T = window.THREE;
  if(!T){ return; }

  function clamp(x,a,b){ return Math.max(a,Math.min(b,x)); }
  function lerp(a,b,t){ return a+(b-a)*t; }
  function smooth(a,b,x){ x=clamp((x-a)/(b-a),0,1); return x*x*(3-2*x); }
  function faceToward(x,z,tx,tz){ return Math.atan2(tx-x,tz-z); }

  function solid(c,opts){ return new T.MeshStandardMaterial(Object.assign({color:new T.Color(c),roughness:.82,metalness:.05},opts||{})); }
  function basic(c,opts){ return new T.MeshBasicMaterial(Object.assign({color:new T.Color(c)},opts||{})); }
  function shadowAll(o){ o.traverse(function(n){ if(n.isMesh){ n.castShadow=true; n.receiveShadow=true; } }); return o; }

  function capsule(radius,length,material,axis){
    var g=new T.Group(), bodyLen=Math.max(0.001,length-radius*2);
    var c=new T.Mesh(new T.CylinderGeometry(radius,radius,bodyLen,28),material); g.add(c);
    var a=new T.Mesh(new T.SphereGeometry(radius,28,16),material), b=a.clone();
    if(axis==='x'){ c.rotation.z=Math.PI/2; a.position.x=-bodyLen/2; b.position.x=bodyLen/2; }
    else if(axis==='z'){ c.rotation.x=Math.PI/2; a.position.z=-bodyLen/2; b.position.z=bodyLen/2; }
    else { a.position.y=-bodyLen/2; b.position.y=bodyLen/2; }
    g.add(a,b); return shadowAll(g);
  }
  function ovalSphere(radius,material,sx,sy,sz){ var m=new T.Mesh(new T.SphereGeometry(radius,32,18),material); m.scale.set(sx||1,sy||1,sz||1); m.castShadow=true; m.receiveShadow=true; return m; }

  /* The little person — torso, friendly face, hair cap, jointed arms + legs. */
  function buildCharacter(m){
    var group=new T.Group(); var bodyG=new T.Group(); group.add(bodyG);
    var torso=new T.Mesh(new T.CylinderGeometry(.32,.39,.88,28),m.cloth); torso.position.y=1.32; torso.scale.z=.68; torso.castShadow=true; torso.receiveShadow=true; bodyG.add(torso);
    bodyG.add((function(){ var n=new T.Mesh(new T.CylinderGeometry(.085,.095,.16,20),m.skin); n.position.y=1.83; n.castShadow=true; return n; })());
    var head=ovalSphere(.265,m.skin,.94,1.05,.9); head.position.y=2.05; bodyG.add(head);
    var faceMat=solid('#151519',{roughness:.55}), cheekMat=solid('#f2d4b3',{roughness:.7});
    [-1,1].forEach(function(s){
      var eye=new T.Mesh(new T.SphereGeometry(.026,14,8),faceMat); eye.position.set(s*.085,2.095,.224); eye.scale.z=.45; bodyG.add(eye);
      var cheek=new T.Mesh(new T.SphereGeometry(.025,12,8),cheekMat); cheek.position.set(s*.12,2.035,.221); cheek.scale.set(1,.55,.35); bodyG.add(cheek);
    });
    var nose=new T.Mesh(new T.ConeGeometry(.024,.065,14),m.skin); nose.position.set(0,2.055,.245); nose.rotation.x=Math.PI/2; nose.castShadow=true; bodyG.add(nose);
    var smile=new T.Mesh(new T.TorusGeometry(.045,.006,8,24,Math.PI*.9),faceMat); smile.position.set(0,2.0,.235); smile.rotation.set(0,0,Math.PI*.05); smile.scale.y=.45; bodyG.add(smile);
    var hairBase=new T.Mesh(new T.SphereGeometry(.265,24,14,0,Math.PI*2,0,Math.PI*0.62),m.hair); hairBase.position.y=2.12; hairBase.castShadow=true; bodyG.add(hairBase);
    /* a little side tuft so the haircut reads as styled */
    var tuft=ovalSphere(.15,m.hair,1.48,.36,.9); tuft.position.set(.02,2.255,.13); tuft.rotation.set(-0.2,0,.1); bodyG.add(tuft);
    function arm(side){ var g=new T.Group(); g.position.set(side*0.39,1.67,0);
      var up=capsule(.085,.54,m.cloth,'y'); up.position.y=-0.27; g.add(up);
      var fore=new T.Group(); fore.position.y=-0.53; g.add(fore);
      var lo=capsule(.073,.48,m.skin,'y'); lo.position.y=-0.24; fore.add(lo);
      bodyG.add(g); return {g:g,fore:fore}; }
    var armL=arm(-1), armR=arm(1);
    function leg(side){ var hip=new T.Group(); hip.position.set(side*0.17,0.96,0);
      var th=capsule(.105,.54,m.cloth,'y'); th.position.y=-0.27; hip.add(th);
      var knee=new T.Group(); knee.position.y=-0.52; hip.add(knee);
      var sh=capsule(.09,.54,m.cloth,'y'); sh.position.y=-0.27; knee.add(sh);
      var ft=capsule(.075,.36,m.skin,'z'); ft.position.set(0,-0.55,0.09); ft.scale.x=1.22; knee.add(ft);
      group.add(hip); return {hip:hip,knee:knee}; }
    var legL=leg(-1), legR=leg(1);
    return {group:group,bodyG:bodyG,armL:armL,armR:armR,legL:legL,legR:legR,head:head,hairBase:hairBase};
  }

  /* ---- poses ---- */
  function poseStand(ch){ ch.bodyG.position.y=0; ch.bodyG.rotation.set(0,0,0);
    ch.armL.g.rotation.set(0.06,0,0.05); ch.armR.g.rotation.set(0.06,0,-0.05); ch.armL.fore.rotation.x=0.12; ch.armR.fore.rotation.x=0.12;
    ch.legL.hip.rotation.set(0,0,0); ch.legR.hip.rotation.set(0,0,0); ch.legL.knee.rotation.x=0; ch.legR.knee.rotation.x=0; }
  function poseWalk(ch,ph){ var sw=Math.sin(ph)*0.6; ch.bodyG.position.y=Math.abs(Math.sin(ph))*0.05; ch.bodyG.rotation.set(0.05,0,0);
    ch.armL.g.rotation.set(-sw,0,0.05); ch.armR.g.rotation.set(sw,0,-0.05); ch.armL.fore.rotation.x=0.2; ch.armR.fore.rotation.x=0.2;
    ch.legL.hip.rotation.set(sw,0,0); ch.legR.hip.rotation.set(-sw,0,0); ch.legL.knee.rotation.x=Math.max(0,-sw)*0.8; ch.legR.knee.rotation.x=Math.max(0,sw)*0.8; }
  /* both forearms forward — used when carrying the shopping basket in front */
  function poseHold(ch){ ch.bodyG.position.y=0; ch.bodyG.rotation.set(0,0,0);
    ch.armL.g.rotation.set(-0.78,0,0.2); ch.armL.fore.rotation.x=-1.18;
    ch.armR.g.rotation.set(-0.78,0,-0.2); ch.armR.fore.rotation.x=-1.18;
    ch.legL.hip.rotation.set(0,0,0); ch.legR.hip.rotation.set(0,0,0); ch.legL.knee.rotation.x=0; ch.legR.knee.rotation.x=0; }
  /* walking while carrying the basket: legs stride, arms stay holding */
  function poseCarry(ch,ph){ var sw=Math.sin(ph)*0.55; ch.bodyG.position.y=Math.abs(Math.sin(ph))*0.04; ch.bodyG.rotation.set(0.04,0,0);
    ch.armL.g.rotation.set(-0.78,0,0.2); ch.armL.fore.rotation.x=-1.18;
    ch.armR.g.rotation.set(-0.78,0,-0.2); ch.armR.fore.rotation.x=-1.18;
    ch.legL.hip.rotation.set(sw,0,0); ch.legR.hip.rotation.set(-sw,0,0); ch.legL.knee.rotation.x=Math.max(0,-sw)*0.8; ch.legR.knee.rotation.x=Math.max(0,sw)*0.8; }
  function poseReach(ch,t){ ch.bodyG.position.y=0; ch.bodyG.rotation.set(0,0,0);
    ch.armR.g.rotation.set(-2.0+Math.sin(t*3)*0.18,0,-0.15); ch.armR.fore.rotation.x=-0.35;
    ch.armL.g.rotation.set(0.06,0,0.05); ch.armL.fore.rotation.x=0.12;
    ch.legL.hip.rotation.set(0,0,0); ch.legR.hip.rotation.set(0,0,0); ch.legL.knee.rotation.x=0; ch.legR.knee.rotation.x=0; }
  function poseWave(ch,t){ ch.bodyG.position.y=Math.abs(Math.sin(t*4))*0.025; ch.bodyG.rotation.set(0,0,Math.sin(t*3)*0.035);
    ch.legL.hip.rotation.set(0,0,0); ch.legR.hip.rotation.set(0,0,0); ch.legL.knee.rotation.x=0; ch.legR.knee.rotation.x=0;
    ch.armL.g.rotation.set(-1.78,Math.sin(t*7)*0.18,0.58+Math.sin(t*7)*0.38); ch.armL.fore.rotation.x=-0.5;
    ch.armR.g.rotation.set(0.08,0,-0.08); ch.armR.fore.rotation.x=0.16; }
  /* full-body celebration dance */
  function poseDance(ch,t){ ch.bodyG.position.y=Math.abs(Math.sin(t*6))*0.085; ch.bodyG.rotation.set(0,Math.sin(t*3)*0.2,Math.sin(t*5)*0.07);
    ch.armL.g.rotation.set(-2.2+Math.sin(t*9)*0.55,0,0.5+Math.abs(Math.sin(t*7))*0.25); ch.armL.fore.rotation.x=-0.6+Math.sin(t*11)*0.4;
    ch.armR.g.rotation.set(-2.2+Math.cos(t*9)*0.55,0,-0.5-Math.abs(Math.cos(t*7))*0.25); ch.armR.fore.rotation.x=-0.6+Math.cos(t*11)*0.4;
    var sw=Math.sin(t*6)*0.28; ch.legL.hip.rotation.set(sw,0,0); ch.legR.hip.rotation.set(-sw,0,0);
    ch.legL.knee.rotation.x=Math.max(0,-sw)*0.7; ch.legR.knee.rotation.x=Math.max(0,sw)*0.7; }
  function poseSit(ch){ ch.bodyG.position.y=0; ch.bodyG.rotation.set(0,0,0);
    ch.armL.g.rotation.set(-0.25,0,0.12); ch.armR.g.rotation.set(-0.25,0,-0.12); ch.armL.fore.rotation.x=-1.15; ch.armR.fore.rotation.x=-1.15;
    ch.legL.hip.rotation.set(-Math.PI*0.52,0,0.05); ch.legR.hip.rotation.set(-Math.PI*0.52,0,-0.05); ch.legL.knee.rotation.x=Math.PI*0.48; ch.legR.knee.rotation.x=Math.PI*0.48; }

  function setPose(ch,st,ph,t){
    if(st==='walk') poseWalk(ch,ph);
    else if(st==='carry') poseCarry(ch,ph);
    else if(st==='hold') poseHold(ch);
    else if(st==='reach') poseReach(ch,t);
    else if(st==='wave') poseWave(ch,t);
    else if(st==='dance') poseDance(ch,t);
    else if(st==='sit') poseSit(ch);
    else poseStand(ch);
  }

  /* a shopping basket the character can carry; returns the group (add to bodyG, ~y 1.15 z .42) */
  function makeBasket(){
    var g=new T.Group();
    var wire=solid('#2b2b32',{metalness:.6,roughness:.4});
    var body=new T.Mesh(new T.BoxGeometry(.5,.26,.34),wire); body.scale.set(1,1,1); g.add(shadowAll(body));
    var rim=new T.Mesh(new T.TorusGeometry(.27,.02,8,4),wire); rim.rotation.x=Math.PI/2; rim.position.y=.14; rim.scale.set(1,1.32,1); g.add(rim);
    [-1,1].forEach(function(s){ var h=new T.Mesh(new T.TorusGeometry(.1,.014,8,16,Math.PI),solid('#3a3a42',{metalness:.5})); h.position.set(0,.2,s*0.0); h.rotation.x=Math.PI/2; g.add(h); });
    /* a couple of grocery-looking products poking out */
    var p1=new T.Mesh(new T.CylinderGeometry(.05,.05,.22,16),solid('#e0556b')); p1.position.set(-.12,.18,0); g.add(p1);
    var p2=new T.Mesh(new T.CylinderGeometry(.045,.045,.2,16),solid('#4cc3d6')); p2.position.set(.05,.16,.05); g.add(p2);
    var p3=new T.Mesh(new T.BoxGeometry(.12,.16,.1),solid('#e8c45a')); p3.position.set(.14,.14,-.03); g.add(p3);
    return g;
  }

  /* a glowing green "$" that pops above the head — the ka-ching */
  function dollarPop(){
    var cv=document.createElement('canvas'); cv.width=160; cv.height=160; var c=cv.getContext('2d');
    c.font='900 120px Arial,sans-serif'; c.textAlign='center'; c.textBaseline='middle';
    c.shadowColor='rgba(47,210,126,.95)'; c.shadowBlur=26; c.fillStyle='#34e08a'; c.fillText('$',80,86);
    c.lineWidth=4; c.strokeStyle='rgba(255,255,255,.7)'; c.strokeText('$',80,86);
    var tex=new T.CanvasTexture(cv); tex.anisotropy=4;
    var spr=new T.Sprite(new T.SpriteMaterial({map:tex,transparent:true,depthTest:false}));
    spr.scale.set(1,1,1); return spr;
  }

  window.BSKit={
    clamp:clamp, lerp:lerp, smooth:smooth, faceToward:faceToward,
    solid:solid, basic:basic, shadowAll:shadowAll, capsule:capsule, ovalSphere:ovalSphere,
    buildCharacter:buildCharacter, setPose:setPose,
    poseStand:poseStand, poseWalk:poseWalk, poseDance:poseDance, poseWave:poseWave,
    makeBasket:makeBasket, dollarPop:dollarPop
  };
})();
