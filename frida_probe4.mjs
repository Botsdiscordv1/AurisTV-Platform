import * as frida from 'frida';
const dm = frida.getDeviceManager();
const devs = await dm.enumerateDevices(null);
for (const d of devs) {
  console.log('DEV:', JSON.stringify({ type: d.type, id: d.id, name: d.name, description: d.description, path: d.path, hasGadget: d.hasGadget, pid: d.pid, port: d.port, tls: d.tls, serial: d.serial }));
}
const local = await frida.getLocalDevice(null);
console.log('LOCAL DEV:', JSON.stringify({ type: local.type, id: local.id, name: local.name, path: local.path, pid: local.pid, port: local.port }));
const procs = await local.enumerateProcesses(null);
console.log('PROCS:', JSON.stringify(procs).slice(0, 3000));
process.exit(0);
