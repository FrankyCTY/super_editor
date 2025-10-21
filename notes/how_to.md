# SuperEditor Architecture Overview

SuperEditor maintains a clean separation between:

1. The **in-memory document** (a tree of `DocumentNode`s: `ParagraphNode`, `ListItemNode`, `TaskNode`, `ImageNode`, etc.).  
2. The **UI widgets** that paint those nodes on screen (`ParagraphComponent`, `OrderedListItemComponent`, `TaskComponent`, etc.).  
3. The **input pipeline** that turns keystrokes / IME deltas into `EditRequest`s, runs them through `EditorCommand`s, and finally notifies the widgets to rebuild.

| You type | → | `DocumentImeInputClient` (or keyboard handlers) | → | `EditRequest` | → | `EditorCommand` | → | `MutableDocument` updated | → | `SingleColumnDocumentLayout` rebuilds the widget for that node |
|----------|---|---------------------------------------------------|---|---------------|---|-----------------|---|---------------------------|---|---------------------------------------------------------------|

## Where Are the “Actual UI-Only Widgets”?

All of them live in  
`super_editor/lib/src/default_editor/layout_single_column/components/`  
(they are also re-exported through the main library).

### Quick Map (Node → Widget That Paints It)

| Node Class | Widget That Renders It | File |
|------------|------------------------|------|
| `ParagraphNode` | `TextComponent` | `text_component.dart` |
| `ParagraphNode` with `header1`…`header6` attribution | same `TextComponent`, but the **stylesheet** gives it a bigger font | `text_component.dart` + `stylesheet.dart` |
| `ListItemNode` (ordered) | `OrderedListItemComponent` | `list_items.dart` |
| `ListItemNode` (unordered) | `UnorderedListItemComponent` | `list_items.dart` |
| `TaskNode` | `TaskComponent` | `task_component.dart` |
| `ImageNode` | `ImageComponent` | `image_component.dart` |
| `HorizontalRuleNode` | `HorizontalRuleComponent` | `horizontal_rule_component.dart` |
| `BlockquoteNode` | `BlockquoteComponent` | `blockquote_component.dart` |

The “heading” you see on screen **is not a special `HeadingComponent`**.  
It is just a regular `TextComponent` whose `ParagraphNode` carries a `header1` (or `header2` …) attribution.  
The `SingleColumnLayout` asks the `Stylesheet` for the `TextStyle` that corresponds to that attribution, and the `TextComponent` paints itself with the bigger / bolder style.

## How to Recognize a Heading in Code

```dart
final node = document.getNodeById(nodeId) as ParagraphNode;
final isHeader = node.getMetadataValue('blockType') == header1Attribution;
```

## Intercepting Input and Turning “# ” into a Heading

The editor does **not** hard-code that mapping.  
Instead it ships a **reaction** (`EditReaction`) that listens for `InsertTextRequest`s, checks whether the inserted text is a space that follows “# ” at the start of a paragraph, and if so:

1. Issues a `RemoveTextRequest` to delete the “# ”.  
2. Issues a `ChangeParagraphBlockTypeRequest` to add the `header1` attribution to the node.

You can find the default reactions in  
`super_editor/lib/src/default_editor/default_editor_reactions.dart`.

## Mini Walk-Through to Create Your Own Heading Widget

(You rarely need to, but it shows the plumbing.)

1. Sub-class `DocumentNode` → `MyHeadingNode` (or just reuse `ParagraphNode` with an attribution).  
2. Provide a `ComponentBuilder` that returns your own `MyHeadingComponent` (a `StatelessWidget` that paints huge red text, for example).  
3. Register that builder in the `componentBuilders` list you pass to `SuperEditor`.  
4. Add a reaction that turns “# ” into the block-type that your builder recognizes.

Everything else (caret, selection, drag handles, IME, etc.) keeps working because the editor only cares about the **node**, not about the **widget** you chose to paint it.

## Learn by Looking

Open these files for examples:

* `text_component.dart` – the simplest example (pure text).  
* `list_items.dart` – slightly more complex (adds a leading bullet / number).  
* `task_component.dart` – shows a checkbox + text.  
* `default_editor_reactions.dart` – how keystrokes become structure changes.

That is the entire chain: **node → widget → stylesheet → input pipeline → reaction → node update → widget rebuild**.

**Fact-Check Notes**: This information aligns with the official SuperEditor documentation on pub.dev and the project's architecture. The separation of concerns, node types (e.g., `ParagraphNode` for headers via metadata), widget rendering, and reaction-based input handling (including markdown shortcuts like "# ") are confirmed in the package overview and code examples. No inaccuracies found.