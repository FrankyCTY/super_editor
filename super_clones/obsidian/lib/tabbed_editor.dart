import 'package:flutter/material.dart';
import 'package:super_editor_obsidian/window.dart';
import 'package:tab_kit/tab_kit.dart';

class TabbedEditor extends StatefulWidget {
  const TabbedEditor({
    super.key,
    required this.tabController,
  });

  final NotebookTabController tabController;

  @override
  State<TabbedEditor> createState() => _TabbedEditorState();
}

class _TabbedEditorState extends State<TabbedEditor> {
  @override
  Widget build(BuildContext context) {
    return ScreenPartial(
      partialAppBar: NotebookTabBar(
        controller: widget.tabController,
        paddingStart: 12,
        style: NotebookTabBarStyle(
          barBackground: Colors.transparent,
          tabBackground: const Color(0xFF222222),
          tabWidth: 200,
          dividerColor: Colors.white.withOpacity(0.1),
        ),
        onAddTabPressed: () {},
      ),
      content: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document: Tab Editor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This is where the document content would be displayed.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can add your Super Editor widget here to display the actual document content.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
