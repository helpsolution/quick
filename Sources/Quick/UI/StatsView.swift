import Charts
import SwiftUI

struct StatsView: View {
    @State private var report: StatsReport?
    @State private var period: StatsPeriod = .week

    static let windowSize = CGSize(width: 880, height: 570)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let report {
                    if report.isEmpty {
                        empty
                    } else {
                        content(report)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(24)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .task { StatsReport.load { report = $0 } }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Данных пока нет")
                .font(.system(size: 14, weight: .medium))
            Text("Статистика появится после первых открытий шторки")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    @ViewBuilder
    private func content(_ report: StatsReport) -> some View {
        Picker("", selection: $period) {
            ForEach(StatsPeriod.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        counters(report.totals(for: period))
        // Без копирований экономить было нечего — строка «примерно 0 сек»
        // только занимает место.
        if report.totals(for: period).copies > 0 {
            savedTime(report.totals(for: period))
        }

        section(period.chartTitle) {
            copiesChart(report.series(for: period))
        }

        section("Насколько шторка попадает в цель") {
            conversion(report)
        }
    }

    // MARK: - Счётчики

    /// Все четыре в одну строку: окно достаточно широкое, а разбивка на два
    /// ряда заставляла бы сравнивать числа по диагонали.
    private func counters(_ totals: StatsTotals) -> some View {
        HStack(spacing: 12) {
            counter("Открытий шторки", totals.opens)
            counter("Копирований", totals.copies)
            counter("Скопировано изображений", totals.images)
            counter("Перетаскиваний", totals.drags, note: totals.drags > 0
                ? "доставлено: \(Self.number(totals.dragsAccepted))"
                : nil)
        }
    }

    private func counter(_ title: String, _ value: Int, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.number(value))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let note {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        // Растягиваем по высоте: иначе карточка с пояснением оказывается выше
        // соседних и ряд разъезжается.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    /// Строкой, а не плашкой: это прикидка, и заметностью она не должна
    /// перевешивать измеренные числа над ней.
    private func savedTime(_ totals: StatsTotals) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Сэкономлено примерно \(Self.duration(totals.savedSeconds))")
                .font(.system(size: 12, weight: .medium))
            Text("— по \(Int(StatsTotals.secondsSavedPerCopy)) секунд на поход за скриншотом вручную")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - График

    /// Только копирования. Открытия шторки рядом стояли лишь как фон и
    /// перетягивали внимание высотой: их место — в счётчиках и в конверсии.
    private func copiesChart(_ series: StatsSeries) -> some View {
        Chart(series.points) { point in
            BarMark(
                x: .value("Когда", point.date, unit: series.unit.component),
                y: .value("Копирований", point.copies)
            )
            .foregroundStyle(Color.accentColor)
        }
        // Шаг запаса справа: столбик последней корзины иначе упирается
        // в край области и подрезается.
        .chartXScale(domain: Self.domain(for: series))
        // Отметки задаём явно, а не шагом: шаг ставит последнюю подпись
        // вплотную к правому краю, и она обрезается многоточием.
        .chartXAxis {
            AxisMarks(values: Self.axisDates(for: series)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.axisLabel(date, for: series))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 190)
    }

    private func conversion(_ report: StatsReport) -> some View {
        let totals = report.totals(for: period)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.percent(totals.conversion))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("открытий закончились копированием или перетаскиванием")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let median = report.medianSecondsToClick {
                    Text("от появления шторки до клика — обычно \(Self.seconds(median))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: min(max(totals.conversion, 0), 1))
                .progressViewStyle(.linear)
        }
    }

    // MARK: - Оформление

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Формат

    /// Интерфейс написан по-русски целиком, поэтому и подписи собираем сами,
    /// а не через системную локаль: иначе на английской системе рядом с
    /// русскими заголовками встают «6 PM» и «Feb».
    private static let ruLocale = Locale(identifier: "ru_RU")

    private static func dateFormatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ruLocale
        formatter.dateFormat = pattern
        return formatter
    }

    private static let hourFormatter = dateFormatter("H:00")
    private static let dayFormatter = dateFormatter("d MMM")
    private static let monthFormatter = dateFormatter("LLL")
    private static let monthYearFormatter = dateFormatter("LLL yy")

    private static func axisLabel(_ date: Date, for series: StatsSeries) -> String {
        switch series.unit {
        case .hour:
            return hourFormatter.string(from: date)
        case .day:
            return dayFormatter.string(from: date)
        case .month:
            // Без года «янв.» разных лет не различить.
            return series.spansMultipleYears
                ? monthYearFormatter.string(from: date)
                : monthFormatter.string(from: date)
        }
    }

    /// Разряды разделяем неразрывным пробелом, как принято в русской типографике.
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "\u{00A0}"
        formatter.locale = ruLocale
        return formatter
    }()

    private static func number(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Подписи через `labelStride`, кроме хвоста: у самого края не помещаются.
    private static func axisDates(for series: StatsSeries) -> [Date] {
        let step = max(series.labelStride, 1)
        let limit = max(series.points.count - step / 2, 0)
        return stride(from: 0, to: limit, by: step).map { series.points[$0].date }
    }

    /// Домен на шаг шире ряда — чтобы крайний столбик не срезало краем.
    private static func domain(for series: StatsSeries) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = series.points.first?.date ?? calendar.startOfDay(for: Date())
        let last = series.points.last?.date ?? start
        let end = calendar.date(byAdding: series.unit.component, value: 1, to: last) ?? last
        return start...end
    }

    private static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours) ч \(minutes) мин" : "\(hours) ч" }
        if minutes > 0 { return "\(minutes) мин" }
        return "\(total) сек"
    }

    private static func seconds(_ value: Double) -> String {
        value < 10
            ? String(format: "%.1f сек", value)
            : "\(Int(value.rounded())) сек"
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
