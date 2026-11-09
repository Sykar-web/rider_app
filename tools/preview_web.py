"""Serve a /FastRide/ release build locally, including its base-path assets."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import argparse


class PreviewHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        requested = urlsplit(self.path)
        if requested.path in ('/', '/FastRide'):
            self.send_response(302)
            self.send_header('Location', '/FastRide/')
            self.end_headers()
            return
        if not requested.path.startswith('/FastRide/'):
            self.send_error(404)
            return
        self.path = requested.path[len('/FastRide'):]
        return super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8081)
    args = parser.parse_args()
    web = Path(__file__).resolve().parents[1] / 'build' / 'web'
    if not (web / 'main.dart.js').exists():
        raise SystemExit('Build the web app with --base-href /FastRide/ first.')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(PreviewHandler, directory=str(web)))
    print(f'FastRide preview: http://127.0.0.1:{args.port}/FastRide/', flush=True)
    server.serve_forever()
