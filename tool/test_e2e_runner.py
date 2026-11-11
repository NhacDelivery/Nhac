"""Exercise runner orchestration and cleanup without Android, Flutter or a real DB."""

import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import tempfile
import unittest


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.app = root / "app"
        self.backend = root / "backend"
        self.bin = root / "bin"
        (self.app / "tool").mkdir(parents=True)
        (self.backend / "target").mkdir(parents=True)
        self.bin.mkdir()
        for name in ("run_e2e.sh", "check_e2e_backend.py"):
            shutil.copy(Path(__file__).parent / name, self.app / "tool" / name)
        (self.backend / "target/backend_nhac-0.0.1-SNAPSHOT.jar").touch()
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            self.port = sock.getsockname()[1]
        self.trace = root / "trace.txt"
        self.env = dict(os.environ, RUN_E2E="true", E2E_DB_MANAGED="true",
                        E2E_REPEAT="1", E2E_ONLY="all", E2E_BACKEND_PORT=str(self.port),
                        BACKEND_DIR=str(self.backend), BACKEND_JAVA_HOME=str(root),
                        FLUTTER_BIN=str(self.bin / "fake-flutter"), TRACE=str(self.trace),
                        NO_PROXY="127.0.0.1,localhost", no_proxy="127.0.0.1,localhost",
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        # Do not append test results to a real Actions job if these tests run in CI.
        self.env.pop("GITHUB_STEP_SUMMARY", None)
        self.env.pop("E2E_DB_CONTAINER", None)
        self.env.pop("E2E_LOG_DIR", None)
        (self.app / ".env").write_text(
            f"API_BASE_URL=http://127.0.0.1:{self.port}/api/v1\nE2E_MODE=true\n")
        self.executable("java", '''#!/usr/bin/env python3
import json, os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
if '-version' in sys.argv:
    print('fake Java 25')
    raise SystemExit(0)
with open(os.environ['TRACE'], 'a') as f: f.write('backend-start\\n')
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/actuator/health': data = {'status': 'UP'}
        elif self.path.startswith('/api/v1/produtos/cards?'): data = {'content': [{'id':'e2e-produto-001'}]}
        elif self.path.startswith('/api/v1/pedidos/ativos'): data = []
        else: data = {'content': [], 'totalElements': 0}
        self.respond(data)
    def do_POST(self):
        self.rfile.read(int(self.headers['Content-Length']))
        self.respond({'token': 'fixture-test-token'})
    def respond(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data, separators=(',', ':')).encode())
    def log_message(self, *args): pass
HTTPServer(('127.0.0.1', int(os.environ['SERVER_PORT'])), Handler).serve_forever()
''')
        self.executable("fake-flutter", '''#!/usr/bin/env python3
import os, sys
if sys.argv[1] == '--version':
    print('fake Flutter')
    raise SystemExit(0)
target = sys.argv[2]
with open(os.environ['TRACE'], 'a') as f: f.write(target + '\\n')
raise SystemExit(1 if os.environ.get('FAIL_CONTRACT') == 'true' and 'contract_smoke' in target else 0)
''')
        self.executable("adb", "#!/usr/bin/env bash\nif [[ \"$*\" == *getprop* ]]; then echo 34; fi\n")
        self.executable("curl", '''#!/usr/bin/env python3
import sys, urllib.request
try:
    with urllib.request.urlopen(sys.argv[-1], timeout=1) as response:
        print(response.read().decode())
except Exception:
    raise SystemExit(22)
''')

    def executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_suite(self):
        # A regression in process cleanup must not hang the test job.
        process = subprocess.Popen(["bash", "tool/run_e2e.sh"], cwd=self.app,
                                   env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=10)
            logs = '\n'.join(p.read_text() for p in (self.app / 'e2e-logs').glob('backend-*.log'))
            self.fail('Runner timed out:\n' + stdout + stderr + logs)
        return subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr)

    def assert_port_released(self):
        with socket.socket() as sock:
            self.assertNotEqual(sock.connect_ex(("127.0.0.1", self.port)), 0)

    def test_all_runs_seven_scenarios_with_a_fresh_backend_each_time(self):
        result = self.run_suite()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        trace = self.trace.read_text().splitlines()
        self.assertEqual(trace, [
            'backend-start', 'integration_test/backend_contract_smoke_test.dart',
            'backend-start', 'integration_test/client_login_e2e_test.dart',
            'backend-start', 'integration_test/client_order_cash_e2e_test.dart',
            'backend-start', 'integration_test/client_delivery_e2e_test.dart',
            'backend-start', 'integration_test/client_payment_pix_e2e_test.dart',
            'backend-start', 'integration_test/client_payment_card_e2e_test.dart',
            'backend-start', 'integration_test/client_chat_e2e_test.dart',
        ])
        self.assert_port_released()

    def test_contract_failure_cannot_be_hidden_by_successful_ui_tests(self):
        self.env['FAIL_CONTRACT'] = 'true'
        result = self.run_suite()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('| contract_smoke | 0 | 1 |',
                      (self.app / 'e2e-logs/summary.md').read_text())
        self.assert_port_released()

    def test_payment_card_can_run_alone(self):
        self.env['E2E_ONLY'] = 'payment_card'
        result = self.run_suite()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.trace.read_text().splitlines(), [
            'backend-start', 'integration_test/client_payment_card_e2e_test.dart',
        ])
        self.assert_port_released()

    def test_external_api_is_rejected_before_starting_any_process(self):
        (self.app / '.env').write_text('API_BASE_URL=https://backend-nhac.onrender.com/api/v1\nE2E_MODE=true\n')
        result = self.run_suite()
        self.assertEqual(result.returncode, 2)
        self.assertIn('API E2E recusada', result.stderr)
        self.assertFalse(self.trace.exists())


if __name__ == '__main__':
    unittest.main()
