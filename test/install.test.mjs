import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const script=readFileSync(new URL('../web/install.js',import.meta.url),'utf8');
function browserShell(standalone=false){
  const listeners=new Map();
  const window={matchMedia:()=>({matches:standalone}),addEventListener:(type,fn)=>listeners.set(type,fn)};
  vm.runInNewContext(script,{window,navigator:{}});
  return {window,listeners};
}
test('unsupported browsers fall back to manual installation',async()=>{
  const {window}=browserShell();
  assert.equal(await window.requestRoutineInstall(),'unavailable');
});
test('installation prompts require a captured event and can be used only once',async()=>{
  const {window,listeners}=browserShell();let prompted=0,prevented=false;
  listeners.get('beforeinstallprompt')({preventDefault(){prevented=true;},async prompt(){prompted++;},userChoice:Promise.resolve({outcome:'accepted'})});
  assert.equal(await window.requestRoutineInstall(),'accepted');
  assert.equal(prevented,true);assert.equal(prompted,1);
  assert.equal(await window.requestRoutineInstall(),'unavailable');
  listeners.get('appinstalled')();
  assert.equal(await window.requestRoutineInstall(),'installed');
});
test('dismissal is respected and standalone launches do not offer a new prompt',async()=>{
  const {window,listeners}=browserShell();
  listeners.get('beforeinstallprompt')({preventDefault(){},async prompt(){},userChoice:Promise.resolve({outcome:'dismissed'})});
  assert.equal(await window.requestRoutineInstall(),'dismissed');
  assert.equal(await browserShell(true).window.requestRoutineInstall(),'installed');
});
test('manifest scope and icons stay inside the Routine application',()=>{
  const manifest=JSON.parse(readFileSync(new URL('../web/manifest.json',import.meta.url),'utf8'));
  const origin=new URL('https://joaopedra-amdg.github.io/Routine/manifest.json');
  for(const key of ['id','scope','start_url'])assert.equal(new URL(manifest[key],origin).pathname,'/Routine/');
  assert.equal(manifest.display,'standalone');
  for(const size of ['192x192','512x512'])assert(manifest.icons.some(icon=>icon.sizes===size));
  for(const icon of manifest.icons)assert(readFileSync(new URL('../web/'+icon.src,import.meta.url)).length>0);
});
