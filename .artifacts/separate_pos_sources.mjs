// Source/dependency inspection and ownership migration only. Does not run Flutter.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const pos = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const main = path.resolve(pos, '../Trexven');
const artifacts = path.join(pos, '.artifacts');
const baselineFile = path.join(artifacts, 'POS_SOURCE_SEPARATION_BASELINE_20261017.json');
const evidenceFile = path.join(artifacts, 'POS_SOURCE_SEPARATION_MANIFEST_20261017.json');
const names = ['trexven_design_system', 'trexven_operations'];
const omitted = ['account_operations_screen.dart', 'operational_permissions_screen.dart',
  'entitlements.dart', 'metric_content.dart'];
const ignore = new Set(['.git', '.dart_tool', 'build', '.gradle', 'node_modules', '.symlinks']);
const sourceDirs = ['lib', 'packages', 'assets', 'test', 'integration_test', 'android',
  'ios', 'linux', 'macos', 'windows', 'web', 'supabase'];
const slash = p => p.replaceAll('\\', '/');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const read = p => fs.readFile(p, 'utf8');
const exists = async p => !!(await fs.stat(p).catch(() => null));
const inside = (root, target) => {
  const rel = path.relative(root, target);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
};
async function files(dir) {
  if (!await exists(dir)) return [];
  const out = [];
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    if (ignore.has(e.name)) continue;
    const target = path.join(dir, e.name);
    if (e.isSymbolicLink()) throw Error(`Filesystem link in source: ${target}`);
    if (e.isDirectory()) out.push(...await files(target));
    else if (e.isFile()) out.push(target);
  }
  return out.sort();
}
async function snapshot(root) {
  const selected = [];
  for (const e of await fs.readdir(root, { withFileTypes: true })) {
    if (e.isFile()) selected.push(path.join(root, e.name));
  }
  for (const dir of sourceDirs) selected.push(...await files(path.join(root, dir)));
  const out = {};
  for (const p of selected) out[slash(path.relative(root, p))] = hash(await fs.readFile(p));
  return out;
}
function changes(before, after) {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])].sort()
    .filter(p => before[p] !== after[p])
    .map(p => ({ path: p, before: before[p] ?? null, after: after[p] ?? null }));
}
const save = (p, obj) => fs.writeFile(p, JSON.stringify(obj, null, 2) + '\n');
async function packageRoots(root) {
  const configPath = path.join(root, '.dart_tool/package_config.json');
  const config = JSON.parse(await read(configPath));
  return config.packages.map(p => ({
    name: p.name, rootUri: p.rootUri,
    resolved: slash(fileURLToPath(new URL(p.rootUri.endsWith('/') ? p.rootUri : p.rootUri + '/',
      new URL('file:///' + slash(configPath))))),
  }));
}
async function inspect() {
  if (await exists(baselineFile)) throw Error('Baseline already exists; do not overwrite.');
  const [mainSnapshot, posSnapshot, posRoots, mainRoots] = await Promise.all([
    snapshot(main), snapshot(pos), packageRoots(pos), packageRoots(main),
  ]);
  const packageFiles = {};
  for (const name of names) {
    packageFiles[name] = {};
    for (const p of await files(path.join(main, 'packages', name))) {
      packageFiles[name][slash(path.relative(path.join(main, 'packages', name), p))] = hash(await fs.readFile(p));
    }
  }
  const data = { capturedAt: new Date().toISOString(), mainSnapshot, posSnapshot,
    posRoots, mainRoots, packageFiles };
  await save(baselineFile, data);
  console.log(JSON.stringify({ mainFiles: Object.keys(mainSnapshot).length,
    posFiles: Object.keys(posSnapshot).length,
    posMainOwnedDependencies: posRoots.filter(p => inside(main, p.resolved)),
    mainLocalPackages: mainRoots.filter(p => inside(main, p.resolved)),
    packageFiles: Object.fromEntries(Object.entries(packageFiles).map(([k,v]) => [k,Object.keys(v)])),
  }, null, 2));
}
async function replace(p, old, next, expected) {
  const original = await read(p);
  const count = original.split(old).length - 1;
  if (count !== expected) throw Error(`Expected ${expected} replacements, got ${count}: ${p}`);
  await fs.writeFile(p, original.split(old).join(next));
}
async function implement() {
  const baseline = JSON.parse(await read(baselineFile));
  if (changes(baseline.mainSnapshot, await snapshot(main)).length) throw Error('Main changed since snapshot.');
  for (const name of names) {
    const dest = path.join(pos, 'packages', name);
    if (await exists(dest)) throw Error(`Destination already exists: ${dest}`);
    const source = path.join(main, 'packages', name);
    for (const [rel, expected] of Object.entries(baseline.packageFiles[name])) {
      if (!(rel.startsWith('lib/') || rel === 'pubspec.yaml')) continue;
      if (name === 'trexven_operations' && omitted.includes(path.basename(rel))) continue;
      const bytes = await fs.readFile(path.join(source, rel));
      if (hash(bytes) !== expected) throw Error(`Source changed: ${rel}`);
      const target = path.join(dest, rel);
      if (!inside(pos, target)) throw Error('Destination escaped POS.');
      await fs.mkdir(path.dirname(target), {recursive:true});
      await fs.writeFile(target, bytes, {flag:'wx'});
    }
  }
  for (const file of ['pubspec.yaml','pubspec.lock']) {
    for (const name of names) {
      await replace(path.join(pos,file), `../Trexven/packages/${name}`, `packages/${name}`, 1);
    }
  }
  const packageConfig = path.join(pos, '.dart_tool/package_config.json');
  for (const name of names) {
    await replace(packageConfig, `../../Trexven/packages/${name}`, `../packages/${name}`, 1);
  }
  await replace(path.join(pos,'.idea/libraries/Dart_Packages.xml'),
    '$PROJECT_DIR$/../Trexven/packages/trexven_operations/lib',
    '$PROJECT_DIR$/packages/trexven_operations/lib', 2);
  const barrel = path.join(pos,'packages/trexven_operations/lib/trexven_operations.dart');
  for (const file of omitted) {
    const before = await read(barrel);
    const after = before.replace(new RegExp(`^export 'src/${file.replaceAll('.', '\\.')}';\\r?\\n`, 'm'), '');
    if (before === after) throw Error(`Missing unused export: ${file}`);
    await fs.writeFile(barrel,after);
  }
  await replace(path.join(pos,'packages/trexven_operations/pubspec.yaml'),
    'Trusted operational workflows shared by TREXVEN Owner and POS.',
    'Independent POS-owned operational workflows for TREXVEN POS.', 1);
  await replace(path.join(pos,'packages/trexven_design_system/pubspec.yaml'),
    'Canonical TREXVEN visual foundation for Owner, POS and operational workflows.',
    'Independent POS-owned visual foundation and operational components.', 1);
  console.log('Copied required packages and rewired POS configuration. Main was read-only.');
}
function dynamicConstCalls(text) {
  const out=[];
  for(const m of text.matchAll(/\bconst\s+[A-Z]\w*(?:\.\w+)?\s*\(/g)) {
    const open=m.index+m[0].length-1; let depth=1, quote=null, end=open+1;
    for(;end<text.length&&depth;end++) {
      const c=text[end];
      if(quote){if(c==='\\')end++;else if(c===quote)quote=null;continue;}
      if(c==='"'||c==="'"){quote=c;continue;}
      if(c==='(')depth++;else if(c===')')depth--;
    }
    if(/TrexvenPresentation\.(?!pos\b)/.test(text.slice(open,end)))out.push({index:m.index,line:text.slice(0,m.index).split('\n').length,call:m[0]});
  }
  return out;
}
async function refine() {
  const fixes=[];
  for(const name of names) {
    for(const p of await files(path.join(pos,'packages',name,'lib'))) {
      if(!p.endsWith('.dart'))continue;
      const before=await read(p); const matches=dynamicConstCalls(before); let text=before;
      for(const m of matches.toReversed())text=text.slice(0,m.index)+text.slice(m.index).replace(/^const\s+/,'');
      if(matches.length){await fs.writeFile(p,text);fixes.push({path:slash(path.relative(pos,p)),removedInvalidConstAtLines:matches.map(m=>m.line)});}
    }
  }
  await save(path.join(artifacts,'POS_LOCAL_UI_SOURCE_CORRECTIONS_20261017.json'),fixes);
  console.log(JSON.stringify(fixes,null,2));
}
async function verify() {
  const baseline = JSON.parse(await read(baselineFile));
  const [mainNow,posNow,roots] = await Promise.all([snapshot(main),snapshot(pos),packageRoots(pos)]);
  const mainChanges=changes(baseline.mainSnapshot,mainNow);
  const posChanges=changes(baseline.posSnapshot,posNow);
  const mainDependencies=roots.filter(p=>inside(main,p.resolved));
  const missingImports=[];
  const mainReferences=[];
  const invalidConst=[];
  const localPackages={trexvenpos:pos,...Object.fromEntries(names.map(n=>[n,path.join(pos,'packages',n)]))};
  const allPackages=Object.fromEntries(roots.map(p=>[p.name,p.resolved]));
  const directives=/^[ \t]*(?:import|export|part)\b[^;]*;/gm;
  for (const [name,root] of Object.entries(localPackages)) {
    const sourceFiles=[...await files(path.join(root,'lib')),
      ...await files(path.join(root,'test')),...await files(path.join(root,'integration_test'))];
    for(const p of sourceFiles) {
      if(!p.endsWith('.dart'))continue;
      const text=await read(p);
      for(const m of dynamicConstCalls(text))invalidConst.push({file:slash(path.relative(pos,p)),line:m.line,call:m.call});
      if(/\.\.[/\\]Trexven[/\\]|AndroidStudioProjects[/\\]Trexven[/\\]/i.test(text))mainReferences.push(slash(path.relative(pos,p)));
      for(const directive of text.matchAll(directives)) {
       for(const match of directive[0].matchAll(/['"]([^'"]+)['"]/g)) {
        const uri=match[1]; let target;
        if(uri.startsWith('dart:'))continue;
        if(uri.startsWith('package:')) {
          const [pkg,...rest]=uri.slice(8).split('/');
          if(!allPackages[pkg]){missingImports.push({file:slash(path.relative(pos,p)),uri,reason:'Package absent from resolved configuration'});continue;}
          target=path.join(allPackages[pkg],'lib',...rest);
          if(!localPackages[pkg]){
            if(!await exists(target))missingImports.push({file:slash(path.relative(pos,p)),uri,target});
            continue;
          }
        } else target=path.resolve(path.dirname(p),uri);
        if(!inside(pos,target)||!await exists(target)) missingImports.push({file:slash(path.relative(pos,p)),uri,target});
       }
      }
    }
  }
  const copied=[];
  for(const name of names) {
    const prefix=`packages/${name}/`;
    for(const p of await files(path.join(pos,prefix))) {
      const rel=slash(path.relative(path.join(pos,prefix),p));
      const original=baseline.packageFiles[name][rel];
      copied.push({path:prefix+rel,sha256:hash(await fs.readFile(p)),sourceSha256:original??null});
    }
  }
  const localPaths=[];
  for(const name of ['trexvenpos',...names]) {
    const root=localPackages[name];
    const text=await read(path.join(root,'pubspec.yaml'));
    for(const m of text.matchAll(/^\s+path:\s*["']?([^\r\n"']+)/gm)) {
      const resolved=path.resolve(root,m[1].trim());
      localPaths.push({package:name,path:m[1].trim(),resolved:slash(resolved),insidePos:inside(pos,resolved)});
    }
  }
  const generatedConfigFiles=['.dart_tool/package_config.json','.idea/libraries/Dart_Packages.xml'];
  const generatedConfiguration=[];
  for(const rel of generatedConfigFiles)generatedConfiguration.push({path:rel,sha256:hash(await fs.readFile(path.join(pos,rel)))});
  const physicalOwnership=[];
  for(const name of names){
    const root=path.join(pos,'packages',name);
    const realRoot=await fs.realpath(root);
    const linkedFiles=[];
    for(const p of await files(root)){
      const stat=await fs.lstat(p);
      if(stat.nlink!==1||stat.isSymbolicLink())linkedFiles.push(slash(path.relative(pos,p)));
    }
    physicalOwnership.push({package:name,realRoot:slash(realRoot),insidePos:inside(pos,realRoot),linkedFiles});
  }
  const invalidatedGeneratedMetadata=[
    '.dart_tool/flutter_build/1c4fe3f67683e1b54f98adbcedff32ab/kernel_snapshot_program.stamp',
    '.dart_tool/flutter_build/1c4fe3f67683e1b54f98adbcedff32ab/kernel_snapshot_program.d',
    '.dart_tool/flutter_build/1c4fe3f67683e1b54f98adbcedff32ab/.filecache'];
  const operationalBehaviorDifferences=copied.filter(p=>p.path.endsWith('.dart')&&p.sha256!==p.sourceSha256&&
    p.path!=='packages/trexven_operations/lib/trexven_operations.dart');
  const unexpectedOperationalChanges=[];
  for(const p of operationalBehaviorDifferences){
    const local=await read(path.join(pos,p.path));
    const original=await read(path.join(main,p.path));
    const normalized=original.replace(/\bconst\s+(?=EdgeInsets\.)/g,'');
    if(local.replace(/\bconst\s+(?=EdgeInsets\.)/g,'')!==normalized)unexpectedOperationalChanges.push(p.path);
  }
  const preservedApplicationFiles=Object.keys(baseline.posSnapshot).filter(p=>
    p.startsWith('lib/')&&p!=='lib/src/ui/theme/pos_theme.dart'&&baseline.posSnapshot[p]===posNow[p]);
  const declarationOnlyChanges=[];
  for(const rel of ['pubspec.yaml','pubspec.lock']){
    const restored=(await read(path.join(pos,rel))).replaceAll('packages/trexven_design_system','../Trexven/packages/trexven_design_system')
      .replaceAll('packages/trexven_operations','../Trexven/packages/trexven_operations');
    declarationOnlyChanges.push({path:rel,onlyTwoPathsChanged:hash(Buffer.from(restored))===baseline.posSnapshot[rel]});
  }
  const data={date:new Date().toISOString(),scope:'Static source/dependency inspection; no Flutter commands or runtime tests.',
    mainInspectedFileCount:Object.keys(mainNow).length,mainChanges,posChanges,
    mainDependencies,localPaths,missingImports,mainReferences,invalidConst,copied,
    omittedOwnerOnlyFiles:omitted,
    generatedConfiguration,invalidatedGeneratedMetadata,unexpectedOperationalChanges,physicalOwnership,
    preservedApplicationFiles,declarationOnlyChanges,
    resolvedPackageCount:roots.length,
    validationLimits:['No build','No analyzer','No formatter','No automated tests','No app/emulator launch','No backend calls or mutations'],
  };
  await save(evidenceFile,data);
  console.log(JSON.stringify({mainFiles:data.mainInspectedFileCount,mainChanges,
    modifiedExistingPosFiles:posChanges.filter(p=>p.before).map(p=>p.path),
    addedFiles:posChanges.filter(p=>!p.before).length,mainDependencies,localPaths,missingImports,
    mainReferences,invalidConst,unexpectedOperationalChanges,preservedApplicationFiles:preservedApplicationFiles.length,
    declarationOnlyChanges,physicalOwnership,resolvedPackageCount:roots.length,copiedFiles:copied.length,
    copiedDartFiles:copied.filter(p=>p.path.endsWith('.dart')).length,
    copiedSourceIdentical:copied.filter(p=>p.sha256===p.sourceSha256).length},null,2));
  if(mainChanges.length||mainDependencies.length||missingImports.length||mainReferences.length||invalidConst.length||unexpectedOperationalChanges.length||localPaths.some(p=>!p.insidePos)||declarationOnlyChanges.some(p=>!p.onlyTwoPathsChanged)||physicalOwnership.some(p=>!p.insidePos||p.linkedFiles.length))process.exitCode=1;
}
const mode=process.argv[2];
if(mode==='inspect')await inspect();
else if(mode==='implement')await implement();
else if(mode==='refine')await refine();
else if(mode==='verify')await verify();
else throw Error('Use inspect, implement, or verify. These are source operations, not runtime tests.');
