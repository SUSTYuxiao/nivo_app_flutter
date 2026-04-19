//
//  MeetingActivityLiveActivity.swift
//  MeetingActivity
//
//  Created by 张鹏霄 on 2026/4/19.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MeetingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var startTime: Date
    }
    var meetingId: String
}

struct MeetingActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetingActivityAttributes.self) { context in
            // ━━ 锁屏横幅 ━━
            HStack(spacing: 12) {
                Circle()
                    .fill(context.state.isPaused ? Color.orange : Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        context.state.isPaused ? nil :
                        Circle()
                            .stroke(Color.red.opacity(0.4), lineWidth: 3)
                            .scaleEffect(1.5)
                    )

                Text(context.state.isPaused ? "会议已暂停" : "会议录音中")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                } else {
                    Text(context.state.startTime, style: .timer)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(Color(.systemBackground))

        } dynamicIsland: { context in
            DynamicIsland {
                // ━━ 展开态 ━━
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(context.state.isPaused ? Color.orange : Color.red)
                            .frame(width: 8, height: 8)
                        Text("录音")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text("暂停")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.orange)
                    } else {
                        Text(context.state.startTime, style: .timer)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.center) {}
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isPaused ? "会议已暂停" : "会议录音中")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            } compactLeading: {
                // ━━ 紧凑态左侧 ━━
                Circle()
                    .fill(context.state.isPaused ? Color.orange : Color.red)
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                // ━━ 紧凑态右侧 ━━
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                } else {
                    Text(context.state.startTime, style: .timer)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            } minimal: {
                // ━━ 最小态 ━━
                Circle()
                    .fill(context.state.isPaused ? Color.orange : Color.red)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview("Notification", as: .content, using: MeetingActivityAttributes(meetingId: "preview")) {
    MeetingActivityLiveActivity()
} contentStates: {
    MeetingActivityAttributes.ContentState(isPaused: false, startTime: Date())
    MeetingActivityAttributes.ContentState(isPaused: true, startTime: Date())
}
