const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const path = require('path');

const CHROME = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
const PORT = 8099;
const CDP_PORT = 9229;
const WEB_DIR = "D:\\flutter projects\\universe_v1\\build\\web";
const OUT_DIR = "D:\\flutter projects\\universe_v1\\docs\\screenshots\\phase_3";

if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

const server = http.createServer((req, res) => {
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
  const filePath = path.join(WEB_DIR, reqPath);
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath);
    const contentType = ext === '.html' ? 'text/html' :
                        ext === '.js' ? 'application/javascript' :
                        ext === '.json' ? 'application/json' :
                        ext === '.wasm' ? 'application/wasm' :
                        ext === '.png' ? 'image/png' : 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    fs.createReadStream(path.join(WEB_DIR, 'index.html')).pipe(res);
  }
});

server.listen(PORT, async () => {
  console.log(`Web server listening on http://127.0.0.1:${PORT}`);

  const chrome = spawn(CHROME, [
    '--headless=new',
    `--remote-debugging-port=${CDP_PORT}`,
    '--window-size=1440,900',
    '--force-prefers-reduced-motion',
    'about:blank'
  ]);

  await new Promise(r => setTimeout(r, 1500));

  let callId = 1;
  function callCDP(ws, method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++callId;
      const timeout = setTimeout(() => reject(new Error(`Timeout calling ${method}`)), 15000);
      const onMessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          if (msg.id === id) {
            clearTimeout(timeout);
            ws.removeEventListener('message', onMessage);
            if (msg.error) reject(msg.error);
            else resolve(msg.result);
          }
        } catch (e) {}
      };
      ws.addEventListener('message', onMessage);
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async function setViewport(ws, width, height, isMobile = false) {
    await callCDP(ws, 'Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: isMobile
    });
    await new Promise(r => setTimeout(r, 500));
  }

  async function takeScreenshot(ws, filename) {
    const shot = await callCDP(ws, 'Page.captureScreenshot', { format: 'png' });
    const buffer = Buffer.from(shot.data, 'base64');
    const outFile = path.join(OUT_DIR, filename);
    fs.writeFileSync(outFile, buffer);
    console.log(`Saved: ${filename} (${buffer.length} bytes)`);
  }

  async function loadRoute(ws, route, waitMs = 3500) {
    await callCDP(ws, 'Page.navigate', {
      url: `http://127.0.0.1:${PORT}/#${route}`
    });
    await new Promise(r => setTimeout(r, waitMs));
  }

  try {
    const listRes = await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`);
    const pages = await listRes.json();
    const page = pages.find(p => p.type === 'page') || pages[0];
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise(r => ws.onopen = r);

    await callCDP(ws, 'Page.enable');
    await callCDP(ws, 'Runtime.enable');

    // 0. Splash Screen
    console.log('\n--- Capturing Splash Screen ---');
    await setViewport(ws, 1440, 900);
    await callCDP(ws, 'Page.navigate', { url: `http://127.0.0.1:${PORT}/` });
    await new Promise(r => setTimeout(r, 1000));
    await takeScreenshot(ws, '00_splash_desktop_1440.png');

    await setViewport(ws, 390, 844, true);
    await callCDP(ws, 'Page.navigate', { url: `http://127.0.0.1:${PORT}/` });
    await new Promise(r => setTimeout(r, 1000));
    await takeScreenshot(ws, '00_splash_mobile_390.png');

    // 1. Onboarding Screen
    console.log('\n--- Capturing Onboarding Screen ---');
    // Clear onboarding_done
    await callCDP(ws, 'Runtime.evaluate', {
      expression: `window.localStorage.removeItem('flutter.onboarding_done');`
    });

    await setViewport(ws, 1440, 900);
    await loadRoute(ws, '/onboarding', 3500);
    await takeScreenshot(ws, '01_onboarding_stage1_desktop_1440.png');

    await setViewport(ws, 920, 800);
    await loadRoute(ws, '/onboarding', 2500);
    await takeScreenshot(ws, '01_onboarding_medium_920.png');

    await setViewport(ws, 390, 844, true);
    await loadRoute(ws, '/onboarding', 2500);
    await takeScreenshot(ws, '01_onboarding_mobile_390.png');

    // Set onboarding_done so auth routes do not get redirected to onboarding
    await callCDP(ws, 'Runtime.evaluate', {
      expression: `window.localStorage.setItem('flutter.onboarding_done', 'true');`
    });

    // List of auth routes to capture
    const authScreens = [
      { name: '02_login', route: '/login' },
      { name: '03_email_login', route: '/email-login' },
      { name: '04_email_signup', route: '/email-signup' },
      { name: '05_role_selection', route: '/role-selection' },
      { name: '06_student_register', route: '/student-register' },
      { name: '07_faculty_register', route: '/faculty-register' },
      { name: '08_verify_email', route: '/verify-email' },
      { name: '09_forgot_password', route: '/forgot-password' },
      { name: '10_reset_password', route: '/reset-password' },
      { name: '11_not_whitelisted', route: '/not-whitelisted' },
      { name: '12_auth_error', route: '/auth-error' },
    ];

    for (const screen of authScreens) {
      console.log(`\n--- Capturing ${screen.name} ---`);
      
      // Desktop 1440x900
      await setViewport(ws, 1440, 900);
      await loadRoute(ws, screen.route, 3000);
      await takeScreenshot(ws, `${screen.name}_desktop_1440.png`);

      // If login, also capture medium 920
      if (screen.name === '02_login') {
        await setViewport(ws, 920, 800);
        await loadRoute(ws, screen.route, 2000);
        await takeScreenshot(ws, `${screen.name}_medium_920.png`);
      }

      // Mobile 390x844
      await setViewport(ws, 390, 844, true);
      await loadRoute(ws, screen.route, 2500);
      await takeScreenshot(ws, `${screen.name}_mobile_390.png`);
    }

    console.log('\n=========================================');
    console.log('ALL SCREENSHOTS CAPTURED WITH 100% SUCCESS!');
    console.log('=========================================');
    ws.close();
  } catch (err) {
    console.error('Error during capture:', err);
  } finally {
    chrome.kill();
    server.close();
  }
});
