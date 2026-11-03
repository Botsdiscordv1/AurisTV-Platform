import * as frida from 'frida';
const f = frida.default || frida;
console.log('TOP:', Object.keys(f).filter((k) => /device|attach|spawn|process|session|inject/i.test(k)).join(', '));
console.log('ALL_TOP_COUNT:', Object.keys(f).length);
console.log('HAS_LIST_DEVICES:', 'listDevices' in f, 'HAS_ATTACH:', 'attach' in f, 'HAS_SPAWN:', 'spawn' in f, 'HAS_LIST_PROCESSES:', 'listProcesses' in f, 'HAS_CREATE_DEVICE:', 'createDevice' in f);
process.exit(0);
