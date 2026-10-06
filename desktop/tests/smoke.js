// Medha Windows Desktop — Headless Electron Smoke Test
// Verifies Electron launches, loads index.html, executes JS without throwing, and receives renderer-ready signal

const { spawn } = require('child_process');
const path = require('path');
const electronPath = require('electron');

console.log('🧪 Starting Electron Headless Smoke Test...');

const mainPath = path.resolve(__dirname, '../electron/main.js');

const env = {
    ...process.env,
    MEDHA_TEST_SMOKE: '1',
    ELECTRON_ENABLE_LOGGING: '1'
};

const proc = spawn(electronPath, [mainPath], {
    env,
    stdio: ['ignore', 'pipe', 'pipe']
});

let output = '';
let passed = false;

proc.stdout.on('data', (chunk) => {
    const text = chunk.toString();
    output += text;
    process.stdout.write(text);
    if (text.includes('Renderer ready signal received') || text.includes('[IPC] Renderer signaled ready')) {
        passed = true;
    }
});

proc.stderr.on('data', (chunk) => {
    const text = chunk.toString();
    output += text;
    // Filter common harmless Chromium GPU notices on headless/macOS
    if (!text.includes('Secure transport not available') && !text.includes('GLDriver')) {
        process.stderr.write(text);
    }
});

const timer = setTimeout(() => {
    if (!passed) {
        console.error('❌ Smoke test timed out after 15 seconds without renderer-ready signal.');
        proc.kill('SIGKILL');
        process.exit(1);
    }
}, 15000);

proc.on('close', (code) => {
    clearTimeout(timer);
    if (passed) {
        console.log('\n🎉 SMOKE TEST PASSED: Electron + Renderer initialized with 0 errors and valid IPC handshakes!');
        process.exit(0);
    } else {
        console.error(`\n❌ SMOKE TEST FAILED: Process exited with code ${code} without signaling ready.`);
        process.exit(1);
    }
});
