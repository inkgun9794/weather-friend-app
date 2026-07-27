import WidgetKit
import SwiftUI

// Must match kWidgetAppGroupId in the Flutter side (weather_widget_service.dart)
// and the App Group enabled on BOTH the Runner target and this widget target.
private let appGroupId = "group.com.weatherfriend.app"

// MARK: - Timeline entry

struct WeatherEntry: TimelineEntry {
    let date: Date
    let city: String
    let temp: String
    let condition: String   // clear | cloudy | rain | snow
    let isDay: Bool
    let precip: String
    let outfit: [String]    // native image keys, e.g. ["coat","scarf","umbrella"]
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), city: "서울", temp: "23°",
                     condition: "clear", isDay: true,
                     precip: "강수 20%", outfit: ["polo", "shirt_1", "umbrella"])
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        // The widget renders whatever the app last wrote. Fresh data arrives via
        // HomeWidget.updateWidget() from the app; here we just schedule a redraw
        // in ~30 min as a safety net.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [readEntry()], policy: .after(next)))
    }

    private func readEntry() -> WeatherEntry {
        let d = UserDefaults(suiteName: appGroupId)
        return WeatherEntry(
            date: Date(),
            city: d?.string(forKey: "city") ?? "날씨",
            temp: d?.string(forKey: "temp") ?? "--°",
            condition: d?.string(forKey: "condition") ?? "clear",
            isDay: (d?.object(forKey: "isDay") as? Bool) ?? true,
            precip: d?.string(forKey: "precip") ?? "",
            outfit: (d?.string(forKey: "outfit") ?? "")
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}

// MARK: - View

struct WeatherWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.city)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(entry.temp)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                if !entry.precip.isEmpty {
                    Text(entry.precip)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer(minLength: 0)
                if !entry.outfit.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.outfit.prefix(3), id: \.self) { key in
                            if let img = UIImage(named: "oc_\(key)") {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                VStack {
                    Image(systemName: symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 40))
                    Spacer()
                }
            }
        }
        .widgetBackground(gradient)
    }

    private var symbolName: String {
        switch entry.condition {
        case "rain": return "cloud.rain.fill"
        case "snow": return "cloud.snow.fill"
        case "cloudy": return "cloud.fill"
        default: return entry.isDay ? "sun.max.fill" : "moon.stars.fill"
        }
    }

    private var gradient: LinearGradient {
        let colors: [Color]
        switch entry.condition {
        case "rain", "snow":
            colors = [Color(hex: 0x4C5966), Color(hex: 0x6B7885)]
        case "cloudy":
            colors = [Color(hex: 0x6E7E8F), Color(hex: 0x93A3B3)]
        default:
            colors = entry.isDay
                ? [Color(hex: 0x4A90D9), Color(hex: 0x7FB2E8)]
                : [Color(hex: 0x1B2A4A), Color(hex: 0x2E4372)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Widget

@main
struct WeatherWidget: Widget {
    // `kind` must equal the iOSName passed to HomeWidget.updateWidget().
    let kind = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("현재 날씨")
        .description("현재 날씨를 홈 화면에서 바로 확인하세요.")
        .supportedFamilies([.systemSmall]) // 2x2 정사각 고정
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension View {
    /// iOS 17 requires `containerBackground` for widget backgrounds; older
    /// versions take a plain background. This keeps one call site for both.
    @ViewBuilder
    func widgetBackground<Background: View>(_ background: Background) -> some View {
        if #available(iOS 17.0, *) {
            self.padding(16).containerBackground(for: .widget) { background }
        } else {
            self.padding(16).background(background)
        }
    }
}
