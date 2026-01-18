import 'package:super_editor/super_editor.dart';

/// A callout block that can contain text and has a type (info, warning, error, etc.)
class CalloutNode extends BlockNode {
  const CalloutNode({
    required super.id,
    required this.calloutType,
    required this.text,
  });

  final String calloutType;
  final AttributedText text;

  @override
  BlockNode copyWith({
    String? id,
    String? calloutType,
    AttributedText? text,
  }) {
    return CalloutNode(
      id: id ?? this.id,
      calloutType: calloutType ?? this.calloutType,
      text: text ?? this.text,
    );
  }

  @override
  bool get hasContent => text.isNotEmpty;

  @override
  TextNodePosition get beginningPosition => const TextNodePosition(offset: 0);

  @override
  TextNodePosition get endPosition => TextNodePosition(offset: text.length);

  @override
  String get textContent => text.toPlainText();

  @override
  bool get isSelectable => true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalloutNode &&
        other.id == id &&
        other.calloutType == calloutType &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(id, calloutType, text);
}

/// Attribution for callout blocks
class CalloutAttribution extends Attribution {
  const CalloutAttribution(this.calloutType);

  final String calloutType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalloutAttribution && other.calloutType == calloutType;
  }

  @override
  int get hashCode => calloutType.hashCode;

  @override
  String toString() => 'CalloutAttribution($calloutType)';
}

/// Predefined callout types
const infoCalloutAttribution = CalloutAttribution('info');
const warningCalloutAttribution = CalloutAttribution('warning');
const errorCalloutAttribution = CalloutAttribution('error');
const successCalloutAttribution = CalloutAttribution('success');