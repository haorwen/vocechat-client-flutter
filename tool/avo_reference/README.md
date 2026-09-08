# Original Avo reference fixtures

This tool executes the complete original `avo/js/avo.js` and bundled **p5.js 1.9.4** in a JSDOM window. The only source instrumentation adds an export for the otherwise private `Creature` class and `hashString` function. All personality, state updates, noise, color conversion, shape conversion, and drawing run through the original JavaScript. The DOM canvas delegates to `@napi-rs/canvas` (Skia); a proxy records the actual 2D Canvas commands.

No browser or server is needed. Node 24.19.0 was used for generation. The source `avo/` directory must be adjacent to `vocechat-client-flutter/`, as in the development workspace.

From `vocechat-client-flutter/`:

```sh
npm --prefix tool/avo_reference ci --ignore-scripts --no-audit --no-fund
node tool/avo_reference/generate.mjs
node tool/avo_reference/generate.mjs --check
```

`--check` rerenders the PNGs and compares the generated JSON, including individual PNG SHA-256 values, byte for byte against the saved fixture. Rasterization can vary across native graphics-library versions/platforms; compare geometry numerically and allow edge antialiasing tolerance for Flutter image comparisons. The package lock fixes the tested JavaScript/native package versions.

Outputs are `test/shared/fixtures/avo_reference.json`, 15 transparent scene PNGs in `test/shared/fixtures/avo_reference/`, and a contact sheet. Contact sheet columns are blob, ring, wave; rows are idle, voice, pointer, pop, pet.

To compare exported native Flutter rendering:

```sh
flutter test --dart-define=AVO_EXPORT=true test/shared/widgets/avo_reference_test.dart
node tool/avo_reference/compare.mjs
```

The comparison reads `build/avo_comparison/{scene}.png` and the original PNGs, composites both over `#101214`, and writes `build/avo_comparison/metrics.json` and `contact_sheet.png`. The sheet alternates p5/Flutter columns for blob, ring and wave across five state rows. Metrics use decoded straight RGBA, apply alpha once, and report mean absolute RGB channel error in 0–255 units plus the fraction of pixels whose maximum RGB channel error exceeds 24. It exits nonzero if any mean is ≥.5 or outlier coverage is ≥.001 (0.1% of pixels). All scenes in the JSON receive metrics; the sheet displays the standard 15 snapshots.

For interactive review with the repository's Flutter 3.27 SDK (which predates `widget_previews`), run `flutter run -t tool/avo_preview.dart -d windows` or choose another supported Flutter device. The isolated preview displays all three styles with pointer/touch reactions and controls for voice level, energy, hue and variant. It does not require signing in or a server.

The native implementation keeps painting pure and state in the avatar. Its noise table is seeded for cross-client consistency (the original p5 instance otherwise picks a random table), and animation randomness can be seeded for tests. At 60 Hz the reference animation coefficients are retained; exponential interpolation and time-based particle steps preserve speed at 120 Hz. Agora samples use the attack/release coefficients from `avo/js/audio.js`, and remote pointer samples are interpolated between network updates. `TickerMode` pauses hidden avatars without losing state; an active slow frame still advances the full event time.

The JSON contains:

- `metadata`: schema context, exact original source SHA-256 values, versions and coordinate conventions.
- `personalities`: original constructor results for Han, guest, variants, Chinese, emoji and empty names; unsigned hash, signed shifts and remainders are included.
- `noise`: original `p.noise` results after `p.noiseSeed(12345)`, including negative coordinates, large coordinates and actual Han blob samples.
- `curveVertex`: an asymmetric five-vertex input and the original complete Canvas output from `beginShape()` / `endShape(CLOSE)`.
- `scenes`: exact inputs, original state before/after render, original p5 API calls, Canvas commands and PNG paths/hashes.
- `stateTransition`: one real 1/60-second original render after `pet()` then `pop()`, with voice, pointer and rubbing, to check animation separately from painting.

Each Canvas command is `[method, ...arguments]`; a property assignment is `["set", property, value]`. Coordinates are local to the Canvas transform recorded in sequence. The list records actual p5 renderer output, including RGBA paint strings. `p5Calls` provides the original shape inputs before conversion, but includes nested delegation (for example `circle` calls `ellipse`, and `curveVertex` calls `vertex`), so do not replay that list as independent draws. The initial context uses p5 defaults: stroke cap round, join miter, width 1, opaque white fill and black stroke. Each recorded scene starts from the identity transform and a transparent canvas; p5 draw calls establish the required styles.

Every scene uses a 256×256 canvas, pixel density 1, center (128,128), body diameter 158.72 (`256 * .62`), `t=.8`, params `{name:"Han",variant:0,hue:193,energy:.6,style}`, and independent Math.random/noise seeds 12345. Math.random is replaced with the 32-bit LCG `state=(1664525*state+1013904223)%4294967296`, returning `state/4294967296`, and reset immediately before each original constructor. Original `p.noiseSeed(12345)` independently initializes the noise table.

These are prescribed time snapshots rather than a simulation from t=0: `p.deltaTime=0` and the following inputs/state overrides are applied:

| Scene | Level | Input / original state |
| --- | ---: | --- |
| idle | 0 | Constructor defaults |
| voice | .65 | Constructor defaults |
| pointer | 0 | pointer=(35,-18), hover=.8, leanX=3.1744, leanY=-1.5872 |
| pop | 0 | Call original `pop()`, then set popT=.12 |
| pet | 0 | Call original `pet()`, then set petGlow=.8 |

Pointer speed is zero in snapshots. `leanX`, `leanY`, pointer and particle positions are in original pixel coordinates; divide lean/particle values by body diameter if the Flutter model stores normalized coordinates. Particle size also uses `bodySize/100`. The original particle implementation changes position and damps vx **even when deltaTime is zero**, so a pure Flutter painter must use the recorded `stateAfter` particles. For body and face, the snapshot scalar state is otherwise unchanged. The real state transition fixture supplies a separate nonzero deltaTime.

## Verified conversion details

The p5 public `endShape(CLOSE)` and `Renderer2D.endShape` each append the first vertex. For an original list `v0..vN-1`, the effective list is `v0..vN-1,v0,v0`. It moves to `v1` and emits cubics for `i=1..N-1`, with default tightness zero:

```text
start = v[i]
control1 = v[i] + (v[i+1] - v[i-1]) / 6
control2 = v[i+1] + (v[i] - v[i+2]) / 6
end = v[i+1]
```

Then it calls `lineTo(v0)` (a degenerate line because the last cubic ended there), and closes the path with a **straight line v0→v1**. The 29 original blob samples therefore produce 28 cubics per layer. A periodic Catmull–Rom loop has different geometry. Inspecting the renderer without the public wrapper misses one appended vertex and one cubic; the generator asserts the output of the full runtime.

For the five vertices `(0,0),(10,20),(30,10),(40,40),(60,0)`, the first cubic is `(15,21.666666666666668),(25,6.666666666666666)→(30,10)`, and the fourth/final cubic is `(53.333333333333336,-6.666666666666667),(10,0)→(0,0)`. The entire numeric path is in `curveVertex.commands`.

The unsigned FNV32 result does **not** make `>>` unsigned in JavaScript. The hash iterates UTF-16 code units with `Math.imul`, returns `>>>0`, and each later `>>` converts back to signed int32. `%` keeps the dividend's sign; use signed remainder rather than Dart's nonnegative modulo for those knobs.

| Input | Unsigned seed | Signed seed | Lobes | Orbiters | Squish | Eye gap | Eye size | Noise offset |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Han#0 | 1883705327 | 1883705327 | 8 | 6 | 1 | .39 | .1 | 32.7 |
| guest#0 | 3161914560 | -1133052736 | 5 | 2 | .6599999999999999 | .3 | .09000000000000001 | 56 |

`Han#0` has a positive signed seed; `guest#0` is the negative-shift regression case. For guest, shifts by 3/6/9/12 produce -141631592, -17703949, -2212994, -276625; remainders by 7/30/14/8 are -4, -19, 0, -1. Do not clamp resulting personality knobs to the apparent positive-only ranges.

Noise uses a 4096-value table/mask 4095, cosine interpolation `.5*(1-cos(pi*t))`, four octaves with initial amplitude .5 and falloff .5. Inputs are made absolute independently. Table indexing is `xi + (yi << 4) + (zi << 8)`, masked by 4095; each octave doubles coordinates. `noiseSeed` fills the table with the LCG above, using the first generated value rather than the seed itself. With seed 12345, the first entry is .02040268573909998 and:

| Input | Original p5 output |
| --- | ---: |
| (0,0,0) | .01912751788040623 |
| (.1,.2,.3) | .28723916894247103 |
| (1,2,3) | .7822828248026781 |
| (-.1,-.2,-.3) | .28723916894247103 |

`inspect-p5.mjs` optionally extracts relevant minified-source excerpts to ignored `p5-excerpts.txt` for source review. The generator does not use excerpts or copied renderer/noise formulas.
