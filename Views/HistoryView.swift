import SwiftUI

/// 历史记录视图
public struct HistoryView: View {
    // MARK: - Properties

    @Bindable var viewModel: HistoryViewModel
    let todoRepository: TodoRepository
    @State private var selectedRange: TimeRange = .today
    @State private var selectedCalendarDate = Date()
    @Environment(\.languageVersion) private var languageVersion

    // MARK: - Body

    public var body: some View {
        FlowOSPage {
            VStack(alignment: .leading, spacing: 18) {
                header
                timeRangePicker
                calendarStrip
                statsCards
                sessionList
            }
        }
        .onAppear {
            viewModel.loadToday()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Focus History", defaultValue: "专注历史"))
                .font(.title2.bold())
            Text(L("Review completed sessions and recent momentum.", defaultValue: "回顾已完成的专注记录和近期状态。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var timeRangePicker: some View {
        Picker(L("Time Range", defaultValue: "时间范围"), selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.localizedName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedRange) { _, newValue in
            loadRange(newValue)
            selectedCalendarDate = Date()
        }
    }

    private var statsCards: some View {
        HStack(spacing: 12) {
            FlowOSMetric(
                title: L("Focus Sessions", defaultValue: "专注次数"),
                value: "\(viewModel.stats.focusSessions)",
                icon: "target",
                color: .red
            )

            FlowOSMetric(
                title: L("Total Focus Time", defaultValue: "专注时长"),
                value: viewModel.stats.formattedFocusDuration,
                icon: "clock.fill",
                color: .blue
            )

            FlowOSMetric(
                title: L("Total Sessions", defaultValue: "总 Session"),
                value: "\(viewModel.stats.totalSessions)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    private var calendarStrip: some View {
        FlowOSPanel {
            HStack(spacing: 12) {
                DatePicker(
                    L("Calendar", defaultValue: "日历"),
                    selection: $selectedCalendarDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)

                Spacer()

                Text(selectedDateSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var sessionList: some View {
        FlowOSPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("Sessions", defaultValue: "记录"))
                        .font(.headline)
                    Spacer()
                    Text("\(filteredSessions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                if filteredSessions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(emptyHistoryTitle)
                            .font(.headline)
                        Text(emptyHistoryMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .padding()
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedSessions, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(formatDayHeader(group.day))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(group.sessions) { session in
                                    SessionRow(session: session, todoRepository: todoRepository)
                                }
                            }
                        }
                    }
                }
            }
        }
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

    private var filteredSessions: [SessionRecord] {
        if selectedRange == .today {
            return viewModel.sessions
        }

        return viewModel.sessions.filter {
            Calendar.current.isDate($0.startedAt, inSameDayAs: selectedCalendarDate)
        }
    }

    private var groupedSessions: [(day: Date, sessions: [SessionRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredSessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        return groups
            .map { day, sessions in
                (
                    day: day,
                    sessions: sessions.sorted { $0.startedAt > $1.startedAt }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private var selectedDateSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: selectedCalendarDate)) · \(filteredSessions.count) \(L("sessions", defaultValue: "次"))"
    }

    private var emptyHistoryTitle: String {
        viewModel.sessions.isEmpty ? L("No records yet", defaultValue: "暂无记录") : L("No sessions on this date", defaultValue: "这一天暂无记录")
    }

    private var emptyHistoryMessage: String {
        viewModel.sessions.isEmpty
            ? L("Completed focus sessions will appear here.", defaultValue: "完成的专注记录会显示在这里。")
            : L("Pick another date or time range to review completed sessions.", defaultValue: "选择其他日期或时间范围查看完成记录。")
    }

    private func formatDayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd EEEE"
        return formatter.string(from: date)
    }

    // MARK: - Init

    public init(viewModel: HistoryViewModel, todoRepository: TodoRepository = .shared) {
        self.viewModel = viewModel
        self.todoRepository = todoRepository
    }
}

// MARK: - Supporting Types

enum TimeRange: CaseIterable, Identifiable {
    case today, last7Days, last30Days, all

    var id: Self { self }

    var localizedName: String {
        switch self {
        case .today: return L("Today", defaultValue: "今天")
        case .last7Days: return L("7 Days", defaultValue: "7天")
        case .last30Days: return L("30 Days", defaultValue: "30天")
        case .all: return L("All Time", defaultValue: "全部")
        }
    }
}

struct SessionRow: View {
    let session: SessionRecord
    let todoRepository: TodoRepository

    @State private var taskNames: [String] = []

    var body: some View {
        HStack {
            Image(systemName: session.sessionType.iconName)
                .foregroundStyle(colorForType(session.sessionType))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(colorForType(session.sessionType).opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionType.displayName)
                        .font(.headline)

                    if !session.completed {
                        Text(L("Incomplete", defaultValue: "(未完成)"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(formatDate(session.endedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !taskNames.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Completed Tasks", defaultValue: "完成任务"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(taskNames.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(session.durationSeconds))
                    .font(.subheadline.bold())
                    .monospacedDigit()

                Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(session.completed ? .green : .red)
            }
        }
        .padding(10)
        .background(FlowOSDesign.elevatedBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(FlowOSDesign.hairline, lineWidth: 1)
        }
        .onAppear {
            loadTaskNames()
        }
    }

    private func loadTaskNames() {
        guard let taskIds = session.completedTaskIds, !taskIds.isEmpty else { return }
        let items = todoRepository.load().items
        taskNames = taskIds.compactMap { id in
            items.first { $0.id == id }?.displayText
        }
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
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let unit = L("minutes", defaultValue: "分钟")
        return "\(minutes) \(unit)"
    }
}

#Preview {
    let viewModel = HistoryViewModel(sessionRepository: .shared)
    HistoryView(viewModel: viewModel, todoRepository: .shared)
        .frame(width: 500, height: 600)
}
