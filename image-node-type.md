# Image Node Implementation Guide

This document provides a comprehensive overview of how the `ImageNode` is implemented in the Super Editor package, serving as a reference for creating custom block-level node types, particularly those that display images or similar media content.

## Overview

The `ImageNode` is a **block-level node** that represents an image in the document. It supports:
- Remote images via URL (network images)
- Image sizing with placeholder dimensions during loading
- Selection with upstream/downstream positioning
- Copy/paste operations
- Markdown and HTML serialization
- Automatic URL-to-image conversion

## Node Type Definition

### Location
`super_editor/lib/src/default_editor/image.dart`

### Class Structure

```dart
class ImageNode extends BlockNode {
  ImageNode({
    required this.id,
    required this.imageUrl,
    this.expectedBitmapSize,
    this.altText = '',
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution("image")});
  }

  @override
  final String id;

  final String imageUrl;
  final ExpectedSize? expectedBitmapSize;
  final String altText;
  
  // ... methods below
}
```

## Key Features & Fields

### 1. **Node Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` | Yes | Unique identifier for the node |
| `imageUrl` | `String` | Yes | URL of the image (network URL) |
| `expectedBitmapSize` | `ExpectedSize?` | No | Expected dimensions to prevent layout shift during loading |
| `altText` | `String` | No | Alternative text for accessibility (default: empty) |
| `metadata` | `Map<String, dynamic>?` | No | Additional metadata for styling/configuration |

### 2. **Expected Size**

The `ExpectedSize` class helps prevent content shift while images load:

```dart
class ExpectedSize {
  const ExpectedSize(this.width, this.height);

  final int? width;
  final int? height;

  double get aspectRatio => height != null 
      ? (width ?? 0) / height!
      : throw UnsupportedError("Can't compute the aspect ratio with a null height");
}
```

**Purpose**: When both width and height are provided, the component reserves space using `AspectRatio` widget during image loading, preventing jarring layout changes.

### 3. **Selection Model**

ImageNode uses **UpstreamDownstreamNodeSelection**:
- **Upstream**: Caret positioned before/at the start of the image
- **Downstream**: Caret positioned after/at the end of the image
- **Expanded**: Both upstream and downstream selected = entire image selected

```dart
@override
String? copyContent(dynamic selection) {
  if (selection is! UpstreamDownstreamNodeSelection) {
    throw Exception('ImageNode can only copy content from a UpstreamDownstreamNodeSelection.');
  }

  return !selection.isCollapsed ? imageUrl : null;
}
```

### 4. **Required Methods**

```dart
// Content equality check
@override
bool hasEquivalentContent(DocumentNode other) {
  return other is ImageNode && imageUrl == other.imageUrl && altText == other.altText;
}

// Metadata manipulation
@override
DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) { /* ... */ }

@override
DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) { /* ... */ }

// Deep copy
@override
ImageNode copy() { /* ... */ }
```

## Component & Builder

### ImageComponentBuilder

Implements `ComponentBuilder` interface to create view models and visual components:

```dart
class ImageComponentBuilder implements ComponentBuilder {
  const ImageComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ImageNode) {
      return null;
    }

    return ImageComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      imageUrl: node.imageUrl,
      expectedSize: node.expectedBitmapSize,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, 
      SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ImageComponentViewModel) {
      return null;
    }

    return ImageComponent(
      componentKey: componentContext.componentKey,
      imageUrl: componentViewModel.imageUrl,
      expectedSize: componentViewModel.expectedSize,
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      opacity: componentViewModel.opacity,
    );
  }
}
```

### ImageComponentViewModel

Extends `SingleColumnLayoutComponentViewModel` and mixes in `SelectionAwareViewModelMixin`:

```dart
class ImageComponentViewModel extends SingleColumnLayoutComponentViewModel 
    with SelectionAwareViewModelMixin {
  ImageComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.imageUrl,
    this.expectedSize,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
  }) {
    this.selection = selection;
    this.selectionColor = selectionColor;
  }

  String imageUrl;
  ExpectedSize? expectedSize;
  
  // Must implement copy() for immutability
  @override
  ImageComponentViewModel copy() { /* ... */ }
}
```

### ImageComponent Widget

The actual Flutter widget that renders the image:

```dart
class ImageComponent extends StatelessWidget {
  const ImageComponent({
    Key? key,
    required this.componentKey,
    required this.imageUrl,
    this.expectedSize,
    this.selectionColor = Colors.blue,
    this.selection,
    this.opacity = 1.0,
    this.imageBuilder,
  }) : super(key: key);

  final GlobalKey componentKey;
  final String imageUrl;
  final ExpectedSize? expectedSize;
  final Color selectionColor;
  final UpstreamDownstreamNodeSelection? selection;
  final double opacity;
  final Widget Function(BuildContext context, String imageUrl)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      hitTestBehavior: HitTestBehavior.translucent,
      child: IgnorePointer(
        child: Center(
          child: SelectableBox(
            selection: selection,
            selectionColor: selectionColor,
            child: BoxComponent(
              key: componentKey,
              opacity: opacity,
              child: imageBuilder != null
                  ? imageBuilder!(context, imageUrl)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame != null) {
                          // The image is already loaded. Use the image as is.
                          return child;
                        }

                        if (expectedSize != null && 
                            expectedSize!.width != null && 
                            expectedSize!.height != null) {
                          // Both width and height were provided.
                          // Preserve the aspect ratio of the original image.
                          return AspectRatio(
                            aspectRatio: expectedSize!.aspectRatio,
                            child: SizedBox(
                              width: expectedSize!.width!.toDouble(),
                              height: expectedSize!.height!.toDouble(),
                            ),
                          );
                        }

                        // The image is still loading and only one dimension was provided.
                        // Use the given dimension.
                        return SizedBox(
                          width: expectedSize?.width?.toDouble(),
                          height: expectedSize?.height?.toDouble(),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
```

## Image Loading Behavior

### Current Implementation: Remote Images Only

**Supported**: `Image.network()` - remote images via URL

**Not Supported Out-of-Box**:
- Local file images (`Image.file()`)
- Asset images (`Image.asset()`)
- Memory images (`Image.memory()`)

### Loading States

The `frameBuilder` in `Image.network()` handles loading states:

1. **Loading State**: When `frame == null`
   - If `expectedSize` has both width and height: Shows `AspectRatio` + `SizedBox` placeholder
   - If only partial size provided: Shows `SizedBox` with available dimension
   - If no size provided: Shows nothing (may cause layout shift)

2. **Loaded State**: When `frame != null`
   - Displays the actual image child

**Important**: There's **NO circular progress indicator** or visual loader in the default implementation. The loading state is handled purely by reserving space.

### Custom Image Builder

For testing or custom loading behavior, use the `imageBuilder` parameter:

```dart
ImageComponent(
  imageUrl: 'https://example.com/image.png',
  imageBuilder: (context, imageUrl) {
    // Custom implementation - useful for testing or custom loading UI
    return YourCustomImageWidget(url: imageUrl);
  },
)
```

## Related Requests, Commands & Reactions

### 1. Insertion

**Method**: `CommonEditorOperations.insertImage(String url)`

Location: `super_editor/lib/src/default_editor/common_editor_operations.dart`

```dart
bool insertImage(String url) {
  if (composer.selection == null) {
    return false;
  }
  if (composer.selection!.base.nodeId != composer.selection!.extent.nodeId) {
    return false;
  }

  final node = document.getNodeById(composer.selection!.base.nodeId);
  if (node is! ParagraphNode) {
    return false;
  }

  return _insertBlockLevelContent(
    ImageNode(id: Editor.createNodeId(), imageUrl: url),
  );
}
```

**Behavior**:
- Can only be inserted from a ParagraphNode
- If paragraph is empty: Replaces paragraph with image, adds new paragraph after
- If at end of paragraph: Inserts image after, adds new paragraph after image
- If in middle of paragraph: Splits paragraph, inserts image between the two parts

**Request Used**: `InsertNodeAtCaretRequest`

### 2. URL Auto-Conversion Reaction

**Class**: `ImageUrlConversionReaction`

Location: `super_editor/lib/src/default_editor/default_document_editor_reactions.dart`

**How it works**:
1. User types a URL in a paragraph
2. User presses Enter
3. System checks if paragraph contains only a single URL
4. Makes HTTP request to check if URL is an image (checks `Content-Type: image/*`)
5. If yes: Replaces paragraph node with ImageNode

```dart
class ImageUrlConversionReaction extends EditReaction {
  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    // Checks for SubmitParagraphIntention
    // Verifies paragraph contains single URL
    // Async checks if URL is image
    // Converts ParagraphNode to ImageNode if true
  }
}
```

**Async Behavior**: Uses `_isImageUrl()` to make HTTP HEAD/GET request and check Content-Type header.

### 3. Deletion

ImageNode can be deleted like other block nodes:

- **Backspace at upstream edge**: Deletes the image, replaces with empty paragraph
- **Delete at downstream edge**: Moves selection to next node or deletes if appropriate
- **Select entire node + delete**: Removes the image

**Command**: `ReplaceNodeWithEmptyParagraphWithCaretRequest`

### 4. Copy/Paste

**Copy**: Returns the `imageUrl` when the selection is expanded (entire image selected)

**Paste**: Not specifically handled - pasted text can trigger URL conversion if it's an image URL

## Keyboard Handlers

### Standard Block-Level Keyboard Behavior

ImageNode doesn't have special keyboard handlers. It uses the **standard block-level node keyboard handling**:

1. **Arrow Keys**: Move selection to upstream/downstream position or to adjacent nodes
2. **Backspace**: 
   - At upstream edge with downstream affinity: Replaces image with empty paragraph
   - At upstream edge with upstream affinity: Moves to previous node or deletes upstream non-selectable nodes
3. **Delete**:
   - At downstream edge with upstream affinity: Replaces image with empty paragraph  
   - At downstream edge with downstream affinity: Moves to next node
4. **Enter**: Inserts new paragraph before or after the image depending on affinity
5. **Typing**: Inserts new paragraph and starts typing

### Implementation

From `box_component.dart`:

```dart
abstract class BlockNode extends DocumentNode {
  @override
  UpstreamDownstreamNodePosition get beginningPosition => 
      const UpstreamDownstreamNodePosition.upstream();

  @override
  UpstreamDownstreamNodePosition get endPosition => 
      const UpstreamDownstreamNodePosition.downstream();

  @override
  bool containsPosition(Object position) => position is UpstreamDownstreamNodePosition;
}
```

## Serialization Support

### 1. Markdown Serialization

Location: `super_editor_markdown/lib/src/document_to_markdown_serializer.dart`

```dart
class ImageNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ImageNode> {
  const ImageNodeSerializer({
    this.useSizeNotation = false,
  });

  @override
  String doSerialization(Document document, ImageNode node, {NodeSelection? selection}) {
    if (!useSizeNotation || (node.expectedBitmapSize?.width == null && 
                             node.expectedBitmapSize?.height == null)) {
      return '![${node.altText}](${node.imageUrl})';
    }

    // With size notation: ![alt](url =widthxheight)
    return '![${node.altText}](${node.imageUrl} =${width}x${height})';
  }
}
```

**Output Format**:
- Standard: `![alt text](https://example.com/image.png)`
- With size: `![alt text](https://example.com/image.png =1920x1080)`

### 2. HTML Serialization

Location: `super_editor/lib/src/infrastructure/serialization/html/html_images.dart`

```dart
String? defaultImageToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! ImageNode) {
    return null;
  }
  if (selection != null) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      return null;
    }
    if (selection.isCollapsed) {
      return null;
    }
  }

  return '<img src="${node.imageUrl}">';
}
```

## Creating a Custom Multi-Image Block Node

Based on the ImageNode implementation, here's how to create a custom node type that displays multiple images horizontally with click callbacks:

### 1. Define the Node

```dart
class MultiImageNode extends BlockNode {
  MultiImageNode({
    required this.id,
    required this.imageUrls,
    this.expectedSizes,
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution("multi-image")});
  }

  @override
  final String id;

  final List<String> imageUrls;
  final List<ExpectedSize>? expectedSizes;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception('MultiImageNode can only copy content from UpstreamDownstreamNodeSelection.');
    }
    return !selection.isCollapsed ? imageUrls.join('\n') : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is MultiImageNode && 
           const ListEquality().equals(imageUrls, other.imageUrls);
  }

  @override
  MultiImageNode copy() {
    return MultiImageNode(
      id: id,
      imageUrls: List.from(imageUrls),
      expectedSizes: expectedSizes != null ? List.from(expectedSizes!) : null,
      metadata: Map.from(metadata),
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return MultiImageNode(
      id: id,
      imageUrls: imageUrls,
      expectedSizes: expectedSizes,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return MultiImageNode(
      id: id,
      imageUrls: imageUrls,
      expectedSizes: expectedSizes,
      metadata: newMetadata,
    );
  }
}
```

### 2. Create the Component Builder

```dart
class MultiImageComponentBuilder implements ComponentBuilder {
  const MultiImageComponentBuilder({
    this.onImageTap,
  });

  final void Function(String nodeId, int imageIndex, String imageUrl)? onImageTap;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document, 
    DocumentNode node
  ) {
    if (node is! MultiImageNode) {
      return null;
    }

    return MultiImageComponentViewModel(
      nodeId: node.id,
      imageUrls: node.imageUrls,
      expectedSizes: node.expectedSizes,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! MultiImageComponentViewModel) {
      return null;
    }

    return MultiImageComponent(
      componentKey: componentContext.componentKey,
      imageUrls: componentViewModel.imageUrls,
      expectedSizes: componentViewModel.expectedSizes,
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      onImageTap: (index) => onImageTap?.call(
        componentViewModel.nodeId,
        index,
        componentViewModel.imageUrls[index],
      ),
    );
  }
}
```

### 3. Create the ViewModel

```dart
class MultiImageComponentViewModel extends SingleColumnLayoutComponentViewModel
    with SelectionAwareViewModelMixin {
  MultiImageComponentViewModel({
    required super.nodeId,
    super.createdAt,
    required this.imageUrls,
    this.expectedSizes,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
  }) {
    this.selection = selection;
    this.selectionColor = selectionColor;
  }

  List<String> imageUrls;
  List<ExpectedSize>? expectedSizes;

  @override
  MultiImageComponentViewModel copy() {
    return MultiImageComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      imageUrls: imageUrls,
      expectedSizes: expectedSizes,
      selection: selection,
      selectionColor: selectionColor,
    );
  }
}
```

### 4. Create the Widget Component

```dart
class MultiImageComponent extends StatelessWidget {
  const MultiImageComponent({
    Key? key,
    required this.componentKey,
    required this.imageUrls,
    this.expectedSizes,
    this.selection,
    this.selectionColor = Colors.blue,
    this.onImageTap,
  }) : super(key: key);

  final GlobalKey componentKey;
  final List<String> imageUrls;
  final List<ExpectedSize>? expectedSizes;
  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final void Function(int imageIndex)? onImageTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: SelectableBox(
        selection: selection,
        selectionColor: selectionColor,
        child: BoxComponent(
          key: componentKey,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < imageUrls.length; i++)
                  GestureDetector(
                    onTap: () => onImageTap?.call(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _buildImage(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(int index) {
    final imageUrl = imageUrls[index];
    final expectedSize = expectedSizes != null && index < expectedSizes!.length
        ? expectedSizes![index]
        : null;

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          return child;
        }

        if (expectedSize != null &&
            expectedSize.width != null &&
            expectedSize.height != null) {
          return AspectRatio(
            aspectRatio: expectedSize.aspectRatio,
            child: SizedBox(
              width: expectedSize.width!.toDouble(),
              height: expectedSize.height!.toDouble(),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return SizedBox(
          width: expectedSize?.width?.toDouble() ?? 200,
          height: expectedSize?.height?.toDouble() ?? 200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
```

### 5. Register the Builder

```dart
SuperEditor(
  editor: editor,
  document: document,
  composer: composer,
  componentBuilders: [
    MultiImageComponentBuilder(
      onImageTap: (nodeId, imageIndex, imageUrl) {
        print('Tapped image $imageIndex in node $nodeId: $imageUrl');
        // Handle your callback here - open full screen, etc.
      },
    ),
    // ... other builders
    ...defaultComponentBuilders,
  ],
);
```

## Summary

### Key Takeaways

1. **ImageNode extends BlockNode** - Uses upstream/downstream selection model
2. **Remote images only** - Uses `Image.network()` 
3. **No visible loader** - Loading handled by space reservation, not progress indicators
4. **ExpectedSize prevents layout shift** - Provide dimensions for better UX
5. **Auto-conversion from URLs** - `ImageUrlConversionReaction` converts URL paragraphs to images
6. **Standard block keyboard handling** - No special keyboard shortcuts
7. **Serialization support** - Both Markdown and HTML output available
8. **Component architecture** - Requires Node, Builder, ViewModel, and Widget components

### To Support Local Images

You would need to:
1. Add a `localPath` field to ImageNode
2. Create a custom `imageBuilder` that checks if URL is local vs remote
3. Use `Image.file(File(localPath))` for local images
4. Handle platform-specific file access permissions

This guide should provide everything needed to understand and extend the image node implementation!
