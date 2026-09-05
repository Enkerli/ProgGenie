# Working on ProgGenie

*Short on purpose. This is the second plug-in on a shared foundation, so most of
what you need to know is about the seam between them.*

---

## The two things that surprise everybody

**Nothing builds without the foundation checked out beside this repo.**

```bash
git clone https://github.com/Enkerli/enkerli-swift ../enkerli-swift
```

`Scripts/verify.sh` and `ProgGenie.xcodeproj` both look in `$REPO/../enkerli-swift`;
override with `ENKERLI_SWIFT=...`. Without it every suite fails with that line
printed, which is deliberate — a suite that quietly passed without the foundation
would be checking nothing.

**Xcode's test targets reach almost nothing.** Everything real is either in the
`ProgGenieExtension` target (extension-only membership) or in the package next
door. A green test action says the host app compiles. The real check is:

```bash
Scripts/verify.sh            # all suites
Scripts/verify.sh curation   # one
```

If you cannot run a terminal, say so plainly and ask for it to be run rather than
reporting a change as verified. Building both schemes is necessary and is not
sufficient.

---

## Where a change belongs

The question to ask about any new type is *would a third plug-in want this?*

| It is | Put it |
|---|---|
| Chords, scales, voice leading, progressions | `enkerli-swift` → `Sources/Theory` |
| A pattern, a note, measurement, curation of material | → `Sources/Carrier` |
| A control any plug-in could use | → `Sources/UI` |
| AU plumbing | → `Sources/Shell` |
| About chord progressions as *this product* sees them | here |

**When in doubt, put it here.** Moving something down later is a `git mv` plus a
`public` sweep; moving it up is a compile error you find immediately. And a
foundation that grows by accident is the failure mode the whole layering exists
to prevent — see `PORTING.md` in [MelGen](https://github.com/Enkerli/MelGen),
which is where the reasoning lives.

Changing the foundation means changing another repo. Run *its* checks and
MelGen's `Scripts/verify.sh` too: MelGen is the other consumer, and a `public`
you narrow or a signature you change breaks it silently from here.

---

## Rules that are not negotiable

**The component triple is forever.** `aumi/PgGn/Enke`. This project was
scaffolded by copying MelGen's project file, so it started life claiming
MelGen's code, and `Scripts/verify.sh identity` exists because that exact class
of mistake already shipped once — the Xcode template's default subtype was
`Prst`, and loading Progression Studio in AUM launched MelGen. Never change the
triple. The check reads every sibling checkout, JUCE `CMakeLists.txt` and Swift
`Info.plist` alike.

**Nothing generates on the audio thread.** Generation produces a whole
progression off-thread and hands the kernel already-decided notes. This is
inherited from the shell and it is load-bearing.

**Curation is multipliers, not scores.** A weight of 1 means no opinion and the
corpus shows through untouched. If you find yourself wanting a 0–5 rating, read
the file comment in `TransitionCuration.swift` first — the reasons are written
down there.

---

## House style

The prose in this repo — comments, commit messages, documents — explains *why*,
records what was measured, and says plainly what is not known. A comment that
restates the code is noise; a comment naming the bug that made the code look like
that is the reason the file is readable a month later. When you are unsure
whether something works, write that down instead of rounding up. The README's
"What has not been done" section is the model.
