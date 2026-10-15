import Foundation
import XCTest
@testable import HomeCore

final class LocalizationTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let portuguese = Locale(identifier: "pt_BR")

    func testCoreLabelsAndPeriodsInBothLanguages() {
        let translations = [
            "Controles": "Controls",
            "Ambiente e segurança": "Environment and safety",
            "Consumo": "Consumption",
            "Horários e rotinas": "Schedules and routines",
            "Manutenção": "Maintenance",
            "Configurações dos aparelhos": "Device settings",
            "Diagnóstico": "Diagnostics",
            "Outras leituras": "Other readings",
            "Energia consumida": "Energy consumed",
            "Potência agora": "Current power",
            "Água": "Water",
            "Gás": "Gas",
            "Medições elétricas": "Electrical measurements",
            "Outras medições": "Other measurements",
            "Ontem": "Yesterday",
            "Este mês": "This month",
            "Mês passado": "Last month",
            "Hoje": "Today",
            "Contador acumulado": "Cumulative counter"
        ]
        for (key, translation) in translations {
            XCTAssertEqual(L10n.text(key, locale: english), translation, key)
            XCTAssertEqual(L10n.text(key, locale: portuguese), key, key)
        }
    }

    func testPortugueseLocaleAliasesUseBrazilianPortuguese() {
        for identifier in ["pt-BR", "pt_BR", "pt", "pt-PT"] {
            XCTAssertEqual(L10n.text("Horários e rotinas", locale: Locale(identifier: identifier)), "Horários e rotinas", identifier)
        }
        XCTAssertEqual(L10n.text("Horários e rotinas", locale: Locale(identifier: "en-US")), "Schedules and routines")
    }

    func testUnsupportedLanguagesFallBackToEnglish() {
        for identifier in ["fr_FR", "de_DE", "es_BR", "zh-Hant-TW"] {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(L10n.text("Configurações dos aparelhos", locale: locale), "Device settings", identifier)
            XCTAssertEqual(L10n.format("Dispositivo removido: %@.", "Sala", locale: locale), "Device removed: Sala.", identifier)
        }
    }

    func testUnknownKeysRemainReadable() {
        let key = "A future key without a translation"
        for locale in [english, portuguese, Locale(identifier: "fr_FR")] {
            XCTAssertEqual(L10n.text(key, locale: locale), key)
        }
    }

    func testNumbersUseRegionalSeparatorsAndRequestedPrecision() {
        XCTAssertEqual(L10n.number(1_234.56, locale: english), "1,234.6")
        XCTAssertEqual(L10n.number(1_234.56, locale: portuguese), "1.234,6")
        XCTAssertEqual(L10n.number(21, locale: english), "21")
        XCTAssertEqual(L10n.number(21, locale: portuguese), "21")
        XCTAssertEqual(L10n.number(-21.56, maximumFractionDigits: 2, locale: portuguese), "-21,56")
        XCTAssertEqual(L10n.number(21.56, maximumFractionDigits: 0, locale: english), "22")
    }

    func testNumericRegionIsIndependentOfTranslationLanguage() {
        let englishInBrazil = Locale(identifier: "en_BR")
        XCTAssertEqual(L10n.text("Controles", locale: englishInBrazil), "Controls")
        XCTAssertEqual(L10n.number(21.5, locale: englishInBrazil), "21,5")

        let unsupportedLanguage = Locale(identifier: "de_DE")
        XCTAssertEqual(L10n.text("Controles", locale: unsupportedLanguage), "Controls")
        XCTAssertEqual(L10n.number(21.5, locale: unsupportedLanguage), "21,5")
    }

    func testFormattedMessagesPreserveNamesAndReasonsVerbatim() {
        let name = "Lâmpada 100% — Sala %@"
        let templates: [(String, String, String)] = [
            ("Reverter: %@", "Revert: \(name)", "Reverter: \(name)"),
            ("O plano repete o item %@.", "The plan contains the item \(name) more than once.", "O plano repete o item \(name)."),
            ("O cômodo de destino de %@ não existe mais.", "The destination room for \(name) no longer exists.", "O cômodo de destino de \(name) não existe mais."),
            ("Dispositivo removido: %@.", "Device removed: \(name).", "Dispositivo removido: \(name)."),
            ("Entidade removida: %@.", "Entity removed: \(name).", "Entidade removida: \(name)."),
            ("O cômodo de %@ mudou depois do inventário. Atualize o plano antes de aplicar.",
             "The room for \(name) changed after the inventory. Update the plan before applying it.",
             "O cômodo de \(name) mudou depois do inventário. Atualize o plano antes de aplicar.")
        ]
        for (key, englishMessage, portugueseMessage) in templates {
            XCTAssertEqual(L10n.format(key, name, locale: english), englishMessage, key)
            XCTAssertEqual(L10n.format(key, name, locale: portuguese), portugueseMessage, key)
        }
    }

    func testFormattedKeychainStatusPreservesItsCode() {
        let key = "Não foi possível acessar o token no Chaves do macOS (%@). Verifique o acesso e tente novamente."
        let status: Int32 = -25293
        XCTAssertEqual(L10n.format(key, String(status), locale: english), "Could not access the token in macOS Keychain (-25293). Check access and try again.")
        XCTAssertEqual(L10n.format(key, String(status), locale: portuguese), "Não foi possível acessar o token no Chaves do macOS (-25293). Verifique o acesso e tente novamente.")
    }

    func testFormatSupportsMultiplePositionalArguments() {
        // An unknown template passes through text lookup and still formats safely.
        for locale in [english, portuguese] {
            XCTAssertEqual(L10n.format("%2$@ / %1$@ (%3$d)", "A", "B", Int32(3), locale: locale), "B / A (3)")
        }
    }

    func testCoreErrorMessagesInBothLanguages() {
        let translations = [
            "Use o endereço completo, como http://homeassistant.local:8123, sem usuário, senha ou parâmetros na URL.":
                "Use the full address, such as http://homeassistant.local:8123, without a username, password, or URL parameters.",
            "O Home Assistant recusou o token. Gere outro em Perfil → Segurança → Tokens de acesso de longa duração.":
                "Home Assistant rejected the token. Create another in Profile → Security → Long-lived access tokens.",
            "Sem conexão com o Home Assistant. Verifique a rede e tente novamente.":
                "No connection to Home Assistant. Check your network and try again.",
            "O Home Assistant não respondeu a tempo. Confira o estado do aparelho antes de repetir o comando.":
                "Home Assistant did not respond in time. Check the device's state before repeating the command.",
            "A resposta do Home Assistant não pôde ser lida. Tente reconectar.":
                "The response from Home Assistant could not be read. Try reconnecting.",
            "O Home Assistant recusou a ação.": "Home Assistant rejected the action.",
            "A configuração de atualizações precisa de um feed HTTPS e de uma chave pública Ed25519 válida.":
                "The update configuration requires an HTTPS feed and a valid Ed25519 public key."
        ]
        for (key, translation) in translations {
            XCTAssertEqual(L10n.text(key, locale: english), translation, key)
            XCTAssertEqual(L10n.text(key, locale: portuguese), key, key)
        }
    }

    func testUIFormatsCountsAndPreservesRoomNamesInBothLanguages() {
        XCTAssertEqual(L10n.text("1 item de uso diário", locale: english), "1 everyday item")
        XCTAssertEqual(L10n.format("%ld itens de uso diário", 2, locale: english), "2 everyday items")
        XCTAssertEqual(L10n.format("%ld itens de uso diário", 2, locale: portuguese), "2 itens de uso diário")
        XCTAssertEqual(L10n.format("Abrir %@, %@", "Quarto 100%", "2 everyday items", locale: english), "Open Quarto 100%, 2 everyday items")
        XCTAssertEqual(L10n.format("Temperatura %@", "minimum", locale: english), "minimum temperature")
        XCTAssertEqual(L10n.format("Temperatura %@", "mínima", locale: portuguese), "Temperatura mínima")
    }

    func testServerNamesMessagesAndWireValuesRemainUnchanged() {
        // Even a server value that happens to be a translation key stays verbatim.
        let entity = HAEntity("light.sala", state: "on", attributes: ["friendly_name": .string("Controles")])
        XCTAssertEqual(entity.name, "Controles")
        XCTAssertEqual(HAError.server("Controles").errorDescription, "Controles")
        XCTAssertEqual(ServiceCall(entity, "turn_off").payload["service"], .string("turn_off"))
        XCTAssertEqual(ServiceCall(entity, "turn_off").payload["target"]?["entity_id"], .string("light.sala"))
        XCTAssertEqual(EntityPurpose.configuration.rawValue, "configuration")
    }
}
