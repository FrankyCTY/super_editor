import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/content/callout.dart';

/// A [BlockDeltaFormat] that parses callout blocks from Quill Delta format.
class CalloutDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _callout = "callout";

  const CalloutDeltaFormat() : super(_callout);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    if (value is! String) {
      return null;
    }

    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final selectedNodeId = composer.selection!.extent.nodeId;
    final selectedNode = document.getNodeById(selectedNodeId);

    // Get the text content from the current paragraph
    String textContent = "";
    if (selectedNode is ParagraphNode) {
      textContent = selectedNode.text.toPlainText();
    }

    // Create a new callout node
    final calloutNodeId = Editor.createNodeId();
    final calloutNode = CalloutNode(
      id: calloutNodeId,
      calloutType: value,
      text: AttributedText(textContent),
    );

    return [
      // Replace the current paragraph with the callout node
      ReplaceNodeRequest(
        existingNodeId: selectedNodeId,
        newNode: calloutNode,
      ),
      // Insert an empty paragraph after the callout
      InsertNodeAfterNodeRequest(
        existingNodeId: calloutNodeId,
        newNode: ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(""),
        ),
      ),
      // Move selection to the new paragraph
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: calloutNodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.contentChange,
      ),
    ];
  }
}

/// A [BlockDeltaFormat] that handles callout embeds (when callout is inserted as an embed)
class CalloutEmbedBlockDeltaFormat extends StandardEmbedBlockDeltaFormat {
  const CalloutEmbedBlockDeltaFormat();

  @override
  DocumentNode? createNodeForEmbed(Operation operation, String nodeId) {
    final data = operation.data;
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final calloutType = data['callout'];
    if (calloutType is! String) {
      return null;
    }

    final text = data['text'] as String? ?? "";

    return CalloutNode(
      id: nodeId,
      calloutType: calloutType,
      text: AttributedText(text),
    );
  }
}

/// A [BlockDeltaFormat] that filters out any operation that doesn't have
/// an attribute with the given [name].
abstract class FilterByNameBlockDeltaFormat implements BlockDeltaFormat {
  const FilterByNameBlockDeltaFormat(this.name);

  final String name;

  @override
  List<EditRequest>? applyTo(Operation operation, Editor editor) {
    if (!operation.hasAttribute(name)) {
      return null;
    }

    return doApplyFormat(editor, operation.attributes![name]);
  }

  List<EditRequest>? doApplyFormat(Editor editor, Object value);
}

/// A base class for block-level embed formats that follow a standard pattern.
abstract class StandardEmbedBlockDeltaFormat implements BlockDeltaFormat {
  const StandardEmbedBlockDeltaFormat();

  @override
  List<EditRequest>? applyTo(Operation operation, Editor editor) {
    // Check if the selected node is an empty text node. If it is, we want to replace it
    // with the media that we're inserting.
    final document = editor.context.find<MutableDocument>(Editor.documentKey);
    final selectedNodeId = editor.context.composer.selection!.extent.nodeId;
    final selectedNode = document.getNodeById(selectedNodeId);
    final shouldReplaceSelectedNode = selectedNode is TextNode && selectedNode.text.isEmpty;

    final newNodeId = Editor.createNodeId();
    final newNode = createNodeForEmbed(operation, newNodeId);
    if (newNode == null) {
      return null;
    }

    final newParagraphId = Editor.createNodeId();
    return [
      shouldReplaceSelectedNode
          ? ReplaceNodeRequest(
              existingNodeId: selectedNodeId,
              newNode: newNode,
            )
          : InsertNodeAfterNodeRequest(
              existingNodeId: editor.context.composer.selection!.extent.nodeId,
              newNode: newNode,
            ),
      // Always insert an empty paragraph after the embed block so that the user
      // is able to enter text below it.
      InsertNodeAfterNodeRequest(
        existingNodeId: newNodeId,
        newNode: ParagraphNode(
          id: newParagraphId,
          text: AttributedText(""),
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newParagraphId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.insertContent,
        SelectionReason.contentChange,
      ),
    ];
  }

  /// Attempts to parse the given [operation] as a desired block-level embed,
  /// returning a [DocumentNode] that represents the embed, or `null` if this
  /// format doesn't apply to the given block-level embed.
  ///
  /// The returned [DocumentNode] should use the given [nodeId] as its ID.
  DocumentNode? createNodeForEmbed(Operation operation, String nodeId);
}