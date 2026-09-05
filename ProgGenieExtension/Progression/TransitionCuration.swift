//
//  TransitionCuration.swift
//  ProgGenieExtension
//
//  "This change sounds good" as a durable, portable weight.
//
//  This is the one thing ProgGenie has that ProgGenie does not, and it is why this
//  plug-in is worth building rather than being a mode inside that one. ProgGenie
//  curates *takes* — a line you kept, with a disposition and a pass number.
//  Here what is judged is a **transition**: `IIm7 → V7` is either a change you
//  reach for or one you are tired of, and that judgement outlives every
//  progression it was made in.
//
//  Ported from `packages/proggen/src/curation.js`, which keeps a map of
//  multipliers per `from → to` transition, nudges them by emphasizing a single
//  change or by rating a whole progression, clamps them, persists them, and can
//  export them as a shareable profile.
//
//  Three decisions worth stating, because none of them is obvious:
//
//  **Multipliers, not scores.** A weight of 1 means "no opinion", and the corpus
//  statistics show through untouched. That is the difference between curation
//  and a preference file: a transition you have never judged behaves exactly as
//  the leadsheets say it should, and the thing you are adjusting is visibly a
//  nudge to a distribution rather than a rating of a chord change.
//
//  **Clamped to [1/16, 16].** Sixteen times is a strong opinion and enough for
//  one transition to dominate a distribution; unbounded multipliers turn a walk
//  over a corpus into a walk over your own last ten clicks, which is the failure
//  mode this whole approach exists to avoid. The bound is symmetric in log
//  space, so "never" and "always" cost the same number of nudges.
//
//  **Rating a progression spreads over its transitions.** Rating an eight-bar
//  progression is one gesture about seven changes, and attributing it equally is
//  the only honest thing to do without asking which change you meant. The nudge
//  per transition is therefore smaller than a deliberate single-transition
//  emphasis — a diffuse judgement should move less than a pointed one.
//

import Foundation

/// A learned multiplier per `from → to` transition, over the corpus's own labels.
struct TransitionCuration: Codable, Hashable, Sendable {

    /// Bounds, in multiples. See the file comment for why they are these.
    static let floor = 1.0 / 16
    static let ceiling = 16.0

    /// How far one deliberate emphasis moves a transition, multiplicatively.
    static let emphasisStep = 1.6

    /// How far rating a whole progression moves each of its transitions. Smaller
    /// than `emphasisStep` because the judgement is spread rather than aimed.
    static let ratingStep = 1.15

    /// Keyed `"from→to"`, holding only transitions with an opinion on them.
    /// Absent means 1, which is what makes an empty profile a no-op.
    private(set) var weights: [String: Double] = [:]

    init(weights: [String: Double] = [:]) {
        self.weights = weights.mapValues(Self.clamped)
    }

    static func key(from: String, to: String) -> String { "\(from)→\(to)" }

    static func clamped(_ weight: Double) -> Double {
        min(ceiling, max(floor, weight))
    }

    /// What this profile says about one change. 1 when it has never been judged.
    func weight(from: String, to: String) -> Double {
        weights[Self.key(from: from, to: to)] ?? 1
    }

    /// A pointed judgement about one change.
    mutating func emphasise(from: String, to: String, liked: Bool) {
        nudge(from: from, to: to, by: liked ? Self.emphasisStep : 1 / Self.emphasisStep)
    }

    /// A diffuse judgement about a whole progression, spread over its changes.
    mutating func rate(_ labels: [String], liked: Bool) {
        let step = liked ? Self.ratingStep : 1 / Self.ratingStep
        for (previous, next) in zip(labels, labels.dropFirst()) {
            nudge(from: previous, to: next, by: step)
        }
    }

    mutating func nudge(from: String, to: String, by factor: Double) {
        let key = Self.key(from: from, to: to)
        let updated = Self.clamped((weights[key] ?? 1) * factor)
        // An opinion that has drifted back to neutral is not an opinion, and a
        // profile full of 1.0000001 is a profile nobody can read.
        if abs(updated - 1) < 0.001 {
            weights.removeValue(forKey: key)
        } else {
            weights[key] = updated
        }
    }

    mutating func forget(from: String, to: String) {
        weights.removeValue(forKey: Self.key(from: from, to: to))
    }

    mutating func forgetAll() { weights.removeAll() }

    var isEmpty: Bool { weights.isEmpty }

    /// The changes you reach for and the ones you avoid, strongest first — the
    /// part of this that is worth showing on screen.
    func strongest(_ count: Int = 8) -> [(from: String, to: String, weight: Double)] {
        weights
            .map { key, weight -> (from: String, to: String, weight: Double) in
                let parts = key.split(separator: "→", maxSplits: 1)
                return (String(parts.first ?? ""), String(parts.last ?? ""), weight)
            }
            .sorted { abs(log($0.weight)) > abs(log($1.weight)) }
            .prefix(count)
            .map { $0 }
    }
}
