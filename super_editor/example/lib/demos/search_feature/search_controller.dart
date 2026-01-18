import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

/// Attribution used to highlight search results in the document
const searchHighlightAttribution = NamedAttribution('search-highlight');

/// Attribution for the currently active/selected search result
const activeSearchHighlightAttribution = NamedAttribution('active-search-highlight');

/// Manages search functionality for a Super Editor document
class SearchController extends ChangeNotifier {
  SearchController({
    required this.document,
  });

  final Document document;

  /// Current search query
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  /// List of all search result matches
  final List<SearchMatch> _matches = [];
  List<SearchMatch> get matches => List.unmodifiable(_matches);

  /// Index of the currently selected match (-1 if none)
  int _currentMatchIndex = -1;
  int get currentMatchIndex => _currentMatchIndex;

  /// Current match (null if none)
  SearchMatch? get currentMatch =>
      _currentMatchIndex >= 0 && _currentMatchIndex < _matches.length
          ? _matches[_currentMatchIndex]
          : null;

  /// Whether search is case-sensitive
  bool _caseSensitive = false;
  bool get caseSensitive => _caseSensitive;

  set caseSensitive(bool value) {
    if (_caseSensitive == value) return;
    _caseSensitive = value;
    if (_searchQuery.isNotEmpty) {
      search(_searchQuery);
    }
  }

  /// Perform a search through the document
  void search(String query) {
    _searchQuery = query;
    _matches.clear();
    _currentMatchIndex = -1;

    if (query.isEmpty) {
      _clearHighlights();
      notifyListeners();
      return;
    }

    // Search through all text nodes
    for (final node in document) {
      if (node is! TextNode) {
        continue;
      }

      final text = node.text.toPlainText();
      final searchText = _caseSensitive ? text : text.toLowerCase();
      final searchPattern = _caseSensitive ? query : query.toLowerCase();

      // Find all occurrences in this node
      int startIndex = 0;
      while (true) {
        final index = searchText.indexOf(searchPattern, startIndex);
        if (index == -1) break;

        _matches.add(SearchMatch(
          nodeId: node.id,
          startOffset: index,
          endOffset: index + query.length - 1,
        ));

        startIndex = index + 1;
      }
    }

    // Apply highlights
    _applyHighlights();

    // Select first match if any
    if (_matches.isNotEmpty) {
      _currentMatchIndex = 0;
      _updateActiveHighlight();
    }

    notifyListeners();
  }

  /// Move to the next search match
  void nextMatch() {
    if (_matches.isEmpty) return;

    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    _updateActiveHighlight();
    notifyListeners();
  }

  /// Move to the previous search match
  void previousMatch() {
    if (_matches.isEmpty) return;

    _currentMatchIndex = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    _updateActiveHighlight();
    notifyListeners();
  }

  /// Clear the search
  void clear() {
    _searchQuery = '';
    _matches.clear();
    _currentMatchIndex = -1;
    _clearHighlights();
    notifyListeners();
  }

  /// Apply highlight attributions to all matches
  void _applyHighlights() {
    _clearHighlights();

    for (final match in _matches) {
      final node = document.getNodeById(match.nodeId);
      if (node is! TextNode) continue;

      node.text.addAttribution(
        searchHighlightAttribution,
        SpanRange(match.startOffset, match.endOffset),
      );
    }
  }

  /// Update the active highlight (different color for current match)
  void _updateActiveHighlight() {
    // Remove all active highlights first
    for (final match in _matches) {
      final node = document.getNodeById(match.nodeId);
      if (node is! TextNode) continue;

      node.text.removeAttribution(
        activeSearchHighlightAttribution,
        SpanRange(match.startOffset, match.endOffset),
      );
    }

    // Add active highlight to current match
    if (currentMatch != null) {
      final node = document.getNodeById(currentMatch!.nodeId);
      if (node is TextNode) {
        node.text.addAttribution(
          activeSearchHighlightAttribution,
          SpanRange(currentMatch!.startOffset, currentMatch!.endOffset),
        );
      }
    }
  }

  /// Remove all search highlight attributions
  void _clearHighlights() {
    for (final node in document) {
      if (node is! TextNode) continue;

      final text = node.text;
      final textLength = text.length;

      if (textLength == 0) continue;

      // Remove all search highlights
      text.removeAttribution(
        searchHighlightAttribution,
        SpanRange(0, textLength - 1),
      );
      text.removeAttribution(
        activeSearchHighlightAttribution,
        SpanRange(0, textLength - 1),
      );
    }
  }

  @override
  void dispose() {
    _clearHighlights();
    super.dispose();
  }
}

/// Represents a single search match in the document
class SearchMatch {
  SearchMatch({
    required this.nodeId,
    required this.startOffset,
    required this.endOffset,
  });

  final String nodeId;
  final int startOffset;
  final int endOffset;

  @override
  String toString() => 'SearchMatch(nodeId: $nodeId, range: $startOffset-$endOffset)';
}
