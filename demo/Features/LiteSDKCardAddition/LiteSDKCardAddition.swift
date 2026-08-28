//
//  LiteSDKCardAddition.swift
//  bex-litesdk-demo
//

import BKMExpressLiteSDK
import Combine
import SwiftUI

enum LiteSDKCardAddition {
  enum Focus {
    case number
    case cvc
  }
  
  struct AgreementState: Identifiable, Equatable {
    let id = UUID()
    let agreement: BKMExpress.Agreement
    var approved: Bool
    var attributedString: AttributedString {
      var attributedString = AttributedString(agreement.label)
      attributedString.font = .system(.body)
      if let range = attributedString.range(of: agreement.labelHighlight) {
        attributedString[range].font = .system(.body, weight: .bold)
        attributedString[range].underlineStyle = .single
      }
      return attributedString
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id && lhs.approved == rhs.approved
    }
  }
  
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
  
  struct Screen: View {
    @State var month: Int?
    @State var year: Int?
    @State var name: String = ""
    @State var alert: AlertState?
    @State var number: BKMExpress.CardNumber?
    @State var agreements: [AgreementState]
    @State var presentedAgreement: PresentedAgreement?
    
    @FocusState var focus: Focus?
    let api: BKMExpress.API
    
    let onCardsAdded: (([BKMExpress.Card]) -> Void)?
    let onVerificationRequired: ((BKMExpress.StoreCardOTP) -> Void)?
    
    init(
      api: BKMExpress.API,
      agreements: [BKMExpress.Agreement],
      onCardsAdded: (([BKMExpress.Card]) -> Void)? = nil,
      onVerificationRequired: ((BKMExpress.StoreCardOTP) -> Void)? = nil
    ) {
      self.api = api
      self.agreements = agreements.map { AgreementState(agreement: $0, approved: $0.kind == .info) }
      self.onCardsAdded = onCardsAdded
      self.onVerificationRequired = onVerificationRequired
    }
    
    var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          BKMExpressCardNumberView(
            font: .boldSystemFont(ofSize: 25),
            placeholder: "Kart numarasi",
            number: $number
          )
          .padding()
          .font(.body)
          .focused($focus, equals: .number)
          .overlay {
            Capsule(style: .circular)
              .stroke()
          }
          
          TextField("Kart ismi", text: $name)
            .padding()
            .overlay {
              Capsule(style: .circular)
                .stroke()
            }
          
          ExpiryDateTextField(month: $month, year: $year)
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
          
          Button("Kart Ekle") {
            Task {
              guard
                let number,
                let month,
                let year,
                let expiryDate = try? BKMExpress.CardExpiryDate(month: month, year: year)
              else {
                alert = .init(message: "lutfen formu eksiksiz doldurunuz.")
                return
              }
              
              do {
                let response = try await api.storeCard(
                  context: .init(
                    number: number,
                    expiryDate: expiryDate,
                    alias: name,
                  )
                )
                switch response {
                case let .added(cards):
                  onCardsAdded?(cards)
                case let .verificationRequired(otp):
                  onVerificationRequired?(otp)
                }
              } catch {
                alert = .init(message: "hata: \(error.localizedDescription)")
              }
            }
          }
          .disabled(buttonDisabled)
          .hubButtonStyle(backgroundColor: .bkmGold)
        }
      }
      .padding()
      .alert(state: $alert)
      .navigationTitle("Kart Ekleme")
      .toolbarTitleDisplayMode(.inline)
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
      .navigationDestination(item: $presentedAgreement) { presented in
        AgreementConfirmation.Screen(
          title: presented.title,
          content: presented.content
        )
      }
    }
    
    var buttonDisabled: Bool {
      number == nil
      || month == nil
      || year == nil
      || !agreements.filter(\.agreement.mandatory).allSatisfy(\.approved)
    }
    
    func approvedAgreementIDs() -> [BKMExpress.Agreement.ID] {
      agreements.filter(\.approved).map(\.agreement.id)
    }
  }
  
  struct ExpiryDateTextField: View {
    @Binding var month: Int?
    @Binding var year: Int?
    
    @State private var text: String = ""
    
    var body: some View {
      TextField("MM/YY", text: $text)
        .keyboardType(.numberPad)
        .padding()
        .overlay(Capsule().stroke())
        .onChange(of: text) { _, newValue in
          let digits = String(newValue.filter(\.isNumber).prefix(4))
          
          let now = Date()
          let calendar = Calendar.current
          let currentMonth = calendar.component(.month, from: now)
          let currentYear = calendar.component(.year, from: now)
          
          var parsedMonth: Int? =
          digits.count >= 2 ? Int(digits.prefix(2)) : nil
          
          var parsedYear: Int? =
          digits.count == 4 ? Int("20" + digits.dropFirst(2)) : nil
          
          if let m = parsedMonth,
             !(1...12).contains(m) {
            parsedMonth = currentMonth
          }
          
          if let enteredMonth = parsedMonth,
             let enteredYear = parsedYear {
            
            let enteredValue = enteredYear * 12 + enteredMonth
            let currentValue = currentYear * 12 + currentMonth
            
            if enteredValue < currentValue {
              parsedMonth = currentMonth
              parsedYear = currentYear
            }
          }
          
          let formatted: String
          
          if digits.count <= 2 {
            if let month = parsedMonth {
              formatted = String(format: "%02d", month)
            } else {
              formatted = digits
            }
          } else if let month = parsedMonth,
                    let year = parsedYear,
                    digits.count == 4 {
            
            formatted = String(
              format: "%02d/%02d",
              month,
              year % 100
            )
          } else {
            let monthPart: String
            
            if let month = parsedMonth {
              monthPart = String(format: "%02d", month)
            } else {
              monthPart = String(digits.prefix(2))
            }
            
            formatted =
            monthPart +
            "/" +
            String(digits.dropFirst(2))
          }
          
          if text != formatted {
            text = formatted
          }
          
          month = parsedMonth
          year = parsedYear
        }
    }
  }
}
