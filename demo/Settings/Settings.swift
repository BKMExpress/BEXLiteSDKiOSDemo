//
//  Settings.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI

enum Settings {
  struct Screen: View {
    @AppStorage("mode") var mode: Mode = .default
    
    var body: some View {
      VStack {
        HStack {
          Text("Uygulama Modu")
            .bold()
          
          Spacer()
          
          Picker("Uygulama Modu", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { mode in
              Text(mode.name).tag(mode)
            }
          }
        }
        
        Spacer()
      }
      .padding()
      .navigationTitle("Ayarlar")
    }
  }
}

#if DEBUG
#Preview {
  Settings.Screen()
}
#endif
