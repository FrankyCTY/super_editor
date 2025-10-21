## Complete E2E Function Call Graph for "User types 'H'"

### 1. **UI Widget Entry Point**
```
SuperEditor (widget)
└── build() method (line 684)
    └── DocumentScaffold
        └── textInputBuilder: _buildTextInputSystem() (line 781)
            └── SuperEditorImeInteractor (when inputSource is ime)
```

### 2. **IME Connection Setup**
```
SuperEditorImeInteractorState.initState() (line 176)
└── _setupImeConnection() (line 180)
    └── DocumentImeInputClient (created as _documentImeClient)
        └── Implements DeltaTextInputClient
        └── updateEditingValueWithDeltas() method (line 192) ← **THIS IS WHERE DELTAS ARRIVE**
```

### 3. **Delta Reception**
```
DocumentImeInputClient.updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas)
└── editorImeLog.fine("Received edit deltas from platform: ${textEditingDeltas.length} deltas")
└── _updatePlatformImeValueWithDeltas(textEditingDeltas) (line 229)
└── textDeltasDocumentEditor.applyDeltas(textEditingDeltas) (line 232) ← **KEY CALL**
```

### 4. **Delta Processing** (`document_delta_editing.dart`)
```
TextDeltasDocumentEditor.applyDeltas(List<TextEditingDelta> textEditingDeltas) (line 46)
└── editor.startTransaction() (line 72) ← **Transaction begins**
└── for (final delta in textEditingDeltas) {
    if (delta is TextEditingDeltaInsertion) {
        _applyInsertion(delta) (line 81) ← **Our 'H' delta**
    }
}
```

### 5. **Insertion Processing**
```
TextDeltasDocumentEditor._applyInsertion(TextEditingDeltaInsertion delta) (line 119)
└── editorImeLog.fine('Inserted text: "${delta.textInserted}"') ← **Logs "H"**
└── insert(insertionSelection, delta.textInserted) (line 180)
└── _insertPlainText(insertionPosition, text) (line 325)
```

### 6. **Request Generation**
```
TextDeltasDocumentEditor._insertPlainText() (line 343)
└── editor.execute([
    InsertTextRequest(
        documentPosition: insertionPosition,
        textToInsert: text, ← **"H"**
        attributions: composerPreferences.currentAttributions,
        createdAt: DateTime.now(),
    ),
]) (line 380)
```

### 7. **Editor Pipeline** (`editor.dart`)
```
Editor.execute(List<EditRequest> requests) (line 241)
└── _findCommandForRequest(request) (line 265)
    └── Maps InsertTextRequest → InsertTextCommand
└── _executeCommand(command) (line 266)
```

### 8. **Command Execution** (`text.dart`)
```
InsertTextCommand.execute(EditContext context, CommandExecutor executor) (line 2151)
└── textNode = textNode.copyTextNodeWith(
    text: textNode.text.insertString(
        textToInsert: textToInsert, ← **"H" inserted**
        startOffset: textOffset,
    ),
)
└── document.replaceNodeById(textNode.id, textNode) (line 2174)
└── executor.logChanges([
    DocumentEdit(
        TextInsertionEvent(
            nodeId: textNode.id,
            offset: textOffset,
            text: AttributedText(textToInsert), ← **"H"**
        ),
    ),
]) (line 2179)
```

### 9. **Event Notification**
```
Editor._notifyListeners(List<EditEvent> changeList) (line 474)
└── for (final listener in _changeListeners) {
    listener.onEdit(changeList) (line 478)
}
```

### 10. **Document Change Notification**
```
MutableDocument.onTransactionEnd(List<EditEvent> edits) (line 1363)
└── final documentChanges = edits.whereType<DocumentEdit>().map((edit) => edit.change).toList()
└── final changeLog = DocumentChangeLog(documentChanges)
└── for (final listener in _listeners) {
    listener(changeLog) ← **Final consumer notification**
}
```

## Key Files in Order:

1. **`super_editor.dart`** - Main widget, builds IME interactor
2. **`supereditor_ime_interactor.dart`** - IME connection management
3. **`document_ime_communication.dart`** - Receives `updateEditingValueWithDeltas()`
4. **`document_delta_editing.dart`** - Processes deltas, creates requests
5. **`editor.dart`** - Routes requests to commands
6. **`text.dart`** - Executes text insertion command
7. **`editor.dart`** - Notifies listeners of events
8. **`document.dart`** - Notifies document change listeners

## Consumer Access Points:

1. **EditListener**: `editor.addListener((events) => ...)`
2. **DocumentListener**: `document.addListener((changeLog) => ...)`
3. **ValueListenable**: `composer.selectionNotifier.addListener(() => ...)`

The architecture ensures that every character typed goes through this complete pipeline, generating events that consumers can observe at multiple levels.