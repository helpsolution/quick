import SwiftUI

struct SettingsView: View {
    let onOpenStats: () -> Void

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var analyticsEnabled = EventLog.isEnabled
    @State private var confirmErase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Divider()

            switchRow("Запускать при входе в систему", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItem.set(newValue)
                }

            Divider()

            statsRow

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

    /// Подпись слева, переключатель у правого края. Обычный `Toggle` жмётся
    /// к своему тексту, и тумблеры разных строк встают на разной высоте
    /// по горизонтали — ряд выглядит рваным.
    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            switchRow("Собирать статистику", isOn: $analyticsEnabled)
                .onChange(of: analyticsEnabled) { _, newValue in
                    EventLog.isEnabled = newValue
                }

            // Приложение не ходит в сеть вовсе — это стоит сказать прямо,
            // а не подразумевать.
            Text("Остаётся на этом компьютере и никуда не отправляется")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button("Статистика…") { onOpenStats() }
                Spacer(minLength: 8)
                Button("Удалить данные") { confirmErase = true }
            }
            .padding(.top, 6)
        }
        .alert("Удалить собранную статистику?", isPresented: $confirmErase) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { EventLog.shared.eraseAll {} }
        } message: {
            Text("Все накопленные события будут стёрты без возможности восстановления.")
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
