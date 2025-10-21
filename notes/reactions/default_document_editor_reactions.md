Below is a “guided tour” of four representative reactions that are already in the file.  
For each one I show:

1. What the user **does**  
2. What the reaction **listens for**  
3. What the reaction **does back to the document**  
4. The smallest possible **custom reaction** you could write by copy-pasting the same skeleton.

Once you see the pattern you can mix-and-match: listen to any `EditEvent` stream, run any logic you want, and fire any `EditRequest` (or even your own custom requests) through the `requestDispatcher`.

--------------------------------------------------------
1. HeaderConversionReaction  (extends ParagraphPrefixConversionReaction)
--------------------------------------------------------
1. User types  
   `# `  or  `## `  … up to six hashes and a space at the very start of a paragraph.

2. The base class `ParagraphPrefixConversionReaction.react()` already did the plumbing:
   - it found the last text insertion that ended with a space  
   - checked that the insertion happened in a `ParagraphNode`  
   - ran the regexp `^#{1,6}\s+$` against the node text  
   - if it matched, called `onPrefixMatched`.

3. `onPrefixMatched` simply:
   - picks the right `header1Attribution…header6Attribution`  
   - sends a batch of requests:
     ```dart
     ChangeParagraphBlockTypeRequest  // turn the paragraph into a header
     DeleteContentRequest             // remove the “# ” characters
     ChangeSelectionRequest           // leave caret at start of line
     ```

4. Skeleton for your own “prefix” reaction
   ```dart
   class MyCustomPrefixReaction extends ParagraphPrefixConversionReaction {
     static final _pattern = RegExp(r'^@@@\s+$');

     const MyCustomPrefixReaction() : super(requireSpaceInsertion: true);

     @override
     RegExp get pattern => _pattern;

     @override
     void onPrefixMatched(editCtx, dispatcher, changes, paragraph, match) {
       dispatcher.execute([
         // whatever you need
         ReplaceNodeRequest(
           existingNodeId: paragraph.id,
           newNode: MyCustomNode(id: paragraph.id, text: AttributedText()),
         ),
         ChangeSelectionRequest(
           DocumentSelection.collapsed(
             position: DocumentPosition(
               nodeId: paragraph.id,
               nodePosition: const TextNodePosition(offset: 0),
             ),
           ),
           SelectionChangeType.placeCaret,
           SelectionReason.contentChange,
         ),
       ]);
     }
   }
   ```
   Drop the class into your `Editor` constructor’s `reactions:` list and you are done.

--------------------------------------------------------
2. HorizontalRuleConversionReaction  (plain EditReaction)
--------------------------------------------------------
1. User types  
   `--- `  (three dashes and a space) at the start of any text node.

2. The reaction itself listens to the raw `List<EditEvent>`:
   - needs at least two events (insertion + selection change)  
   - checks that the last *document edit* is a `TextInsertionEvent` with a space  
   - looks at the node text and runs `_hrPattern.firstMatch`.

3. When it matches it:
   - deletes the “--- ” characters  
   - inserts a brand-new `HorizontalRuleNode` **before** the current node  
   - puts the caret at the start of the remaining text.

4. Skeleton for an “insert something in the middle” reaction
   ```dart
   class MagicSymbolReaction extends EditReaction {
     static final _magic = RegExp(r'^>>>\s');

     const MagicSymbolReaction();

     @override
     void react(EditContext ctx, RequestDispatcher d, List<EditEvent> edits) {
       if (edits.length < 2) return;
       final doc = ctx.document;

       final edit = edits.reversed.firstWhere((e) => e is DocumentEdit, orElse: () => null) as DocumentEdit?;
       if (edit?.change is! TextInsertionEvent) return;
       final insert = edit!.change as TextInsertionEvent;
       if (insert.text.toPlainText() != ' ') return;

       final node = doc.getNodeById(insert.nodeId) as TextNode;
       final match = _magic.firstMatch(node.text.toPlainText())?.group(0);
       if (match == null) return;

       d.execute([
         DeleteContentRequest(/* delete the >>> and space */),
         InsertNodeAtIndexRequest(
           nodeIndex: doc.getNodeIndexById(node.id),
           newNode: MyCustomInlineWidgetNode(id: Editor.createNodeId()),
         ),
         ChangeSelectionRequest(/* caret at start of remaining text */),
       ]);
     }
   }
   ```

--------------------------------------------------------
3. LinkifyReaction  (text-level attribution reaction)
--------------------------------------------------------
1. User types any word that looks like a URL **followed by a space**.

2. The reaction scans the whole `EditEvent` list for:
   - a `TextInsertionEvent` whose text is `" "`  
   - a collapsed selection sitting right after that space  
   - the word just before the space does not already contain a `LinkAttribution`.

3. It uses the `linkify` package to extract the URL, creates a `LinkAttribution`, and applies it with:
   ```dart
   text.addAttribution(LinkAttribution.fromUri(uri), SpanRange(start, end));
   ```

4. Skeleton for “style the word the user just typed”
   ```dart
   class HashTagReaction extends EditReaction {
     static final _hashTag = RegExp(r'#\w+$');

     const HashTagReaction();

     @override
     void react(EditContext ctx, RequestDispatcher d, List<EditEvent> edits) {
       final spaceEdit = edits.whereType<DocumentEdit>()
           .lastWhereOrNull((e) => e.change is TextInsertionEvent && (e.change as TextInsertionEvent).text.text == ' ');
       if (spaceEdit == null) return;

       final insert = spaceEdit.change as TextInsertionEvent;
       final node = ctx.document.getNodeById(insert.nodeId) as TextNode;
       final wordStart = _startOfWord(node.text.text, insert.offset);
       final word = node.text.text.substring(wordStart, insert.offset);

       final match = _hashTag.firstMatch(word);
       if (match == null) return;

       node.text.addAttribution(
         const HashTagAttribution(),
         SpanRange(wordStart + match.start, wordStart + match.end - 1),
       );
     }

     int _startOfWord(String text, int offset) { /* trivial helper */ }
   }

   class HashTagAttribution extends Attribution {
     const HashTagAttribution() : super('hashTag');
   }
   ```

--------------------------------------------------------
4. DashConversionReaction  (two-character auto-replace)
--------------------------------------------------------
1. User types a second dash directly after a first dash:  `--`

2. Reaction looks for:
   - a `TextInsertionEvent` with text `"-"`  
   - the character immediately before the insertion offset is also `"-"`.

3. It deletes the two dashes and inserts an em-dash character in one atomic request list.

4. Skeleton for “replace last two characters”
   ```dart
   class ArrowReaction extends EditReaction {
     const ArrowReaction();

     @override
     void react(EditContext ctx, RequestDispatcher d, List<EditEvent> edits) {
       final insert = edits.whereType<DocumentEdit>()
           .map((e) => e.change)
           .whereType<TextInsertionEvent>()
           .lastWhereOrNull((e) => e.text.text == '>');
       if (insert == null) return;

       final node = ctx.document.getNodeById(insert.nodeId) as TextNode;
       if (insert.offset == 0) return;
       if (node.text.text[insert.offset - 1] != '-') return;

       d.execute([
         DeleteContentRequest(
           documentRange: DocumentRange(
             start: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: insert.offset - 1)),
             end:   DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: insert.offset + 1)),
           ),
         ),
         InsertTextRequest(
           documentPosition: DocumentPosition(
             nodeId: node.id,
             nodePosition: TextNodePosition(offset: insert.offset - 1),
           ),
           textToInsert: '→',
         ),
         ChangeSelectionRequest(
           DocumentSelection.collapsed(
             position: DocumentPosition(
               nodeId: node.id,
               nodePosition: TextNodePosition(offset: insert.offset),
             ),
           ),
           SelectionChangeType.placeCaret,
           SelectionReason.contentChange,
         ),
       ]);
     }
   }
   ```

--------------------------------------------------------
Cheatsheet for building your own
--------------------------------------------------------
1. Pick the **granularity**  
   - Whole-node replacement ➜ subclass `ParagraphPrefixConversionReaction`  
   - Character-level or inline-widget ➜ implement `EditReaction` directly.

2. Implement **one** method:
   - `onPrefixMatched` (for prefix reactions)  
   - `react(EditContext, RequestDispatcher, List<EditEvent>)` (for plain reactions).

3. Do your logic, then **fire requests** through `requestDispatcher.execute([...])`.  
   Common requests:  
   `InsertTextRequest`, `DeleteContentRequest`, `ReplaceNodeRequest`, `ChangeParagraphBlockTypeRequest`, `AddTextAttributionsRequest`, plus selection requests.

4. Register it:
   ```dart
   Editor(
     editContext: editContext,
     requestDispatcher: dispatcher,
     reactions: [
       const HeaderConversionReaction(),
       const MyCustomPrefixReaction(),
       const ArrowReaction(),
     ],
   )
   ```
