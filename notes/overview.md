# MyApp Editor – 30 000 ft map  
*(built on super_editor – keeps the same extension points, just re-labels the blocks)*

---

## 1. Core editing engine (`lib/src/core/`)
| Artifact | Purpose |
| --- | --- |
| **Document** | Immutable tree of `DocumentNode`s (Paragraph, ListItem, Image, Video, Math, …) |
| **DocumentComposer** | Caret position, selection, current attributions, composing region |
| **Editor** | Single mediator: |
| | • converts `EditRequest` ➜ `EditCommand` |
| | • runs commands inside a `Transaction` (undo/redo unit) |
| | • fires `EditReaction`s (auto-markdown, hashtags, spell-check, …) |
| | • notifies listeners → UI rebuilds once per transaction |

---

## 2. Visual layer (`lib/src/layout_single_column/`)
*Single source of truth for what users see*

1. **SingleColumnLayoutPresenter** walks the document once per frame  
2. For every node asks **ComponentBuilder** list (your order)  
   - first non-null widget wins → becomes the on-screen block  
3. **Stylesheet** + **StylePhase**s add:  
   padding, colours, selection highlights, composing underlines, block decorations, …

---

## 3. Input layer (pick one per platform)
| Path | Widget | Data flow |
| --- | --- | --- |
| **hardware keyboard** | `SuperEditorHardwareKeyHandler` | `RawKeyboard` ➜ `EditRequest` |
| **IME** (default mobile) | `SuperEditorImeInteractor` | OS IME deltas ➜ `DocumentImeInputClient` ➜ `TextDeltasDocumentEditor` ➜ `EditRequest` |

`SuperEditorImeInteractor` is the **StatefulWidget** that creates, decorates and attaches the single `DocumentImeInputClient` to Flutter’s `TextInput` system.

**Customise at:**  
`imeOverrides:`, `keyboardActions:`, `EditReaction`s

---

## 4. Plugin / extension points
| Extension | How |
| --- | --- |
| new block type | implement `ComponentBuilder` |
| new key behaviour | insert into `keyboardActions` |
| new overlay | supply `documentUnderlayBuilders` / `documentOverlayBuilders` |
| post-command side effect | add `EditReaction` |

All attached automatically via `SuperEditorPlugin` – no fork of core code required.

---

## 5. Life of a keystroke (IME mode)
```
user types "a"
→ Flutter delta
→ SuperEditorImeInteractor → DocumentImeInputClient.updateEditingValueWithDeltas
→ TextDeltasDocumentEditor.applyDeltas
→ InsertTextRequest
→ Editor.executeRequest
→ InsertTextCommand
→ Transaction (document + composer change)
→ History.push
→ EditReaction(s) (e.g. turn "# " into heading)
→ notify listeners
→ SingleColumnLayoutPresenter rebuilds
→ ParagraphComponentBuilder returns TextComponent
→ TextComponent paints bigger text (header style)
```

*Caret, handles, toolbar, floating cursor, selection colour, undo/redo, serialisation, IME sync already wired – customise only the labelled extension points.*

---

# Super Editor Architecture Overview

## Project Structure

The Super Editor codebase is organized into several main packages and directories:

### Core Packages
- **`super_editor/`** - Main editor package with core functionality
- **`super_clones/`** - Example implementations mimicking popular editors (Google Docs, Medium, Obsidian, Quill, Slack, Bear)
- **`super_text_layout/`** - Text layout and rendering utilities
- **`super_keyboard/`** - Keyboard input handling
- **`super_editor_clipboard/`** - Clipboard operations
- **`super_editor_markdown/`** - Markdown support
- **`super_editor_quill/`** - Quill.js integration
- **`super_editor_spellcheck/`** - Spell checking functionality
- **`attributed_text/`** - Text with rich formatting attributes

## Core Architecture

### 1. Document Model (`src/core/`)
The foundation of Super Editor is its document model:

- **`Document`** - Abstract representation of a document containing `DocumentNode`s
- **`DocumentNode`** - Individual content pieces (paragraphs, images, lists, etc.)
- **`DocumentPosition`** - Logical position within the document
- **`DocumentSelection`** - User selection within the document
- **`DocumentComposer`** - Manages user selection and text styles

### 2. Editor Engine (`src/core/editor.dart`)
The `Editor` class is the central command processor:

- **Request-Command-Event Pattern**: 
  - `EditRequest` → `EditCommand` → `EditEvent`
  - Commands mutate `Editable` objects (Document, Composer, etc.)
  - Events notify listeners of changes
- **Transaction Management**: Groups related changes for undo/redo
- **Reaction Pipeline**: Allows commands to spawn additional commands
- **History Management**: Tracks changes for undo/redo functionality

### 3. Document Layout (`src/core/document_layout.dart`)
Handles visual positioning and rendering:

- **`DocumentLayout`** - Maps logical positions to visual coordinates
- **`DocumentComponent`** - Visual components that render document nodes
- **Position Mapping**: Converts between screen coordinates and document positions
- **Selection Visualization**: Handles caret and selection highlighting

### 4. Infrastructure (`src/infrastructure/`)
Platform-specific and cross-cutting concerns:

- **Platform Support**: iOS, Android, macOS, Web-specific implementations
- **Input Handling**: Touch, mouse, keyboard, IME (Input Method Editor)
- **Scrolling**: Document scrolling and viewport management
- **Serialization**: HTML and plain text export/import
- **Content Layers**: Overlay system for UI elements

### 5. Default Editor (`src/default_editor/`)
Ready-to-use editor implementation:

- **`SuperEditor`** - Main widget that brings everything together
- **Component Builders**: Creates visual components for different node types
- **Gesture Handlers**: Touch and mouse interaction handling
- **Keyboard Actions**: Standard keyboard shortcuts and behaviors
- **Styling System**: Stylesheet-based theming

## Key Design Patterns

### 1. Command Pattern
All document changes go through the command system:
```dart
Editor.execute([EditRequest]) → EditCommand → Document Changes → EditEvent
```

### 2. Layered Architecture
- **Core Layer**: Document model and editor engine
- **Layout Layer**: Visual positioning and rendering
- **Infrastructure Layer**: Platform-specific implementations
- **UI Layer**: Widgets and user interactions

### 3. Plugin System
Extensible through `SuperEditorPlugin`:
- Add custom keyboard actions
- Create new component builders
- Add document layers (overlays/underlays)
- Implement custom tap handlers

### 4. Component-Based Rendering
Each document node type has a corresponding component:
- `ParagraphComponent` for text
- `ImageComponent` for images
- `ListItemComponent` for lists
- Custom components via `ComponentBuilder`

## Data Flow

1. **User Input** → Gesture handlers detect interaction
2. **Request Creation** → Input converted to `EditRequest`
3. **Command Execution** → `Editor` finds appropriate `EditCommand`
4. **Document Mutation** → Command modifies `Document` and `DocumentComposer`
5. **Event Notification** → `EditEvent`s notify listeners
6. **UI Update** → Layout recalculates and rebuilds components
7. **Visual Feedback** → User sees the change

## Platform Support

### Mobile (iOS/Android)
- Touch gesture handling
- Software keyboard integration
- Platform-specific selection handles
- IME (Input Method Editor) support

### Desktop (macOS/Windows/Linux)
- Mouse interaction
- Hardware keyboard shortcuts
- Context menus
- Drag and drop

### Web
- Browser IME integration
- Touch and mouse support
- Clipboard API integration

## Extensibility

### Custom Node Types
1. Create a `DocumentNode` subclass
2. Implement a `ComponentBuilder` for visual rendering
3. Add keyboard actions if needed
4. Register with the editor

### Custom Plugins
1. Extend `SuperEditorPlugin`
2. Add behaviors in `attach()` method
3. Provide UI components via getters
4. Register with `SuperEditor`

### Custom Styling
1. Create custom `Stylesheet` rules
2. Add `SingleColumnLayoutStylePhase` for complex styling
3. Override component builders for custom appearance

## Example Implementations

The `super_clones/` directory contains full implementations mimicking popular editors:

- **Google Docs**: Collaborative editing features
- **Medium**: Clean, distraction-free writing
- **Obsidian**: Note-taking with linking
- **Quill**: Rich text editing
- **Slack**: Chat-style editing
- **Bear**: Markdown-based writing

Each clone demonstrates different aspects of the Super Editor architecture and serves as a reference for building custom editors.

## Key Benefits

1. **Modularity**: Clean separation of concerns
2. **Extensibility**: Plugin system for custom functionality
3. **Platform Support**: Works across all Flutter platforms
4. **Performance**: Efficient rendering and layout
5. **Flexibility**: Can build anything from simple text editors to complex document editors
6. **Maintainability**: Well-structured codebase with clear patterns