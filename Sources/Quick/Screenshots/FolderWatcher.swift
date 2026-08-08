import Foundation

/// Следит за изменениями в папке через kqueue. Без polling — реакция мгновенная.
/// Скриншот пишется на диск в несколько заходов, поэтому события схлопываются дебаунсом.
final class FolderWatcher {
    private let url: URL
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var pending: DispatchWorkItem?

    init(url: URL, debounceInterval: TimeInterval = 0.2, onChange: @escaping () -> Void) {
        self.url = url
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit { stop() }

    /// Первое обращение к папке может упереться в диалог TCC и заблокировать
    /// поток на время ответа пользователя — поэтому открываем дескриптор в фоне.
    func start() {
        stop()

        let url = self.url
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let descriptor = open(url.path, O_EVTONLY)
            DispatchQueue.main.async {
                guard let self else {
                    if descriptor >= 0 { close(descriptor) }
                    return
                }
                guard descriptor >= 0 else { return }
                self.attach(descriptor: descriptor)
            }
        }
    }

    private func attach(descriptor: CInt) {
        // Пока открывали дескриптор, наблюдение могли остановить или перезапустить.
        guard source == nil else {
            close(descriptor)
            return
        }
        self.descriptor = descriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.scheduleChange() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
        descriptor = -1
    }

    private func scheduleChange() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
