// Run the bundled converter's actual script with lightweight controls.
// HTML/DOM conversion is covered separately in the app's WebKit dialog.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const html = fs.readFileSync(__dirname + '/../Resources/markdown2text.html', 'utf8');
const elements = {};
for (const match of html.matchAll(/<(input|select|textarea|button)\b([^>]*\bid="([^"]+)"[^>]*)>([\s\S]*?)(?=<\/(?:select|textarea|button)>|<)/g)) {
  const [, tag, attrs, id] = match;
  elements[id] = {value: (attrs.match(/value="([^"]*)"/) || [,''])[1], checked: /\bchecked\b/.test(attrs), type: /type="checkbox"/.test(attrs) ? 'checkbox' : tag, style: {}, addEventListener() {}, focus() {}};
}
for (const match of html.matchAll(/<select\b[^>]*id="([^"]+)"[^>]*>([\s\S]*?)<\/select>/g)) {
 const options = [...match[2].matchAll(/<option value="([^"]*)"([^>]*)>/g)];
 elements[match[1]].value = (options.find(x=>x[2].includes('selected')) || options[0])[1];
}
const messages=[];
const context = vm.createContext({document:{getElementById:id=>elements[id]}, window:{webkit:{messageHandlers:{markdownText:{postMessage:m=>messages.push(m)}}}}, setTimeout(){}});
vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1],context);
const convert=s=>context.convert(s);
assert.equal(convert('## 見出し\n\n**本文**'), '■ 見出し\n\n本文');
assert.equal(convert('- 一つ\n  - 二つ'), '・一つ\n　・二つ');
assert.equal(convert('[公式](https://example.com)'), '公式 <https://example.com>');
assert.equal(convert('| A | B |\n| --- | --- |\n| 1 | 2 |'), 'A\tB\n1\t2');
elements.boldMode.value='bracket';
assert.equal(convert('**強調**'), '【強調】');
elements.numMode.value='renumber';
assert.equal(convert('3. A\n9. B'), '1. A\n2. B');
elements.imgMode.value='ignore';
assert.equal(convert('![alt](image.png)'), '');
elements.h2m.value='rule';
assert.ok(convert('## 見出し').includes('◤'));
assert.ok(messages.some(m=>m.action==='settings'));
console.log('Markdown text converter: 9 checks passed');
