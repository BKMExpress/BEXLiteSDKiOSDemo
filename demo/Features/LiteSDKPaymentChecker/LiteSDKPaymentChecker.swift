//
//  LiteSDKPaymentChecker.swift
//  bex-litesdk-demo
//

import BKMExpressLiteSDK
import Foundation
import SwiftUI

enum LiteSDKPaymentChecker {
  struct Screen: View {
    let token: BKMExpress.PaymentToken
    let api: BKMExpress.API
    
    let onBack: () -> Void
    let onCompleted: (BKMExpress.ControlPaymentResponse) -> Void
    let onFailure: (BKMExpress.Failure) -> Void
    
    // MARK: State
    @State private var isLoading = true
    @State private var errorState: ErrorState? = nil
    @State private var onBackProcess: Bool = false
    
    struct ErrorState {
      let message: String
    }
    
    var body: some View {
      Group {
        if isLoading {
          VStack(spacing: 12) {
            ProgressView()
              .progressViewStyle(.circular)
            Text("Ödeme kontrol ediliyor...")
          }
          
        } else if let error = errorState {
          TransactionResultErrorView(error: error)
        }
      }
      .navigationTitle("Ödeme Sonucu")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            onBackProcess = true
            onBack()
          } label: {
            Image(systemName: "chevron.left")
          }
        }
      }
      .navigationBarBackButtonHidden(true)
      .task {
        do throws(BKMExpress.Failure) {
          let response = try await api.controlPayment(token: token, maxAttempts: 4)
          isLoading = false
          onCompleted(response)
        } catch(let error) {
          guard !onBackProcess else { return }
          isLoading = false
          errorState = ErrorState(
            message: error.message
          )
          onFailure(error)
        }
      }
    }
  }
  
  private struct TransactionResultErrorView: View {
    let error: Screen.ErrorState
    
    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        Text("Ödeme Sonucu")
          .font(.headline)
          .padding(.horizontal)
          .padding(.vertical, 12)
        
        Text(error.message)
          .foregroundColor(.red)
          .padding(.horizontal)
          .padding(.bottom, 12)
        
        Divider()
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
