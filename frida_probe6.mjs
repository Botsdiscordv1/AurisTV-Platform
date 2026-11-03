import * as frida from 'frida';
const dm = frida.getDeviceManager();
const devs = await dm.enumerateDevices(null);
const usb = devs.find((d) => d.type === 'usb');
const procs = await usb.enumerateProcesses(null);
console.log('USB PROC COUNT:', procs.length);
for (const p of procs) {
  const info = await p.getProcessInfo();
  const j = info ? JSON.stringify(info) : String(info);
  console.log('PROC:', j.slice(0, 400));
}
process.exit(0);
