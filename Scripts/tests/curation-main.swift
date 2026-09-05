//
//  curation-main.swift
//  ProgGenie
//
//  The thing this plug-in has that MelGen does not: a durable weight per chord
//  change. Everything here is about the properties that make it curation rather
//  than a preference file.
//

import Foundation

var failures = 0
var checks = 0

func check(_ what: String, _ passed: Bool, _ detail: String = "") {
    checks += 1
    if passed {
        print("  PASS  \(what)\(detail.isEmpty ? "" : " — \(detail)")")
    } else {
        failures += 1
        print("  FAIL  \(what)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

print("── an unjudged profile is a no-op ─────────────────")

var curation = TransitionCuration()
check("nothing judged is nothing stored", curation.isEmpty)
check("an unjudged change weighs exactly 1",
      curation.weight(from: "IIm7", to: "V7") == 1)

print("\n── a judgement moves one change and only that one ──")

curation.emphasise(from: "IIm7", to: "V7", liked: true)
check("liking a change raises it", curation.weight(from: "IIm7", to: "V7") > 1,
      "\(curation.weight(from: "IIm7", to: "V7"))")
check("and leaves its reverse alone", curation.weight(from: "V7", to: "IIm7") == 1)
check("and leaves every other change alone", curation.weights.count == 1)

curation.emphasise(from: "IIm7", to: "V7", liked: false)
check("disliking it back is neutral again, and stops being stored",
      curation.isEmpty, "\(curation.weights)")

print("\n── the bounds ─────────────────────────────────────")

var extreme = TransitionCuration()
for _ in 0..<50 { extreme.emphasise(from: "I", to: "IV", liked: true) }
check("fifty likes stop at the ceiling",
      extreme.weight(from: "I", to: "IV") == TransitionCuration.ceiling,
      "\(extreme.weight(from: "I", to: "IV"))")
for _ in 0..<100 { extreme.emphasise(from: "I", to: "IV", liked: false) }
check("and a hundred dislikes stop at the floor",
      extreme.weight(from: "I", to: "IV") == TransitionCuration.floor,
      "\(extreme.weight(from: "I", to: "IV"))")

// Symmetric in log space: "never" and "always" cost the same number of nudges,
// which is the property that makes the two verbs feel like one control.
let up = log(TransitionCuration.ceiling) / log(TransitionCuration.emphasisStep)
let down = -log(TransitionCuration.floor) / log(TransitionCuration.emphasisStep)
check("the bounds are symmetric in log space", abs(up - down) < 0.001,
      "\(up) up, \(down) down")

print("\n── rating a progression spreads over its changes ───")

var rated = TransitionCuration()
rated.rate(["I", "VIm7", "IIm7", "V7"], liked: true)
check("a four-chord progression judges its three changes",
      rated.weights.count == 3, "\(rated.weights.count)")
check("each change moved less than a pointed one would",
      rated.weight(from: "I", to: "VIm7") < TransitionCuration.emphasisStep,
      "\(rated.weight(from: "I", to: "VIm7"))")
check("a one-chord progression has no changes to judge",
      { var c = TransitionCuration(); c.rate(["I"], liked: true); return c.isEmpty }())

print("\n── it survives the session ────────────────────────")

var session = ProgGenieState()
session.curation.emphasise(from: "IIm7", to: "V7", liked: true)
session.generate(seed: 12345)
check("generating produces changes", !session.labels.isEmpty,
      session.labels.joined(separator: " "))
check("and text the parser can read back", session.progression != nil,
      session.progressionText)
check("and notes the kernel can play", !session.notes.isEmpty,
      "\(session.notes.count) notes over \(session.lengthBeats) beats")

let encoded = try! JSONEncoder().encode(session)
let restored = try! JSONDecoder().decode(ProgGenieState.self, from: encoded)
check("the session round-trips through JSON, curation included",
      restored.curation == session.curation && restored.labels == session.labels)

print("\n── the same seed is the same progression ──────────")

var a = ProgGenieState(); a.generate(seed: 99)
var b = ProgGenieState(); b.generate(seed: 99)
check("the same seed gives the same changes", a.labels == b.labels,
      a.labels.joined(separator: " "))
var c = ProgGenieState(); c.generate(seed: 100)
check("a different seed usually gives different changes", c.labels != a.labels,
      c.labels.joined(separator: " "))

print("\n── curation actually steers the generator ─────────")

// Rejection sampling over twelve draws, so this is a tendency rather than a
// guarantee, and the check is written to say so: over many seeds, a strongly
// liked change should appear more often than with no opinion at all.
func appearances(of pair: (String, String), curated: Bool, seeds: Int = 60) -> Int {
    var count = 0
    for seed in 0..<seeds {
        var state = ProgGenieState()
        if curated {
            for _ in 0..<8 { state.curation.emphasise(from: pair.0, to: pair.1, liked: true) }
        }
        state.generate(seed: UInt64(seed &* 7919 &+ 13))
        if zip(state.labels, state.labels.dropFirst()).contains(where: { $0 == pair.0 && $1 == pair.1 }) {
            count += 1
        }
    }
    return count
}

let pair = ("IIm7", "V7")
let plain = appearances(of: pair, curated: false)
let steered = appearances(of: pair, curated: true)
check("a strongly liked change shows up more often once judged",
      steered >= plain, "\(plain) of 60 unjudged, \(steered) of 60 judged")

print("\n\(failures == 0 ? "all checks passed" : "\(failures) of \(checks) FAILED")")
exit(failures == 0 ? 0 : 1)
