# ProgGenie

An iOS/macOS **AUv3 MIDI processor** (`aumi PgGn`) that generates chord
progressions by walking corpus transition statistics, plays them through a
shared kernel, and — the part that is only here — lets you keep a durable
opinion about **individual chord changes**.

It is the second plug-in built on
[`enkerli-swift`](https://github.com/Enkerli/enkerli-swift), and it exists as
much to prove that foundation stands twice as to be a product. The engine was
already written: MelGen's `ProgressionGenerator` walks the same tables, and if
this repo had ended up with its own copy of the chord dictionary, the extraction
would have failed. It has none. Everything musical here comes from the package.

## What it does that its siblings don't

**It curates transitions, not takes.** MelGen judges a *line* you kept, with a
disposition and a pass number. Here what is judged is a **change**: `IIm7 → V7`
is either something you reach for or something you are tired of, and that
judgement outlives every progression it was made in. Weights are multipliers —
1 means "no opinion", and the corpus shows through untouched — clamped to
[1/16, 16], symmetric in log space so "never" and "always" cost the same number
of taps. Rating a whole progression spreads a smaller nudge over each of its
changes, because a diffuse judgement should move less than a pointed one.

Ported from `packages/proggen/src/curation.js` in
[music-suite](https://github.com/Enkerli/music-suite), which is where this
plug-in's engine also comes from.

It is **not** the JUCE [Progression
Studio](https://github.com/Enkerli/progression-studio-plugin). That one is
`aumi Prst` and ships AU, VST3, CLAP, LV2 and Standalone on four platforms. This
one is AUv3 only, macOS and iOS only, SwiftUI rather than WebView — a different
trade for the iPad-first case, and a different four-character code so both can
be installed at once and compared.

## Building

Clone the foundation beside this repo first. Nothing builds without it:

```bash
git clone https://github.com/Enkerli/enkerli-swift ../enkerli-swift
```

Then open `ProgGenie.xcodeproj` (Xcode 27+, iOS/macOS 26.0+). Two schemes:
`ProgGenieExtension` is the plug-in, `ProgGenie` is a host app that loads it for
quick testing.

## Verifying

Xcode's test targets can reach almost nothing here — everything real is either
extension-only or in the package next door. The check that means something runs
outside Xcode:

```bash
Scripts/verify.sh            # all suites
Scripts/verify.sh curation   # one suite
```

| Suite | Checks |
|---|---|
| `identity` | The component triple is unique across every sibling checkout, JUCE and Swift alike, and matches the host app's lookup. First, because it is the one mistake that cannot be taken back |
| `curation` | The per-transition weights — bounds, symmetry, what a rating spreads — and that generation is actually steered by them |

That last one is worth reading rather than trusting: it measures how often a
liked change appears over sixty seeds with and without an opinion on it. Last
run, `IIm7 → V7` went from 6 of 60 to 47 of 60.

## What this plug-in is, in files

The whole of what a plug-in on this foundation has to write:

| File | Lines | What it is |
|---|---:|---|
| `AudioUnit/ProgGenieAudioUnit.swift` | ~85 | The session, and what the kernel plays out of it |
| `AudioUnit/AudioUnitViewController.swift` | ~35 | Three overrides: which audio unit, which parameters, which root view |
| `AudioUnit/Parameters.swift` | ~80 | The parameter tree, over the kernel's own three addresses |
| `Progression/ProgGenieState.swift` | ~170 | What to generate, what was generated, what you thought of it |
| `Progression/TransitionCuration.swift` | ~120 | The durable weights |
| `UI/ProgGenieMainView.swift` | ~280 | One screen |

Everything else — 172 chord qualities, the corpus tables, taxicab voice leading,
the pattern interchange format, the SwiftUI kit with its WCAG-audited palette,
the AU shell and the C++ kernel — is the package.

## What has not been done

Stated plainly, in the house style of the repo this grew out of:

- **None of this has been heard on a device.** It builds, its suites pass, and
  the kernel it plays through is the same one MelGen has been heard through. That
  is not the same as knowing it sounds like anything.
- **Curation steers by rejection sampling** — generate up to twelve candidates
  and keep the one the profile likes best. That is honest about being
  approximate. Weighting the transition distribution directly would be better
  and would mean the generator learning that anyone keeps opinions, which is a
  change to shared foundation and wants more thought than it has had.
- **There is no corpus browsing.** PORTING.md lists it as the other thing
  ProgGenie has over MelGen. Seeing what the statistics actually say, rather than
  only hearing their output, is the next real feature.
- **No vectors hold this against `@enkerli/proggen`.** MelGen's `verify.sh
  proggen` compares the deterministic half — label splitting, numerals to
  semitones, what is refused — and that check lives in MelGen because that is
  where the port is. It covers the engine this plug-in uses.

## Licence

Public domain, all the way down. See [LICENSE](LICENSE).
