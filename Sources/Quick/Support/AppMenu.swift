import AppKit

/// Главное меню приложения.
///
/// Quick живёт в режиме `.accessory` и меню-бар не показывает — но меню ему
/// всё равно нужно. В AppKit ⌘X/⌘C/⌘V/⌘A/⌘Z не встроены в текстовые поля:
/// это сочетания клавиш пунктов меню «Правка», и `performKeyEquivalent`
/// ищет их в `NSApp.mainMenu`. Без меню в редакторе заготовок и в настройках
/// не работает даже вставка.
enum AppMenu {
    static func install() {
        let main = NSMenu()
        main.addItem(submenu(application))
        main.addItem(submenu(edit))
        main.addItem(submenu(window))
        NSApp.mainMenu = main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    private static var application: NSMenu {
        let menu = NSMenu(title: "Quick")
        menu.addItem(
            withTitle: "Выйти из Quick",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }

    private static var edit: NSMenu {
        let menu = NSMenu(title: "Правка")
        // Отмену и повтор ищем по имени: `undo:` и `redo:` объявлены в
        // `NSResponder` неформально, прямой ссылки на селектор нет.
        menu.addItem(withTitle: "Отменить", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Повторить", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Вырезать", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Скопировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выбрать все", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static var window: NSMenu {
        let menu = NSMenu(title: "Окно")
        menu.addItem(
            withTitle: "Закрыть",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        return menu
    }
}
