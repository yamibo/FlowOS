import SwiftUI

/// 计时器视图
public struct TimerView: View {
    // MARK: - Properties

    @Bindable var viewModel: TimerViewModel

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 32) {
            // Session 类型选择器
            sessionTypePicker

            // 计时器显示
            timerDisplay

            // 控制按钮
            controlButtons

            // 今日统计
            todayStatsView
        }
        .padding()
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    // MARK: - Subviews

    private var sessionTypePicker: some View {
        HStack(spacing: 16) {
            ForEach(SessionType.allCases) { type in
                Button {
                    viewModel.switchTo(type)
                } label: {
                    Label(type.displayName, systemImage: type.iconName)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.sessionType == type ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundStyle(viewModel.sessionType == type ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timerDisplay: some View {
        ZStack {
            // 进度环
            Circle()
                .stroke(viewModel.progressColor.opacity(0.2), lineWidth: 12)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(viewModel.progressColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))

            // 时间显示
            Text(viewModel.formattedTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 24) {
            // 开始/暂停按钮
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
                Image(systemName: viewModel.status == .running ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(30)
            }
            .buttonStyle(.plain)

            // 停止按钮
            if viewModel.status != .idle {
                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .cornerRadius(22)
                }
                .buttonStyle(.plain)
            }

            // 跳过按钮
            if viewModel.status != .idle {
                Button {
                    viewModel.skip()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .cornerRadius(22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var todayStatsView: some View {
        HStack(spacing: 32) {
            VStack {
                Text("\(viewModel.todayStats.focusSessions)")
                    .font(.title2.bold())
                Text("专注次数")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack {
                Text(viewModel.todayStats.formattedFocusDuration)
                    .font(.title2.bold())
                Text("专注时长")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack {
                Text("\(viewModel.sessionsCompletedInCycle)/\(viewModel.settings.longBreakEvery)")
                    .font(.title2.bold())
                Text("当前周期")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Init

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