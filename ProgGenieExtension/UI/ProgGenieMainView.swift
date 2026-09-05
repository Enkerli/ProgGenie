//
//  ProgGenieMainView.swift
//  ProgGenieExtension
//
//  One screen: the changes, the dials that make them, and what you thought.
//
//  Almost every control here comes out of the shared UI kit — `Eyebrow`,
//  `LabelledSlider`, `ChipPicker`, `PrimaryAction`, `CollapsibleSection`,
//  `MiniRoll`, `MelGenTheme` and its metrics — and none of it was written for
//  chord progressions. That is the point of the kit being a package: a second
//  plug-in inherits the touch targets, the WCAG-audited palette, the border
//  rule and the light/dark behaviour without deciding any of it again.
//
//  The kit still carries ProgGenie's name in its types (`MelGenTheme`,
//  `MelGenMetrics`), which is honest about where it came from and is worth
//  renaming once a third plug-in makes the name actively wrong rather than
//  merely historical.
//
//  What is ProgGenie's own is the shape of the screen: the progression is the
//  subject, so it is at the top and it is large; the dials that produced it sit
//  under it in the order you reach for them; and the judgement — the thing this
//  plug-in has that ProgGenie does not — is a row of two verbs on the change you
//  are pointing at, not a rating of the whole thing.
//

import SwiftUI
import Carrier
import Shell
import Theory
import UI

struct ProgGenieMainView: View {
    var parameterTree: ObservableAUParameterGroup
    weak var audioUnit: ProgGenieAudioUnit?

    @State private var state = ProgGenieState()
    @State private var selectedTransition: Int?
    @Environment(\.colorScheme) private var colorScheme

    private var theme: MelGenTheme { colorScheme == .dark ? .dark : .light }

    private var playParameter: ObservableAUParameter { parameterTree.global.playMelody }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MelGenMetrics.space3) {
                changes
                mini
                transport
                dials
                judgement
            }
            .padding(MelGenMetrics.space3)
        }
        .background(theme.background)
        .onAppear {
            if let audioUnit { state = audioUnit.state }
            if state.progressionText.isEmpty { generate() }
        }
    }

    // MARK: - The changes

    @ViewBuilder
    private var changes: some View {
        VStack(alignment: .leading, spacing: MelGenMetrics.space2) {
            Eyebrow(text: "Changes", theme: theme)
            if state.labels.isEmpty {
                Text("Nothing generated yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textMuted)
            } else {
                // Roman numerals above, spelled chords below: the corpus's own
                // vocabulary is what the statistics are in and what curation is
                // about, and the spelling is what you play. Showing one without
                // the other makes half the plug-in unreadable.
                FlowLayout(spacing: 6) {
                    ForEach(Array(state.labels.enumerated()), id: \.offset) { index, label in
                        chordChip(index: index, label: label)
                    }
                }
            }
        }
    }

    private func chordChip(index: Int, label: String) -> some View {
        let symbol = ProgressionGenerator.chordText(for: label, key: state.key) ?? label
        let isSelected = selectedTransition == index
        return Button {
            // Selecting a chord selects the change *into* it, which is what a
            // transition is. The first chord has no change into it.
            selectedTransition = index == 0 ? nil : (isSelected ? nil : index)
        } label: {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textMuted)
                Text(symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
            }
            .padding(.horizontal, MelGenMetrics.space2)
            .frame(minWidth: 56, minHeight: MelGenMetrics.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: MelGenMetrics.radiusSmall)
                    .fill(isSelected ? theme.sunken : theme.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MelGenMetrics.radiusSmall)
                    .strokeBorder(isSelected ? theme.accent : theme.border,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(symbol)")
        .accessibilityHint(index == 0 ? "The first chord has no change into it"
                                      : "Selects the change into this chord")
    }

    private var mini: some View {
        MiniRoll(notes: state.notes,
                 progression: state.progression,
                 lengthBeats: state.lengthBeats,
                 theme: theme,
                 playheadBeat: audioUnit?.loopPhaseBeats)
    }

    // MARK: - Transport and generation

    private var transport: some View {
        HStack(spacing: MelGenMetrics.space2) {
            PrimaryAction(title: "New changes",
                          subtitle: state.curation.isEmpty
                              ? "instant"
                              : "instant · weighted by \(state.curation.weights.count) judged changes",
                          systemImage: "arrow.triangle.2.circlepath",
                          isWorking: false,
                          isEnabled: true,
                          theme: theme) { generate() }

            Button {
                playParameter.value = playParameter.boolValue ? 0 : 1
            } label: {
                Image(systemName: playParameter.boolValue ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: MelGenMetrics.controlHeight * 1.4,
                           height: MelGenMetrics.controlHeight)
                    .background(
                        RoundedRectangle(cornerRadius: MelGenMetrics.radiusSmall)
                            .fill(theme.raised))
                    .overlay(
                        RoundedRectangle(cornerRadius: MelGenMetrics.radiusSmall)
                            .strokeBorder(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playParameter.boolValue ? "Stop" : "Play")
        }
    }

    // MARK: - The dials

    private var dials: some View {
        VStack(alignment: .leading, spacing: MelGenMetrics.space2) {
            Eyebrow(text: "How", theme: theme)

            ChipPicker(options: [(ProgressionMode.major, "Major"), (ProgressionMode.minor, "Minor")],
                       selection: Binding(get: { state.mode },
                                          set: { state.mode = $0; generate() }),
                       theme: theme)

            LabelledSlider(title: "Surprise",
                           lowLabel: "expected",
                           highLabel: "far down the list",
                           value: $state.surprise,
                           theme: theme,
                           format: { $0.formatted(.number.precision(.fractionLength(2))) },
                           onCommit: { generate() })

            ChipPicker(options: Reharm.allCases.map { ($0, $0.rawValue.capitalized) },
                       selection: Binding(get: { state.reharm },
                                          set: { state.reharm = $0; generate() }),
                       theme: theme)

            ChipPicker(options: [(4, "4 bars"), (8, "8 bars"), (12, "12 bars"), (16, "16 bars")],
                       selection: Binding(get: { state.bars },
                                          set: { state.bars = $0; generate() }),
                       theme: theme)
        }
    }

    // MARK: - The judgement

    @ViewBuilder
    private var judgement: some View {
        VStack(alignment: .leading, spacing: MelGenMetrics.space2) {
            Eyebrow(text: "This change", theme: theme)

            if let index = selectedTransition, index > 0, index < state.labels.count {
                let from = state.labels[index - 1]
                let to = state.labels[index]
                let weight = state.curation.weight(from: from, to: to)
                Text("\(from) → \(to)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.text)
                Text(weightSentence(weight))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                HStack(spacing: MelGenMetrics.space2) {
                    verb("More of this", systemName: "hand.thumbsup") {
                        state.curation.emphasise(from: from, to: to, liked: true)
                        commit(reloadKernel: false)
                    }
                    verb("Less of this", systemName: "hand.thumbsdown") {
                        state.curation.emphasise(from: from, to: to, liked: false)
                        commit(reloadKernel: false)
                    }
                }
            } else {
                Text("Tap a chord to judge the change into it. What you decide "
                     + "outlives this progression — it is a weight on that change, "
                     + "not a rating of these eight bars.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !state.curation.isEmpty {
                CollapsibleSection(title: "What you have decided",
                                   summary: "\(state.curation.weights.count) changes",
                                   isExpanded: .constant(false),
                                   theme: theme) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(state.curation.strongest(), id: \.from) { entry in
                            Text("\(entry.from) → \(entry.to)  \(weightSentence(entry.weight))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.textMuted)
                        }
                    }
                }
            }
        }
    }

    private func verb(_ title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, minHeight: MelGenMetrics.controlHeight)
                .background(RoundedRectangle(cornerRadius: MelGenMetrics.radiusSmall).fill(theme.raised))
                .overlay(RoundedRectangle(cornerRadius: MelGenMetrics.radiusSmall)
                    .strokeBorder(theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// A multiplier read as a sentence. "1.6×" is a number; "you reach for this"
    /// is what the number means, and the number is there for anyone who wants it.
    private func weightSentence(_ weight: Double) -> String {
        let formatted = weight.formatted(.number.precision(.fractionLength(2)))
        if abs(weight - 1) < 0.01 { return "no opinion yet — the corpus decides" }
        return weight > 1 ? "you reach for this — ×\(formatted)"
                          : "you avoid this — ×\(formatted)"
    }

    // MARK: - Doing it

    private func generate() {
        state.generate(seed: UInt64.random(in: 1...UInt64.max))
        selectedTransition = nil
        commit()
    }

    private func commit(reloadKernel: Bool = true) {
        audioUnit?.update(state: state, reloadKernel: reloadKernel)
    }
}
