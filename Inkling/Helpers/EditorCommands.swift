import SwiftUI

/// Actions the editor exposes for keyboard shortcuts
struct EditorActions {
    var insertBold: () -> Void = {}
    var insertItalic: () -> Void = {}
    var insertStrikethrough: () -> Void = {}
    var insertHeading: () -> Void = {}
    var insertQuote: () -> Void = {}
    var insertList: () -> Void = {}
    var togglePreview: () -> Void = {}
}

struct EditorActionsKey: FocusedValueKey {
    typealias Value = EditorActions
}

extension FocusedValues {
    var editorActions: EditorActions? {
        get { self[EditorActionsKey.self] }
        set { self[EditorActionsKey.self] = newValue }
    }
}
