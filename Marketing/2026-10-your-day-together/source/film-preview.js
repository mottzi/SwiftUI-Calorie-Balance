"use strict";
const canvas=document.querySelector("#art"),ctx=canvas.getContext("2d",{alpha:true});
const playButton=document.querySelector("#play"),timeline=document.querySelector("#timeline"),timeLabel=document.querySelector("#time"),variantPicker=document.querySelector("#variant");
const params=new URLSearchParams(location.search),reduced=matchMedia("(prefers-reduced-motion: reduce)");
const images=new Map();
let config,variant=params.get("variant")==="portrait"?"portrait":"wide",time=Number(params.get("t")||(reduced.matches?3.6:0)),playing=!reduced.matches&&!params.has("paused"),last=0,ready=false;
const clamp=x=>Math.max(0,Math.min(1,x));
const smooth=x=>{const p=clamp(x);return p*p*(3-2*p)};
const soft=x=>{const p=clamp(x);return p*p*p*(p*(p*6-15)+10)};
const ramp=(t,a,b)=>smooth((t-a)/(b-a));
const mix=(a,b,p)=>a+(b-a)*p;
const rgba=(hex,a)=>{const n=parseInt(hex.slice(1),16);return`rgba(${n>>16&255},${n>>8&255},${n&255},${clamp(a)})`};
function text(str,x,y,size,weight,color,opacity=1,kern=0){if(opacity<=0)return;ctx.save();ctx.fillStyle=rgba(color,opacity);ctx.font=`${weight} ${size}px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif`;ctx.letterSpacing=`${kern}px`;ctx.fillText(str,x,y);ctx.restore()}
function centeredText(str,x,y,size,color,alpha){ctx.save();ctx.font=`400 ${size}px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif`;const w=ctx.measureText(str).width;ctx.restore();text(str,x-w/2,y,size,400,color,alpha)}
function bezier(a,b,c,d,p){const u=1-p;return{x:u*u*u*a.x+3*u*u*p*b.x+3*u*p*p*c.x+p*p*p*d.x,y:u*u*u*a.y+3*u*u*p*b.y+3*u*p*p*c.y+p*p*p*d.y}}
function route(index,layout){
 const r=layout.readings[index],h=layout.health,a={x:r.startX,y:r.startY},d={x:h.x,y:h.y};let b,c,target,out1,out2;
 if(variant==="wide"){
  b={x:850,y:r.startY};c={x:910,y:h.y};const ty=layout.phone.centerY-layout.phone.height/2+layout.phone.height*config.readingData[index].cardFraction;
  target={x:layout.phoneEntryX+20,y:ty};out1={x:h.x+118,y:h.y};out2={x:layout.phoneEntryX-38,y:ty};
 }else{
  b={x:r.startX,y:590};c={x:h.x,y:564};target={x:540,y:layout.phone.centerY-layout.phone.height/2+70};out1={x:h.x,y:h.y+90};out2={x:540,y:target.y-65};
 }
 const points=[];for(let i=0;i<=90;i++)points.push(bezier(a,b,c,d,i/90));for(let i=1;i<=90;i++)points.push(bezier(d,out1,out2,target,i/90));return points;
}
function stroke(points,width,color,opacity,glow=0,from=0,to=1){
 const lo=Math.max(0,Math.floor(from*(points.length-1))),hi=Math.min(points.length-1,Math.floor(to*(points.length-1)));if(hi<=lo||opacity<=0)return;
 ctx.save();ctx.strokeStyle=rgba(color,opacity);ctx.lineWidth=width;ctx.lineCap="round";ctx.lineJoin="round";if(glow){ctx.shadowColor=rgba(color,opacity*.35);ctx.shadowBlur=glow}ctx.beginPath();ctx.moveTo(points[lo].x,points[lo].y);for(let i=lo+1;i<=hi;i++)ctx.lineTo(points[i].x,points[i].y);ctx.stroke();ctx.restore();
}
function drawImage(path,x,y,w,h,alpha=1){const im=images.get(path);if(!im||alpha<=0)return;ctx.save();ctx.globalAlpha=alpha;ctx.drawImage(im,x,y,w,h);ctx.restore()}
function draw(inputTime){
 if(!ready)return;const t=inputTime>=config.duration?0:inputTime,layout=config.layouts[variant],timing=config.timing;
 const reset=soft((t-timing.holdEnd)/(timing.resetEnd-timing.holdEnd));
 const forward=soft((t-timing.forwardStart)/(timing.forwardEnd-timing.forwardStart))*(1-reset);
 const support=1-ramp(t,timing.readingsFadeStart,timing.readingsFadeEnd),early=ramp(t,.12,.70)*(1-ramp(t,timing.headingFadeStart,timing.headingFadeEnd)),final=ramp(t,timing.finalHeadingStart,timing.finalHeadingEnd)*(1-ramp(t,9.2,9.72));
 const h=layout.health,healthAlpha=ramp(t,1.4,1.95)*(1-ramp(t,timing.healthFadeStart,timing.healthFadeEnd));
 ctx.clearRect(0,0,canvas.width,canvas.height);
 for(let i=0;i<3;i++){
  const r=config.readingData[i],u=(t-r.pulseStart)/.95,points=route(i,layout),reveal=ramp(t,1.65+i*.12,2.05+i*.12)*support;
  stroke(points,variant==="wide"?1.8:2.6,r.color,.24*reveal);
  if(u>=0&&u<=1)stroke(points,variant==="wide"?3.4:4.4,r.color,.90*Math.sin(Math.PI*clamp(u))*support,16,Math.max(0,u-.18),Math.min(1,u));
  const receive=Math.sin(Math.PI*clamp((u-.40)/.28));
  if(u>.40&&u<.68){ctx.save();ctx.strokeStyle=rgba(r.color,.28*receive*healthAlpha);ctx.lineWidth=1.5;ctx.shadowBlur=9;ctx.shadowColor=rgba(r.color,.1*receive*healthAlpha);ctx.beginPath();ctx.arc(h.x,h.y,49+receive*7,0,Math.PI*2);ctx.stroke();ctx.restore()}
 }
 const ph=mix(layout.phone.height,layout.phone.finalHeight,forward),px=mix(layout.phone.centerX,layout.phone.finalCenterX,forward),py=mix(layout.phone.centerY,layout.phone.finalCenterY,forward),pw=ph*config.assets.poseWidth/config.assets.poseHeight;
 const pose=Math.round(forward*(config.assets.poseCount-1)),posePath=config.assets.posePattern.replace("%03d",String(pose).padStart(3,"0")),nativeAlpha=mix(.78,1,ramp(t,1.9,4.8))*(1-reset)+.78*reset;
 drawImage(posePath,px-pw/2,py-ph/2,pw,ph,nativeAlpha);
 drawImage(config.assets.health,h.x-h.size/2,h.y-h.size/2,h.size,h.size,healthAlpha);centeredText("Apple Health",h.x,h.y+h.size/2+29,h.captionSize,config.colors.muted,healthAlpha);
 text("Count.kcal",layout.brand.x,layout.brand.y,layout.brand.size,500,config.colors.muted);
 const e=layout.earlyHeading,f=layout.finalHeading;
 text("Your day,",e.x,e.firstBaseline,e.size,500,config.colors.white,early,-2);text("brought together.",e.x,e.secondBaseline,e.size,500,config.colors.white,early,-2);
 text("Your day.",f.x,f.firstBaseline,f.size,500,config.colors.white,final,-2);text("One clear picture.",f.x,f.secondBaseline,f.size,500,config.colors.white,final,-2);
 for(let i=0;i<3;i++){const r=config.readingData[i],p=layout.readings[i],enter=ramp(t,.22+i*.40,.82+i*.40),alpha=enter*support,lift=12*(1-enter);text(r.name,p.x,p.labelY+lift,layout.labelSize,400,config.colors.muted,alpha);text(r.value,p.x,p.valueY+lift,layout.valueSize,500,r.color,alpha,-1);text(r.unit,p.unitX,p.unitY+lift,layout.unitSize,400,config.colors.muted,alpha)}
 timeline.value=t;timeLabel.value=`${t.toFixed(1)} / 10 s`;document.body.dataset.time=t.toFixed(3);document.body.dataset.variant=variant;
}
function setPlaying(value){playing=Boolean(value);last=0;playButton.textContent=playing?"Pause":"Play";playButton.setAttribute("aria-pressed",String(playing))}
function seek(t){time=Math.max(0,Math.min(9.999,Number(t)));setPlaying(false);draw(time)}
function setVariant(value){variant=value==="portrait"?"portrait":"wide";document.body.classList.toggle("portrait",variant==="portrait");variantPicker.value=variant;if(config){const l=config.layouts[variant];canvas.width=l.width;canvas.height=l.height;draw(time)}}
playButton.addEventListener("click",()=>setPlaying(!playing));timeline.addEventListener("input",()=>seek(timeline.value));variantPicker.addEventListener("change",()=>setVariant(variantPicker.value));document.querySelector("#transparent").addEventListener("change",e=>document.querySelector("#stage").classList.toggle("transparent",e.target.checked));
reduced.addEventListener("change",e=>{if(e.matches)seek(3.6)});document.addEventListener("visibilitychange",()=>{last=0});
if(params.has("bare"))document.body.classList.add("bare");
function tick(now){if(playing&&!document.hidden){if(last)time=(time+Math.min(.1,(now-last)/1000))%config.duration;draw(time)}last=now;requestAnimationFrame(tick)}
function loadImage(path){return new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{images.set(path,im);resolve()};im.onerror=()=>reject(new Error(`Unable to load ${path}`));im.src="../"+path})}
async function boot(){
 config=await fetch("motion-config.json").then(r=>{if(!r.ok)throw new Error("Config unavailable");return r.json()});
 const paths=[config.assets.health];for(let i=0;i<config.assets.poseCount;i++)paths.push(config.assets.posePattern.replace("%03d",String(i).padStart(3,"0")));
 await Promise.all(paths.map(loadImage));ready=true;setVariant(variant);setPlaying(playing);draw(time);document.body.dataset.ready="true";requestAnimationFrame(tick);
}
window.film={seek,play:()=>setPlaying(true),pause:()=>setPlaying(false),setVariant,draw:()=>draw(time),get ready(){return ready},get time(){return time},get variant(){return variant}};
boot().catch(error=>{console.error(error);document.body.dataset.error="true";timeLabel.value="Source images unavailable"});
