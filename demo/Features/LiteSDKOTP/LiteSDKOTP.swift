//
//  LiteSDKOTP.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI
import BKMExpressLiteSDK

enum LiteSDKOTP {
  struct Screen: View {
    @State private var otp: BKMExpress.OTPInfo
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendRemaining: Int
    
    let onVerifyButtonTapped: (String) throws -> Void
    let onResendButtonTapped: () async throws -> BKMExpress.OTPInfo
    
    init(
      otp: BKMExpress.OTPInfo,
      onVerifyButtonTapped: @escaping (String) throws -> Void,
      onResendButtonTapped: @escaping () async throws -> BKMExpress.OTPInfo
    ) {
      _otp = State(initialValue: otp)
      _resendRemaining = State(initialValue: otp.resendTimeInSeconds)
      
      self.onVerifyButtonTapped = onVerifyButtonTapped
      self.onResendButtonTapped = onResendButtonTapped
    }
    
    var body: some View {
      VStack(spacing: 24) {
        
        VStack(alignment: .leading, spacing: 8) {
          Text("SMS Doğrulama")
            .font(.title3.bold())
          
          Text("Telefon")
          Text(otp.receiver)
            .foregroundStyle(.secondary)
          
          Text("Referans No")
          Text("\(otp.referenceNumber)")
            .foregroundStyle(.secondary)
        }
        
        TextField("Kod", text: $code)
          .keyboardType(.numberPad)
          .textFieldStyle(.roundedBorder)
        
        if let errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
            .font(.caption)
        }
        
        Button {
          verify()
        } label: {
          if isLoading {
            ProgressView()
          } else {
            Text("Onayla")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(code.count != otp.length || isLoading)
        
        Button {
          resend()
        } label: {
          Text(
            resendRemaining > 0
            ? "Tekrar Gönder (\(resendRemaining)s)"
            : "Tekrar Gönder"
          )
        }
        .disabled(resendRemaining > 0 || isLoading)
        
        Spacer()
      }
      .padding()
      .task {
        await countdownLoop()
      }
    }
    
    private func verify() {
      Task {
        do {
          isLoading = true
          try onVerifyButtonTapped(code)
        } catch {
          errorMessage = error.localizedDescription
        }
        isLoading = false
      }
    }
    
    private func resend() {
      Task {
        do {
          isLoading = true
          
          let newOtp = try await onResendButtonTapped()
          
          otp = newOtp
          resendRemaining = newOtp.resendTimeInSeconds
          
        } catch {
          errorMessage = error.localizedDescription
        }
        
        isLoading = false
      }
    }
    
    private func countdownLoop() async {
      while true {
        try? await Task.sleep(for: .seconds(1))
        
        if resendRemaining > 0 {
          resendRemaining -= 1
        }
      }
    }
  }
}
