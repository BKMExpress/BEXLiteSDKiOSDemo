//
//  Home.swift
//  bex-litesdk-demo
//

@_spi(Internals) import BKMExpressLiteSDK
import Foundation
import SwiftUI

enum Home {
  struct HashableWrapper<A>: Hashable {
    private let id = UUID()
    let content: A
    
    init(content: A) {
      self.content = content
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  enum Destination: Hashable {
    struct LiteSdkListing: Hashable {
      let id = UUID()
      let api: BKMExpressLiteSDK.BKMExpress.API
      let number: BKMExpressLiteSDK.BKMExpress.GSMNO
      let amount: Decimal
      let security: BKMExpressLiteSDK.BKMExpress.PaymentSecurity
      let transactionType: BKMExpressLiteSDK.BKMExpress.TransactionType
      let orderId: String
      let installmentCount: Int
      let currencySymbol: String
      let successUrl: String
      let failUrl: String
      
      func hash(into hasher: inout Hasher) {
        hasher.combine(id)
      }
      
      static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
      }
    }
    
    struct LiteSdkCardAddition: Hashable {
      let id = UUID()
      let api: BKMExpressLiteSDK.BKMExpress.API
      
      func hash(into hasher: inout Hasher) {
        hasher.combine(id)
      }
      
      static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
      }
    }
    
    struct LiteSdkPartialRegister: Hashable {
      let id = UUID()
      let api: BKMExpressLiteSDK.BKMExpress.API
      
      func hash(into hasher: inout Hasher) { hasher.combine(id) }
      static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }
    
    case liteSdkPartialRegister(LiteSdkPartialRegister)
    
    struct LiteSDKTransactionSuccess: Hashable {
      let id = UUID()
      let response: BKMExpressLiteSDK.BKMExpress.ControlPaymentResponse
      
      func hash(into hasher: inout Hasher) { hasher.combine(id) }
      static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }
    
    struct LiteSDKTransactionError: Hashable {
      let id = UUID()
      let message: String
      
      func hash(into hasher: inout Hasher) { hasher.combine(id) }
      static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }
    
    case liteSDKTransactionSuccess(LiteSDKTransactionSuccess)
    case liteSDKTransactionError(LiteSDKTransactionError)
    
    struct LiteSdkOTP: Hashable {
      enum Kind {
        case addCard(BKMExpressLiteSDK.BKMExpress.StoreCardOTP)
        case link(BKMExpressLiteSDK.BKMExpress.LinkOTP)
        case payment(BKMExpressLiteSDK.BKMExpress.PaymentOTP, api: BKMExpressLiteSDK.BKMExpress.API)
        case register(BKMExpressLiteSDK.BKMExpress.RegisterOTP)
      }
      
      let id = UUID()
      let kind: Kind
      
      func hash(into hasher: inout Hasher) {
        hasher.combine(id)
      }
      
      static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
      }
    }
    
    struct LiteSDKPaymentChecker {
      let token: BKMExpressLiteSDK.BKMExpress.PaymentToken
      let api: BKMExpressLiteSDK.BKMExpress.API
    }
    
    struct LiteSDKTDS {
      let tds: BKMExpressLiteSDK.BKMExpress.TDSInfo
      let api: BKMExpressLiteSDK.BKMExpress.API
    }
    
    case settings
    case liteSdkTests
    case liteSdkCardListing(LiteSdkListing)
    case liteSdkOTP(LiteSdkOTP)
    case liteSdkCardAddition(LiteSdkCardAddition)
    case liteSDKTDS(HashableWrapper<LiteSDKTDS>)
    case liteSDKPaymentChecker(HashableWrapper<LiteSDKPaymentChecker>)
  }
  
  struct Screen: View {
    // MARK: State
    @AppStorage("mode") var mode: Mode = .default
    @State var path: [Destination] = []
    
    // MARK: UI
    var body: some View {
      NavigationStack(path: $path) {
        LiteSDKTests.Screen(
          onStarted: { info in
            path.append(
              .liteSdkCardListing(
                .init(
                  api: info.api,
                  number: info.gsmno,
                  amount: info.amount,
                  security: info.security,
                  transactionType: info.transactionType,
                  orderId: info.orderId,
                  installmentCount: info.installmentCount,
                  currencySymbol: info.currencySymbol,
                  successUrl: info.successUrl,
                  failUrl: info.failUrl
                )
              )
            )
          }
        )
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              path.append(.settings)
            } label: {
              Image(systemName: "gear")
            }
          }
        }
        .navigationDestination(for: Destination.self) { destination in
          switch destination {
          case .liteSdkTests:
            LiteSDKTests.Screen(
              onStarted: { info in
                path.append(
                  .liteSdkCardListing(
                    .init(
                      api: info.api,
                      number: info.gsmno,
                      amount: info.amount,
                      security: info.security,
                      transactionType: info.transactionType,
                      orderId: info.orderId,
                      installmentCount: info.installmentCount,
                      currencySymbol: info.currencySymbol,
                      successUrl: info.successUrl,
                      failUrl: info.failUrl
                    )
                  )
                )
              }
            )
            
          case .settings:
            Settings.Screen()
          case let .liteSdkOTP(data):
            switch data.kind {
            case let .addCard(otp):
              LiteSDKOTP.Screen(
                otp: otp.info,
                onVerifyButtonTapped: { code in
                  Task { @MainActor in
                    _ = try await otp.verify(code: code)
                    popToLiteSDKCardSelection()
                  }
                },
                onResendButtonTapped: {
                  try await otp.resend()
                }
              )
            case let .link(otp):
              LiteSDKOTP.Screen(
                otp: otp.info,
                onVerifyButtonTapped: { code in
                  Task { @MainActor in
                    _ = try await otp.verify(code: code)
                    popToLiteSDKCardSelection()
                  }
                },
                onResendButtonTapped: {
                  try await otp.resend()
                }
              )
              
            case let .payment(otp, api):
              LiteSDKOTP.Screen(
                otp: otp.info,
                onVerifyButtonTapped: { code in
                  Task { @MainActor in
                    let token = try await otp.verify(code: code)
                    path.append(
                      .liteSDKPaymentChecker(
                        .init(content: .init(token: token, api: api))
                      )
                    )
                  }
                },
                onResendButtonTapped: {
                  try await otp.resend()
                }
              )
            case let .register(otp):
              LiteSDKOTP.Screen(
                otp: otp.info,
                onVerifyButtonTapped: { code in
                  Task { @MainActor in
                    _ = try await otp.verify(code: code)
                    popToLiteSDKCardSelection()
                  }
                },
                onResendButtonTapped: {
                  try await otp.resend()
                }
              )
            }
            
          case let .liteSDKPaymentChecker(context):
            LiteSDKPaymentChecker.Screen(
              token: context.content.token,
              api: context.content.api,
              onBack: {
                popToLiteSDKTests()
              },
              onCompleted: { response in
                guard let testsIndex = path.firstIndex(where: {
                  if case .liteSdkTests = $0 { return true }
                  return false
                }) else { return }
                path = Array(path[...testsIndex])
                path.append(.liteSDKTransactionSuccess(.init(response: response)))
              },
              onFailure: { error in
                guard let testsIndex = path.firstIndex(where: {
                  if case .liteSdkTests = $0 { return true }
                  return false
                }) else { return }
                path = Array(path[...testsIndex])
                path.append(
                  .liteSDKTransactionError(
                    .init(
                      message: error.message
                    )
                  )
                )
              }
            )
            .navigationBarBackButtonHidden(true)
            
          case let .liteSDKTransactionSuccess(data):
            LiteSDKTransactionResult.SuccessScreen(response: data.response)
              .navigationBarBackButtonHidden(false)
            
          case let .liteSDKTransactionError(data):
            LiteSDKTransactionResult.ErrorScreen(
              message: data.message
            )
            .navigationBarBackButtonHidden(false)
            
          case let .liteSdkCardListing(data):
            LiteSDKCardSelection.Screen(
              api: data.api,
              number: data.number,
              amount: data.amount,
              currencySymbol: data.currencySymbol,
              security: data.security,
              transactionType: data.transactionType,
              orderId: data.orderId,
              installmentCount: data.installmentCount,
              successUrl: data.successUrl,
              failUrl: data.failUrl,
              onCardAdditionTapped: {
                path.append(.liteSdkCardAddition(.init(api: data.api)))
              },
              onBKMExpressLinkTapped: { otp in
                path.append(.liteSdkOTP(.init(kind: .link(otp))))
              },
              onPaymentTDSRequired: { tds in
                path.append(.liteSDKTDS(.init(content: .init(tds: tds, api: data.api))))
              },
              onCheckRequired: { token in
                _ = path.popLast()
                path.append(.liteSDKPaymentChecker(.init(content: .init(token: token, api: data.api))))
              },
              onPaymentOTPRequired: { otp in
                path.append(.liteSdkOTP(.init(kind: .payment(otp, api: data.api))))
              },
              onPartialRegisterRequired: {
                path.append(.liteSdkPartialRegister(.init(api: data.api)))
              },
              onBack: {
                popToLiteSDKTests()
              }
            )
            
          case let .liteSDKTDS(info):
            LiteSDKTds.Screen(
              token: info.content.tds.paymentToken,
              api: info.content.api,
              htmlForm: info.content.tds.htmlForm!,
              tdsURL: info.content.tds.tdsURL!,
              onCompleted: { response in
                guard let testsIndex = path.firstIndex(where: {
                  if case .liteSdkTests = $0 { return true }
                  return false
                }) else { return }
                path = Array(path[...testsIndex])
                path.append(.liteSDKTransactionSuccess(.init(response: response)))
              },
              onError: { message in
                guard let testsIndex = path.firstIndex(where: {
                  if case .liteSdkTests = $0 { return true }
                  return false
                }) else { return }
                path = Array(path[...testsIndex])
                path.append(
                  .liteSDKTransactionError(
                    .init(
                      message: message
                    )
                  )
                )
              },
              onCancel: {
                popToLiteSDKCardSelection()
              },
              allowSslErrors: true
            )
            
          case let .liteSdkCardAddition(data):
            LiteSDKCardAddition.Screen(
              api: data.api,
              agreements: data.api.pendingAgreements(),
              onCardsAdded: { cards in
                popToLiteSDKCardSelection()
              },
              onVerificationRequired: { otp in
                path.append(.liteSdkOTP(.init(kind: .addCard(otp))))
              }
            )
          case let .liteSdkPartialRegister(data):
            LiteSDKPartialRegister.Screen(
              api: data.api,
              agreements: data.api.pendingAgreements(),
              onVerificationRequired: { otp in
                path.append(.liteSdkOTP(.init(kind: .register(otp))))
              },
              onCompleted: {
                popToLiteSDKCardSelection()
              },
              onBack: {
                popToLiteSDKTests()
              }
            )
          }
        }
      }
    }
    
    private func popToLiteSDKCardSelection() {
      let firstIndex = path.firstIndex {
        guard case .liteSdkCardListing = $0
        else { return false }
        return true
      }
      
      guard let firstIndex else { return }
      path = Array(path[...firstIndex])
    }
    
    private func popToLiteSDKTests() {
      path = []
    }
  }
}

#if DEBUG
#Preview {
  Home.Screen()
}
#endif
