import {htmlText} from 'micromark-core-commonmark';

// cmark-gfm rejects inline HTML comments whose content ends in a dash.
// Reject at tokenization time so Markdown inside the invalid comment is still
// parsed normally. Block HTML has separate rules and must remain unaffected.
export default function githubHTMLSyntax() {
  const data = this.data();
  (data.micromarkExtensions ||= []).push({
    disable: {null: ['htmlText']},
    text: {60: {name: 'githubHtmlText', tokenize(effects, ok, nok) {
      return effects.check(invalidComment, nok, htmlText.tokenize.call(this, effects, ok, nok));
    }}},
  });
}

const invalidComment = {partial: true, tokenize(effects, ok, nok) {
  let prefix = 0;
  let tail = '';
  let length = 0;
  return start;
  function start(code) {
    if (code !== '<!--'.charCodeAt(prefix)) return nok(code);
    effects.consume(code);
    prefix++;
    tail += String.fromCharCode(code);
    length++;
    return prefix === 4 ? body : start;
  }
  function body(code) {
    if (code === null) return nok(code);
    tail = (tail + (code < 0 ? '\n' : String.fromCharCode(code))).slice(-4);
    length++;
    effects.consume(code);
    return tail.endsWith('-->') ? finish : body;
  }
  function finish(code) {
    return tail === '--->' && length !== 7 ? ok(code) : nok(code);
  }
}};
