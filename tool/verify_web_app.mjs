import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const directory=resolve(process.argv[2]||'build/web');
const read=path=>readFileSync(resolve(directory,path),'utf8');
const html=read('index.html');
assert(html.includes('<base href="/Routine/">'),'GitHub Pages base path is missing');
assert(html.includes('src="install.js"'),'Install integration is missing from the app shell');
assert(read('install.js').includes('beforeinstallprompt'),'Install integration was not packaged');
assert(read('flutter_service_worker.js').includes('"install.js"'),'Install integration is missing from offline resources');
assert(html.includes('src="offline.js"'),'Offline integration is missing from the app shell');
const worker=read('flutter_service_worker.js');
assert(worker.includes('routine-offline-'),'Full offline cache was not generated');
for(const resource of ['index.html','flutter_bootstrap.js','main.dart.js','install.js','offline.js','assets/fonts/MaterialIcons-Regular.otf','canvaskit/canvaskit.js','canvaskit/canvaskit.wasm','canvaskit/chromium/canvaskit.js','canvaskit/chromium/canvaskit.wasm']) {
  assert(worker.includes(JSON.stringify(resource)),`Missing offline resource: ${resource}`);
  assert(readFileSync(resolve(directory,resource)).length>0,`Missing file: ${resource}`);
}
assert(read('flutter_bootstrap.js').includes("canvasKitBaseUrl: 'canvaskit/'"),'Renderer must use packaged files');
const bootstrap=read('flutter_bootstrap.js');
const startup=bootstrap.slice(bootstrap.lastIndexOf('_flutter.loader.load('));
assert(!startup.includes('serviceWorkerSettings:'),'Legacy worker registration must be disabled');
const fonts=JSON.parse(read('assets/FontManifest.json'));
assert(fonts.some(font=>font.family==='Roboto'),'Default text font must be bundled');
for(const font of fonts) for(const asset of font.fonts) assert(worker.includes(JSON.stringify('assets/'+asset.asset)),`Font missing offline: ${asset.asset}`);
const manifest=JSON.parse(read('manifest.json'));
assert.equal(manifest.display,'standalone');
for(const key of ['id','scope','start_url'])assert.equal(new URL(manifest[key],'https://joaopedra-amdg.github.io/Routine/manifest.json').pathname,'/Routine/');
for(const icon of manifest.icons)assert(readFileSync(resolve(directory,icon.src)).length>0,'Missing app icon');
process.stdout.write('Installable offline web-app package verified.\n');
