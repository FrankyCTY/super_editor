# Super Editor Search Feature

A complete implementation of search functionality for Super Editor with text highlighting.

## Features

- **Text Search**: Find any text in your document
- **Highlight Matches**: All matches highlighted in yellow
- **Active Match**: Current match highlighted in orange
- **Case Sensitivity**: Toggle case-sensitive search
- **Keyboard Navigation**:
  - `Cmd+F` / `Ctrl+F`: Open search panel
  - `Enter` or `F3`: Next match
  - `Shift+F3`: Previous match
  - `Esc`: Close search panel
- **Match Counter**: Shows current match position (e.g., "2 of 5")

## Files

- **`search_controller.dart`**: Core search logic and highlighting
- **`search_panel.dart`**: Search UI widget
- **`search_demo.dart`**: Complete demo showing integration

## Quick Start

### 1. Add to Your App

```dart
import 'package:flutter/material.dart';
import 'search_feature/search_demo.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SearchDemo(),
    );
  }
}
```

### 2. Integrate with Existing Editor

If you already have a Super Editor setup, here's how to add search:

```dart
class MyEditorScreen extends StatefulWidget {
  @override
  State<MyEditorScreen> createState() => _MyEditorScreenState();
}

class _MyEditorScreenState extends State<MyEditorScreen> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  late SearchController _searchController;

  bool _showSearchPanel = false;

  @override
  void initState() {
    super.initState();

    // Your existing editor setup
    _document = MutableDocument(nodes: [...]);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );

    // Add search controller
    _searchController = SearchController(document: _document);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => setState(() => _showSearchPanel = !_showSearchPanel),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add search panel
          if (_showSearchPanel)
            SearchPanel(
              searchController: _searchController,
              onClose: () => setState(() => _showSearchPanel = false),
            ),

          // Your editor
          Expanded(
            child: SuperEditor(
              editor: _editor,
              document: _document,
              composer: _composer,
              // Add search highlight styles
              stylesheet: defaultStylesheet.copyWith(
                inlineTextStyler: (attributions, existingStyle) {
                  TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

                  if (attributions.contains(searchHighlightAttribution)) {
                    style = style.copyWith(
                      backgroundColor: Colors.yellow.withOpacity(0.4),
                    );
                  }

                  if (attributions.contains(activeSearchHighlightAttribution)) {
                    style = style.copyWith(
                      backgroundColor: Colors.orange.withOpacity(0.6),
                    );
                  }

                  return style;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## API Reference

### SearchController

Main controller for search functionality.

#### Constructor
```dart
SearchController({required Document document})
```

#### Properties
- `String searchQuery` - Current search query
- `List<SearchMatch> matches` - All found matches
- `int currentMatchIndex` - Index of current match
- `SearchMatch? currentMatch` - Current match object
- `bool caseSensitive` - Whether search is case-sensitive

#### Methods
- `void search(String query)` - Perform search
- `void nextMatch()` - Navigate to next match
- `void previousMatch()` - Navigate to previous match
- `void clear()` - Clear search and highlights

#### Example
```dart
// Create controller
final searchController = SearchController(document: document);

// Perform search
searchController.search('hello');

// Navigate matches
searchController.nextMatch();
searchController.previousMatch();

// Check results
print('Found ${searchController.matches.length} matches');
print('Current: ${searchController.currentMatchIndex + 1}');

// Clear
searchController.clear();
```

### SearchPanel

UI widget for search interface.

#### Constructor
```dart
SearchPanel({
  required SearchController searchController,
  VoidCallback? onClose,
})
```

#### Features
- Text input field
- Match counter display
- Case sensitivity toggle
- Previous/Next navigation buttons
- Close button
- Keyboard shortcuts

### SearchMatch

Represents a single match in the document.

#### Properties
- `String nodeId` - ID of the document node containing the match
- `int startOffset` - Start position in the text
- `int endOffset` - End position in the text

## Customization

### Custom Highlight Colors

Modify the stylesheet in your SuperEditor:

```dart
SuperEditor(
  stylesheet: defaultStylesheet.copyWith(
    inlineTextStyler: (attributions, existingStyle) {
      TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

      // Customize regular match highlight
      if (attributions.contains(searchHighlightAttribution)) {
        style = style.copyWith(
          backgroundColor: Colors.green.withOpacity(0.3), // Your color
          color: Colors.black, // Text color
        );
      }

      // Customize active match highlight
      if (attributions.contains(activeSearchHighlightAttribution)) {
        style = style.copyWith(
          backgroundColor: Colors.blue.withOpacity(0.5), // Your color
          fontWeight: FontWeight.bold,
        );
      }

      return style;
    },
  ),
)
```

### Custom Search Panel

Create your own search UI by using the SearchController directly:

```dart
class CustomSearchBar extends StatelessWidget {
  final SearchController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: controller.search,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  suffixText: controller.matches.isEmpty
                    ? ''
                    : '${controller.currentMatchIndex + 1}/${controller.matches.length}',
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: controller.previousMatch,
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward),
              onPressed: controller.nextMatch,
            ),
          ],
        );
      },
    );
  }
}
```

## Advanced Usage

### Programmatic Search

```dart
// Search and navigate programmatically
_searchController.search('important');

if (_searchController.matches.isNotEmpty) {
  // Jump to specific match
  _searchController.currentMatchIndex = 2; // Third match

  // Get match details
  final match = _searchController.currentMatch;
  print('Match at node: ${match.nodeId}, position: ${match.startOffset}');
}
```

### Scroll to Match

To scroll to the current match, you can extend the functionality:

```dart
void scrollToCurrentMatch() {
  final match = _searchController.currentMatch;
  if (match == null) return;

  // Update composer selection to the match
  _composer.selection = DocumentSelection(
    base: DocumentPosition(
      nodeId: match.nodeId,
      nodePosition: TextNodePosition(offset: match.startOffset),
    ),
    extent: DocumentPosition(
      nodeId: match.nodeId,
      nodePosition: TextNodePosition(offset: match.endOffset + 1),
    ),
  );
}
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+F` / `Ctrl+F` | Open search panel |
| `Enter` | Next match |
| `F3` | Next match |
| `Shift+F3` | Previous match |
| `Esc` | Close search panel |

## Troubleshooting

### Highlights not showing

Make sure you've added the `inlineTextStyler` to your stylesheet:

```dart
stylesheet: defaultStylesheet.copyWith(
  inlineTextStyler: (attributions, existingStyle) {
    // Add your styling logic here
  },
)
```

### Search not finding matches

- Check if `caseSensitive` is set correctly
- Verify the document has text content
- Ensure you're searching TextNode types (not images, etc.)

### Performance with large documents

For very large documents (1000+ nodes), consider:
- Debouncing search input
- Limiting visible matches
- Implementing pagination

Example debounced search:
```dart
Timer? _debounce;

void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 300), () {
    _searchController.search(query);
  });
}
```

## License

This code is provided as an example for Super Editor integration.
