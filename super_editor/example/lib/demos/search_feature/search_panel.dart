import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_controller.dart';

/// A search panel UI that displays above the editor
class SearchPanel extends StatefulWidget {
  const SearchPanel({
    Key? key,
    required this.searchController,
    this.onClose,
  }) : super(key: key);

  final SearchController searchController;
  final VoidCallback? onClose;

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.searchController.searchQuery);
    _focusNode = FocusNode();

    // Auto-focus when panel opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    widget.searchController.addListener(_onSearchUpdate);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchUpdate);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchUpdate() {
    setState(() {});
  }

  void _onSearchChanged(String query) {
    widget.searchController.search(query);
  }

  void _onClose() {
    widget.searchController.clear();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final matchCount = widget.searchController.matches.length;
    final currentIndex = widget.searchController.currentMatchIndex;
    final hasMatches = matchCount > 0;

    return Material(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Search icon
            Icon(
              Icons.search,
              size: 20,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 8),

            // Search input field
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    // Enter or F3: Next match
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.f3) {
                      if (event.logicalKey == LogicalKeyboardKey.f3 &&
                          HardwareKeyboard.instance.isShiftPressed) {
                        widget.searchController.previousMatch();
                      } else {
                        widget.searchController.nextMatch();
                      }
                      return KeyEventResult.handled;
                    }

                    // Escape: Close search
                    if (event.logicalKey == LogicalKeyboardKey.escape) {
                      _onClose();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            // Match counter
            if (hasMatches) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${currentIndex + 1} of $matchCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (_textController.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                'No matches',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],

            const SizedBox(width: 8),

            // Case sensitive toggle
            Tooltip(
              message: 'Match case',
              child: InkWell(
                onTap: () {
                  widget.searchController.caseSensitive =
                      !widget.searchController.caseSensitive;
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.searchController.caseSensitive
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.text_fields,
                    size: 18,
                    color: widget.searchController.caseSensitive
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Previous match button
            Tooltip(
              message: 'Previous match (Shift+F3)',
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                iconSize: 20,
                splashRadius: 20,
                onPressed: hasMatches ? widget.searchController.previousMatch : null,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),

            // Next match button
            Tooltip(
              message: 'Next match (Enter or F3)',
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                iconSize: 20,
                splashRadius: 20,
                onPressed: hasMatches ? widget.searchController.nextMatch : null,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),

            // Close button
            Tooltip(
              message: 'Close (Esc)',
              child: IconButton(
                icon: const Icon(Icons.close),
                iconSize: 20,
                splashRadius: 20,
                onPressed: _onClose,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
