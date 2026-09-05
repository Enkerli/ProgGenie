//
//  ProgGenieAudioUnit.swift
//  ProgGenieExtension
//
//  ProgGenie's half of the audio unit: the session, and what the kernel plays.
//
//  `PluginAudioUnit` in the shared package is the other half — kernel,
//  parameter tree, transport readings, capture ring — and knows nothing about
//  chords. This file is the whole of what a second plug-in on that foundation
//  has to write on the AU side, which is the claim PORTING.md §2 makes and this
//  repo exists to test.
//
//  It is deliberately the same shape as ProgGenie's `ProgGenieExtensionAudioUnit`:
//  a locked session, a `fullState` that round-trips it as JSON under one key,
//  and a reload that only restarts the loop when the material actually changed.
//  Not shared code — a plug-in's session type is the plug-in's — but the same
//  three moves, which is what "days per app" in `JUCE_INDEPENDENCE.md` §3 has to
//  mean if it means anything.
//

import AVFoundation
import Shell

public final class ProgGenieAudioUnit: PluginAudioUnit, @unchecked Sendable {

    private let stateLock = NSLock()
    private var _state = ProgGenieState()

    /// The progression the kernel is currently looping, so a re-voicing can be
    /// told apart from a new progression: changing the voicing style should not
    /// jump the playhead back to bar one.
    private var lastLoadedText: String?

    var state: ProgGenieState {
        get { stateLock.withLock { _state } }
        set { update(state: newValue) }
    }

    /// - Parameter reloadKernel: pass `false` for edits that cannot change the
    ///   notes, so the render thread is not handed a new sequence for nothing.
    func update(state newState: ProgGenieState, reloadKernel: Bool = true) {
        stateLock.withLock { _state = newState }
        if reloadKernel { loadIntoKernel(newState) }
    }

    private func loadIntoKernel(_ state: ProgGenieState) {
        let notes = state.notes
        guard !notes.isEmpty else { return }
        let isNewProgression = state.progressionText != lastLoadedText
        lastLoadedText = state.progressionText
        setMelody(notes, lengthBeats: state.lengthBeats, restartFromTop: isNewProgression)
    }

    private static let stateKey = "ProgGenie.sessionState"

    public override var fullState: [String: Any]? {
        get {
            var dictionary = super.fullState ?? [:]
            if let data = try? JSONEncoder().encode(state) {
                dictionary[Self.stateKey] = data
            }
            return dictionary
        }
        set {
            super.fullState = newValue
            guard let data = newValue?[Self.stateKey] as? Data,
                  let restored = try? JSONDecoder().decode(ProgGenieState.self, from: data) else {
                return
            }
            // Assigning through `state` reloads the kernel, so a reopened
            // session plays without the UI having been shown.
            state = restored
        }
    }

    /// Hosts save session documents through this rather than `fullState`; for
    /// ProgGenie the two are the same thing.
    public override var fullStateForDocument: [String: Any]? {
        get { fullState }
        set { fullState = newValue }
    }
}
