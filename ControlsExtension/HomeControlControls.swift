import AppIntents
import HomeCore
import SwiftUI
import WidgetKit

@main
struct HomeControlControlsBundle: WidgetBundle {
    var body: some Widget {
        HomeControlsWidget()
        HomeClimateWidget()
        if #available(macOS 26.0, *) {
            FavoritePowerControl()
            FavoriteSceneControl()
        }
    }
}

@available(macOS 26.0, *)
struct FavoritePowerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "br.com.homecontrol.favoritePower", provider: FavoriteProvider<SelectPowerFavoriteIntent>(kind: .toggle)) { state in
            ControlWidgetToggle(state.name, isOn: state.favorite?.isOn ?? false,
                                action: SetHomeFavoritePowerIntent(favorite: state.selection)) { on in
                Label(on ? "On" : "Off", systemImage: state.symbol)
            }.disabled(!state.available).privacySensitive()
        }
        .displayName("Favorite switch")
        .description("Turn a favorite light, switch or fan on and off.")
        .promptsForUserConfiguration()
    }
}

@available(macOS 26.0, *)
struct FavoriteSceneControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "br.com.homecontrol.favoriteScene", provider: FavoriteProvider<SelectSceneFavoriteIntent>(kind: .scene)) { state in
            ControlWidgetButton(action: ActivateHomeFavoriteIntent(favorite: state.selection)) {
                Label(state.name, systemImage: "sparkles")
            }.disabled(!state.available).privacySensitive()
        }
        .displayName("Favorite scene")
        .description("Activate a favorite Home Assistant scene.")
        .promptsForUserConfiguration()
    }
}

@available(macOS 26.0, *)
private protocol FavoriteSelection: ControlConfigurationIntent { var favorite: HomeFavoriteEntity? { get } }
@available(macOS 26.0, *)
extension SelectPowerFavoriteIntent: FavoriteSelection {}
@available(macOS 26.0, *)
extension SelectSceneFavoriteIntent: FavoriteSelection {}

@available(macOS 26.0, *)
private struct FavoriteState {
    let selection: HomeFavoriteEntity
    let favorite: FavoriteControl?
    let available: Bool
    var name: String { favorite?.name ?? selection.name }
    var symbol: String { favorite?.symbol ?? "star" }
}

@available(macOS 26.0, *)
private struct FavoriteProvider<Configuration: FavoriteSelection>: AppIntentControlValueProvider {
    var kind: FavoriteControlKind? = nil
    private var placeholder: HomeFavoriteEntity {
        HomeFavoriteEntity(FavoriteControl(entity: HAEntity("sensor.preview", state: "unknown", attributes: ["friendly_name": .string(String(localized: "Favorite"))]), serverID: "preview"))
    }
    func previewValue(configuration: Configuration) -> FavoriteState {
        FavoriteState(selection: configuration.favorite ?? placeholder, favorite: nil, available: false)
    }
    func currentValue(configuration: Configuration) async throws -> FavoriteState {
        let snapshot = try ControlSharedStore.configured()?.read()
        let favorite = snapshot?.favorites.first {
            $0.id == configuration.favorite?.id && (kind == nil || $0.kind == kind)
        }
        return FavoriteState(selection: configuration.favorite ?? placeholder, favorite: favorite,
                             available: snapshot.map { ControlSharedStore.isFresh($0) } == true && favorite?.available == true)
    }
}
