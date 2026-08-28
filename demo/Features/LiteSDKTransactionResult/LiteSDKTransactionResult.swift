//
//  LiteSDKTransactionResult.swift
//  bkm-mobile
//

import BKMExpressLiteSDK
import SwiftUI

enum LiteSDKTransactionResult {
  
  // MARK: Success Screen
  struct SuccessScreen: View {
    let response: BKMExpress.ControlPaymentResponse
    
    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          Text("Ödeme Sonucu")
            .font(.headline)
            .padding(.bottom, 4)
          
          Row(label: "success", value: response.success.description)
          Row(label: "message", value: response.message)
          Row(label: "code", value: response.code)
          Row(label: "posResponseMessage", value: response.posResponseMessage)
          Row(label: "successAmount", value: response.successAmount)
          Row(label: "authCode", value: response.authCode)
          Row(label: "hostRefCode", value: response.hostRefCode)
          Row(label: "procReturnCode", value: response.procReturnCode)
          Row(label: "secureType", value: String(response.secureType))
          Row(label: "transactionType", value: String(response.transactionType))
          Row(label: "installment", value: String(response.installment))
          Row(label: "terminalInformation", value: response.terminalInformation)
          Row(label: "cardBrand", value: String(response.cardBrand))
          Row(label: "cardType", value: String(response.cardType))
          Row(label: "cardNumber", value: response.cardNumber)
          Row(label: "bankTransactionDate", value: response.bankTransactionDate.description)
          Row(label: "transactionDate", value: response.transactionDate.description)
          Row(label: "paymentId", value: String(response.paymentID))
          Row(label: "hostRefNum", value: response.hostRefNum)
          Row(label: "bankTransactionId", value: response.bankTransactionID)
          Row(label: "orderId", value: response.orderID)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      }
      .navigationTitle("Ödeme Sonucu")
    }
  }
  
  // MARK: Error Screen
  struct ErrorScreen: View {
    let message: String
    
    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          Text("Ödeme Sonucu")
            .font(.headline)
            .padding(.bottom, 4)
          
          Text(message)
            .font(.body)
            .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      }
      .navigationTitle("Ödeme Sonucu")
    }
  }
  
  private struct Row: View {
    let label: String
    let value: String?
    
    var body: some View {
      Text("\(label): \(value ?? "-")")
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
