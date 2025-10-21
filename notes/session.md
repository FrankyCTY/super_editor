I'm going to try to understand the name "super" within this "super" editor package. So looking at this, right, looking at... I'm quite new to that code, but I think I could be better. So can you capture what's set and try to correct me if I'm wrong? [typing] So from this code, the first thing is that we have a main function, and we have initialized some logger stuff in here. I don't care about those, let's look into this. I want to dive into how the "super" editor actually... the architecture and how I can understand the code base, because I'm going to implement a lot of stuff on top of it. Okay. So I would dive directly into the demo stateful widget, that means that we have state, and the state is the demo state. And they have a mutable document, it's interesting because it's referencing some part of the core code from the package itself, it's called "mutable document", and it's a mutable thing. So I guess it will be a weird, only kind of... far end of this. And it implements document and editable, which I haven't looked into, but let's look at our size first, how do we use it. So we have used late key so that we expect that it will be initialized in the initial state. Perfect. And we create initial document, and I can see that, interestingly, we have done a lot of things like... This example document is trying to build a tree, I would say, or like the document notes, right? Not necessarily a tree, but at least a node. That actually initialized all the notes for this document. So if I look into mutable document like the constructor, essentially I set a list of document notes. So I can already, in my manual model, I really like that. So we'd only, or potentially... a mutable version of document. So I can just... I would usually just try and think about these. And later on, let's have some notes for this, and refresh node ID caches. So we will have caches as well. All the maps to use the ID as key. So what is node ID caches, I guess, is like a map that we don't need to loop through the array again and again, but we can just build the... by the... I see. Two things that we are getting, right? One is to get... One is to make... So these are two data structures that make it like getting the node fast, and the other one is getting the node in that fast. Okay, cool. So we have the node caches, and I can see that it's part of the editor itself. So the editor itself actually will have some cache. Let me mark it down. Usually, we'll do it like this, where we put our interesting thing here. And I just Exceled it off for this to help me to understand what's going on. Okay, so we have two maps and continue counting. Maybe to finish this workflow of how, like, a user type will happen. So I will continue. 
*From Cursor:*
```
class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
```


*From Cursor:*
```
class MutableDocument with Iterable<DocumentNode> implements Document, Editable {
```


*From Cursor:*
```
 Document, Editable {
```


*From Cursor:*
```
  @override
  void initState() {
    super.initState();
    _document = createInitialDocument();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _document, composer: _composer, isHistoryEnabled: true);
  }
```


*From Cursor:*
```
  MutableDocument({
    List<DocumentNode>? nodes,
  }) : _nodes = nodes ?? [] {
    _refreshNodeIdCaches();

    _latestNodesSnapshot = List.from(_nodes);
  }
```


*From Cursor:*
```
  /// Updates all the maps which use the node id as the key.
  ///
  /// All the maps are cleared and re-populated.
  void _refreshNodeIdCaches() {
    _nodeIndicesById.clear();
    _nodesById.clear();
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      _nodeIndicesById[node.id] = i;
      _nodesById[node.id] = node;
    }
  }
```


*From Cursor:*
```
  /// Updates all the maps which use the node id as the key.
  ///
  /// All the maps are cleared and re-populated.
  void _refreshNodeIdCaches() {
    _nodeIndicesById.clear();
    _nodesById.clear();
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      _nodeIndicesById[node.id] = i;
      _nodesById[node.id] = node;
    }
  }
```

So we just basically built the note ID caches. And we have the notes, snapshot kept somewhere. And the snapshot is actually the list of notes. Interesting. So we set it up. When we initialize, basically we set it up. And we have to create a hydrate state, some state of the editor. Sorry. The multiple document. The multiple document. And the notes I have at different kind of notes. We have image note, which could be interesting. I will get back into one by one. I have a paragraph note, which is huge. Paragraph note, probably one of the most basic ones. It is crazy. Not of code there. I don't know why. I think it's need to be breakdown. It's too much though. The reference is from the default editor. The default editor is like the internal editor. That by default would be like that. And it can be over with it. And the metadata, this metadata, this is a header one. Okay. Flock type. So interestingly, we have paragraph note, but it can be different type. So we use the metadata to kind of guide this. That's kind of odd. Why not a H1 note? I would need to look at this at the end of my understanding better. I think a lot of stuff I won't actually agree on there. That is design decision. So they have attributions. Okay. H1 basically this is the metadata that I've seen, right? Attributes themselves is basically implementing an extra class with ID and can merge with. And I'm not sure when can you actually merge it, but there is a crazy, crazy code using it. Not too sure yet. Then we have normal plane paragraph, we have block code, fold, blah, blah, blah. So we can have different attributes that mark a paragraph note. Okay. Continue. At least this can be ordered or unordered right now. This item note sounds like one item, but it might be actually one item. We have X2, Quick Start. And the task note is kind of like a to do note, I guess. Okay. Who can read that? No problem. And then this note can have this own state. So basically we have different type of note. Okay. Let's mark it down first. We have node. We'll say like this item node, something that we can dive into. And as we can see, it can be ordered or unordered. Okay. And then something called test note, that extend document note. Oh my God. So related test note. Oh, a lot of inheritance man. Making it very hard to. It could be good in this kind of structure. It's very static structure. Yeah, we'll wait to see how we can maintain this set. Okay. We'll name the constructors. Okay. But what is that crazy syntax? Oh, yeah. Don't really understand this syntax. Try to do this. Okay. Okay. Okay. Okay. [ Silence ] 
*From Cursor:*
```
  late final List<DocumentNode> _latestNodesSnapshot;
```
