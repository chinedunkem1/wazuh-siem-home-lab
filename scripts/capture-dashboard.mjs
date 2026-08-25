import { spawn, spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const projectRoot = resolve(import.meta.dirname, '..');
const outputDir = join(projectRoot, 'evidence', 'screenshots');
const profileDir = join(projectRoot, 'evidence', 'private', `edge-capture-profile-${process.pid}`);
const installLog = join(projectRoot, 'evidence', 'private', 'wsl-wazuh-provision.log');
const edgePath = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const debugPort = 10000 + (process.pid % 20000);

mkdirSync(outputDir, { recursive: true });
rmSync(profileDir, { recursive: true, force: true });

const installBuffer = readFileSync(installLog);
const installText = installBuffer[0] === 0xff && installBuffer[1] === 0xfe
  ? installBuffer.toString('utf16le')
  : installBuffer.toString('utf8');
const passwordMatch = installText.match(/^\s*Password:\s+(.+)$/m);
if (!passwordMatch) throw new Error('Dashboard password not found in the private installation log.');
const credentials = { username: 'admin', password: passwordMatch[1].trim() };

const edge = spawn(edgePath, [
  '--headless=new',
  '--disable-gpu',
  '--ignore-certificate-errors',
  '--allow-insecure-localhost',
  '--no-first-run',
  '--disable-default-apps',
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${profileDir}`,
  'about:blank',
], { stdio: 'ignore' });

const delay = (ms) => new Promise((resolveDelay) => setTimeout(resolveDelay, ms));

async function retry(operation, timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try { return await operation(); } catch (error) { lastError = error; await delay(500); }
  }
  throw lastError ?? new Error('Operation timed out.');
}

let socket;
let nextId = 1;
const pending = new Map();

function send(method, params = {}) {
  const id = nextId++;
  return new Promise((resolveSend, rejectSend) => {
    pending.set(id, { resolve: resolveSend, reject: rejectSend });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(expression) {
  const response = await send('Runtime.evaluate', {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
  return response.result?.value;
}

async function waitFor(expression, timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await evaluate(expression)) return;
    await delay(750);
  }
  throw new Error(`Timed out waiting for: ${expression}`);
}

async function navigate(url) {
  await send('Page.navigate', { url });
  await waitFor('document.readyState === "complete"', 60000);
}

async function capture(filename) {
  await delay(2500);
  const result = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
  });
  const path = join(outputDir, filename);
  writeFileSync(path, Buffer.from(result.data, 'base64'));
  console.log(`Captured ${path}`);
}

try {
  await retry(async () => {
    const response = await fetch(`http://127.0.0.1:${debugPort}/json/new?https://localhost:8443/`, { method: 'PUT' });
    if (!response.ok) throw new Error(`DevTools returned ${response.status}`);
    const target = await response.json();
    socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolveOpen, rejectOpen) => {
      socket.addEventListener('open', resolveOpen, { once: true });
      socket.addEventListener('error', rejectOpen, { once: true });
    });
  });

  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    if (!message.id || !pending.has(message.id)) return;
    const operation = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) operation.reject(new Error(message.error.message));
    else operation.resolve(message.result);
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
  });

  await navigate('https://localhost:8443/');
  await waitFor('document.querySelector("input[type=password]") !== null');
  await evaluate(`(() => {
    const username = document.querySelector('input[name=username], input[id=username], input[type=text]');
    const password = document.querySelector('input[type=password]');
    const setValue = (element, value) => {
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(element, value);
      element.dispatchEvent(new Event('input', { bubbles: true }));
      element.dispatchEvent(new Event('change', { bubbles: true }));
    };
    setValue(username, ${JSON.stringify(credentials.username)});
    setValue(password, ${JSON.stringify(credentials.password)});
    const submit = document.querySelector('button[type=submit], input[type=submit]');
    if (!submit) throw new Error('Login button not found.');
    submit.click();
    return true;
  })()`);

  await waitFor('!location.pathname.includes("login") && document.body.innerText.length > 200', 90000);
  await delay(15000);
  await capture('01-wazuh-dashboard-overview.png');

  await navigate('https://localhost:8443/app/file-integrity-monitoring');
  await waitFor('document.body.innerText.includes("Alerts by action over time")', 90000);
  await delay(15000);
  await capture('02-file-integrity-monitoring.png');

  const eventsClicked = await evaluate(`(() => {
    const candidates = [...document.querySelectorAll('a, button, [role=tab]')];
    const eventsTab = candidates.find((element) => element.innerText.trim() === 'Events');
    if (!eventsTab) return false;
    eventsTab.click();
    return true;
  })()`);
  if (!eventsClicked) throw new Error('The File Integrity Monitoring Events tab was not found.');
  await waitFor('document.body.innerText.includes("Integrity checksum changed")', 90000);
  await delay(10000);
  await capture('03-fim-events.png');

  console.log('Captured the authenticated overview, FIM dashboard, and FIM event evidence.');
} finally {
  if (socket?.readyState === WebSocket.OPEN) {
    try { await send('Browser.close'); } catch { /* taskkill is the fallback */ }
    socket.close();
  }
  spawnSync('taskkill.exe', ['/PID', String(edge.pid), '/T', '/F'], { stdio: 'ignore' });
  try {
    rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 500 });
  } catch {
    console.warn('The temporary browser profile will remain under evidence/private and is excluded from Git.');
  }
}
