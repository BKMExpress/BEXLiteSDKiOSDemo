//
//  Models+Extensions.swift
//  bex-litesdk-demo
//

@_spi(Internals) import BKMExpressLiteSDK
import Foundation

extension Mode {
  static var `default`: Self {
    .test
  }
  
  var name: String {
    switch self {
    case .test: "Test"
    case .preprod: "Preprod"
    case .production: "Production"
    }
  }
}
