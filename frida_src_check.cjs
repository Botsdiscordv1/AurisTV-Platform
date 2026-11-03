const fs = require('fs');
const src = fs.readFileSync('E:/AurisTV_plataformas/node_modules/frida/build/src/frida.js', 'utf8');
const lines = src.split('\n');
function show(a, b) { for (let i = a; i < b && i < lines.length; i++) console.log(i + ': ' + lines[i]); }
// find attach implementation in Device class region
const idx = [];
for (let i = 0; i < lines.length; i++) { if (lines[i].includes('attach')) idx.push(i); }
console.log('ATTACH LINES:', idx.slice(0, 40).join(','));
