import {unified} from 'unified';
import remarkParse from 'remark-parse';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import remarkGemoji from 'remark-gemoji';
import remarkRehype from 'remark-rehype';
import rehypeRaw from 'rehype-raw';
import rehypeSanitize, {defaultSchema} from 'rehype-sanitize';
import rehypeSlug from 'rehype-slug';
import rehypeKatex from 'rehype-katex';
import rehypeStringify from 'rehype-stringify';
import {visit} from 'unist-util-visit';
import githubHTMLSyntax from './github-html.js';

function githubHTMLFilter() {
  return tree => {
    visit(tree, 'html', node => {
      node.value = node.value.replace(/(<!--[\s\S]*?-->)|<(\/?(?:title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext))(?=[\s/>])/gi,
        (match, comment, tag) => comment || '&lt;' + tag);
    });
  };
}

function protocolAutolinks() {
  return tree => {
    visit(tree, node => Array.isArray(node.children), parent => {
      for (let i = 1; i < parent.children.length; i++) {
        const previous = parent.children[i - 1], link = parent.children[i], next = parent.children[i + 1];
        if (previous.type !== 'text' || link.type !== 'link' || !link.url.startsWith('mailto:') || link.children.length !== 1 || link.children[0].type !== 'text') continue;
        const match = /(?:^|\s)(mailto|xmpp):$/.exec(previous.value);
        if (!match) continue;
        const prefix = match[1] + ':';
        previous.value = previous.value.slice(0, -prefix.length);
        link.children[0].value = prefix + link.children[0].value;
        link.url = prefix + link.url.slice(7);
        if (match[1] === 'xmpp' && next?.type === 'text') {
          const resource = /^\/[^\s/]+/.exec(next.value)?.[0]?.replace(/[.,!?;:]+$/, '');
          if (resource) {
            link.url += resource;
            link.children[0].value += resource;
            next.value = next.value.slice(resource.length);
          }
        }
      }
    });
  };
}

function githubExtensions() {
  return (tree) => {
    visit(tree, ['math', 'inlineMath'], node => {
      // GitHub also accepts $`expression`$ to avoid Markdown conflicts.
      if (node.type === 'inlineMath' && node.value.startsWith('`') && node.value.endsWith('`')) {
        node.value = node.value.slice(1, -1);
        node.data.hChildren = [{type: 'text', value: node.value}];
      }
    });
    visit(tree, 'blockquote', node => {
      const paragraph = node.children[0];
      const text = paragraph?.type === 'paragraph' && paragraph.children[0];
      if (text?.type !== 'text') return;
      const match = /^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:\n|$)/.exec(text.value);
      if (!match) return;
      text.value = text.value.slice(match[0].length);
      const kind = match[1].toLowerCase();
      node.data = {hName: 'div', hProperties: {className: ['markdown-alert', `markdown-alert-${kind}`]}};
      node.children.unshift({type: 'paragraph', data: {hProperties: {className: ['markdown-alert-title']}},
        children: [{type: 'text', value: kind[0].toUpperCase() + kind.slice(1)}]});
    });
  };
}

function githubHTMLAttributes() {
  return tree => {
    const ids = new Set();
    visit(tree, 'element', node => { if (node.properties.id) ids.add(node.properties.id); });
    visit(tree, 'element', node => {
      if (node.tagName === 'code') node.properties.className = [...(node.properties.className || []), 'notranslate'];
      const href = node.properties.href;
      if (node.tagName === 'a' && typeof href === 'string' && /^(?:https?:)?\/\//i.test(href)) node.properties.rel = ['nofollow'];
      if (typeof href === 'string' && href.startsWith('#')) {
        // Footnote labels can contain percent-encoded text, so try the exact
        // serialized identifier before decoding ordinary heading links.
        const raw = href.slice(1);
        let decoded = raw;
        try { decoded = decodeURIComponent(raw); } catch (_) {}
        const id = [raw, decoded, 'user-content-' + raw, 'user-content-' + decoded].find(id => ids.has(id));
        if (id) node.properties.href = '#' + id;
      }
      for (const attr of ['ariaDescribedBy', 'ariaLabelledBy']) {
        if (node.properties[attr]) node.properties[attr] = node.properties[attr].map(id => ids.has(id) ? id : 'user-content-' + id);
      }
    });
  };
}

// Sanitize user HTML before trusted math/heading transforms add their markup.
const schema = {
  ...defaultSchema,
  protocols: {...defaultSchema.protocols, href: [...defaultSchema.protocols.href, 'xmpp']},
  attributes: {
    ...defaultSchema.attributes,
    code: [...defaultSchema.attributes.code, ['className', /^language-./, 'math-inline', 'math-display']],
    div: [...(defaultSchema.attributes.div || []), ['className', /^markdown-alert(?:-|$)/]],
    p: [...(defaultSchema.attributes.p || []), ['className', 'markdown-alert-title']],
    '*': [...defaultSchema.attributes['*'], 'dir'],
  },
};

const renderer = unified()
  .use(remarkParse).use(githubHTMLSyntax).use(remarkGfm).use(protocolAutolinks).use(githubHTMLFilter)
  .use(remarkMath).use(remarkGemoji).use(githubExtensions)
  .use(remarkRehype, {allowDangerousHtml: true}).use(rehypeRaw)
  .use(rehypeSanitize, schema).use(rehypeSlug).use(githubHTMLAttributes)
  .use(rehypeKatex, {output: 'mathml', throwOnError: false, trust: false, strict: 'ignore'})
  .use(rehypeStringify);
export function render(source) { return String(renderer.processSync(source)); }

// Parsing conformance is measured before HTML postprocessing/sanitization.
const gfm = unified().use(remarkParse).use(githubHTMLSyntax).use(remarkGfm)
  .use(protocolAutolinks).use(githubHTMLFilter)
  .use(remarkRehype, {allowDangerousHtml: true})
  .use(rehypeStringify, {allowDangerousHtml: true});
export function renderGFM(source) { return String(gfm.processSync(source)); }
