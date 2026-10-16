const sharp=require('sharp'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),p=x=>path.join(root,x);
const data=x=>'data:image/png;base64,'+fs.readFileSync(p(x)).toString('base64');
const themes={light:{bg:'#edf2f6',ink:'#092d42',muted:'#526672',rule:'#c6d3dc',foot:'#72838d'},dark:{bg:'#07131f',ink:'#edf5fa',muted:'#a3b8c8',rule:'#263b4b',foot:'#8199aa'}};
const layout={width:3840,height:2160,device:{x:2280,y:190,scale:2,width:560,height:880},screen:{x:72,y:192,width:416,height:496,radius:84}};
const defs='<defs><clipPath id="screen"><rect x="72" y="192" width="416" height="496" rx="84"/></clipPath></defs>';
function svgStart(t){return `<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160" viewBox="0 0 3840 2160">${defs}<rect width="3840" height="2160" fill="${t.bg}"/>`}
function copy(t){return `<g font-family="Avenir Next, Helvetica Neue, sans-serif" fill="${t.ink}">
<text x="210" y="215" font-size="66" font-weight="700" letter-spacing="-2">Count.kcal</text>
<text x="218" y="474" font-size="34" font-weight="600" letter-spacing="5">FOR APPLE WATCH</text>
<text x="205" y="714" font-size="174" font-weight="700" letter-spacing="-8">Your balance.</text>
<text x="205" y="922" font-size="174" font-weight="700" letter-spacing="-8">On your wrist.</text>
<text x="218" y="1088" font-size="47" fill="${t.muted}">See where you are now. Tap the ring</text>
<text x="218" y="1157" font-size="47" fill="${t.muted}">for your midnight estimate.</text>
<line x1="218" y1="1350" x2="1570" y2="1350" stroke="${t.rule}" stroke-width="2"/>
<circle cx="234" cy="1441" r="12" fill="#268ef2"/>
<text x="274" y="1459" font-size="52" font-weight="600">Now</text>
<text x="218" y="1537" font-size="36" fill="${t.muted}">Calories eaten and</text>
<text x="218" y="1592" font-size="36" fill="${t.muted}">burned so far.</text>
<path d="M923 1424A20 20 0 1 0 947 1448A22 22 0 0 1 923 1424" fill="#e8874f"/>
<text x="974" y="1459" font-size="52" font-weight="600">Midnight</text>
<text x="918" y="1537" font-size="36" fill="${t.muted}">Your estimated balance</text>
<text x="918" y="1592" font-size="36" fill="${t.muted}">by the end of the day.</text>
<text x="218" y="1985" font-size="32" fill="${t.muted}">Now. Midnight. One tap.</text>
<text x="218" y="2075" font-size="18" fill="${t.foot}">Apple and Apple Watch are trademarks of Apple Inc. Demo data shown.</text>
</g>`}
function badge(t,mode){return `<g font-family="Avenir Next, Helvetica Neue, sans-serif" fill="${t.ink}" text-anchor="middle"><text x="2840" y="2050" font-size="38" font-weight="600" letter-spacing="5">${mode==='now'?'NOW':'MIDNIGHT ESTIMATE'}</text></g>`}
function device(mode){return `<g transform="translate(2280,190) scale(2)"><image x="72" y="192" width="416" height="496" href="${data('captures/watch-'+mode+'.png')}" clip-path="url(#screen)"/><image width="560" height="880" href="${data('source/apple-watch-s11-46-black.png')}"/></g>`}
(async()=>{
 for(const [name,t] of Object.entries(themes)){
  const bg=svgStart(t)+copy(t)+'</svg>';
  await sharp(Buffer.from(bg)).png().toFile(p('source/background-'+name+'.png'));
  for(const mode of ['now','midnight']){
   const s=svgStart(t)+copy(t)+device(mode)+badge(t,mode)+'</svg>';
   fs.writeFileSync(p(`stills/count-kcal-watch-${name}-${mode}.svg`),s);
   await sharp(Buffer.from(s)).png().toFile(p(`stills/count-kcal-watch-${name}-${mode}-4k.png`));
   if(mode==='now')await sharp(Buffer.from(s)).resize(1920).webp({quality:93}).toFile(p(`web/watch-${name}-poster.webp`));
   const layer=`<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160">${badge(t,mode)}</svg>`;
   await sharp(Buffer.from(layer)).png().toFile(p(`source/badge-${name}-${mode}.png`));
  }
 }
 for(const mode of ['now','midnight']){
  const s=`<svg xmlns="http://www.w3.org/2000/svg" width="560" height="880">${defs}<image x="72" y="192" width="416" height="496" href="${data('captures/watch-'+mode+'.png')}" clip-path="url(#screen)"/><image width="560" height="880" href="${data('source/apple-watch-s11-46-black.png')}"/></svg>`;
  await sharp(Buffer.from(s)).png().toFile(p(`stills/watch-${mode}-framed.png`));
 }
 await sharp(Buffer.from('<svg width="416" height="496"><rect width="416" height="496" rx="84" fill="white"/></svg>')).png().toFile(p('source/screen-mask.png'));
 fs.writeFileSync(p('source/layout.json'),JSON.stringify(layout,null,2));
 console.log('Watch hero stills and animation layers rendered.');
})();
