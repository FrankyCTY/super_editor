## ImageUrlConversionReaction

`ImageUrlConversionReaction` is an **auto-formatter** that runs **after the user presses ENTER** (`SubmitParagraphIntention`).  
If the paragraph the user just finished **contains nothing except a single image URL**, the reaction **silently replaces that paragraph with an actual image node**.

### Step-by-step what happens

1. User types  
   `https://example.com/cat.png⏎`

2. Flutter’s input system turns the ENTER key into a `SubmitParagraphIntention` and adds it to the edit-event list.

3. The editor finishes the transaction and calls every `EditReaction.react()` with the whole change list.

4. `ImageUrlConversionReaction` looks at the list:

   - last event is `SubmitParagraphIntention` → continue.
   - find the preceding `SelectionChangeEvent` to know which node was active before the split.
   - that node must be a `ParagraphNode`.

5. Extract plain text from the paragraph and run the `linkify` package on it:

   - must contain **exactly one** URL.
   - the URL must be **the entire text** (trimmed).

6. Fire an **async HTTP HEAD** request to the URL:

   - if `content-type` starts with `image/` → proceed.
   - any network error or non-image type → abort, do nothing.

7. **Double-check** that the node still exists and its text hasn’t changed in the meantime (user could have kept typing).

8. Build an `ImageNode` with the same `id` as the old paragraph and enqueue one request:

   ```dart
   ReplaceNodeRequest(existingNodeId: oldId, newNode: imageNode)
   ```

9. Editor executes the request → the paragraph disappears, the image widget appears, cursor lands after it.

---

Edge cases / safety checks

- More than one link, or extra words → ignore.
- Node mutated between key-press and HTTP response → abort.
- Network failure → logged, no crash, no change.
- Whole operation is **undoable** because it is just another `ReplaceNodeRequest` in the history stack.
