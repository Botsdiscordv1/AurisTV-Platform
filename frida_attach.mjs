import * as frida from 'frida';

async function tryAttach(target) {
  try {
    const session = await frida.attach(target, {}, null);
    console.log('ATTACHED OK to', String(target));
    const devs = await frida.getDeviceManager().enumerateDevices(null);
    for (const d of devs) {
      try {
        const procs = await d.enumerateProcesses(null);
        for (const p of procs) {
          const name = await p.name();
          const pid = await p.pid();
          console.log('PROC:', pid, name);
        }
      } catch (e) {}
    }
    await session.detach();
    process.exit(0);
  } catch (e) {
    console.log('ATTACH ERROR to', String(target), ':', e && e.message ? e.message : String(e));
  }
}
await tryAttach('com.android.mgstxNF');
process.exit(0);
