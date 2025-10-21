## Super Editor Architecture Overview

### Core Architecture Flow
The super_editor follows a **Command Pattern** with **Event Sourcing**:

**User Input → IME Deltas → EditRequests → EditCommands → EditEvents → Consumer Notifications**

### Simple Use Case: User Types "Hello" in a Paragraph

Let's trace through what happens when a user types the letter "H" in an existing paragraph:

#### 1. **IME Input Processing**
- User presses "H" on their keyboard
- Flutter's IME system generates a `TextEditingDeltaInsertion`
- The delta contains: `"textInserted": "H"`, `"insertionOffset": X`, etc.

#### 2. **Delta Processing** (`document_delta_editing.dart`)
```dart
// Line ~80 in document_delta_editing.dart
if (delta is TextEditingDeltaInsertion) {
  _applyInsertion(delta);
}
```

#### 3. **Request Creation** (in `_applyInsertion`)
```dart
// Line ~180 in document_delta_editing.dart
editor.execute([
  InsertTextRequest(
    documentPosition: insertionPosition,
    textToInsert: text,
    attributions: composerPreferences.currentAttributions,
    createdAt: DateTime.now(),
  ),
]);
```

#### 4. **Editor Pipeline** (`editor.dart`)
The `Editor` acts as the central hub with a **Chain of Responsibility** pattern:

```dart
// Line ~290 in editor.dart
EditCommand _findCommandForRequest(EditRequest request) {
  for (final handler in requestHandlers) {
    command = handler(this, request);
    if (command != null) {
      return command;
    }
  }
}
```

Handler mapping from `defaultRequestHandlers` in `default_document_editor.dart`:
```dart
(editor, request) => request is InsertTextRequest
    ? InsertTextCommand(
        documentPosition: request.documentPosition,
        textToInsert: request.textToInsert,
        attributions: request.attributions,
        createdAt: request.createdAt,
      )
    : null,
```

#### 5. **Command Execution** (`text.dart`)
```dart
// Line ~2163 in text.dart
textNode = textNode.copyTextNodeWith(
  text: textNode.text.insertString(
    textToInsert: textToInsert,
    startOffset: textOffset,
    applyAttributions: {...attributions},
  ),
);

// Document mutation
document.replaceNodeById(textNode.id, textNode);

// Event generation
executor.logChanges([
  DocumentEdit(
    TextInsertionEvent(
      nodeId: textNode.id,
      offset: textOffset,
      text: AttributedText(textToInsert),
    ),
  ),
]);
```

#### 6. **Event Notification Flow**
The generated events propagate through multiple layers:

```dart
// Line ~365 in editor.dart - notify all listeners
_notifyListeners(List<EditEvent>.from(_activeChangeList!, growable: false));

// Line ~474 in editor.dart - listener notification
for (final listener in _changeListeners) {
  listener.onEdit(changeList);
}
```

#### 7. **Final Consumer Accessibility**

**Option A: EditListener Pattern**
Consumers can register as listeners:
```dart
editor.addListener((List<EditEvent> events) {
  for (final event in events) {
    if (event is DocumentEdit) {
      final change = event.change;
      if (change is TextInsertionEvent) {
        print("Text inserted: ${change.text.text} at offset ${change.offset}");
      }
    }
  }
});
```

**Option B: Document Listeners**
The `MutableDocument` itself acts as a listener:
```dart
// Line ~1371 in editor.dart (within MutableDocument.onTransactionEnd)
final changeLog = DocumentChangeLog(documentChanges);
for (final listener in _listeners) {
  listener(changeLog);
}
```

**Option C: Document Observers**
Consumers can listen directly to document changes:
```dart
document.addListener((DocumentChangeLog changeLog) {
  for (final change in changeLog.changes) {
    if (change is TextInsertionEvent) {
      print("Text inserted: ${change.text.text}");
    }
  }
});
```

### Architecture Benefits

1. **Separation of Concerns**: Input handling, mutation logic, and event notifications are cleanly separated
2. **Testability**: Each layer (Request → Command → Event) can be tested in isolation
3. **Extensibility**: New request types can be added by implementing new handlers
4. **Undo/Redo**: The event-based system naturally supports transaction-based undo/redo
5. **Real-time Collaboration**: The event stream can be serialized and transmitted for collaborative editing

### Key Files and Their Roles

- **`editor.dart`**: Central orchestrator, handles request routing and event distribution
- **`default_document_editor.dart`**: Request-to-command mapping definitions
- **`document_delta_editing.dart`**: IME input processing and delta → request conversion
- **`text.dart`**: Command implementations (e.g., `InsertTextCommand`)
- **`_example_document.dart`**: Document structure definition
- **`example_editor.dart`**: Complete app integration showing how to wire everything together

This architecture makes super_editor both powerful and maintainable, allowing developers to intercept and respond to any document change at multiple points in the pipeline.