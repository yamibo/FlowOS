import SwiftUI

/// 历史记录视图
public struct HistoryView: View {
    // MARK: - Properties

    @Bindable var viewModel: HistoryViewModel
    @State private var selectedRange: TimeRange = .today

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 20) {
            // 时间范围选择器
            timeRangePicker

            // 统计卡片
            statsCards

            // 记录列表
            sessionList
        }
        .padding()
        .onAppear {
            viewModel.loadToday()
        }
    }

    // MARK: - Subviews

    private var timeRangePicker: some View {
        Picker("时间范围", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedRange) { _, newValue in
            loadRange(newValue)
        }
    }

    private var statsCards: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "专注次数",
                value: "\(viewModel.stats.focusSessions)",
                icon: "target",
                color: .red
            )

            StatCard(
                title: "专注时长",
                value: viewModel.stats.formattedFocusDuration,
                icon: "clock.fill",
                color: .blue
            )

            StatCard(
                title: "总 Session",
                value: "\(viewModel.stats.totalSessions)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    private var sessionList: some View {
        List {
            ForEach(viewModel.sessions) { session in
                SessionRow(session: session)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func loadRange(_ range: TimeRange) {
        switch range {
        case .today:
            viewModel.loadToday()
        case .last7Days:
            viewModel.loadLast7Days()
        case .last30Days:
            viewModel.loadLast30Days()
        case .all:
            viewModel.loadAll()
        }
    }

    // MARK: - Init

    public init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
    }
}

// MARK: - Supporting Types

enum TimeRange: CaseIterable, Identifiable {
    case today, last7Days, last30Days, all

    var id: Self { self }

    var displayName: String {
        switch self {
        case .today: return "今日"
        case .last7Days: return "7天"
        case .last30Days: return "30天"
        case .all: return "全部"
        }
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SessionRow: View {
    let session: SessionRecord

    var body: some View {
        HStack {
            Image(systemName: session.sessionType.iconName)
                .foregroundStyle(colorForType(session.sessionType))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionType.displayName)
                    .font(.headline)

                Text(formatDate(session.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(session.durationSeconds))
                    .font(.subheadline.bold())

                Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(session.completed ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForType(_ type: SessionType) -> Color {
        switch type {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)分钟"
    }
}

#Preview {
    let viewModel = HistoryViewModel(sessionRepository: .shared)
    HistoryView(viewModel: viewModel)
        .frame(width: 500, height: 600)
}
