import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var store: ScreenshotStore
    @ObservedObject var snippets: SnippetStore
    @ObservedObject var state: PanelState
    /// Не @ObservedObject намеренно: панель не должна перерисовываться на
    /// каждый клик — за выбором следят только отметки на миниатюрах.
    let selection: SelectionStore
    /// Клик с учётом зажатых модификаторов: индекс нужен для выбора диапазона.
    let onClick: (Screenshot, Int) -> Void
    let onCopyOnly: (Screenshot) -> Void
    let onUseSnippet: (Snippet, Int) -> Void
    let onOpenSettings: () -> Void
    let onOpenSnippets: () -> Void

    private var panelWidth: CGFloat { state.panelWidth }

    var body: some View {
        VStack(spacing: 0) {
            // Зона челки — прозрачная, панель выезжает из-под неё.
            Color.clear.frame(height: state.notchHeight)

            ZStack(alignment: .top) {
                panel
                    .frame(width: panelWidth, height: PanelLayout.height)
                    .offset(y: state.isExpanded ? 0 : -PanelLayout.height)
                    .opacity(state.isExpanded ? 1 : 0)
            }
            .frame(height: PanelLayout.height + PanelLayout.edgePadding, alignment: .top)
            .clipShape(Rectangle())

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: state.isExpanded)
        // Оформление шторки не зависит от того, светлая сейчас тема системы
        // или тёмная: панель чёрная в любое время суток.
        .environment(\.colorScheme, .dark)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: PanelLayout.headerGap) {
            header
            content
        }
        .padding(PanelLayout.padding)
        .frame(width: panelWidth, height: PanelLayout.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: PanelLayout.cornerRadius, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PanelLayout.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
        )
        // Тени нет намеренно: прямоугольный клип, которым панель «выезжает»
        // из-под челки, обрезает её резким краем — на светлых обоях это
        // выглядит как серая коробка вокруг скруглённой панели.
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 6) {
            if state.snippetsEnabled {
                tab(.screenshots, title: "Скриншоты", count: store.items.count)
                tab(.snippets, title: "Заготовки", count: snippets.items.count)

                if state.tab == .snippets && !state.pasteAllowed {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                        .help("Клик кладет заготовку в буфер. Чтобы она вставлялась сама, разрешите Quick доступ в «Универсальном доступе» — Настройки Quick → Заготовки.")
                }
            } else {
                Text("Скриншоты")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                if !store.items.isEmpty {
                    Text("\(store.items.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Spacer()

            SettingsMenu(onOpenSettings: onOpenSettings)
        }
        .frame(height: PanelLayout.headerHeight)
    }

    /// Заголовок раздела и есть кнопка переключения: отдельный сегментед-контрол
    /// на 11 пунктах шрифта в шторку не помещается, а два слова — помещаются.
    private func tab(_ tab: PanelTab, title: String, count: Int) -> some View {
        let isActive = state.tab == tab
        return HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isActive ? 0.85 : 0.4))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(isActive ? 0.4 : 0.25))
            }
        }
        .padding(.horizontal, 7)
        .frame(height: PanelLayout.headerHeight)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(isActive ? 0.08 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture { state.tab = tab }
    }

    @ViewBuilder
    private var content: some View {
        if state.snippetsEnabled && state.tab == .snippets {
            SnippetList(
                store: snippets,
                asCards: state.snippetsAsCards,
                onUse: onUseSnippet,
                onEdit: onOpenSnippets
            )
        } else {
            screenshots
        }
    }

    @ViewBuilder
    private var screenshots: some View {
        if store.accessDenied {
            message(
                "Нет доступа к папке «\(store.folder.lastPathComponent)»",
                action: ("Открыть Настройки", openPrivacySettings)
            )
        } else if store.items.isEmpty {
            message("Скриншотов пока нет", action: nil)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PanelLayout.spacing) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, screenshot in
                        ThumbnailCell(
                            screenshot: screenshot,
                            selection: selection,
                            dragURLs: { [store, selection] in
                                // Захватываем store и selection по ссылке, а не
                                // значения: выбор мог измениться уже после
                                // создания ячейки.
                                let selected = store.items
                                    .filter { selection.contains($0.id) }
                                    .map(\.url)
                                // Тянем за выбранный — переносятся все выбранные,
                                // как в Finder. Тянем за невыбранный — только он.
                                return selection.contains(screenshot.id) && selected.count > 1
                                    ? selected
                                    : [screenshot.url]
                            },
                            onClick: { onClick(screenshot, index) },
                            onCopyOnly: { onCopyOnly(screenshot) }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: PanelLayout.thumbnail.height)
        }
    }

    private func message(_ text: String, action: (title: String, run: () -> Void)?) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            if let action {
                Button(action.title, action: action.run)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(height: PanelLayout.thumbnail.height)
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// В меню только то, что больше взять негде. Папка скриншотов открывается из
/// Finder, заготовки правятся из настроек — обе строки отсюда убраны, чтобы
/// меню оставалось коротким.
private struct SettingsMenu: View {
    let onOpenSettings: () -> Void

    var body: some View {
        Menu {
            Button("Настройки…") { onOpenSettings() }
            Divider()
            Button("Выйти из Quick") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
