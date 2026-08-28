//
//  DemoApp.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI

@main
struct DemoApp: App {
  var body: some Scene {
    WindowGroup {
      Home.Screen()
        .tint(Color.bkmGold)
    }
  }
}
