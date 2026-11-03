import * as frida from 'frida';
console.log('KEYS:', Object.keys(frida));
const f = frida.default || frida;
console.log('DEFAULT KEYS:', Object.keys(f));
console.log('NAMES:', Object.keys(f).slice(0, 60));
process.exit(0);
