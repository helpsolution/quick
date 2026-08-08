import SwiftUI

struct SettingsView: View {
    let folder: URL

    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Divider()

            Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItem.set(newValue)
                }

            folderRow

            HStack {
                Spacer()
                Button("Выйти из Quick") { NSApp.terminate(nil) }
            }
            .padding(.top, 4)
        }
        .padding(24)
        // Только ширина: высоту окно берёт из фактического размера содержимого,
        // иначе последняя кнопка обрезается нижним краем.
        .frame(width: 400)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quick")
                    .font(.system(size: 15, weight: .semibold))
                Text("Версия \(Self.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Папка со скриншотами")
                .font(.system(size: 12, weight: .medium))

            HStack(spacing: 8) {
                Text(Self.shortPath(folder))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Button("Открыть") { FileActions.openFolder(folder) }
            }

            // Папку задаёт сама macOS, а не Quick: менять её отсюда значило бы
            // молча переписывать системную настройку снимков экрана.
            Text("Берётся из системной настройки снимков экрана")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private static func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home)
            ? "~" + url.path.dropFirst(home.count)
            : url.path
    }
}
