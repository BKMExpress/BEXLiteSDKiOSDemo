//
//  FilledButtonStyle.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI

struct HubFilledButtonStyle: ButtonStyle {
  let backgroundColor: Color
  
  func makeBody(configuration: Configuration) -> some View {
    HubFilledButtonView(
      configuration: configuration,
      backgroundColor: backgroundColor
    )
  }
}

extension View {
  func hubButtonStyle(backgroundColor: Color) -> some View {
    buttonStyle(HubFilledButtonStyle(backgroundColor: backgroundColor))
  }
}

private extension HubFilledButtonStyle {
  struct HubFilledButtonView: View {
    @Environment(\.isEnabled) var isEnabled
    
    let configuration: ButtonStyle.Configuration
    let backgroundColor: Color
    
    var body: some View {
      let label = configuration.label
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .padding()
        .foregroundColor(.white)
        .contentShape(Rectangle())
      
      let color = isEnabled ? backgroundColor: backgroundColor.opacity(0.4)
      let shape = RoundedRectangle(cornerRadius: 12)
      
      if #available(iOS 26.0, *) {
        return label
          .glassEffect(.regular.tint(color).interactive(), in: shape)
      } else {
        return label
          .background(shape.fill(color))
          .scaleEffect(configuration.isPressed ? 0.95: 1)
      }
    }
  }
}
