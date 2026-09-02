//
//  LiteSDKCardSelection.swift
//  bex-litesdk-demo
//

import BKMExpressLiteSDK
import SwiftUI

enum LiteSDKCardSelection {
  enum Card: Identifiable, Equatable {
    struct InternalCard: Hashable {
      let cardID: BKMExpress.Card.ID
      let name: String
      let number: String
    }

    struct BexCard: Equatable {
      static func == (lhs: BexCard, rhs: BexCard) -> Bool {
        lhs.rawValue.id == rhs.rawValue.id
      }

      let rawValue: BKMExpress.Card

      var id: BKMExpress.Card.ID {
        rawValue.id
      }
    }

    case internalCard(InternalCard)
    case bex(BexCard)

    var id: BKMExpress.Card.ID {
      switch self {
        case let .internalCard(card): card.cardID
        case let .bex(card): card.id
      }
    }

    var cardId: BKMExpress.Card.ID? {
      switch self {
        case .internalCard: return nil
        case let .bex(card): return card.id
      }
    }
  }

  struct Screen: View {
    @State var cards: [Card] = []
    @State var canLinkBex: Bool = false
    @State var showsAddCard: Bool = false
    @State var alert: AlertState?
    @State var loadingCardId: BKMExpress.Card.ID?
    @State private var selectedCardId: BKMExpress.Card.ID? = nil
    @State private var deletingCardId: BKMExpress.Card.ID? = nil

    let api: BKMExpress.API
    let number: BKMExpress.GSMNO
    let amount: Decimal
    let currencySymbol: String
    let security: BKMExpress.PaymentSecurity
    let transactionType: BKMExpress.TransactionType
    let orderId: String
    let installmentCount: Int
    let successUrl: String
    let failUrl: String

    let onCardAdditionTapped: () -> Void
    let onBKMExpressLinkTapped: (BKMExpress.LinkOTP) -> Void
    let onPaymentTDSRequired: (BKMExpress.TDSInfo) -> Void
    let onCheckRequired: (BKMExpress.PaymentToken) -> Void
    let onPaymentOTPRequired: (BKMExpress.PaymentOTP) -> Void
    let onPartialRegisterRequired: () -> Void
    let onBack: () -> Void

    init(
      api: BKMExpress.API,
      number: BKMExpress.GSMNO,
      amount: Decimal,
      currencySymbol: String,
      security: BKMExpress.PaymentSecurity,
      transactionType: BKMExpress.TransactionType,
      orderId: String,
      installmentCount: Int,
      successUrl: String,
      failUrl: String,
      onCardAdditionTapped: @escaping () -> Void,
      onBKMExpressLinkTapped: @escaping (BKMExpress.LinkOTP) -> Void,
      onPaymentTDSRequired: @escaping (BKMExpress.TDSInfo) -> Void,
      onCheckRequired: @escaping (BKMExpress.PaymentToken) -> Void,
      onPaymentOTPRequired: @escaping (BKMExpress.PaymentOTP) -> Void,
      onPartialRegisterRequired: @escaping () -> Void,
      onBack: @escaping () -> Void
    ) {
      self.api = api
      self.number = number
      self.onCardAdditionTapped = onCardAdditionTapped
      self.onBKMExpressLinkTapped = onBKMExpressLinkTapped
      self.onPaymentTDSRequired = onPaymentTDSRequired
      self.onCheckRequired = onCheckRequired
      self.onPaymentOTPRequired = onPaymentOTPRequired
      self.amount = amount
      self.currencySymbol = currencySymbol
      self.security = security
      self.transactionType = transactionType
      self.orderId = orderId
      self.installmentCount = installmentCount
      self.successUrl = successUrl
      self.failUrl = failUrl
      self.onPartialRegisterRequired = onPartialRegisterRequired
      self.onBack = onBack
    }

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          (Text("ORDER ID: ")
            .fontWeight(.semibold) +
           Text(orderId)
          )
          .font(.subheadline)

          Text("Kart listesi (\(cards.filter { $0.cardId != nil }.count))")
            .font(.subheadline.weight(.semibold))

          if showsAddCard {
            Button("Kart Ekle") { onCardAdditionTapped() }
              .buttonStyle(.borderedProminent)
              .frame(maxWidth: .infinity)
          }

          if canLinkBex {
            Button {
              Task {
                let response = try await api.linkAccount()
                switch response {
                  case .recheck:
                    await checkBKMExpress()
                  case let .verificationRequired(otp):
                    onBKMExpressLinkTapped(otp)
                }
              }
            } label: {
              Text("BKM Express hesabınızı bağlayın")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }

          if cards.isEmpty {
            Text("Ekli kartınız bulunmamaktadır.")
              .font(.subheadline)
              .foregroundColor(.secondary)
          } else {
            ForEach(cards, id: \.id) { card in
              cardRow(for: card)
            }
          }
        }.padding(16)
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          guard let cardId = selectedCardId,
                let card = bexCard(withId: cardId) else { return }
          Task { await payWithCard(card: card) }
        } label: {
          Text("\(currencySymbol) \(amount.formatted()) Öde (\(security.displayText()))")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedCardId == nil)
        .padding()
        .background(.regularMaterial)
      }
      .navigationTitle("SDK Akışı")
      .navigationBarTitleDisplayMode(.inline)
      .alert(state: $alert)
      .onAppear {
        Task {
          await checkBKMExpress()
        }
      }
      .onChange(of: cards) { _, newCards in
        autoSelectFirstCardIfNeeded(from: newCards)
      }
    }

    @ViewBuilder
    private func cardRow(for card: Card) -> some View {
      switch card {
        case let .internalCard(internalCard):
          VStack(alignment: .leading, spacing: 2) {
            Text(internalCard.name).font(.subheadline.weight(.semibold))
            Text(internalCard.number).font(.caption).foregroundColor(.secondary)
          }
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color(UIColor.secondarySystemBackground))
          )

        case let .bex(bexCard):
          let isSelected = selectedCardId == bexCard.id
          let isDeletingThis = deletingCardId == bexCard.id

          HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
              Text(bexCard.rawValue.alias.isEmpty
                   ? "BKM Express"
                   : bexCard.rawValue.alias)
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.primary)
              Text(bexCard.rawValue.maskedCardNumber)
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
                .padding(.trailing, 8)
            }

            Button {
              deleteCard(bexCard: bexCard)
            } label: {
              if isDeletingThis {
                ProgressView().frame(width: 24, height: 24)
              } else {
                Image(systemName: "trash")
                  .font(.system(size: 18))
                  .foregroundColor(Color(UIColor.label).opacity(0.6))
              }
            }
            .buttonStyle(.plain)
            .disabled(deletingCardId != nil)
            .frame(width: 44, height: 44)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 14)
          .frame(maxWidth: .infinity)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color(UIColor.secondarySystemBackground))
          )
          .contentShape(Rectangle())
          .onTapGesture {
            guard loadingCardId == nil, deletingCardId == nil else { return }
            selectedCardId = bexCard.id
          }
          .animation(.easeInOut(duration: 0.15), value: isSelected)
      }
    }

      // MARK: - Helpers
    private func autoSelectFirstCardIfNeeded(from newCards: [Card]) {
      let bexIds = newCards.compactMap { $0.cardId }
      if selectedCardId == nil {
        selectedCardId = bexIds.first
      } else if !bexIds.contains(where: { $0 == selectedCardId }) {
        selectedCardId = bexIds.first
      }
    }

    private func bexCard(withId id: BKMExpress.Card.ID) -> Card.BexCard? {
      for card in cards {
        if case let .bex(b) = card, b.id == id { return b }
      }
      return nil
    }

      // MARK: - API calls
    private func checkBKMExpress() async {
      do {
        let response = try await api.checkStatus()
        switch response {
          case let .linked(bexCards):
            cards = bexCards
              .map { Card.BexCard(rawValue: $0) }
              .map(Card.bex)
            canLinkBex = false
            showsAddCard = true
            autoSelectFirstCardIfNeeded(from: cards)

          case .unlinked:
            canLinkBex = true
            showsAddCard = false

          case .unregistered:
            canLinkBex = false
            showsAddCard = false
            onPartialRegisterRequired()
        }
      } catch {
        alert = .init(message: "BKM Express hatası: \(error.localizedDescription)")
      }
    }

    private func deleteCard(bexCard: Card.BexCard) {
      let cardId = bexCard.id
      deletingCardId = cardId

      Task {
        do {
          let response = try await api.deleteCard(id: cardId)
          switch response {
            case let .cardDeleted(returnedCards):
              await MainActor.run {
                deletingCardId = nil
                cards = (returnedCards)
                  .map { Card.BexCard(rawValue: $0) }
                  .map(Card.bex)

                autoSelectFirstCardIfNeeded(from: cards)
              }
            case .accountDeleted:
              deletingCardId = nil
              alert = .init(
                message: "BKM Express Üyeliğiniz İsteğiniz Üzerine Sonlandırılmıştır.",
                buttons: .single(
                  .init(
                    title: "Tamam",
                    action: {
                      onBack()
                    }
                  )
                )
              )
          }

        } catch {
          await MainActor.run {
            deletingCardId = nil
            alert = .init(message: "Kart silinemedi: \(error.localizedDescription)")
          }
        }
      }
    }

    private func payWithCard(card: Card.BexCard) async {
      loadingCardId = card.id
      defer { loadingCardId = nil }

      do {
        let response = try await api.startPayment(
          context: .init(
            cardID: card.rawValue.id,
            security: security,
            transactionType: transactionType,
            amount: amount,
            orderID: orderId,
            date: Date(),
            transactionID: UUID(),
            installmentCount: .init(installmentCount)!,
            successUrl: successUrl,
            failUrl: failUrl
          )
        )

        switch response {
          case let .tds(tds):
            guard
              let _ = tds.tdsURL,
              let _ = tds.htmlForm
            else {
              alert = .init(message: "BKM Express hatası: \(tds.message)")
              return
            }
            onPaymentTDSRequired(tds)
          case let .otp(otp):
            onPaymentOTPRequired(otp)
          case let .control(token):
            onCheckRequired(token)
        }
      } catch {
        alert = .init(message: "BKM Express hatası: \(error.localizedDescription)")
      }
    }
  }
}

fileprivate extension BKMExpress.PaymentSecurity {
  func displayText() -> String{
    switch self {
        case .tds:
        "TDS"
        case .otp:
        "OTP"
        case .none:
        "NONE"
        @unknown default:
        fatalError()
        }
    }
}