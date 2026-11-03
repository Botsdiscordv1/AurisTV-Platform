import * as frida from 'frida';
const dm = frida.getDeviceManager();
const devs = await dm.enumerateDevices(null);
for (const d of devs) {
  console.log('DEV:', d.type, d.id, d.name);
  const proto = Object.getPrototypeOf(d);
  console.log('  PROTO:', Object.getOwnPropertyNames(proto).join(', '));
}
const usb = devs.find((d) => d.type === 'usb');
console.log('USB:', JSON.stringify(usb));
if (usb) {
  try {
    const s = await usb.attach(18890, {}, null);
    console.log('USB ATTACH OK');
    const info = await s.getProcessInfo();
    console.log('INFO:', JSON.stringify(info));
    await s.detach();
  } catch (e) { console.log('USB ATTACH ERR:', e && e.message); }
}
process.exit(0);
