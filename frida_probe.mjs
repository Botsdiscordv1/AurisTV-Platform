import frida from 'frida';

const device = await frida.createDevice({
  // type: 'usb',
  // id: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
});
const devices = await frida.listDevices();
const target = devices.find((d) => d.type === 'usb') || devices[0];
console.log('DEVICE:', JSON.stringify(target));
const processes = await frida.listProcesses(target);
console.log('PROCESSES:', JSON.stringify(processes, null, 2));
process.exit(0);
