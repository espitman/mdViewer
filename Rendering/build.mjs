import {build} from 'esbuild';
import {readFile, writeFile} from 'node:fs/promises';
await build({entryPoints: ['renderer.js'], bundle: true, minify: true, format: 'iife', globalName: 'MarkdownEngine',
  platform: 'browser', target: 'safari17', outfile: '../Sources/mdViewer/Resources/markdown-engine.min.js', legalComments: 'eof'});
// Inline script elements must never be terminated by bundled text.
const path = '../Sources/mdViewer/Resources/markdown-engine.min.js';
await writeFile(path, (await readFile(path, 'utf8')).replace(/<\/script/gi, '<\\/script'));

// Keep full upstream license texts beside the redistributed bundle.
import {readdir} from 'node:fs/promises';
const lock = JSON.parse(await readFile('package-lock.json', 'utf8'));
const notices = ['MD Viewer bundled Markdown engine — third-party notices\n'];
for (const [directory, entry] of Object.entries(lock.packages).sort()) {
  if (!directory || entry.dev) continue;
  const pkg = JSON.parse(await readFile(`${directory}/package.json`, 'utf8'));
  notices.push(`\n=== ${pkg.name}@${pkg.version} (${pkg.license || 'see license below'}) ===\n`);
  const files = (await readdir(directory)).filter(name => /^(licen[sc]e|copying|notice)(\.|$)/i.test(name)).sort();
  for (const file of files) notices.push(await readFile(`${directory}/${file}`, 'utf8'));
}
await writeFile('../Sources/mdViewer/Resources/markdown-engine-LICENSES.txt', notices.join('\n'));
