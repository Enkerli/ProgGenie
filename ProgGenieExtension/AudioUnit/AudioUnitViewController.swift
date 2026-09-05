//
//  AudioUnitViewController.swift
//  ProgGenieExtension
//
//  ProgGenie's principal class: the three things a plug-in tells the shell.
//
//  Info.plist names `$(PRODUCT_MODULE_NAME).AudioUnitViewController` as both the
//  principal class and the factory function, so this type keeps that name. The
//  lifecycle it used to hold — creating the audio unit on the main queue,
//  setting up the parameter tree before the `@AUParameterUI` properties are
//  built, hosting a SwiftUI view and pinning it to the bounds — is
//  `PluginViewController` in the shared package.
//
//  Thirty lines. That is the second half of what a sibling plug-in writes.
//

import CoreAudioKit
import SwiftUI
import Shell

@MainActor
public final class AudioUnitViewController: PluginViewController {

    public override func makeAudioUnit(componentDescription: AudioComponentDescription) throws -> PluginAudioUnit {
        try ProgGenieAudioUnit(componentDescription: componentDescription, options: [])
    }

    public override var parameterTreeSpec: ParameterTreeSpec { ProgGenieParameterSpecs }

    public override func makeRootView(parameterTree: ObservableAUParameterGroup,
                                      audioUnit: PluginAudioUnit) -> AnyView {
        AnyView(ProgGenieMainView(parameterTree: parameterTree,
                                  audioUnit: audioUnit as? ProgGenieAudioUnit))
    }
}
