import AppKit

/// Журнал событий. Всё, что попадает сюда, остаётся на этом компьютере:
/// приложение ничего никуда не отправляет.
///
/// Цена события на горячем пути — один append в массив, без блокировок и без
/// диска: все вызовы приходят с главного потока, поэтому синхронизация не
/// нужна вовсе. Файл трогается пачками на фоновой очереди раз в `flushDelay`
/// секунд, и пользователь этого момента не ждёт.
///
/// Считать что-либо в глобальном мониторе мыши (`NotchController`) нельзя:
/// он срабатывает на каждое движение курсора по всему экрану.
@MainActor
final class EventLog {
    static let shared = EventLog()

    static let enabledKey = "AnalyticsEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            shared.enabled = newValue
            if !newValue { shared.discardBuffer() }
        }
    }

    private var enabled: Bool
    private var buffer: [AnalyticsEvent] = []
    private var flushScheduled = false

    /// Состояние текущего показа шторки.
    private var panelOpenedAt: Date?
    private var panelDidAct = false
    private var dragCount: Int?

    private let flushDelay: TimeInterval = 10
    private let flushThreshold = 100

    private init() {
        // Ключа ещё нет при первом запуске — по умолчанию сбор включён.
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
        enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        observeShutdown()
    }

    // MARK: - События

    func panelOpened() {
        guard enabled else { return }
        panelOpenedAt = Date()
        panelDidAct = false
    }

    func panelClosed() {
        guard enabled, let openedAt = panelOpenedAt else { return }
        panelOpenedAt = nil
        record(AnalyticsEvent(
            kind: .panel,
            time: openedAt,
            seconds: Date().timeIntervalSince(openedAt),
            ok: panelDidAct
        ))
        panelDidAct = false
    }

    /// - Parameter index: позиция миниатюры в карусели; `nil`, когда
    ///   копирование пришло не из клика по ленте (например из меню).
    func copied(count: Int, index: Int?) {
        guard enabled else { return }
        panelDidAct = true
        record(AnalyticsEvent(
            kind: .copy,
            time: Date(),
            count: count,
            index: index,
            seconds: panelOpenedAt.map { Date().timeIntervalSince($0) }
        ))
    }

    /// Перетаскивание засчитывается как действие уже в начале: шторка успевает
    /// закрыться раньше, чем приёмник примет файлы.
    func dragStarted(count: Int) {
        guard enabled else { return }
        panelDidAct = true
        dragCount = count
    }

    func dragFinished(accepted: Bool) {
        guard enabled, let count = dragCount else { return }
        dragCount = nil
        record(AnalyticsEvent(kind: .drag, time: Date(), count: count, ok: accepted))
    }

    // MARK: - Буфер

    private func record(_ event: AnalyticsEvent) {
        buffer.append(event)

        if buffer.count >= flushThreshold {
            flush()
        } else if !flushScheduled {
            // Отсчёт от первого события в пачке, а не от последнего: иначе
            // равномерный поток кликов откладывал бы запись бесконечно.
            flushScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + flushDelay) { [weak self] in
                self?.flush()
            }
        }
    }

    /// Перед чтением архива буфер надо дописать. Иначе окно статистики
    /// покажет копирования, чей показ шторки ещё не долетел до диска, —
    /// и конверсия окажется заниженной или нулевой.
    func flushPending() {
        flushNow()
    }

    private func flush() {
        flushScheduled = false
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer.removeAll(keepingCapacity: true)
        EventStore.queue.async { EventStore.append(batch) }
    }

    /// Перед смертью процесса писать нужно здесь и сейчас: очередь уже никто
    /// не дождётся.
    private func flushNow() {
        flushScheduled = false
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer.removeAll(keepingCapacity: true)
        EventStore.queue.sync { EventStore.append(batch) }
    }

    private func discardBuffer() {
        buffer.removeAll(keepingCapacity: false)
        panelOpenedAt = nil
        dragCount = nil
    }

    /// Незакрытый показ шторки на момент выключения не выбрасываем — иначе
    /// последний сеанс перед сном всегда терялся бы.
    private func observeShutdown() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                EventLog.shared.panelClosed()
                EventLog.shared.flushNow()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                EventLog.shared.panelClosed()
                EventLog.shared.flushNow()
            }
        }
    }

    // MARK: - Удаление

    func eraseAll(completion: @escaping () -> Void) {
        discardBuffer()
        EventStore.queue.async {
            EventStore.removeAll()
            DispatchQueue.main.async(execute: completion)
        }
    }
}
