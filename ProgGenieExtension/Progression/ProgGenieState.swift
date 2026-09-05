//
//  ProgGenieState.swift
//  ProgGenieExtension
//
//  The session: what to generate, what was generated, and what you thought of it.
//
//  One `Codable` struct, saved into and restored from the audio unit's
//  `fullState`, the same shape ProgGenie's session has. That is not a coincidence
//  and it is not shared code either — `PluginAudioUnit` deliberately knows
//  nothing about what a plug-in's session *is*, so each one declares its own and
//  the shell stores whatever it is handed.
//
//  What is not here is as deliberate as what is. There is no take history: a
//  progression is cheap to regenerate from its seed, so the seed is the history,
//  and the durable judgement lives in `TransitionCuration` where it survives the
//  progression it was made about.
//

import Foundation
import Carrier
import Theory

struct ProgGenieState: Codable, Hashable, Sendable {

    // MARK: - What to generate

    /// Pitch class of the tonic, 0 = C.
    var key: Int = 0
    var mode: ProgressionMode = .major
    var bars: Int = 8

    /// How far down the ranked list of next chords to reach.
    ///
    /// ProgGenie's original used temperature; ProgGenie replaced it with this and
    /// the argument holds here too — a leadsheet corpus has a long tail of
    /// things seen once, and flattening the distribution reaches the tail before
    /// it reaches the interesting middle.
    var surprise: Double = 0.3
    var freshness: Freshness = .fresh
    var reharm: Reharm = .subtle
    var cadence: Bool = true

    /// The seed the current progression came from, so "again, the same" and
    /// "again, different" are both one word.
    var seed: UInt64 = 0

    // MARK: - What was generated

    /// Leadsheet text, one chord per bar. Empty before the first generation.
    var progressionText: String = ""
    /// The corpus's own Roman-numeral labels for that text — what curation is
    /// about, and what the text alone cannot give back.
    var labels: [String] = []

    // MARK: - What you thought of it

    var curation = TransitionCuration()

    /// The voicing the chords are sounded with. Block chords rather than a comp:
    /// this plug-in is about the changes, and a rhythm would be an opinion about
    /// something it is not trying to have an opinion about.
    var voicingStyle: VoicingStyle = .rootlessA
    var centre: Int = 60
    var beatsPerBar: Double = 4

    // MARK: - Deriving

    var progression: ChordProgression? {
        guard !progressionText.isEmpty else { return nil }
        return try? ChordProgression.parse(progressionText, beatsPerBar: beatsPerBar)
    }

    var lengthBeats: Double { Double(max(1, labels.count)) * beatsPerBar }

    /// The notes the kernel loops: each chord voiced once, led from the last.
    ///
    /// `ChordVoicings.voiceLead` is the shared foundation doing the work — the
    /// same taxicab voice leading ProgGenie comps with, held to the suite's own
    /// vectors. Nothing about it knows which plug-in called it, which is the
    /// whole claim PORTING.md makes, tested here rather than asserted.
    var notes: [SequencedNote] {
        guard let progression else { return [] }
        var notes: [SequencedNote] = []
        var previous: [Int]?
        for placed in progression.chords {
            let voicing = ChordVoicings.voice(placed.symbol, style: voicingStyle, centre: centre)
            let pitches = ChordVoicings.lead(from: previous, to: voicing.pitches,
                                             centre: centre, mode: .smooth)
            previous = pitches
            for pitch in pitches {
                notes.append(SequencedNote(note: UInt8(clamping: pitch),
                                           velocity: 84,
                                           startBeat: placed.startBeat,
                                           durationBeats: max(0.25, placed.durationBeats - 0.05)))
            }
        }
        return notes
    }

    /// Generate, with the curation profile weighting the corpus.
    ///
    /// The curation is applied here rather than inside `ProgressionGenerator`
    /// because the generator is shared foundation and has no business knowing
    /// that anyone keeps opinions about transitions. What it exposes is enough:
    /// generate, then re-generate with a different seed until the result is one
    /// the profile likes, which is rejection sampling and is honest about being
    /// approximate.
    mutating func generate(seed newSeed: UInt64, attempts: Int = 12) {
        var best: GeneratedProgression?
        var bestScore = -Double.infinity
        for attempt in 0..<max(1, attempts) {
            let candidate = ProgressionGenerator.generate(
                bars: bars, key: key, mode: mode,
                surprise: Surprise(surprise), freshness: freshness,
                reharm: reharm, cadence: cadence,
                seed: newSeed &+ UInt64(attempt))
            guard let candidate else { continue }
            let score = curationScore(of: candidate.labels)
            if score > bestScore {
                bestScore = score
                best = candidate
            }
            // An unjudged profile has nothing to say, so the first draw wins and
            // twelve generations for one progression are not spent.
            if curation.isEmpty { break }
        }
        guard let best else { return }
        seed = best.seed
        labels = best.labels
        progressionText = best.text
        key = best.key
        mode = best.mode
    }

    /// Mean log multiplier over the progression's transitions. Log because the
    /// weights are multiplicative and averaging them raw would let one 16 drown
    /// six 1/16s.
    func curationScore(of labels: [String]) -> Double {
        let steps = zip(labels, labels.dropFirst())
        var total = 0.0
        var count = 0
        for (previous, next) in steps {
            total += log(curation.weight(from: previous, to: next))
            count += 1
        }
        return count > 0 ? total / Double(count) : 0
    }
}
