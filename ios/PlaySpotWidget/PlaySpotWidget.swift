import WidgetKit
import SwiftUI
import ActivityKit

public struct PlaySpotActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingMinutes: Int
        var loungeName: String
        var deviceName: String
    }
    var sessionTitle: String
}

@main
struct PlaySpotWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaySpotWidgetLiveActivity()
    }
}

struct PlaySpotWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaySpotActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            HStack(spacing: 15) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title)
                    .foregroundColor(Color(#colorLiteral(red: 0, green: 0.949, blue: 0.996, alpha: 1)))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.sessionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(context.state.loungeName) - \(context.state.deviceName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(context.state.remainingMinutes) mins")
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .foregroundColor(Color(#colorLiteral(red: 0, green: 0.949, blue: 0.996, alpha: 1)))
                    Text("LIVE")
                        .font(.caption2)
                        .bold()
                        .padding(4)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color.black.opacity(0.85))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(#colorLiteral(red: 0, green: 0.949, blue: 0.996, alpha: 1)).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.deviceName, systemImage: "gamecontroller.fill")
                        .foregroundColor(Color(#colorLiteral(red: 0, green: 0.949, blue: 0.996, alpha: 1)))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.remainingMinutes)m left")
                        .bold()
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.loungeName)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "gamecontroller.fill")
                    .foregroundColor(Color(#colorLiteral(red: 0, green: 0.949, blue: 0.996, alpha: 1)))
            } compactTrailing: {
                Text("\(context.state.remainingMinutes)m")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "gamecontroller.fill")
                    .foregroundColor(Color(#colorLiteral(red: 0, green: 0.949, blue: 0.996, alpha: 1)))
            }
        }
    }
}
