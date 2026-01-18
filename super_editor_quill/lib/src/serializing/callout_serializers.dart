import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/content/callout.dart';
import 'package:super_editor_quill/src/serializing/serializers.dart';

/// A [DeltaSerializer] that serializes [CalloutNode]s into deltas.
const calloutDeltaSerializer = FunctionalDeltaSerializer(_serializeCallout);

bool _serializeCallout(DocumentNode node, Delta deltas) {
  if (node is! CalloutNode) {
    return false;
  }

  // Serialize the callout as an embed with both the callout type and text
  deltas.operations.add(
    Operation.insert({
      "callout": node.calloutType,
      "text": node.text.toPlainText(),
    }),
  );

  return true;
}

/// A [DeltaSerializer] that serializes [CalloutNode]s as block-level callouts.
class CalloutBlockDeltaSerializer implements DeltaSerializer {
  const CalloutBlockDeltaSerializer();

  @override
  bool serialize(DocumentNode node, Delta deltas) {
    if (node is! CalloutNode) {
      return false;
    }

    // Serialize the callout text with block-level callout attribute
    final text = node.text.toPlainText();
    if (text.isNotEmpty) {
      deltas.operations.add(
        Operation.insert(
          text,
          {"callout": node.calloutType},
        ),
      );
    } else {
      // Empty callout - just insert the block format
      deltas.operations.add(
        Operation.insert(
          "",
          {"callout": node.calloutType},
        ),
      );
    }

    // Add newline to end the block
    deltas.operations.add(
      Operation.insert("\n"),
    );

    return true;
  }
}