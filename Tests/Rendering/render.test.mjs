import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';
const require = createRequire(new URL('../../Rendering/package.json', import.meta.url));
const {JSDOM} = require('jsdom');
const browser = new JSDOM('<!doctype html>');
const sandbox = {console, URL, TextEncoder, TextDecoder, document: browser.window.document, DOMParser: browser.window.DOMParser};
// Exercise the actual shipped browser bundle, not only its source modules.
vm.createContext(sandbox);
vm.runInContext(readFileSync(new URL('../../Sources/mdViewer/Resources/markdown-engine.min.js', import.meta.url), 'utf8'), sandbox);
const {render, renderGFM} = sandbox.MarkdownEngine;
const dom = value => JSDOM.fragment(value);
function canonical(value, {syntax = false} = {}) {
  const root = dom(value.trimEnd());
  if (syntax) {
    const walker = root.ownerDocument.createTreeWalker(root, 128 /* SHOW_COMMENT */);
    const comments = [];
    while (walker.nextNode()) comments.push(walker.currentNode);
    comments.forEach(node => node.remove());
    root.normalize();
  }
  // These classes only enable app styling; they do not change the GFM tree.
  root.querySelectorAll('.contains-task-list,.task-list-item').forEach(n => {
    n.classList.remove('contains-task-list', 'task-list-item');
    if (!n.className) n.removeAttribute('class');
  });
  // HTML serializers differ in quoting, void tags and insignificant inter-block whitespace.
  function node(n, pre = false) {
    if (n.nodeType === 8) return syntax ? null : ['comment', n.data];
    if (n.nodeType === 3) return pre || n.data.trim() ? n.data : null;
    if (n.nodeType === 11) return [...n.childNodes].map(c => node(c, pre)).filter(n => n !== null);
    const attrs = [...n.attributes].filter(a => !(syntax && a.name === 'rel' && a.value === 'nofollow')).map(a => [a.name, a.value]).sort((a,b) => a[0].localeCompare(b[0]));
    return [n.tagName, attrs, [...n.childNodes].map(c => node(c, pre || n.tagName === 'PRE')).filter(n => n !== null)];
  }
  return JSON.stringify(node(root));
}
const github = JSON.parse(readFileSync(new URL('./github-rendering.json', import.meta.url), 'utf8'));
assert.ok(github.fetchedAt && github.cases.length >= 12, 'Recorded live GitHub responses loaded');
const overrides = new Map(github.cases.filter(item => typeof item.example === 'number').map(item => [item.example, item]));
assert.equal(overrides.size, 12, 'All twelve previously reported cases covered');
for (const item of github.cases) {
  const actual = render(item.source);
  if (item.example === 'comment-fenced-code') {
    // GitHub adds its own syntax-highlighter wrappers. The native preview
    // highlights after the engine runs; here compare preserved code content.
    assert.equal(dom(actual).querySelector('pre code').textContent.replace(/\n$/, ''), dom(item.expected).querySelector('pre').textContent.replace(/\n$/, ''));
  } else {
    assert.equal(canonical(actual), canonical(item.expected), `Live GitHub rendering: ${item.example}`);
  }
}
console.log(`${github.cases.length}/${github.cases.length} live GitHub rendering snapshots match (including all 12 former differences)`);

const cases = JSON.parse(readFileSync(new URL('./gfm-official.json', import.meta.url), 'utf8'));
assert.equal(cases.length, 677, 'Pinned official GFM corpus loaded');
for (const item of cases) {
  const source = item.source.replaceAll('→', '\t');
  // The 2019 document's base CommonMark examples do not consistently apply
  // GFM extensions. Current GitHub responses take precedence for those cases.
  const expected = (overrides.get(item.example)?.expected ?? item.expected).replaceAll('→', '\t');
  assert.doesNotThrow(() => render(source), `Production renderer: example ${item.example}`);
  assert.equal(canonical(renderGFM(source), {syntax: true}), canonical(expected, {syntax: true}), `GFM syntax: example ${item.example}`);
}
console.log('677/677 reference cases match (665 original expectations + 12 current GitHub expectations)');

const features = [
  ['headings and duplicate anchors', '# Hello\n\n# Hello\n\nعنوان\n===', r => r.querySelector('#hello') && r.querySelector('#hello-1') && r.querySelectorAll('h1').length === 3],
  ['nested and ordered task lists', '1. [x] done\n2. [ ] todo\n   - [X] nested', r => r.querySelectorAll('input[disabled]').length === 3 && r.querySelectorAll('input[checked]').length === 2],
  ['tasks inside code are literal', '```md\n- [x] sample\n```\n\n`- [ ] literal`', r => !r.querySelector('input') && r.querySelector('pre code').textContent.includes('- [x]')],
  ['tables and alignment', '| left | right | center |\n| :--- | ---: | :---: |\n| a \\| b | **bold** | `code` |', r => r.querySelector('th[align=right]') && r.querySelector('th[align=center]') && r.querySelector('strong') && r.textContent.includes('a | b')],
  ['autolinks and strike', 'https://example.com www.example.com a@example.com ~~gone~~', r => r.querySelectorAll('a').length === 3 && r.querySelector('del')],
  ['soft and hard breaks', 'soft\nline\n\nhard  \nline\n\nslash\\\nline', r => r.querySelectorAll('br').length === 2],
  ['references, escapes, entities', '[link][id] ![alt][pic] \\*literal\\* &copy;\n\n[id]: https://example.com "Title"\n[pic]: image.png', r => r.querySelector('a[title=Title]') && r.querySelector('img[src="image.png"]') && r.textContent.includes('*literal* ©')],
  ['footnotes', 'Text[^n] again[^n]\n\n[^n]: Footnote **bold**', r => r.querySelector('[data-footnotes]') && r.querySelectorAll('[data-footnote-ref]').length === 2 && r.querySelector('[data-footnote-backref]') && [...r.querySelectorAll('a[href^="#"]')].every(a => r.querySelector(`[id="${a.getAttribute('href').slice(1)}"]`))],
  ['details and HTML', '<details>\n<summary>More</summary>\n\n**inside**\n\n</details>\n\n<kbd>⌘</kbd> <sup>2</sup> <sub>i</sub>', r => r.querySelector('details summary') && r.querySelector('details strong') && r.querySelector('kbd') && r.querySelector('sup') && r.querySelector('sub')],
  ['five alert kinds', ['NOTE','TIP','IMPORTANT','WARNING','CAUTION'].map(k => `> [!${k}]\n> **Message**`).join('\n\n'), r => r.querySelectorAll('.markdown-alert').length === 5 && r.querySelectorAll('.markdown-alert strong').length === 5],
  ['emoji', ':smile: :+1: :unknown_name:', r => r.textContent.includes('😄') && r.textContent.includes('👍') && r.textContent.includes(':unknown_name:')],
  ['math delimiters and math fences', '$x^2$ and $`a_b`$\n\n$$\n\\frac{1}{2}\n$$\n\n```math\n\\sqrt{4}\n```', r => r.querySelectorAll('math').length === 4 && r.querySelectorAll('math[display=block]').length === 2 && !r.querySelectorAll('math')[1].textContent.includes('`')],
  ['code language and mermaid source', '```swift\nlet x = 1\n```\n\n```mermaid\ngraph TD\n A --> B\n```', r => r.querySelector('code.language-swift') && r.querySelector('code.language-mermaid')],
  ['unsafe HTML removed', '<script>window.pwned=true</script>\n\n<img src="x" onerror="alert(1)"><a href="javascript:alert(1)">x</a><iframe src="https://example.com"></iframe>', r => !r.querySelector('script,iframe,[onerror],a[href]')],
];
for (const [name, source, check] of features) {
  assert.ok(check(dom(render(source))), name);
  console.log(`PASS ${name}`);
}
console.log(`${features.length} feature/regression tests passed`);
