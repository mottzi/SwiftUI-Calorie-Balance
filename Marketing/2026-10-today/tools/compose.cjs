const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const base = path.resolve(__dirname,'..');
const file = p => path.join(base,p);
const png = p => 'data:image/png;base64,'+fs.readFileSync(file(p)).toString('base64');
const W=3840,H=2160;
const devices=[{theme:'light',mode:'now',frame:'silver',x:1900,y:228,s:.64},{theme:'dark',mode:'midnight',frame:'black',x:2820,y:228,s:.64}];
function copy(){return `<g font-family="Avenir Next, Helvetica Neue, sans-serif" fill="#092d42">
<text x="210" y="215" font-size="66" font-weight="700" letter-spacing="-2">Count.kcal</text>
<text x="218" y="474" font-size="34" font-weight="600" letter-spacing="5">TODAY, IN PERSPECTIVE</text>
<text x="205" y="714" font-size="174" font-weight="700" letter-spacing="-8">Your balance.</text>
<text x="205" y="922" font-size="174" font-weight="700" letter-spacing="-8">Now to midnight.</text>
<text x="218" y="1088" font-size="47" fill="#526672">Tap the calorie card to see where you are</text>
<text x="218" y="1157" font-size="47" fill="#526672">and your estimated balance at midnight.</text>
<line x1="218" y1="1350" x2="1570" y2="1350" stroke="#c6d3dc" stroke-width="2"/>
<circle cx="234" cy="1441" r="12" fill="#268ef2"/>
<text x="274" y="1459" font-size="52" font-weight="600">Now</text>
<text x="218" y="1537" font-size="36" fill="#526672">Calories eaten and</text>
<text x="218" y="1592" font-size="36" fill="#526672">burned so far.</text>
<path d="M 923 1424 A 20 20 0 1 0 947 1448 A 22 22 0 0 1 923 1424" fill="#e8874f"/>
<text x="974" y="1459" font-size="52" font-weight="600">Midnight</text>
<text x="918" y="1537" font-size="36" fill="#526672">Your estimated balance</text>
<text x="918" y="1592" font-size="36" fill="#526672">by the end of the day.</text>
<text x="218" y="1985" font-size="32" fill="#647783">A clearer view of your calorie balance.</text>
<text x="218" y="2075" font-size="18" fill="#72838d">Apple and iPhone are trademarks of Apple Inc. Sample data shown.</text>
</g>`}
function device(d,includeScreen){const inner=includeScreen?`<image x="72" y="69" width="1206" height="2622" href="${png('captures/iphone-'+d.theme+'-'+d.mode+'.png')}" clip-path="url(#screen)"/>`:'';return `<g transform="translate(${d.x},${d.y}) scale(${d.s})">${inner}<image width="1350" height="2760" href="${png('source/iphone18-pro-'+d.frame+'.png')}"/></g>`}
(async()=>{
const defs='<defs><clipPath id="screen"><rect x="72" y="69" width="1206" height="2622" rx="190"/></clipPath></defs>';
const start=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}<rect width="3840" height="2160" fill="#edf2f6"/>`;
const svg=start+copy()+devices.map(d=>device(d,true)).join('')+'</svg>';
fs.writeFileSync(file('stills/count-kcal-today-hero.svg'),svg);
await sharp(Buffer.from(svg)).png().toFile(file('stills/count-kcal-today-hero-4k.png'));
await sharp(Buffer.from(svg)).resize(1920).webp({quality:93}).toFile(file('web/count-kcal-today-hero.webp'));
const back=start+copy()+'</svg>';
await sharp(Buffer.from(back)).png().toFile(file('source/hero-background.png'));
for(const d of devices){
 const f=`<svg xmlns="http://www.w3.org/2000/svg" width="1350" height="2760">${defs}<image x="72" y="69" width="1206" height="2622" href="${png('captures/iphone-'+d.theme+'-'+d.mode+'.png')}" clip-path="url(#screen)"/><image width="1350" height="2760" href="${png('source/iphone18-pro-'+d.frame+'.png')}"/></svg>`;
 await sharp(Buffer.from(f)).png().toFile(file('stills/iphone-'+d.theme+'-'+d.mode+'-framed.png'));
}
fs.writeFileSync(file('source/layout.json'),JSON.stringify({width:W,height:H,devices,screen:{x:72,y:69,width:1206,height:2622,radius:190}},null,2));
console.log('Rendered 4K hero, editable SVG and framed stills.');
})();
