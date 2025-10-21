# Evidence: Node ID Issue with Undo/Redo and parseQuillDeltaDocument

## Summary of the Issue

When using `parseQuillDeltaDocument` to load documents from a database, **new node IDs are generated every time**. This breaks SuperEditor's undo/redo system because:

1. **Initial load**: `parseQuillDeltaDocument` creates NEW node IDs for every document load
2. **User edits**: SuperEditor's history tracks changes with those node IDs
3. **Undo operation**: SuperEditor tries to restore nodes by their IDs, but the IDs don't match the original document structure
4. **Result**: The document gets cleared because the node references are invalid

## Evidence from Code

### 1. parseQuillDeltaDocument Creates New Node IDs Every Time

**File**: `super_editor_quill/lib/src/parsing/parser.dart`

**Line 382**: Every time text is parsed, a new node ID is generated:
```dart
final newNodeId = Editor.createNodeId();
```

**Line 46 in editor.dart**: `Editor.createNodeId()` generates a **universally unique ID** using UUID v4:
```dart
static String createNodeId() => _uuid.v4();
```

This means:
- Every time you call `parseQuillDeltaDocument`, all nodes get **brand new IDs**
- Previous node IDs are **completely lost**
- There's no persistence of node IDs between document loads

### 2. SuperEditor's Undo System Relies on Node IDs

**File**: `super_editor/lib/src/core/editor.dart`

**Lines 386-448**: The undo system works by:
1. Resetting the document to a snapshot (line 421)
2. Replaying all history commands except the undone one (lines 428-436)

```dart
void undo() {
  // ...
  
  // Move the latest command from the history to the future.
  final transactionToUndo = _history.removeLast();
  _future.add(transactionToUndo);
  
  // Revert all editables to the last snapshot.
  for (final editable in context._resources.values) {
    editable.reset();  // <-- CRITICAL: Restores to snapshot
  }
  
  // Replay all history except for the most recent command transaction.
  for (final commandTransaction in _history) {
    for (final command in commandTransaction.commands) {
      final commandChanges = _executeCommand(command);  // <-- Replays commands
      changeEvents.addAll(commandChanges);
    }
  }
}
```

**Lines 1449-1456**: The `reset()` method restores the document from a snapshot:
```dart
@override
void reset() {
  _nodes
    ..clear()
    ..addAll(_latestNodesSnapshot);  // <-- Restores from snapshot
  _refreshNodeIdCaches();
  
  _didReset = true;
}
```

**Lines 1127**: The snapshot is created at document initialization:
```dart
MutableDocument({
  List<DocumentNode>? nodes,
}) : _nodes = nodes ?? [] {
  _refreshNodeIdCaches();
  
  _latestNodesSnapshot = List.from(_nodes);  // <-- Initial snapshot
}
```

### 3. Commands Reference Nodes by ID

**File**: `super_editor/lib/src/default_editor/multi_node_editing.dart`

**Lines 290-312**: Insert commands store node IDs:
```dart
class InsertNodeAtIndexCommand extends EditCommand {
  InsertNodeAtIndexCommand({
    required this.nodeIndex,
    required this.newNode,  // <-- Contains a specific node ID
  });
  
  final int nodeIndex;
  final DocumentNode newNode;
  
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    document.insertNodeAt(nodeIndex, newNode);  // <-- Uses the stored node
    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(newNode.id, nodeIndex),  // <-- References node.id
      )
    ]);
  }
}
```

**Lines 1262-1267**: The document doesn't copy nodes when inserting:
```dart
void insertNodeAt(int index, DocumentNode node) {
  if (index <= _nodes.length) {
    _nodes.insert(index, node);  // <-- Direct insertion, NO COPY
    _refreshNodeIdCaches();
  }
}
```

### 4. The Problem in Action

**Scenario**:
1. User loads document from database via `parseQuillDeltaDocument`
   - Document created with node IDs: `["abc-123", "def-456", "ghi-789"]`
   - Snapshot created with these IDs

2. User types text, creating edit commands:
   - Commands reference node ID `"abc-123"`

3. User saves document to database (Quill Delta format - no node IDs)

4. User loads document again via `parseQuillDeltaDocument`
   - NEW document created with node IDs: `["xyz-111", "uvw-222", "rst-333"]`
   - But undo history still references old IDs: `["abc-123", "def-456", "ghi-789"]`

5. User presses undo:
   - System resets to snapshot (contains old IDs)
   - System tries to replay commands referencing old IDs
   - **Node IDs don't match** → Commands fail or produce unexpected results

## Supporting Evidence from CHANGELOG

**File**: `super_editor/CHANGELOG.md`

**Lines 210-211**:
```
* BREAKING: When inserting new nodes, make copies of the provided nodes instead of
  retaining the original node, so that undo/redo can restore the original state.
```

This confirms that:
- The undo/redo system was designed to restore "original state"
- Node identity matters for undo/redo
- The system expects stable node references

## The Root Cause

The Quill Delta format **does not include node IDs**. It only stores content and formatting. This is by design - Quill Delta is a format for representing rich text changes, not document structure with persistent identifiers.

When `parseQuillDeltaDocument` is called:
- It creates a **completely new document** from scratch
- It generates **new UUIDs** for every node
- There's no way to preserve the original node IDs

## Solution Approaches

1. **Store node IDs separately** alongside Quill Delta in the database
2. **Disable undo/redo history** on document load (`isHistoryEnabled: false` temporarily)
3. **Clear history after document load** (lose undo capability but prevent corruption)
4. **Use a different serialization format** that preserves node IDs (e.g., custom JSON format)
5. **Implement a custom parser** that accepts a map of position → node ID to restore IDs

## Test Evidence

**File**: `super_editor/test/super_editor/supereditor_copy_and_paste_test.dart`

**Lines 135-142**: The test suite validates that node IDs remain stable after undo:
```dart
// Undo the text insertion (this causes the paste command re-run).
testContext.editor.undo();

// Ensure that the node IDs in the document didn't change after re-running
// the paste command.
final newNodeIds = testContext.document.toList().map((node) => node.id).toList();
expect(newNodeIds, originalNodeIds);  // <-- Node IDs must match!
```

This confirms that SuperEditor's undo system **expects node IDs to remain stable**.
