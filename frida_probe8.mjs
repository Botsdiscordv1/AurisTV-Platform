import * as frida from 'frida';
const dm = frida.getDeviceManager();
const devs = await dm.enumerateDevices(null);
const usb = devs.find((d) => d.type === 'usb');
const procs = await usb.enumerateProcesses(null);
const p0 = procs[0];
console.log('PROTO:', Object.getOwnPropertyNames(Object.getPrototypeOf(p0)).join(', '));
console.log('PROTO2:', Object.getOwnPropertyNames(Object.getPrototypeOf(Object.getPrototypeOf(p0))).join(', '));
process.exit(0);
