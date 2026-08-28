//
//  SwiftUI+Extensions.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI

struct AlertState: Identifiable {
  struct Button {
    enum Style {
      case desctructive
      case cancel
      case regular
    }
    
    let title: String
    let style: Style
    let action: (() -> Void)?
    
    init(
      title: String,
      style: Style = .regular,
      action: (() -> Void)? = {},
    ) {
      self.title = title
      self.style = style
      self.action = action
    }
  }
  
  enum Buttons {
    case single(Button)
    case double(primary: Button, secondary: Button)
  }
  
  let id: UUID
  let title: String
  let message: String
  let buttons: Buttons
  
  init(
    id: UUID = UUID(),
    title: String = "",
    message: String,
    buttons: Buttons = .single(.init(title: "Tamam"))
  ) {
    self.id = id
    self.title = title
    self.message = message
    self.buttons = buttons
  }
}

extension Alert.Button {
  static func from(state: AlertState.Button) -> Alert.Button {
    switch state.style {
    case .cancel:
      return .cancel(Text(state.title), action: state.action)
    case .desctructive:
      return .destructive(Text(state.title), action: state.action)
    case .regular:
      return .default(Text(state.title), action: state.action)
    }
  }
}

extension View {
  func alert(state binding: Binding<AlertState?>) -> some View {
    alert(item: binding) { alertState in
      switch alertState.buttons {
      case let .double(primary, secondary):
        Alert(
          title: Text(alertState.title),
          message: Text(alertState.message),
          primaryButton: .from(state: primary),
          secondaryButton: .from(state: secondary)
        )
      case let .single(button):
        Alert(
          title: Text(alertState.title),
          message: Text(alertState.message),
          dismissButton: .from(state: button)
        )
      }
    }
  }
}
