import * as frida from 'frida';
const dm = frida.getDeviceManager();
const devs = await dm.enumerateDevices();
for (const d of devs) {
  try {
    const procs = await d.enumerateProcesses();
    console.log('DEV:', JSON.stringify(d).slice(0, 200));
    console.log('PROCS:', JSON.stringify(procs));
  } catch (e) {
    console.log('ERR on dev:', e && e.message);
  }
}
process.exit(0);
