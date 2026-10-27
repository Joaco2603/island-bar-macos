import SwiftUI

struct PageRouter: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        Group {
            switch model.page {
            case .agents: AgentsPage(model: model)
            case .music: MusicPage(model: model)
            case .timer: TimerPage(box: model.timerBox)
            case .calendar: CalendarPage(model: model, calendar: model.calendar)
            case .weather: WeatherPage(model: model)
            case .system: SystemPage(model: model)
            case .tray: TrayPage(model: model)
            case .camera: CameraPage()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
