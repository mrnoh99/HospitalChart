import SwiftUI
import Supabase

@main
struct HospitalChartApp: App {
    @StateObject private var viewModel = HospitalViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.isAuthenticated {
                    MainWindowView()
                        .environmentObject(viewModel)
                } else {
                    LoginView()
                        .environmentObject(viewModel)
                }
            }
            .task { await viewModel.restoreSession() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("아주 정신과 차트 정보") {}
            }
            CommandGroup(replacing: .newItem) {}
        }
    }
}
