import {createHash} from 'node:crypto';
import {readFileSync, readdirSync, writeFileSync} from 'node:fs';
import {resolve, relative, sep} from 'node:path';
import {fileURLToPath} from 'node:url';

export function buildOffline(directory) {
  const root = resolve(directory);
  const paths = [];
  function collect(folder) {
    for (const entry of readdirSync(folder, {withFileTypes: true})) {
      if (entry.name.startsWith('.')) continue;
      const path = resolve(folder, entry.name);
      if (entry.isDirectory()) collect(path);
      else if (entry.name !== 'flutter_service_worker.js' && !/\.(map|symbols)$/.test(entry.name)) {
        paths.push(relative(root, path).split(sep).join('/'));
      }
    }
  }
  collect(root);
  paths.sort();
  const hash = createHash('sha256');
  for (const path of paths) hash.update(path).update('\0').update(readFileSync(resolve(root, path)));
  const name = 'routine-offline-' + hash.digest('hex').slice(0, 20);
  const template = readFileSync(new URL('./offline_worker.js', import.meta.url), 'utf8');
  const worker = template.replace('__ROUTINE_CACHE_NAME__', JSON.stringify(name))
    .replace('__ROUTINE_RESOURCES__', JSON.stringify(paths, null, 2));
  writeFileSync(resolve(root, 'flutter_service_worker.js'), worker);
  return {name, paths, worker};
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const {paths} = buildOffline(process.argv[2] || 'build/web');
  process.stdout.write(`Offline package: ${paths.length} files.\n`);
}
