const fs = require('fs');
const path = require('path');
const { marked } = require(path.join(process.env.HOME, '.snowflake/cortex/skills/md-to-pdf/node_modules/marked'));

// Parse args
const args = process.argv.slice(2);
const getArg = (name) => { const i = args.indexOf(name); return i !== -1 ? args[i + 1] : null; };
const inputFile = getArg('--input');
const outputFile = getArg('--output');
const title = getArg('--title') || 'Document';
const subtitle = getArg('--subtitle') || '';
const date = getArg('--date') || new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
const classification = getArg('--classification') || 'Internal';
const compact = args.includes('--compact');
const noCover = args.includes('--no-cover');

if (!inputFile || !outputFile) { console.error('Usage: --input <file.md> --output <file.pdf>'); process.exit(1); }

const md = fs.readFileSync(inputFile, 'utf8');
const inputDir = path.dirname(path.resolve(inputFile));
let htmlBody = marked(md);

// Inline local SVG images so they render in Puppeteer (no file:// access)
htmlBody = htmlBody.replace(/<img\s+src="([^"]+\.svg)"[^>]*>/gi, (match, src) => {
  const svgPath = path.resolve(inputDir, src);
  if (fs.existsSync(svgPath)) {
    const svgContent = fs.readFileSync(svgPath, 'utf8');
    return `<div class="inline-svg">${svgContent}</div>`;
  }
  return match;
});

const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
@page { size: letter; margin: ${compact ? '0.5in' : '0.75in'}; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif; font-size: ${compact ? '10pt' : '11pt'}; line-height: ${compact ? '1.4' : '1.6'}; color: #1a1a2e; margin: 0; padding: 0; }

/* Cover Page */
.cover { page-break-after: always; display: flex; flex-direction: column; justify-content: center; align-items: center; min-height: 100vh; background: linear-gradient(135deg, #0A1428 0%, #11567F 50%, #29B5E8 100%); color: white; text-align: center; padding: 2in; margin: -0.75in; margin-bottom: 0; }
.cover h1 { font-size: 32pt; font-weight: 700; margin: 0 0 0.3em; letter-spacing: -0.5px; color: #FFFFFF; }
.cover .subtitle { font-size: 16pt; font-weight: 300; color: #FFFFFF; margin-bottom: 1.5em; }
.cover .meta { font-size: 11pt; color: #FFFFFF; margin-top: 2em; }
.cover .classification { display: inline-block; border: 1px solid rgba(255,255,255,0.7); padding: 4px 16px; border-radius: 4px; font-size: 10pt; margin-top: 1em; text-transform: uppercase; letter-spacing: 1px; color: #FFFFFF; }

/* Content */
.content { padding-top: 0.5in; }
h1 { font-size: 20pt; color: #11567F; border-bottom: 3px solid #29B5E8; padding-bottom: 8px; margin-top: 1.5em; ${compact ? '' : 'page-break-before: always;'} }
h1:first-child { page-break-before: avoid; }
h2 { font-size: 16pt; color: #11567F; margin-top: ${compact ? '0.8em' : '1.3em'}; }
h3 { font-size: 13pt; color: #1A3A5C; margin-top: ${compact ? '0.6em' : '1.1em'}; }
h4 { font-size: 11pt; color: #11567F; font-weight: 600; }

/* Tables */
table { border-collapse: collapse; width: 100%; margin: ${compact ? '0.5em 0' : '1em 0'}; font-size: ${compact ? '9pt' : '10pt'}; }
thead th { background: #11567F; color: white; padding: 8px 12px; text-align: left; font-weight: 600; }
tbody td { padding: 7px 12px; border-bottom: 1px solid #E8F6FD; }
tbody tr:nth-child(even) { background: #F8FCFE; }
tbody tr:hover { background: #EBF5FB; }

/* Code */
pre { background: #1a1a2e; color: #e0e0e0; padding: 16px; border-radius: 6px; overflow-x: auto; font-size: 9.5pt; line-height: 1.5; page-break-inside: avoid; }
code { font-family: 'SF Mono', 'Fira Code', Consolas, monospace; font-size: 9.5pt; }
p code, li code { background: #EBF5FB; color: #11567F; padding: 2px 6px; border-radius: 3px; }

/* Blockquotes */
blockquote { border-left: 4px solid #29B5E8; margin: 1em 0; padding: 0.5em 1em; background: #F2FAFE; color: #11567F; }

/* Lists */
ul, ol { padding-left: 1.5em; }
li { margin-bottom: 0.3em; }

/* Links */
a { color: #29B5E8; text-decoration: none; }

/* Images / SVG references */
img { max-width: 100%; height: auto; margin: 1em 0; }
.inline-svg { width: 100%; margin: 1em 0; page-break-inside: avoid; }
.inline-svg svg { width: 100%; height: auto; }

/* Horizontal rules */
hr { border: none; border-top: 2px solid #E8F6FD; margin: 2em 0; }

/* Print */
@media print {
  body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .cover { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  pre { white-space: pre-wrap; word-wrap: break-word; }
}
</style>
</head>
<body>
${noCover ? '' : `<div class="cover">
  <h1>${title}</h1>
  <div class="subtitle">${subtitle}</div>
  <div class="meta">${date}</div>
  <div class="classification">${classification}</div>
</div>`}
<div class="content">
${htmlBody}
</div>
</body>
</html>`;

// Write HTML
const htmlOut = outputFile.replace(/\.pdf$/, '.html');
fs.writeFileSync(htmlOut, html);
console.log('HTML written:', htmlOut);

// Generate PDF with Puppeteer
(async () => {
  const puppeteer = require(path.join(process.env.HOME, '.snowflake/cortex/skills/md-to-pdf/node_modules/puppeteer'));
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.pdf({
    path: outputFile,
    format: 'Letter',
    printBackground: true,
    margin: { top: '0.75in', bottom: '0.75in', left: '0.75in', right: '0.75in' }
  });
  await browser.close();
  const stats = fs.statSync(outputFile);
  console.log('PDF written:', outputFile, `(${(stats.size / 1024).toFixed(0)} KB)`);
})();
