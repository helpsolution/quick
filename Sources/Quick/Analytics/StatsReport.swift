import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case today, week, month, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Сегодня"
        case .week: return "7 дней"
        case .month: return "30 дней"
        case .all: return "Все время"
        }
    }

    /// Границы считаются по началу суток, а не по «минус 24 часа»: иначе
    /// одно и то же событие то попадало бы в период, то выпадало из него.
    func startDate(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today: return today
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)
        case .month: return calendar.date(byAdding: .day, value: -29, to: today)
        case .all: return nil
        }
    }

    /// Шаг графика для этого периода.
    var chartUnit: StatsSeries.Unit {
        switch self {
        case .today: return .hour
        case .week, .month: return .day
        case .all: return .month
        }
    }

    var chartTitle: String {
        switch self {
        case .today: return "Сегодня по часам"
        case .week: return "Последние 7 дней"
        case .month: return "Последние 30 дней"
        case .all: return "По месяцам"
        }
    }
}

struct StatsTotals {
    /// Оценка того, сколько занимает поход за скриншотом на Рабочий стол
    /// вручную. Именно оценка — в интерфейсе так и подписано.
    static let secondsSavedPerCopy: Double = 4

    var opens = 0
    var opensWithAction = 0
    var copies = 0
    var images = 0
    var drags = 0
    var dragsAccepted = 0
    var snippets = 0

    /// Доля показов шторки, закончившихся действием.
    /// Остальное — курсор просто проехал мимо челки.
    var conversion: Double {
        opens > 0 ? Double(opensWithAction) / Double(opens) : 0
    }

    var savedSeconds: Double {
        Double(copies) * Self.secondsSavedPerCopy
    }
}

struct SeriesPoint: Identifiable {
    let date: Date
    var copies = 0

    var id: Date { date }
}

/// Ряд для графика. Шаг зависит от выбранного периода: за сутки интересны
/// часы, за месяц — дни, за всё время — месяцы. Один и тот же шаг на всех
/// периодах либо сплющивал бы день в одну палку, либо растягивал бы годы
/// в нечитаемую гребёнку.
struct StatsSeries {
    enum Unit {
        case hour, day, month

        var component: Calendar.Component {
            switch self {
            case .hour: return .hour
            case .day: return .day
            case .month: return .month
            }
        }
    }

    var unit: Unit = .day
    var points: [SeriesPoint] = []

    /// Через сколько точек ставить подпись оси.
    var labelStride: Int {
        switch unit {
        case .hour: return 6
        case .day: return points.count <= 10 ? 1 : 7
        case .month: return points.count <= 8 ? 1 : Int((Double(points.count) / 6).rounded(.up))
        }
    }

    /// Месяцы разных лет без года подписать нельзя — «янв.» повторится.
    var spansMultipleYears: Bool {
        guard let first = points.first?.date, let last = points.last?.date else { return false }
        let calendar = Calendar.current
        return calendar.component(.year, from: first) != calendar.component(.year, from: last)
    }
}

/// Готовые срезы по всему архиву. Считается один раз при открытии окна:
/// переключение периода после этого ничего не перечитывает.
struct StatsReport {
    var totals: [StatsPeriod: StatsTotals] = [:]
    /// По ряду на период. Пустые корзины в ряду сохраняются: без них выходные
    /// и ночные часы схлопываются, и график врёт про ритм работы.
    var series: [StatsPeriod: StatsSeries] = [:]
    var medianSecondsToClick: Double?

    var isEmpty: Bool {
        (totals[.all]?.opens ?? 0) == 0
            && (totals[.all]?.copies ?? 0) == 0
            && (totals[.all]?.snippets ?? 0) == 0
    }

    func totals(for period: StatsPeriod) -> StatsTotals {
        totals[period] ?? StatsTotals()
    }

    func series(for period: StatsPeriod) -> StatsSeries {
        series[period] ?? StatsSeries()
    }

    // MARK: - Сборка

    static func build(from events: [AnalyticsEvent], now: Date = Date()) -> StatsReport {
        let calendar = Calendar.current
        var report = StatsReport()

        var totals: [StatsPeriod: StatsTotals] = [:]
        var starts: [StatsPeriod: Date?] = [:]
        var buckets: [StatsPeriod: [Date: Int]] = [:]
        for period in StatsPeriod.allCases {
            totals[period] = StatsTotals()
            starts[period] = period.startDate(now: now, calendar: calendar)
            buckets[period] = [:]
        }

        var clickDelays: [Double] = []

        for event in events {
            for period in StatsPeriod.allCases {
                if let start = starts[period] ?? nil, event.time < start { continue }
                totals[period]?.add(event)

                if event.kind == .copy,
                   let bucket = bucketStart(of: event.time, unit: period.chartUnit, calendar: calendar) {
                    buckets[period]?[bucket, default: 0] += 1
                }
            }

            // Позиция клика в карусели в событиях есть и пишется дальше —
            // просто сейчас её никто не показывает.
            if event.kind == .copy, let seconds = event.seconds {
                clickDelays.append(seconds)
            }
        }

        report.totals = totals
        for period in StatsPeriod.allCases {
            report.series[period] = makeSeries(
                for: period,
                counts: buckets[period] ?? [:],
                firstEvent: events.first?.time,
                now: now,
                calendar: calendar
            )
        }
        report.medianSecondsToClick = median(of: clickDelays)
        return report
    }

    /// Начало корзины, в которую попадает момент времени.
    private static func bucketStart(
        of date: Date,
        unit: StatsSeries.Unit,
        calendar: Calendar
    ) -> Date? {
        switch unit {
        case .hour: return calendar.dateInterval(of: .hour, for: date)?.start
        case .day: return calendar.startOfDay(for: date)
        case .month: return calendar.dateInterval(of: .month, for: date)?.start
        }
    }

    /// Ряд разворачивается на весь период целиком, а не только на корзины
    /// с событиями: пустой день — тоже факт.
    private static func makeSeries(
        for period: StatsPeriod,
        counts: [Date: Int],
        firstEvent: Date?,
        now: Date,
        calendar: Calendar
    ) -> StatsSeries {
        let unit = period.chartUnit
        let component = unit.component

        let start: Date?
        switch period {
        case .today:
            start = calendar.startOfDay(for: now)
        case .week, .month:
            start = period.startDate(now: now, calendar: calendar)
        case .all:
            // Архив может начинаться когда угодно; если событий нет вовсе,
            // показываем текущий месяц.
            start = bucketStart(of: firstEvent ?? now, unit: .month, calendar: calendar)
        }
        guard let start, let end = bucketStart(of: now, unit: unit, calendar: calendar) else {
            return StatsSeries(unit: unit, points: [])
        }

        var points: [SeriesPoint] = []
        var cursor = start
        // Ограничение сверху — страховка от кривой даты в архиве: без неё
        // сдвинутые часы прошлого могли бы раскрутить цикл надолго.
        while cursor <= end, points.count < 1000 {
            points.append(SeriesPoint(date: cursor, copies: counts[cursor] ?? 0))
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Сутки показываем целиком, включая часы, которые ещё не наступили:
        // иначе к обеду график каждый день выглядит обрезанным.
        if unit == .hour {
            while points.count < 24, let last = points.last?.date,
                  let next = calendar.date(byAdding: .hour, value: 1, to: last) {
                points.append(SeriesPoint(date: next, copies: counts[next] ?? 0))
            }
        }

        return StatsSeries(unit: unit, points: points)
    }

    private static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    /// Чтение и разбор архива — на фоновой очереди. Окно статистики открывается
    /// редко, но и в этот момент интерфейс ждать диска не должен.
    static func load(completion: @escaping (StatsReport) -> Void) {
        EventStore.queue.async {
            let report = build(from: EventStore.loadAll())
            DispatchQueue.main.async { completion(report) }
        }
    }
}

private extension StatsTotals {
    mutating func add(_ event: AnalyticsEvent) {
        switch event.kind {
        case .panel:
            opens += 1
            if event.ok == true { opensWithAction += 1 }
        case .copy:
            copies += 1
            images += event.count ?? 1
        case .drag:
            drags += 1
            if event.ok == true { dragsAccepted += 1 }
        case .snippet:
            snippets += 1
        }
    }
}
