// Runs the original JavaScript converter (reference-markdown2text.html) with the given options.
import fs from 'node:fs';
const [,, htmlPath, mdPath, optionsJSON] = process.argv;
const html = fs.readFileSync(htmlPath, 'utf8');
const script = html.slice(html.indexOf('<script>') + 8, html.indexOf('function update()'));
const opts = JSON.parse(optionsJSON);
const defaults = { linkMode:'angle', boldMode:'none', tableMode:'tab', stripHtml:true, optTrimBlank:true, optTrimLeading:true,
  optCollapseBlank:true, optZenkakuIndent:true, optLinkBelow:true, listMarker:'・', numMode:'keep', blockGap:'1', imgMode:'text',
  h1p:'', h2p:'■', h3p:'●', h4p:'◇', h5p:'', h6p:'', h1m:'prefix', h2m:'prefix', h3m:'prefix', h4m:'prefix', h5m:'prefix', h6m:'prefix' };
const values = { ...defaults, ...opts };
const element = (id) => {
  const v = values[id];
  return typeof v === 'boolean' ? { checked: v, type: 'checkbox' } : { value: v ?? '', type: 'text' };
};
const document = { getElementById: element };
const convert = new Function('document', script + '\nreturn convert;')(document);
process.stdout.write(convert(fs.readFileSync(mdPath, 'utf8')));
