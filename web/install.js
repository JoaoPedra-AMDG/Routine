// Browser installation integration only. App screens and state stay in Flutter.
(() => {
  let deferredPrompt = null;
  let installed = window.matchMedia?.('(display-mode: standalone)').matches ||
    navigator.standalone === true;

  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    deferredPrompt = event;
  });
  window.addEventListener('appinstalled', () => {
    installed = true;
    deferredPrompt = null;
    // Retain local plans and offline files when the browser supports it.
    navigator.storage?.persist?.().catch(() => {});
  });
  window.requestRoutineInstall = async () => {
    if (installed) return 'installed';
    if (!deferredPrompt) return 'unavailable';
    const promptEvent = deferredPrompt;
    deferredPrompt = null;
    try {
      await promptEvent.prompt();
      return (await promptEvent.userChoice).outcome;
    } catch {
      return 'unavailable';
    }
  };
})();
