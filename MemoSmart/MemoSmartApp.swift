//
//  MemoSmartApp.swift
//  MemoSmart
//
//  Created by Xingguang Wu on 16/02/25.
//

import SwiftUI
import AVFoundation

@main
struct MemoSmartApp: App {
    init() {
        // Configuriamo la sessione audio all'avvio dell'app
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Errore nella configurazione dell'audio session: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
