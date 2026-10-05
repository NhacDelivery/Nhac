import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

from check_e2e_backend import check_backend


class ContractTest(unittest.TestCase):
    def setUp(self):
        self.responses = {
            "/produtos/cards": (200, {"content": [{"id": "e2e-produto-001"}]}),
            "/produtos/cards/promocoes": (200, {"content": []}),
            "/auth/login": (200, {"token": "fixture-test-token"}),
            "/pedidos/ativos": (200, []),
            "/feed/posts": (200, {"content": []}),
        }
        self.calls = []
        test = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                path = urlsplit(self.path).path.removeprefix("/api/v1")
                test.calls.append(path)
                if path in ("/pedidos/ativos", "/feed/posts"):
                    test.assertEqual(self.headers["Authorization"], "Bearer fixture-test-token")
                status, body = test.responses[path]
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(body).encode())

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                test.assertEqual(body["email"], "e2e.cliente@nhac.local")
                self.do_GET()

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.addCleanup(self.close)

    def close(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()

    def check(self):
        check_backend(self.server.server_port)

    def test_current_contract_authenticates_and_checks_empty_active_orders(self):
        self.check()
        self.assertEqual(len(self.calls), 5)

    def test_old_backend_stops_before_login_or_android_test(self):
        self.responses["/produtos/cards"] = (404, {"message": "Produto cards não encontrado"})
        with self.assertRaisesRegex(RuntimeError, "HTTP 404"):
            self.check()
        self.assertEqual(self.calls, ["/produtos/cards"])

    def test_missing_fixture_is_reported_without_waiting_for_widget_timeout(self):
        self.responses["/produtos/cards"] = (200, {"content": []})
        with self.assertRaisesRegex(RuntimeError, "fixture.*ausente"):
            self.check()


if __name__ == "__main__":
    unittest.main()
