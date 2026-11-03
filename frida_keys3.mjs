import * as frida from 'frida';
const dm = frida.getDeviceManager();
console.log('DM KEYS:', Object.keys(dm));
console.log('METHODS:', Object.getOwnPropertyNames(Object.getPrototypeOf(dm)));
process.exit(0);
