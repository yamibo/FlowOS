import SwiftUI

public struct TimerView: View {
    @Bindable var viewModel: TimerViewModel
    @Environment(\.languageVersion) private var languageVersion

    public var body: some View {
        FlowOSPage {
            VStack(alignment: .leading, spacing: 18) {
                header

                FlowOSPanel {
                    VStack(spacing: 24) {
                        sessionTypePicker
                        timerDisplay
                        controlButtons
                    }
                }

                todayStatsView
            }
        }
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Focus Timer", defaultValue: "专注计时"))
                    .font(.title2.bold())
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(viewModel.sessionType.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(viewModel.progressColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(viewModel.progressColor.opacity(0.12), in: Capsule())
        }
    }

    private var sessionTypePicker: some View {
        HStack(spacing: 8) {
            ForEach(SessionType.allCases) { type in
                Button {
                    viewModel.switchTo(type)
                } label: {
                    Label(type.displayName, systemImage: type.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(sessionButtonBackground(for: type), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(viewModel.sessionType == type ? .white : .primary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(FlowOSDesign.hairline, lineWidth: viewModel.sessionType == type ? 0 : 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timerDisplay: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(viewModel.progressColor.opacity(0.16), lineWidth: 14)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(viewModel.progressColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.25), value: viewModel.progress)

                VStack(spacing: 8) {
                    Text(viewModel.formattedTime)
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                FlowOSMetric(
                    title: L("Session Length", defaultValue: "本轮时长"),
                    value: sessionLengthText,
                    icon: "timer",
                    color: viewModel.progressColor
                )

                FlowOSMetric(
                    title: L("Progress", defaultValue: "进度"),
                    value: "\(Int(viewModel.progress * 100))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                switch viewModel.status {
                case .idle:
                    viewModel.start()
                case .running:
                    viewModel.pause()
                case .paused:
                    viewModel.resume()
                }
            } label: {
                Label(primaryButtonTitle, systemImage: viewModel.status == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 132)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if viewModel.status != .idle {
                Button {
                    viewModel.stop()
                } label: {
                    Label(L("Stop", defaultValue: "停止"), systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if viewModel.status != .idle {
                Button {
                    viewModel.skip()
                } label: {
                    Label(L("Skip", defaultValue: "跳过"), systemImage: "forward.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var todayStatsView: some View {
        HStack(spacing: 12) {
            FlowOSMetric(
                title: L("Focus Sessions", defaultValue: "专注次数"),
                value: "\(viewModel.todayStats.focusSessions)",
                icon: "target",
                color: .red
            )

            FlowOSMetric(
                title: L("Total Focus Time", defaultValue: "专注时长"),
                value: viewModel.todayStats.formattedFocusDuration,
                icon: "clock.fill",
                color: .blue
            )

            FlowOSMetric(
                title: L("Current Cycle", defaultValue: "当前周期"),
                value: "\(viewModel.sessionsCompletedInCycle)/\(viewModel.settings.longBreakEvery)",
                icon: "repeat",
                color: .green
            )
        }
    }

    private func sessionButtonBackground(for type: SessionType) -> Color {
        viewModel.sessionType == type ? FlowOSDesign.sessionColor(type) : FlowOSDesign.elevatedBackground.opacity(0.72)
    }

    private var primaryButtonTitle: String {
        switch viewModel.status {
        case .idle: return L("Start", defaultValue: "开始")
        case .running: return L("Pause", defaultValue: "暂停")
        case .paused: return L("Resume", defaultValue: "继续")
        }
    }

    private var statusText: String {
        switch viewModel.status {
        case .idle: return L("Ready", defaultValue: "准备就绪")
        case .running: return L("Running", defaultValue: "进行中")
        case .paused: return L("Paused", defaultValue: "已暂停")
        }
    }

    private var statusDescription: String {
        switch viewModel.status {
        case .idle: return L("Pick a session and start when you are ready.", defaultValue: "选择一个时段，准备好后开始。")
        case .running: return L("Stay with the current task until the timer ends.", defaultValue: "保持在当前任务上，直到计时结束。")
        case .paused: return L("Timer paused. Resume when you are ready.", defaultValue: "计时已暂停，准备好后继续。")
        }
    }

    private var sessionLengthText: String {
        let minutes = max(1, viewModel.settings.durationSeconds(for: viewModel.sessionType) / 60)
        return "\(minutes) \(L("min", defaultValue: "分钟"))"
    }

    public init(viewModel: TimerViewModel) {
        self.viewModel = viewModel
    }
}

#Preview {
    let coordinator = AppCoordinator()
    let viewModel = TimerViewModel(coordinator: coordinator)
    TimerView(viewModel: viewModel)
        .frame(width: 400, height: 500)
}
