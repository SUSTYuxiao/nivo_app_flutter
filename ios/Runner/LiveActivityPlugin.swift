//
//  LiveActivityPlugin.swift
//  Runner
//
//  Created by 张鹏霄 on 2026/4/19.
//

import Flutter
import UIKit
import ActivityKit

// 必须与 MeetingActivity Extension 中的定义完全一致
@available(iOS 16.2, *)
struct MeetingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var startTime: Date
    }
    var meetingId: String
}

class LiveActivityPlugin {
    private var channel: FlutterMethodChannel?

    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.nivo/live_activity", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            switch call.method {
            case "start":
                handleStart(call: call, result: result)
            case "update":
                handleUpdate(call: call, result: result)
            case "end":
                handleEnd(result: result)
            case "isSupported":
                result(ActivityAuthorizationInfo().areActivitiesEnabled)
            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            if call.method == "isSupported" {
                result(false)
            } else {
                result(nil)
            }
        }
    }

    @available(iOS 16.2, *)
    private func handleStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let meetingId = args["meetingId"] as? String ?? ""
        let elapsedSeconds = args["elapsedSeconds"] as? Int ?? 0

        let attributes = MeetingActivityAttributes(meetingId: meetingId)
        let startTime = Date().addingTimeInterval(-Double(elapsedSeconds))
        let state = MeetingActivityAttributes.ContentState(
            isPaused: false,
            startTime: startTime
        )

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            result(true)
        } catch {
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    @available(iOS 16.2, *)
    private func handleUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let isPaused = args["isPaused"] as? Bool ?? false
        let elapsedSeconds = args["elapsedSeconds"] as? Int ?? 0

        let startTime = Date().addingTimeInterval(-Double(elapsedSeconds))
        let state = MeetingActivityAttributes.ContentState(
            isPaused: isPaused,
            startTime: startTime
        )

        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            for activity in Activity<MeetingActivityAttributes>.activities {
                await activity.update(content)
            }
            DispatchQueue.main.async { result(true) }
        }
    }

    @available(iOS 16.2, *)
    private func handleEnd(result: @escaping FlutterResult) {
        Task {
            for activity in Activity<MeetingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            DispatchQueue.main.async { result(true) }
        }
    }
}
