import * as frida from 'frida';
const dm = frida.getDeviceManager();
const devs = await dm.enumerateDevices(null);
const usb = devs.find((d) => d.type === 'usb');
const procs = await usb.enumerateProcesses(null);
console.log('COUNT', procs.length);
const p0 = procs[0];
console.log('P0 TYPE:', typeof p0, p0 && Object.getPrototypeOf(p0) === Object.prototype ? 'plain' : 'obj');
console.log('P0 KEYS:', p0 ? Object.keys(p0) : 'none');
console.log('P0 STRING:', String(p0).slice(0, 300));
const p18890 = procs.find((p) => String(p).includes('18890') || true);
// try to find by name via frida process APIs: maybe p.session? 
// Print constructor names
for (const p of procs.slice(0, 5)) {
  console.log('P:', Object.getPrototypeOf(p)?.constructor?.name, Object.keys(p).slice(0,20));
}
process.exit(0);
