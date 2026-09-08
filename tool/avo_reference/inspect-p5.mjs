import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const source = readFileSync(fileURLToPath(new URL('../../../avo/lib/p5.min.js', import.meta.url)), 'utf8');
const markers = ['key:"endShape"', '.prototype.endShape=function', '.prototype.curveVertex=function', '.prototype.noise=function', '.prototype.noiseSeed=function', 'key:"curveVertex"'];
const excerpts = markers.flatMap(marker => {
  const chunks = [];
  let from = 0;
  for (;;) {
    const at = source.indexOf(marker, from);
    if (at < 0) break;
    chunks.push(`${marker} at byte ${at}\n${source.slice(at, at + 12000).replaceAll(';', ';\n')}`);
    from = at + marker.length;
  }
  return chunks;
});
writeFileSync(fileURLToPath(new URL('./p5-excerpts.txt', import.meta.url)), excerpts.join('\n\n'));
console.log('Extracted p5 source excerpts');
