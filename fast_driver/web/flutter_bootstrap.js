{{flutter_js}}
{{flutter_build_config}}

// Load the renderer alongside this app, avoiding a second host during startup.
// Flutter's development server also serves this local canvaskit/ path.
(async () => {
  const config = { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href };
  try {
    await _flutter.loader.load({
      config,
      onEntrypointLoaded: async (engineInitializer) => {
        try {
          const appRunner = await engineInitializer.initializeEngine(config);
          await appRunner.runApp();
          // The first-frame event removes the splash, not merely runApp resolving.
        } catch (_) {
          window.fastDriverStartup?.fail();
        }
      },
    });
  } catch (_) {
    window.fastDriverStartup?.fail();
  }
})();
