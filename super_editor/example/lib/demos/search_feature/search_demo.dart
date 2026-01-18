import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'search_controller.dart';
import 'search_panel.dart';

/// Demo showing how to integrate search functionality with Super Editor
class SearchDemo extends StatefulWidget {
  const SearchDemo({Key? key}) : super(key: key);

  @override
  State<SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<SearchDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final SearchController _searchController;

  final FocusNode _editorFocusNode = FocusNode();
  bool _showSearchPanel = false;

  @override
  void initState() {
    super.initState();

    // Create document with sample content
    _document = MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('Search Demo'),
          metadata: {'blockType': header1Attribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'This demo shows how to search through your document. Try pressing Cmd+F (Mac) or Ctrl+F (Windows/Linux) to open the search panel.',
          ),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('Sample Text for Searching'),
          metadata: {'blockType': header2Attribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'The quick brown fox jumps over the lazy dog. The fox is quick and clever.',
          ),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Search functionality allows you to find text anywhere in your document. You can search for words, phrases, or even partial matches.',
          ),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Try searching for "search" or "fox" to see the highlighting in action!',
          ),
        ),
        ListItemNode.unordered(
          id: Editor.createNodeId(),
          text: AttributedText('Search is case-insensitive by default'),
        ),
        ListItemNode.unordered(
          id: Editor.createNodeId(),
          text: AttributedText('Click the Aa icon to toggle case-sensitive search'),
        ),
        ListItemNode.unordered(
          id: Editor.createNodeId(),
          text: AttributedText('Use Enter or F3 to jump to the next match'),
        ),
        ListItemNode.unordered(
          id: Editor.createNodeId(),
          text: AttributedText('Use Shift+F3 to jump to the previous match'),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('More Sample Content'),
          metadata: {'blockType': header2Attribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Search through this text to find specific words or phrases.',
          ),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(
            'The search feature highlights all matches in yellow, with the current match highlighted in orange for easy navigation.',
          ),
        ),
      ],
    );

    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );

    _searchController = SearchController(document: _document);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearchPanel() {
    setState(() {
      _showSearchPanel = !_showSearchPanel;
      if (!_showSearchPanel) {
        _editorFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Feature Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearchPanel,
            tooltip: 'Search (Cmd/Ctrl+F)',
          ),
        ],
      ),
      body: Focus(
        onKeyEvent: (node, event) {
          // Handle Cmd/Ctrl+F to open search
          if (event is KeyDownEvent) {
            final isCommandPressed = HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed;

            if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
              _toggleSearchPanel();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            // Search panel (conditionally shown)
            if (_showSearchPanel)
              SearchPanel(
                searchController: _searchController,
                onClose: () {
                  setState(() {
                    _showSearchPanel = false;
                    _editorFocusNode.requestFocus();
                  });
                },
              ),

            // Editor
            Expanded(
              child: _buildEditor(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return SuperEditor(
      editor: _editor,
      document: _document,
      composer: _composer,
      focusNode: _editorFocusNode,
      stylesheet: _createStylesheet(),
      documentOverlayBuilders: [
        DefaultCaretOverlayBuilder(
          caretStyle: const CaretStyle().copyWith(color: Colors.blue),
        ),
      ],
    );
  }

  /// Creates a stylesheet with search highlight styles
  Stylesheet _createStylesheet() {
    return defaultStylesheet.copyWith(
      inlineTextStyler: (attributions, existingStyle) {
        // Start with default styling
        TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

        // Apply search highlight background
        if (attributions.contains(searchHighlightAttribution)) {
          style = style.copyWith(
            backgroundColor: Colors.yellow.withOpacity(0.4),
          );
        }

        // Apply active search highlight (current match)
        if (attributions.contains(activeSearchHighlightAttribution)) {
          style = style.copyWith(
            backgroundColor: Colors.orange.withOpacity(0.6),
            fontWeight: FontWeight.bold,
          );
        }

        return style;
      },
    );
  }
}
