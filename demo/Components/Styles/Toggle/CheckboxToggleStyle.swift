//
//  CheckboxToggleStyle.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack {
        Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
          .resizable()
          .frame(width: 20, height: 20)
          .foregroundStyle(configuration.isOn ? Color.bkmGold : .secondary)
          .font(.system(size: 20))
        
        configuration.label
      }
    }
    .buttonStyle(.plain)
  }
}

extension View {
  func checkboxToggleStyle() -> some View {
    self.toggleStyle(CheckboxToggleStyle())
  }
}

#Preview {
  @Previewable @State var isOn = false
  
  Toggle(isOn: $isOn) {
    
    Text("hello")
      .onTapGesture {
        
      }
  }
  .checkboxToggleStyle()
}
