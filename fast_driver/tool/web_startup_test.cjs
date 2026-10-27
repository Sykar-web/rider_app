// Browser-independent regression checks for the web startup lifecycle.
// Run: node tool/web_startup_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = process.argv[2] || path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'web/index.html'), 'utf8');
const scripts = ['splash-screen-script', 'fastdriver-startup-script'].map((id) => {
  const result = html.match(new RegExp(`<script id="${id}">([\\s\\S]*?)<\\/script>`));
  assert.ok(result, `${id} exists`);
  return result[1];
}).join('\n');
const bootstrap = fs.readFileSync(path.join(root, 'web/flutter_bootstrap.js'), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

function browser(baseURI = 'https://example.test/FastDriver/') {
  const handlers = new Map();
  const timers = new Map();
  const elements = new Map();
  let reloadCount = 0;
  for (const id of ['splash', 'splash-branding', 'fastdriver-startup-status', 'fastdriver-startup-message', 'fastdriver-startup-reload']) {
    const element = { hidden: id.endsWith('reload'), textContent: '',
      remove() { elements.delete(id); },
      addEventListener(type, callback) { this[type] = callback; },
    };
    elements.set(id, element);
  }
  const context = { URL, navigator: { onLine: true },
    document: { baseURI, body: { style: {} }, getElementById: (id) => elements.get(id) },
    setTimeout(fn, ms) { timers.set(1, { fn, ms }); return 1; },
    clearTimeout(id) { timers.delete(id); },
    location: { reload() { reloadCount++; } },
    addEventListener(type, callback) { handlers.set(type, callback); },
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(scripts, context);
  return { context, elements, timers, handlers, reloadCount: () => reloadCount,
    event(type, data = {}) { handlers.get(type)?.(data); },
  };
}

(async () => {
  let checks = 0;
  {
    const app = browser();
    assert.equal(app.timers.get(1).ms, 20000);
    app.event('flutter-first-frame');
    assert.ok(!app.elements.has('splash'));
    assert.ok(!app.elements.has('fastdriver-startup-status'));
    assert.equal(app.timers.size, 0);
    assert.equal(app.context.document.body.style.background, 'transparent');
    app.context.fastDriverStartup.fail(); // A late failure cannot cover a running app.
    checks++;
  }
  {
    const app = browser();
    app.event('DOMContentLoaded');
    app.timers.get(1).fn();
    assert.match(app.elements.get('fastdriver-startup-message').textContent, /longer than expected/);
    assert.equal(app.elements.get('fastdriver-startup-reload').hidden, false);
    app.elements.get('fastdriver-startup-reload').click();
    assert.equal(app.reloadCount(), 1);
    app.event('flutter-first-frame'); // Late completion still recovers.
    assert.ok(!app.elements.has('splash'));
    checks++;
  }
  {
    const app = browser();
    app.context.navigator.onLine = false;
    app.event('DOMContentLoaded');
    assert.match(app.elements.get('fastdriver-startup-message').textContent, /offline/);
    checks++;
  }
  {
    const app = browser();
    app.event('error', { target: { tagName: 'SCRIPT', src: 'https://maps.googleapis.com/maps/api/js' } });
    assert.equal(app.elements.get('fastdriver-startup-reload').hidden, true);
    app.event('error', { filename: 'https://maps.googleapis.com/maps/api/js' });
    assert.equal(app.elements.get('fastdriver-startup-reload').hidden, true);
    app.event('error', { target: { tagName: 'SCRIPT', src: 'https://example.test/FastDriver/flutter_bootstrap.js' } });
    assert.equal(app.elements.get('fastdriver-startup-reload').hidden, false);
    checks++;
  }
  for (const failure of [false, 'loader', 'engine', 'runApp']) {
    const app = browser();
    let launched = false;
    app.context._flutter = { loader: { async load(options) {
      assert.equal(options.config.canvasKitBaseUrl, 'https://example.test/FastDriver/canvaskit/');
      if (failure === 'loader') throw new Error('Loader failed');
      await options.onEntrypointLoaded({ async initializeEngine(config) {
        assert.equal(config.canvasKitBaseUrl, options.config.canvasKitBaseUrl);
        if (failure === 'engine') throw new Error('Renderer failed');
        return { async runApp() {
          if (failure === 'runApp') throw new Error('App failed');
          launched = true;
        } };
      } });
    } } };
    await vm.runInContext(bootstrap, app.context);
    assert.equal(launched, failure === false);
    assert.equal(app.elements.get('fastdriver-startup-reload').hidden, failure === false);
    // Engine initialization must not hide the splash before the first frame.
    assert.ok(app.elements.has('splash'));
    checks++;
  }
  console.log(`${checks} web startup checks passed.`);
})().catch((error) => { console.error(error); process.exitCode = 1; });
