import SwiftUI
import HomeCore

struct SetupView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var address = ""
    @State private var token = ""
    @FocusState private var focusedField: Field?
    private enum Field { case address, token }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "house").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(Palette.accent).padding(.top, 4)
                    Text(store.phase == .connected ? "Sua casa está conectada." : "Sua casa, a um clique.")
                        .font(.system(size: 29, weight: .medium, design: .rounded)).tracking(-0.6)
                    Text("Conecte o Home Assistant e controle seus aparelhos pela barra de menus.")
                        .font(.system(size: 13)).lineSpacing(4).foregroundStyle(Palette.secondary)
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("Endereço do Home Assistant").font(.system(size: 12, weight: .medium))
                    TextField("", text: $address)
                        .textFieldStyle(.plain).font(.system(size: 13)).padding(13)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                        .modifier(GlassSurface(radius: 10))
                        .overlay(alignment: .leading) {
                            if address.isEmpty {
                                Text(verbatim: "http://homeassistant.local:8123").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                                    .padding(.horizontal, 13).allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
                        .focused($focusedField, equals: .address).onSubmit { focusedField = .token }
                        .accessibilityLabel("Endereço do Home Assistant")
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("Token de acesso").font(.system(size: 12, weight: .medium))
                    SecureField("", text: $token)
                        .textFieldStyle(.plain).font(.system(size: 13)).padding(13)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                        .modifier(GlassSurface(radius: 10))
                        .overlay(alignment: .leading) {
                            if token.isEmpty {
                                Text(store.serverAddress.isEmpty ? "Cole seu token de longa duração" : "Deixe vazio para usar o token salvo")
                                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                                    .padding(.horizontal, 13).allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
                        .focused($focusedField, equals: .token).onSubmit(connect)
                        .accessibilityLabel("Token de acesso")
                    Text("Crie em Perfil → Segurança → Tokens de acesso de longa duração, no seu Home Assistant.")
                        .font(.system(size: 11)).lineSpacing(3).foregroundStyle(Palette.secondary)
                    Label("Seu token fica no Chaves deste Mac.", systemImage: "lock")
                        .font(.system(size: 11)).foregroundStyle(Palette.accent).padding(.top, 3)
                }
                Button(action: connect) {
                    HStack(spacing: 8) {
                        if store.isConnecting { ProgressView().controlSize(.small).tint(Palette.background) }
                        Text(store.isConnecting ? "Conectando…" : "Conectar ao Home Assistant")
                    }.font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity)
                }.buttonStyle(TactileButtonStyle(prominent: true)).disabled(store.isConnecting || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button {
                    token = ""
                    if store.entities.isEmpty || store.phase == .disconnected { store.useDemo() }
                    else { store.showSettings = false }
                } label: {
                    Text(store.entities.isEmpty ? "Explorar demonstração" : "Voltar aos controles").font(.system(size: 12)).frame(maxWidth: .infinity)
                }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                if !store.serverAddress.isEmpty {
                    HStack {
                        Text("\(store.entities.count) dispositivos compatíveis").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        Spacer()
                        Button("Esquecer conexão") { store.forgetConnection(); token = ""; address = "" }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Palette.secondary)
                    }
                }
                if let notice = store.metadataNotice { Text(notice).font(.system(size: 11)).foregroundStyle(Palette.secondary) }
            }.padding(.horizontal, 26).padding(.bottom, 24)
        }.scrollIndicators(.hidden).onAppear { address = store.serverAddress }
            .onChange(of: store.phase) { _, value in if value == .connected { token = "" } }
    }
    private func connect() {
        guard !store.isConnecting else { return }
        if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.serverAddress.isEmpty {
            store.connectUsingSavedToken(address: address)
        } else { store.connect(address: address, token: token) }
    }
}
