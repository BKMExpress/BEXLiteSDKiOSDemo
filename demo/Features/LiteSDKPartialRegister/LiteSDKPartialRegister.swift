//
//  LiteSDKPartialRegister.swift
//  bkm-mobile
//

import BKMExpressLiteSDK
import SwiftUI
import WebKit

enum LiteSDKPartialRegister {
  struct Screen: View {
    // MARK: State
    @State var month: Int?
    @State var year: Int?
    @State var name: String = ""
    @State var alert: AlertState?
    @State var number: BKMExpress.CardNumber?
    @State var agreements: [LiteSDKCardAddition.AgreementState]
    @State var presentedAgreement: PresentedAgreement?
    @State private var isLoading = false
    
    let api: BKMExpress.API
    let onVerificationRequired: (BKMExpress.RegisterOTP) -> Void
    let onCompleted: () -> Void
    let onBack: () -> Void
    
    struct PresentedAgreement: Identifiable, Hashable {
      let id: BKMExpress.Agreement.ID
      let title: String
      let content: AgreementWebContent
      
      init(agreement: BKMExpress.Agreement) {
        self.id = agreement.id
        self.title = agreement.title
        self.content = agreement.content.asAgreementWebContent
      }
      
      static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
      }
      
      func hash(into hasher: inout Hasher) {
        hasher.combine(id)
      }
    }
    
    init(
      api: BKMExpress.API,
      agreements: [BKMExpress.Agreement],
      onVerificationRequired: @escaping (BKMExpress.RegisterOTP) -> Void,
      onCompleted: @escaping () -> Void,
      onBack: @escaping () -> Void
    ) {
      self.api = api
      self.agreements = agreements.map {
        LiteSDKCardAddition.AgreementState(agreement: $0, approved: $0.kind == .info)
      }
      self.onVerificationRequired = onVerificationRequired
      self.onCompleted = onCompleted
      self.onBack = onBack
    }
    
    var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Partial register – güvenli kart")
              .font(.headline)
            Text("Ham kart numarası bu ekrana ulaşmaz; yalnızca şifreli token iletilir.")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          
          BKMExpressCardNumberView(
            font: .boldSystemFont(ofSize: 25),
            placeholder: "Kart numarası",
            number: $number
          )
          .padding()
          .font(.body)
          .overlay { Capsule(style: .circular).stroke() }
          .disabled(isLoading)
          
          TextField("Kart ismi", text: $name)
            .padding()
            .overlay { Capsule(style: .circular).stroke() }
            .disabled(isLoading)
          
          LiteSDKCardAddition.ExpiryDateTextField(
            month: $month,
            year: $year
          )
          .frame(maxWidth: .infinity)
          
          VStack(alignment: .leading) {
            ForEach($agreements) { model in
              let content = Text(model.wrappedValue.attributedString)
                .onTapGesture {
                  presentedAgreement = PresentedAgreement(
                    agreement: model.wrappedValue.agreement
                  )
                }
              switch model.wrappedValue.agreement.kind {
              case .agreement:
                HStack {
                  BKMExpressAgreementCheckboxView(isSelected: model.approved)
                  content
                }
              case .info:
                content
              }
            }
          }
          
          Spacer()
          
          Button("Kayıt") {
            Task { await register() }
          }
          .disabled(buttonDisabled)
          .hubButtonStyle(backgroundColor: .bkmGold)
        }
      }
      .padding()
      .alert(state: $alert)
      .navigationTitle("Partial Register")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            onBack()
          } label: {
            Image(systemName: "chevron.left")
          }
        }
      }
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Tamam") {
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder),
              to: nil, from: nil, for: nil
            )
          }
        }
      }
      .navigationDestination(item: $presentedAgreement) { presented in
        AgreementConfirmation.Screen(
          title: presented.title,
          content: presented.content
        )
      }
    }
    
    var buttonDisabled: Bool {
      number == nil ||
      month == nil ||
      year == nil ||
      isLoading ||
      !agreements.filter(\.agreement.mandatory).allSatisfy(\.approved)
    }
    
    private func register() async {
      guard
        let number,
        let month,
        let year,
        let expiryDate = try? BKMExpress.CardExpiryDate(month: month, year: year)
      else {
        alert = .init(message: "Lütfen formu eksiksiz doldurunuz.")
        return
      }
      
      isLoading = true
      defer { isLoading = false }
      
      do {
        let response = try await api.register(
          context: .init(
            number: number,
            expiryDate: expiryDate,
            alias: name.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : name.trimmingCharacters(in: .whitespaces)
          )
        )
        switch response {
        case let .verificationRequired(otp):
          onVerificationRequired(otp)
        }
      } catch {
        alert = .init(message: "Hata: \(error.localizedDescription)")
      }
    }
  }
  
  typealias AgreementState = LiteSDKCardAddition.AgreementState
}

enum AgreementWebContent: Hashable {
  case url(URL)
  case html(String)
}

extension BKMExpress.Agreement.WebContent {
  var asAgreementWebContent: AgreementWebContent {
    switch self {
    case let .url(url):
      return .url(url)
    case let .html(string):
      return .html(string)
    }
  }
}

enum AgreementConfirmation {
  struct Screen: View {
    // MARK: State
    let title: String
    let content: AgreementWebContent
    
    var body: some View {
      WebContentView(content: content)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text(title)
              .font(.headline)
              .multilineTextAlignment(.center)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .frame(width: 250)
          }
        }
    }
  }
}

struct WebContentView: UIViewRepresentable {
  let content: AgreementWebContent
  
  func makeUIView(context: Context) -> WKWebView {
    WKWebView()
  }
  
  func updateUIView(_ webView: WKWebView, context: Context) {
    switch content {
    case let .url(url):
      webView.load(URLRequest(url: url))
    case let .html(html):
      webView.loadHTMLString(html, baseURL: nil)
    }
  }
}

extension BKMExpress.Agreement.ID: @retroactive Hashable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.description == rhs.description
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(description)
  }
}
