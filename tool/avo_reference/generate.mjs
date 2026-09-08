#!/usr/bin/env node
/** Execute the original Avo class and complete bundled p5.js; no drawing/noise formulas are copied. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createCanvas } from '@napi-rs/canvas';
import { JSDOM } from 'jsdom';

const here = new URL('./', import.meta.url);
const flutterRoot = new URL('../../', here);
const referenceRoot = new URL('../../../avo/', here);
const jsonPath = fileURLToPath(new URL('test/shared/fixtures/avo_reference.json', flutterRoot));
const imageDir = new URL('test/shared/fixtures/avo_reference/', flutterRoot);
const avoSource = readFileSync(new URL('js/avo.js', referenceRoot), 'utf8');
const p5Source = readFileSync(new URL('lib/p5.min.js', referenceRoot), 'utf8');
const sha256 = value => createHash('sha256').update(value).digest('hex');
const clone = value => JSON.parse(JSON.stringify(value));
const seed = 12345;
const width = 256;
const bodySize = width * 0.62;
const time = 0.8;

// JSDOM supplies the DOM only. Every actual 2D operation runs on Skia through
// @napi-rs/canvas, with a Proxy observing calls to the actual Canvas context.
const dom = new JSDOM('<!doctype html><html><body></body></html>', {
  runScripts: 'outside-only', pretendToBeVisual: true, url: 'https://avo-reference.invalid/',
});
const { window } = dom;
const canvases = new WeakMap();
const canvasProto = window.HTMLCanvasElement.prototype;
const serializable = value => typeof value === 'number' || typeof value === 'string' ||
  typeof value === 'boolean' || value === null ? value : String(value);
function backing(element) {
  let entry = canvases.get(element);
  if (entry) return entry;
  const canvas = createCanvas(element.width || 300, element.height || 150);
  const context = canvas.getContext('2d');
  entry = { canvas, context, recording: false, commands: [] };
  entry.proxy = new Proxy(context, {
    get(target, property) {
      const value = Reflect.get(target, property, target);
      if (typeof value !== 'function') return value;
      return (...args) => {
        if (entry.recording) entry.commands.push([String(property), ...args.map(serializable)]);
        return Reflect.apply(value, target, args);
      };
    },
    set(target, property, value) {
      if (entry.recording) entry.commands.push(['set', String(property), serializable(value)]);
      return Reflect.set(target, property, value, target);
    },
  });
  canvases.set(element, entry);
  return entry;
}
for (const dimension of ['width', 'height']) {
  const descriptor = Object.getOwnPropertyDescriptor(canvasProto, dimension);
  Object.defineProperty(canvasProto, dimension, {
    ...descriptor,
    set(value) {
      descriptor.set.call(this, value);
      const entry = canvases.get(this);
      if (entry) entry.canvas[dimension] = descriptor.get.call(this);
    },
  });
}
canvasProto.getContext = function (kind) {
  if (kind !== '2d') throw new Error(`Unexpected Canvas context: ${kind}`);
  return backing(this).proxy;
};
canvasProto.toDataURL = function (...args) { return backing(this).canvas.toDataURL(...args); };

window.eval(p5Source);
window.p5.disableFriendlyErrors = true;
// The sole Avo instrumentation adds an export at the IIFE boundary. The class,
// hash function, state updates, geometry, and every renderer method stay intact.
const marker = 'global.Avo = {';
assert.equal(avoSource.split(marker).length, 2, 'Avo export marker must be unique');
window.eval(avoSource.replace(marker,
  'global.__avoReference = { Creature, hashString };\n' + marker));
const { Creature, hashString } = window.__avoReference;
const p = await new Promise((resolve, reject) => {
  new window.p5(instance => {
    instance.setup = () => {
      try {
        instance.pixelDensity(1);
        instance.createCanvas(width, width);
        instance.noLoop();
        resolve(instance);
      } catch (error) { reject(error); }
    };
    instance.draw = () => {};
  });
});
const surface = backing(p.canvas);

// Only Math.random is replaced. p5.noiseSeed remains its original implementation
// and has its own independent LCG/table. Reset random after p5 initialization so
// setup internals cannot consume Creature's deterministic stream.
function resetRandom(randomSeed = seed) {
  let state = randomSeed >>> 0;
  window.Math.random = () => {
    state = (1664525 * state + 1013904223) % 4294967296;
    return state / 4294967296;
  };
}
function personality(name, variant = 0) {
  resetRandom();
  const c = new Creature({ name, variant });
  const s = c.seed;
  return {
    name, variant, hashInput: (name || 'guest') + '#' + (variant | 0),
    seed: s, signedSeed: s | 0,
    shifts: { '3': s >> 3, '6': s >> 6, '9': s >> 9, '12': s >> 12 },
    remainders: { orbiters: (s >> 3) % 7, squish: (s >> 6) % 30,
      eyeGap: (s >> 9) % 14, eyeSize: (s >> 12) % 8 },
    lobes: c.lobes, orbiters: c.orbiters, squish: c.squish,
    eyeGap: c.eyeGap, eyeSize: c.eyeSize, noiseOff: c.noiseOff,
    nextBlink: c.nextBlink,
  };
}
const personalities = [personality('Han'), personality('guest'), personality('Han', 1),
  personality('Han', -1), personality('张三'), personality('😀'), personality('')];
assert.equal(personalities[0].seed, hashString('Han#0'));

p.noiseSeed(seed);
const noiseCoordinates = [[0, 0, 0], [0.1, 0.2, 0.3], [1, 2, 3],
  [-0.1, -0.2, -0.3], [4095.5, 0, 0], [4096, 0, 0],
  [85.3, 84.5, 0.28], [85.3, 84.5, 3.28], [85.3, 84.5, 6.28],
  [100000.25, 12345.5, 234.75]];
// Include actual first/last blob sampling coordinates for Han at t=.8.
const han = personalities[0];
for (const angle of [0, 0.22, 6.16]) {
  noiseCoordinates.push([Math.cos(angle) * 0.8 + han.noiseOff,
    Math.sin(angle) * 0.8 + han.noiseOff, time * 0.35]);
}
const noise = {
  seed, octaves: 4, falloff: 0.5, tableLength: 4096, tableMask: 4095,
  samples: noiseCoordinates.map(input => ({ input, value: p.noise(...input) })),
};
// Observe p5.noiseSeed's LCG without reproducing noise: at integer origin all
// octaves sample the first table entry, and their weights sum to .9375.
p.noiseSeed(seed);
noise.firstTableValueViaNoiseOrigin = p.noise(0, 0, 0) / 0.9375;

function recordDrawing(draw) {
  p.clear();
  p.resetMatrix();
  surface.commands = [];
  surface.recording = true;
  try { draw(); } finally { surface.recording = false; }
  return clone(surface.commands);
}
const vertices = [[0, 0], [10, 20], [30, 10], [40, 40], [60, 0]];
const curveVertex = {
  vertices, tightness: 0,
  commands: recordDrawing(() => {
    p.push(); p.noStroke(); p.fill(255); p.curveTightness(0);
    p.beginShape();
    vertices.forEach(vertex => p.curveVertex(...vertex));
    p.endShape(p.CLOSE); p.pop();
  }),
};
const curveCommands = curveVertex.commands.filter(command =>
  ['moveTo', 'bezierCurveTo', 'lineTo', 'closePath'].includes(command[0]));
assert.deepEqual(curveCommands.map(command => command[0]),
  ['moveTo', 'bezierCurveTo', 'bezierCurveTo', 'bezierCurveTo', 'bezierCurveTo', 'lineTo', 'closePath']);
assert.deepEqual(curveCommands[0], ['moveTo', 10, 20]);
assert.deepEqual(curveCommands.at(-2), ['lineTo', 0, 0]);

// p5's API calls provide original unconverted ellipse/arc/curve input geometry;
// Canvas commands separately capture the genuine p5 conversion and RGBA styles.
let p5Calls = null;
for (const method of ['push', 'pop', 'translate', 'rotate', 'scale', 'colorMode',
  'noStroke', 'noFill', 'fill', 'stroke', 'strokeWeight', 'beginShape', 'vertex',
  'curveVertex', 'bezierVertex', 'endShape', 'circle', 'ellipse', 'arc', 'rect']) {
  const original = p[method].bind(p);
  p[method] = (...args) => {
    if (p5Calls) p5Calls.push([method, ...args.map(serializable)]);
    return original(...args);
  };
}
const presets = [
  { id: 'idle', level: 0, state: {} },
  { id: 'voice', level: 0.65, state: {} },
  { id: 'pointer', level: 0, pointer: { x: 35, y: -18 },
    state: { hover: 0.8, leanX: bodySize * 0.02, leanY: -bodySize * 0.01 } },
  { id: 'pop', level: 0, action: 'pop', state: { popT: 0.12 } },
  { id: 'pet', level: 0, action: 'pet', state: { petGlow: 0.8 } },
];
const scenes = [];
mkdirSync(imageDir, { recursive: true });
for (const style of ['blob', 'ring', 'wave']) {
  for (const preset of presets) {
    resetRandom();
    p.noiseSeed(seed);
    p.deltaTime = 0;
    const params = { name: 'Han', variant: 0, hue: 193, style, energy: 0.6 };
    const c = new Creature(params);
    if (preset.action) c[preset.action]();
    Object.assign(c, preset.state);
    const stateBefore = clone(c);
    const input = { t: time, level: preset.level, pointer: preset.pointer || null, pointerSpeed: 0 };
    p5Calls = [];
    const commands = recordDrawing(() => c.render(p, width / 2, width / 2, bodySize, input));
    const image = surface.canvas.toBuffer('image/png');
    const id = `${style}_${preset.id}`;
    writeFileSync(new URL(`${id}.png`, imageDir), image);
    scenes.push({ id, params, randomSeed: seed, noiseSeed: seed,
      width, height: width, center: [width / 2, width / 2], bodySize,
      deltaTimeMs: 0, input, action: preset.action || null, overrides: preset.state,
      stateBefore, stateAfter: clone(c), p5Calls, commands,
      png: `avo_reference/${id}.png`, pngSha256: sha256(image) });
    p5Calls = null;
  }
}

// A separate real dt render records the original state transition, including
// frame-dependent particles. It is not used as a pure painter snapshot.
resetRandom();
p.noiseSeed(seed);
const moving = new Creature({ name: 'Han' });
moving.pet();
moving.pop();
const stepBefore = clone(moving);
p.deltaTime = 1000 / 60;
const stepInput = { t: time, level: 0.65, pointer: { x: 35, y: -18 }, pointerSpeed: 20 };
recordDrawing(() => moving.render(p, 128, 128, bodySize, stepInput));
const stateTransition = { randomSeed: seed, noiseSeed: seed, width, bodySize,
  deltaTimeMs: 1000 / 60, setupActions: ['pet', 'pop'], input: stepInput,
  stateBefore: stepBefore, stateAfter: clone(moving) };

const contact = createCanvas(width * 3, (width + 28) * presets.length);
const contactContext = contact.getContext('2d');
contactContext.fillStyle = '#18232d';
contactContext.fillRect(0, 0, contact.width, contact.height);
const { loadImage } = await import('@napi-rs/canvas');
for (let column = 0; column < 3; column++) {
  for (let row = 0; row < presets.length; row++) {
    const scene = scenes[column * presets.length + row];
    const image = await loadImage(readFileSync(new URL(`${scene.id}.png`, imageDir)));
    contactContext.drawImage(image, column * width, row * (width + 28));
    contactContext.fillStyle = '#ffffff';
    contactContext.font = '16px sans-serif';
    contactContext.fillText(scene.id, column * width + 12, row * (width + 28) + width + 20);
  }
}
writeFileSync(new URL('contact_sheet.png', imageDir), contact.toBuffer('image/png'));
const fixture = {
  schemaVersion: 1,
  metadata: {
    generator: 'tool/avo_reference/generate.mjs', p5Version: window.p5.VERSION,
    avoSource: 'avo/js/avo.js', avoSha256: sha256(avoSource),
    p5Source: 'avo/lib/p5.min.js', p5Sha256: sha256(p5Source),
    runtime: 'Node.js + jsdom DOM + @napi-rs/canvas Skia Canvas2D; original complete p5 runtime',
    randomAlgorithm: 'LCG: state=(1664525*state+1013904223)%4294967296; result=state/4294967296',
    defaults: { randomSeed: seed, noiseSeed: seed, time, width, height: width,
      bodySize, pixelDensity: 1, deltaTimeMs: 0 },
    commands: '[method, ...arguments], or ["set", property, value]; coordinates are Canvas local coordinates, apply recorded transforms in sequence',
    notes: [
      'Only export access to Creature/hashString is injected; original Avo and p5 implementations execute unchanged.',
      'Math.random resets before each Creature construction; p5.noiseSeed independently resets before each scene.',
      'Scenes are prescribed pure-time snapshots, not .8 seconds of simulated frames.',
      'Render mutates particle positions/velocity even at deltaTime=0; use stateAfter particles with a pure painter.',
      'Transparent scene PNGs use Skia rasterization; browser/Flutter edge antialiasing can differ.',
      'Contact sheet rows: idle, voice, pointer, pop, pet. Columns: blob, ring, wave.',
    ],
  }, personalities, noise, curveVertex, scenes, stateTransition,
};
const json = JSON.stringify(fixture, null, 2) + '\n';
if (process.argv.includes('--check')) {
  assert.equal(readFileSync(jsonPath, 'utf8'), json, 'Generated fixture must match checked-in JSON exactly');
  console.log('Deterministic JSON fixture matches byte-for-byte.');
} else {
  writeFileSync(jsonPath, json);
}
console.log(JSON.stringify({ jsonPath, scenes: scenes.length, han: personalities[0],
  guest: personalities[1], noise: noise.samples.slice(0, 4), curveCommands }, null, 2));
p.remove();
window.close();
