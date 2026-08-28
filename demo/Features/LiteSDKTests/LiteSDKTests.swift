//
//  LiteSDKTests.swift
//  bex-litesdk-demo
//

import Foundation
import SwiftUI
@_spi(Internals) import BKMExpressLiteSDK

enum LiteSDKTests {
  struct Screen: View {
    // MARK: State
    @AppStorage("lite_merchantID") var merchantID = ""
    @AppStorage("lite_merchantUserID") var merchantUserID = ""
    @AppStorage("lite_phoneNumber") var phoneNumber = ""
    @AppStorage("lite_authToken") var token = ""
    @AppStorage("lite_currency") var currency = "TRY"
    @AppStorage("lite_installmentCount") var installmentCount: Int = 1
    @AppStorage("mode") var mode: Mode = .default
    @AppStorage("lite_amount") var amount: Double?
    @AppStorage("lite_orderID") var orderId = ""
    @AppStorage("lite_paymentSecurity") var security: BKMExpressLiteSDK.BKMExpress.PaymentSecurity = .none
    @AppStorage("lite_transactionType") var transactionType: BKMExpressLiteSDK.BKMExpress.TransactionType = .sale
    @AppStorage("lite_success_url") var successUrl: String = ""
    @AppStorage("lite_error_url") var failUrl: String = ""
    @State var numberFormatter: NumberFormatter = {
      var nf = NumberFormatter()
      nf.numberStyle = .decimal
      nf.maximumFractionDigits = 2
      nf.minimumFractionDigits = 2
      nf.minimum = -999_999_999
      return nf
    }()
    @State var integerFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .none
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf
    }()
    @State var sdkInitializationInProgress = false
    @State var alert: AlertState?
    
    struct OnStartedInfo {
      let api: BKMExpress.API
      let gsmno: BKMExpress.GSMNO
      let amount: Decimal
      let security: BKMExpressLiteSDK.BKMExpress.PaymentSecurity
      let transactionType: BKMExpressLiteSDK.BKMExpress.TransactionType
      let orderId: String
      let installmentCount: Int
      let currencySymbol: String
      let successUrl: String
      let failUrl: String
    }
    var onStarted: ((OnStartedInfo) -> Void)?

    // MARK: UI
    var body: some View {
      VStack {
        Text("Uygulama şu an '\(mode.name)' modundadır.")
        
        ScrollView {
          VStack(alignment: .leading) {
            Text("Token")
              .bold()
            
            TextField("", text: $token, axis: .vertical)
              .lineLimit(5)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Merchant ID")
              .bold()
            
            TextField("", text: $merchantID)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Merchant User ID")
              .bold()
            
            TextField("", text: $merchantUserID)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Telefon Numarası")
              .bold()
            
            TextField("", text: $phoneNumber)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Order ID")
              .bold()
            
            TextField("", text: $orderId)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Tutar")
              .bold()
            
            TextField("", value: $amount, formatter: numberFormatter)
              .keyboardType(.numbersAndPunctuation)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Para Birimi")
              .bold()
            
            TextField("", text: $currency)
              .keyboardType(.alphabet)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Taksit Sayısı")
              .bold()
            
            TextField("", value: $installmentCount, formatter: integerFormatter)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          HStack {
            Text("Güvenlik Düzeyi")
              .bold()
            
            Spacer()
            
            Picker("Güvenlik Düzeyi", selection: $security) {
              ForEach(BKMExpress.PaymentSecurity.allCases, id: \.self) { kind in
                Text(kind.rawValue).tag(kind)
              }
            }
          }
          
          Divider()
          
          HStack {
            Text("İşlem Türü")
              .bold()
            
            Spacer()
            
            Picker("İşlem Türü", selection: $transactionType) {
              ForEach(BKMExpress.TransactionType.allCases, id: \.self) { kind in
                Text(kind.rawValue).tag(kind)
              }
            }
          }.padding(.bottom, 16)
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Success Url")
              .bold()
            
            TextField("", text: $successUrl)
              .textFieldStyle(.roundedBorder)
          }
          
          Divider()
          
          VStack(alignment: .leading) {
            Text("Error Url")
              .bold()
            
            TextField("", text: $failUrl)
              .textFieldStyle(.roundedBorder)
          }.padding(.bottom, 16)
          
        }
        .scrollIndicators(.hidden)

        if sdkInitializationInProgress {
          ProgressView()
        } else {
          Button("Başlat") {
            startButtonTapped()
          }
          .hubButtonStyle(backgroundColor: .bkmGold)
        }
      }
      .padding()
      .navigationTitle("Lite SDK Demo")
      .toolbarTitleDisplayMode(.inline)
      .alert(state: $alert)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Tamam") {
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder),
              to: nil,
              from: nil,
              for: nil
            )
          }
        }
      }
    }
    
    // MARK: Utilities
    private func startButtonTapped() {
      guard let number = try? BKMExpress.GSMNO(phoneNumber)
      else {
        alert = .init(
          title: "Uyarı",
          message: "Lütfen geçerli bir telefon numarası giriniz.\n\nGeçerli telefon numarası 5 ile başlamalı, sadece rakamlardan ve toplamda 10 haneden oluşmalıdır."
        )
        return
      }
      
      Task {
        sdkInitializationInProgress = true
        defer { sdkInitializationInProgress = false }
        
        guard !token.isEmpty else {
          alert = .init(
            title: "Hata!",
            message: "Lütfen bir token giriniz."
          )
          return
        }
        
        do throws(BKMExpress.Failure) {
          let api = try await BKMExpress.initialize(
            context: .init(
              authToken: token,
              merchantID: merchantID,
              merchantUserID: merchantUserID,
              gsmNo: number,
              currencyCode: currency,
              transactionType: transactionType,
              installmentCount: .init(installmentCount)!,
              mode: mode.sdkMode,
            )
          )
          if let amount {
            let decimal = Decimal(amount)
            let installment = Int(installmentCount)
            
            onStarted?(
              .init(
                api: api,
                gsmno: number,
                amount: decimal,
                security: security,
                transactionType: transactionType,
                orderId: orderId,
                installmentCount: installment,
                currencySymbol: api.currencySymbol(),
                successUrl: successUrl,
                failUrl: failUrl
              )
            )
          } else {
            alert = .init(message: "Baslatilamadi. Lütfen para miktarını girin")
          }
         
          
        } catch {
          alert = .init(message: "Baslatilamadi. Kod: \(error.code ?? -1) \n\n \(error.message) ")
        }
      }
    }
  }
}

// MARK: Extensions
private extension Mode {
  var sdkMode: BKMExpress._Mode {
    switch self {
    case .test: .test
    case .preprod: .preprod
    case .production: .production
    }
  }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview {
  NavigationStack {
    LiteSDKTests.Screen()
  }
}
#endif



