"""Local browser acceptance probe. Synthetic REST is NOT Supabase/RLS evidence.

Uses the existing Selenium/Chrome and engine virtualenv; installs nothing.
Starts only loopback servers and closes only its own child processes.
Run after a synthetic web build with callback http://127.0.0.1:8765/ approved.
Artifacts go to a fresh temporary directory; source workbooks are never read.
"""
from __future__ import annotations

import base64
import functools
import hashlib
import http.server
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import urllib.request

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

ROOT = Path(__file__).resolve().parents[1]
USER_ID = '00000000-0000-4000-8000-000000000001'
REQUESTS = []
ROLE = 'admin'
INVITED = False
PROFILE_FAILURE = False


def user():
    return dict(id=USER_ID, aud='authenticated', role='authenticated',
                email='synthetic@example.invalid', email_confirmed_at='2026-01-01T00:00:00Z',
                invited_at='2026-01-01T00:00:00Z' if INVITED else None,
                created_at='2026-01-01T00:00:00Z', app_metadata={'provider': 'email'},
                user_metadata={})


def session():
    enc = lambda value: base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
    token = enc({'alg': 'HS256', 'typ': 'JWT'}) + '.' + enc(dict(sub=USER_ID,
        exp=int(time.time()) + 3600, role='authenticated', aud='authenticated')) + '.synthetic'
    return dict(access_token=token, refresh_token='synthetic-refresh', token_type='bearer',
                expires_in=3600, expires_at=int(time.time()) + 3600, user=user())


class FakeRest(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, data, code=200):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Allow-Methods', '*')
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Range', '0-0/1')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def do_OPTIONS(self):
        self.reply({})

    def do_GET(self):
        REQUESTS.append((self.command, self.path))
        if self.path.startswith('/auth/v1/user'):
            return self.reply(user())
        if '/profiles' in self.path:
            if PROFILE_FAILURE:
                return self.reply({'message': 'Synthetic temporary read failure'}, 503)
            profile = dict(id=USER_ID, role=ROLE, email='synthetic@example.invalid',
                           name='Synthetic Reviewer', courses=[])
            return self.reply(profile if 'object+json' in self.headers.get('Accept', '') else [profile])
        return self.reply([])

    do_HEAD = do_GET

    def do_POST(self):
        REQUESTS.append((self.command, self.path))
        self.rfile.read(int(self.headers.get('Content-Length', 0)))
        if '/auth/v1/token' in self.path:
            return self.reply(session())
        if '/auth/v1/logout' in self.path:
            return self.reply({})
        self.reply({'message': 'Fixture rejects all writes'}, 403)

    def do_PUT(self):
        REQUESTS.append((self.command, self.path))
        self.rfile.read(int(self.headers.get('Content-Length', 0)))
        if self.path.startswith('/auth/v1/user'):
            return self.reply(user())
        self.reply({'message': 'Fixture rejects all writes'}, 403)


class QuietFiles(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


def main():
    global ROLE, INVITED, PROFILE_FAILURE
    artifact = Path(tempfile.mkdtemp(prefix='universe-phase1-reverify-'))
    downloads = artifact / 'downloads'
    downloads.mkdir()
    fixture_code = '''
import sys,json,zlib
from pathlib import Path
sys.path.insert(0,'engine/tests')
from conftest import build_workbook,make_config,make_row
p=Path(sys.argv[1]); b=build_workbook([make_row(code="CSE-1101",credit=1,classes=14,duration=1,per_week=1)])
(p/'synthetic.xlsx').write_bytes(b)
cfg=make_config(teachers=('AAA',))
(p/'profile.json').write_text(json.dumps(dict(format='universe-generation-profile-v1',label='Synthetic browser rehearsal',provenance='Generated synthetic data only; no academic approval',meeting_count_policy='distribution',source_crc32=zlib.crc32(b),source_bytes=len(b),config=cfg)))
'''
    subprocess.run([str(ROOT/'engine/.venv/Scripts/python.exe'), '-c', fixture_code,
                    str(artifact)], cwd=ROOT, check=True)
    servers = []
    engine = driver = None
    result = {'artifact_directory': str(artifact), 'classification':
              'Actual compiled Chrome UI + real local engine; synthetic REST/session, not real auth/RLS'}
    try:
        for port, handler in [(54321, FakeRest), (8765, functools.partial(
                QuietFiles, directory=str(ROOT/'build/web'))),
                (8766, functools.partial(QuietFiles,
                    directory=str(ROOT/'supabase/functions/invite-admin')))]:
            server = http.server.ThreadingHTTPServer(('127.0.0.1', port), handler)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            servers.append(server)
        log = (artifact/'engine.log').open('w')
        engine = subprocess.Popen([str(ROOT/'engine/.venv/Scripts/python.exe'), '-m', 'uvicorn',
            'main:app', '--host', '127.0.0.1', '--port', '8000'], cwd=ROOT/'engine',
            stdout=log, stderr=subprocess.STDOUT)
        for _ in range(60):
            try:
                urllib.request.urlopen('http://127.0.0.1:8000/', timeout=1).read()
                break
            except OSError:
                time.sleep(.5)
        options = webdriver.ChromeOptions()
        options.add_argument('--headless=new')
        options.add_argument('--window-size=1298,1100')
        options.add_argument('--disable-dev-shm-usage')
        options.set_capability('goog:loggingPrefs', {'performance': 'ALL'})
        options.add_experimental_option('prefs', {'download.default_directory': str(downloads),
            'download.prompt_for_download': False, 'profile.default_content_setting_values.automatic_downloads': 1})
        cached = Path.home()/'.cache/selenium/chromedriver/win64/156.0.8078.80/chromedriver.exe'
        driver = webdriver.Chrome(service=Service(str(cached)), options=options)
        driver.execute_cdp_cmd('Browser.setDownloadBehavior', {'behavior': 'allow', 'downloadPath': str(downloads)})
        driver.get('http://127.0.0.1:8766/')
        result['javascript_contract_assertions'] = driver.execute_async_script('''
            const done=arguments[0];
            Promise.all([import('/callback_policy_test.js'),import('/handler_test.js')])
            .then(async ([p,h])=>done({policy:p.runCallbackPolicyTests(),handler:await h.runInvitationHandlerTests()}))
            .catch(e=>done({error:String(e)}));
        ''')
        assert 'error' not in result['javascript_contract_assertions']
        driver.get('http://127.0.0.1:8765/')
        driver.execute_script('localStorage.setItem(arguments[0], arguments[1]); localStorage.setItem("flutter.onboarding_done", "true")',
                              'sb-127-auth-token', json.dumps(session()))
        driver.get('http://127.0.0.1:8765/#/admin/dashboard')
        driver.refresh()
        wait = WebDriverWait(driver, 35)

        def enable_semantics():
            time.sleep(2)
            # The accessibility placeholder may appear after fonts/startup.
            for _ in range(30):
                driver.execute_script('document.querySelector("flt-semantics-placeholder")?.click()')
                if driver.execute_script('return !!document.querySelector("flt-semantics-host")'):
                    return
                time.sleep(.3)

        def text_present(value, timeout=35):
            try:
                WebDriverWait(driver, timeout).until(lambda d: value in d.execute_script('return document.body.textContent'))
            except Exception as exc:
                raise RuntimeError('Missing expected semantic text: '+value) from exc

        def click(value):
            nodes = driver.find_elements(By.XPATH, '//*[normalize-space(text())='+json.dumps(value)+']')
            if not nodes:
                nodes = driver.find_elements(By.XPATH,
                    '//flt-semantics[@role="button" and contains(.,'+json.dumps(value)+')]')
            for node in reversed(nodes):
                # Flutter's real semantics overlay is intentionally transparent.
                # Activate its DOM action without treating opacity as absence.
                driver.execute_script('arguments[0].scrollIntoView({block:"center"}); arguments[0].click()', node)
                return
            raise RuntimeError('No semantic action '+value)

        enable_semantics()
        text_present('Synthetic Reviewer')
        result['restored_admin_dashboard'] = driver.current_url
        driver.save_screenshot(str(artifact/'engine-connected.png'))
        result['engine_health_connected_screenshot'] = 'engine-connected.png'
        PROFILE_FAILURE = True
        driver.get('http://127.0.0.1:8765/#/admin/dashboard')
        driver.refresh()
        enable_semantics()
        text_present('Account unavailable')
        assert '/auth-error' in driver.current_url
        PROFILE_FAILURE = False
        click('Retry')
        text_present('Synthetic Reviewer')
        result['failed_profile_retry'] = driver.current_url
        for width in [800, 1000, 1280, 390]:
            gap = driver.execute_script('return outerWidth-innerWidth')
            driver.set_window_size(width+gap, 1100)
            if width < 500:
                driver.execute_cdp_cmd('Emulation.setDeviceMetricsOverride', {
                    'width': width, 'height': 1000, 'deviceScaleFactor': 1, 'mobile': False})
            time.sleep(1)
            result[f'inner_width_{width}'] = driver.execute_script('return innerWidth')
            driver.save_screenshot(str(artifact/f'dashboard-{width}.png'))
        driver.execute_cdp_cmd('Emulation.clearDeviceMetricsOverride', {})
        driver.set_window_size(1298, 1100)
        driver.get('http://127.0.0.1:8765/#/admin/routine?tab=generate')
        enable_semantics()
        text_present('Import run profile (.json)')
        # Retain the actual plugin's HTML input/FileReader. Only bypass the OS dialog.
        driver.execute_script('window.__picker=null; const original=HTMLInputElement.prototype.click; HTMLInputElement.prototype.click=function(){if(this.type==="file"){window.__picker=this;document.body.appendChild(this);this.style.display="block";}else original.call(this)}')

        def choose(label, path):
            driver.execute_script('window.__picker=null')
            click(label)
            element = wait.until(lambda d: d.execute_script('return window.__picker'))
            element.send_keys(str(path))
            time.sleep(1)

        choose('Import run profile (.json)', artifact/'profile.json')
        text_present('Use database settings instead')
        choose('Choose distribution file', artifact/'synthetic.xlsx')
        text_present('synthetic.xlsx')
        click('Generate Timetable')
        text_present('Valid against the distribution', timeout=240)
        result['actual_engine_generation'] = True
        driver.save_screenshot(str(artifact/'generated.png'))
        click('Download Workbook (.xlsx)')
        WebDriverWait(driver, 30).until(lambda _: list(downloads.glob('*.xlsx')))
        click('Save private draft (all faculty)')
        WebDriverWait(driver, 30).until(lambda _: list(downloads.glob('*.json')))
        draft = json.loads(next(downloads.glob('*.json')).read_text())
        assert draft['preview_only'] is True and draft['rows']
        result['private_draft_rows'] = len(draft['rows'])
        workbook = next(downloads.glob('*.xlsx')).read_bytes()
        assert workbook[:2] == b'PK'
        result['xlsx_sha256'] = hashlib.sha256(workbook).hexdigest()
        network = [json.loads(entry['message'])['message'] for entry in driver.get_log('performance')]
        request_urls = [entry['params']['request']['url'] for entry in network
                        if entry['method'] == 'Network.requestWillBeSent']
        download_urls = [url for url in request_urls if '127.0.0.1:8000/api/timetable/download/' in url]
        assert download_urls, 'Missing real engine download network request'
        expected = urllib.request.urlopen(download_urls[-1]).read()
        assert workbook == expected, 'Downloaded bytes differ from actual engine response'
        result['xlsx_matches_engine_bytes'] = True
        # Browser network performance captures the real result-download job URL.
        result['private_export_backend_writes'] = [r for r in REQUESTS if r[0] not in ('GET','HEAD','OPTIONS')]
        assert not result['private_export_backend_writes']
        click('View Full Grid')
        text_present('Timetable Grid')
        text_present('CSE-1101')
        time.sleep(2)
        driver.save_screenshot(str(artifact/'preview.png'))
        result['preview_route'] = driver.current_url
        driver.back()
        time.sleep(2)
        result['history_back'] = driver.current_url
        engine.terminate()
        engine.wait(timeout=15)
        engine = None
        # The nested page scopes its semantics tree, excluding shell controls.
        # Click the actual fixed header health button at the measured1280width.
        for kind in ['mousePressed', 'mouseReleased']:
            driver.execute_cdp_cmd('Input.dispatchMouseEvent', {'type': kind,
                'x': 1035, 'y': 24, 'button': 'left', 'clickCount': 1})
        time.sleep(6)
        driver.save_screenshot(str(artifact/'engine-unavailable.png'))
        result['engine_health_unavailable_screenshot'] = 'engine-unavailable.png'
        driver.get('http://127.0.0.1:8765/#/reset-password')
        enable_semantics()
        result['untrusted_reset_route'] = driver.current_url
        ROLE = 'student'
        driver.get('http://127.0.0.1:8765/#/admin/dashboard')
        driver.refresh()
        enable_semantics()
        result['student_admin_route'] = driver.current_url
        assert '/admin/' not in driver.current_url
        driver.execute_script('localStorage.clear()')
        driver.get('http://127.0.0.1:8765/#/admin/dashboard')
        driver.refresh()
        enable_semantics()
        result['anonymous_admin_route'] = driver.current_url
        assert '/admin/' not in driver.current_url
        ROLE = 'admin'
        driver.execute_script('localStorage.setItem("flutter.supabase.auth.token-code-verifier", arguments[0])',
                              json.dumps('synthetic-verifier/passwordRecovery'))
        driver.get('http://127.0.0.1:8765/?code=synthetic-recovery-code')
        enable_semantics()
        text_present('Update password')
        assert '/reset-password' in driver.current_url
        result['sdk_pkce_recovery_route'] = driver.current_url
        driver.save_screenshot(str(artifact/'recovery.png'))
        # Use real text editing events on the actual reset form.
        for y in (582, 494):
            for kind in ['mousePressed', 'mouseReleased']:
                driver.execute_cdp_cmd('Input.dispatchMouseEvent', {'type': kind,
                    'x': 220, 'y': y, 'button': 'left', 'clickCount': 1})
            time.sleep(.2)
            driver.execute_cdp_cmd('Input.insertText', {'text': 'Synthetic-password8!'})
            time.sleep(.2)
        for kind in ['mousePressed', 'mouseReleased']:
            driver.execute_cdp_cmd('Input.dispatchMouseEvent', {'type': kind,
                'x': 640, 'y': 890, 'button': 'left', 'clickCount': 1})
        text_present('Your password has been changed successfully.')
        result['browser_recovery_password_update'] = True
        click('Sign in now')
        time.sleep(2)
        result['recovery_completion_signout'] = driver.current_url
        # Use the actual SDK invitation verifier against the synthetic REST fixture.
        driver.execute_script('localStorage.clear()')
        INVITED = True
        token = session()['access_token']
        driver.get('http://127.0.0.1:8765/#type=invite&access_token='+token+
                   '&refresh_token=synthetic-refresh&expires_in=3600&token_type=bearer')
        enable_semantics()
        text_present('Update password')
        assert '/reset-password' in driver.current_url
        assert 'access_token' not in driver.current_url
        result['sdk_invitation_route_and_url_cleanup'] = True
        result['synthetic_auth_requests'] = [r for r in REQUESTS if '/auth/' in r[1]]
        result['completed'] = True
    except Exception as exc:
        result['completed'] = False
        result['error'] = str(exc)
        result['synthetic_auth_requests'] = [r for r in REQUESTS if '/auth/' in r[1]]
        if driver:
            driver.save_screenshot(str(artifact/'failure.png'))
            (artifact/'failure.html').write_text(driver.page_source, encoding='utf-8')
            result['failure_body_text'] = driver.execute_script('return document.body.textContent')[-2000:]
            result['failure_url'] = driver.current_url.split('access_token')[0]
    finally:
        (artifact/'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        print(json.dumps(result, indent=2))
        if driver:
            driver.quit()
        if engine:
            engine.terminate()
            engine.wait(timeout=15)
        for server in servers:
            server.shutdown()
    return 0 if result.get('completed') else 1


if __name__ == '__main__':
    raise SystemExit(main())
