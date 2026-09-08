#!/usr/bin/env node
/** Compare original p5 PNGs with exported native Flutter PNGs, without a server. */
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createCanvas, loadImage } from '@napi-rs/canvas';

const flutterRoot = new URL('../../', import.meta.url);
const fixtureDir = new URL('test/shared/fixtures/', flutterRoot);
const outputDir = new URL('build/avo_comparison/', flutterRoot);
const fixture = JSON.parse(readFileSync(new URL('avo_reference.json', fixtureDir), 'utf8'));
const background = { hex: '#101214', rgb: [16, 18, 20] };
const thresholds = { meanChannelError: 0.5, outlierCoverage: 0.001, outlierChannelError: 24 };
const styles = ['blob', 'ring', 'wave'];
const states = ['idle', 'voice', 'pointer', 'pop', 'pet'];
const scenes = [];
const images = new Map();

async function decode(url) {
  const image = await loadImage(readFileSync(url));
  const canvas = createCanvas(image.width, image.height);
  const context = canvas.getContext('2d');
  context.drawImage(image, 0, 0);
  // Canvas getImageData returns straight/unassociated RGBA. Unlike Flutter's
  // rawRgba format, RGB values here have not already been multiplied by alpha.
  const pixels = context.getImageData(0, 0, image.width, image.height).data;
  return { image, pixels };
}
function compare(reference, actual) {
  const sums = [0, 0, 0];
  let outlierPixels = 0;
  let maximumChannelError = 0;
  for (let pixel = 0; pixel < reference.length; pixel += 4) {
    const referenceAlpha = reference[pixel + 3] / 255;
    const actualAlpha = actual[pixel + 3] / 255;
    let pixelMaximum = 0;
    for (let channel = 0; channel < 3; channel++) {
      const expected = reference[pixel + channel] * referenceAlpha +
        background.rgb[channel] * (1 - referenceAlpha);
      const observed = actual[pixel + channel] * actualAlpha +
        background.rgb[channel] * (1 - actualAlpha);
      const delta = Math.abs(expected - observed);
      sums[channel] += delta;
      pixelMaximum = Math.max(pixelMaximum, delta);
    }
    if (pixelMaximum > thresholds.outlierChannelError) outlierPixels++;
    maximumChannelError = Math.max(maximumChannelError, pixelMaximum);
  }
  const pixelCount = reference.length / 4;
  const meanByChannel = sums.map(sum => sum / pixelCount);
  const meanChannelError = sums.reduce((a, b) => a + b, 0) / (pixelCount * 3);
  const outlierCoverage = outlierPixels / pixelCount;
  return {
    meanChannelError, meanByChannel, maximumChannelError,
    outlierPixels, pixelCount, outlierCoverage,
    pass: meanChannelError < thresholds.meanChannelError &&
      outlierCoverage < thresholds.outlierCoverage,
  };
}

for (const scene of fixture.scenes) {
  const [reference, actual] = await Promise.all([
    decode(new URL(scene.png, fixtureDir)),
    decode(new URL(`${scene.id}.png`, outputDir)),
  ]);
  assert.equal(reference.image.width, actual.image.width, `${scene.id}: width mismatch`);
  assert.equal(reference.image.height, actual.image.height, `${scene.id}: height mismatch`);
  scenes.push({ id: scene.id, width: reference.image.width, height: reference.image.height,
    ...compare(reference.pixels, actual.pixels) });
  images.set(scene.id, { reference: reference.image, actual: actual.image });
}

const tileSize = 256;
const labelHeight = 34;
const headerHeight = 44;
const sheet = createCanvas(tileSize * 6, headerHeight + (tileSize + labelHeight) * states.length);
const context = sheet.getContext('2d');
context.fillStyle = background.hex;
context.fillRect(0, 0, sheet.width, sheet.height);
context.fillStyle = '#e7edf2';
context.font = '18px sans-serif';
context.fillText('Original p5 / native Flutter  |  t = 0.8  |  random & noise seed = 12345', 14, 28);
for (let row = 0; row < states.length; row++) {
  for (let style = 0; style < styles.length; style++) {
    const id = `${styles[style]}_${states[row]}`;
    const pair = images.get(id);
    if (!pair) continue;
    for (let native = 0; native < 2; native++) {
      const x = (style * 2 + native) * tileSize;
      const y = headerHeight + row * (tileSize + labelHeight);
      context.drawImage(native ? pair.actual : pair.reference, x, y, tileSize, tileSize);
      context.fillStyle = native ? '#a8d8fb' : '#e7edf2';
      context.font = '14px sans-serif';
      context.fillText(`${id} · ${native ? 'Flutter' : 'p5 reference'}`, x + 12, y + tileSize + 22);
    }
  }
}

const worstMean = scenes.reduce((worst, value) => value.meanChannelError > worst.meanChannelError ? value : worst);
const worstOutliers = scenes.reduce((worst, value) => value.outlierCoverage > worst.outlierCoverage ? value : worst);
const metrics = {
  schemaVersion: 1,
  background,
  description: 'Mean absolute RGB channel errors in 0..255 units after straight-RGBA compositing over the background; outliers are pixels where any composited channel differs by >24.',
  thresholds,
  reference: 'Original Creature and complete bundled p5 runtime; see test/shared/fixtures/avo_reference.json',
  native: 'build/avo_comparison/{scene}.png from flutter test --dart-define=AVO_EXPORT=true test/shared/widgets/avo_reference_test.dart',
  contactSheet: 'build/avo_comparison/contact_sheet.png',
  contactSheetLayout: 'Five rows: idle, voice, pointer, pop, pet. Six columns: blob p5, blob Flutter, ring p5, ring Flutter, wave p5, wave Flutter.',
  scenes,
  summary: {
    sceneCount: scenes.length,
    passed: scenes.filter(scene => scene.pass).length,
    failed: scenes.filter(scene => !scene.pass).map(scene => scene.id),
    maximumMean: { id: worstMean.id, value: worstMean.meanChannelError },
    maximumOutlierCoverage: { id: worstOutliers.id, value: worstOutliers.outlierCoverage },
  },
};
mkdirSync(outputDir, { recursive: true });
writeFileSync(new URL('contact_sheet.png', outputDir), sheet.toBuffer('image/png'));
writeFileSync(new URL('metrics.json', outputDir), JSON.stringify(metrics, null, 2) + '\n');
console.table(scenes.map(scene => ({
  scene: scene.id,
  mean: scene.meanChannelError.toFixed(6),
  'outliers >24': `${(scene.outlierCoverage * 100).toFixed(4)}%`,
  pass: scene.pass,
})));
console.log(JSON.stringify(metrics.summary, null, 2));
console.log(`Contact sheet: ${fileURLToPath(new URL('contact_sheet.png', outputDir))}`);
console.log(`Metrics: ${fileURLToPath(new URL('metrics.json', outputDir))}`);
if (metrics.summary.failed.length) process.exitCode = 1;
