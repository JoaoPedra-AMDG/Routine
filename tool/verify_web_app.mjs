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
const manifest=JSON.parse(read('manifest.json'));
assert.equal(manifest.display,'standalone');
for(const key of ['id','scope','start_url'])assert.equal(new URL(manifest[key],'https://joaopedra-amdg.github.io/Routine/manifest.json').pathname,'/Routine/');
for(const icon of manifest.icons)assert(readFileSync(resolve(directory,icon.src)).length>0,'Missing app icon');
process.stdout.write('Installable web-app package verified.\n');
