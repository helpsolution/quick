import Foundation

/// Файловый слой журнала: JSONL, по файлу на месяц.
///
/// Ничего не удаляется — события живут вечно. Разбиение по месяцам нужно не для
/// ротации, а для чтения: типичный экран смотрит последние 30 дней и разбирает
/// один-два маленьких файла вместо всего архива. Закрытый месяц больше никогда
/// не меняется, поэтому кэш готовых итогов, если он когда-нибудь понадобится,
/// добавляется поверх без переделки формата.
enum EventStore {
    /// Вся работа с диском идёт здесь. На главном потоке не должно быть ни
    /// одного обращения к файлу: шторка открывается быстрее, чем крутится диск.
    static let queue = DispatchQueue(label: "co.quick.analytics", qos: .utility)

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quick/Analytics", isDirectory: true)
    }

    // MARK: - Запись

    /// Дописывает пачку событий. Вызывать только с `queue`.
    static func append(_ events: [AnalyticsEvent]) {
        guard !events.isEmpty else { return }

        // Пачка может застать смену месяца, поэтому раскладываем по файлам.
        let byMonth = Dictionary(grouping: events) { monthKey(for: $0.time) }
        for (month, monthEvents) in byMonth {
            var payload = Data()
            for event in monthEvents {
                guard let line = try? encoder.encode(event) else { continue }
                payload.append(line)
                payload.append(0x0A)
            }
            write(payload, toMonth: month)
        }
    }

    private static func write(_ payload: Data, toMonth month: String) {
        guard !payload.isEmpty else { return }
        let fileManager = FileManager.default
        let url = directory.appendingPathComponent("events-\(month).jsonl")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
        } catch {
            // Статистика не стоит того, чтобы мешать работе приложения.
            NSLog("Quick: не удалось записать статистику — \(error.localizedDescription)")
        }
    }

    // MARK: - Чтение

    /// Все события, отсортированные по времени. Вызывать только с `queue`.
    static func loadAll() -> [AnalyticsEvent] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        var events: [AnalyticsEvent] = []
        for url in files where url.lastPathComponent.hasPrefix("events-") && url.pathExtension == "jsonl" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                guard let event = try? decoder.decode(AnalyticsEvent.self, from: Data(line.utf8)) else { continue }
                events.append(event)
            }
        }
        return events.sorted { $0.time < $1.time }
    }

    /// Вызывать только с `queue`.
    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Служебное

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    /// Имя месяца по локальному времени: месяц статистики должен совпадать
    /// с тем, что пользователь видит в календаре, а не с UTC.
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static func monthKey(for date: Date) -> String {
        monthFormatter.string(from: date)
    }
}
