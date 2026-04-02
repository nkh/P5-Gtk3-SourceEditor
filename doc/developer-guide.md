# Developer Guide: Adding Keybindings and Actions

> Version 0.04 -- P5-Gtk3-SourceEditor

---

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Architecture Overview](#2-architecture-overview)
- [3. Creating a New Action](#3-creating-a-new-action)
- [4. Action Coderef Reference](#4-action-coderef-reference)
- [5. VimBuffer Interface -- Complete Method Reference](#5-vimbuffer-interface--complete-method-reference)
- [6. Context Utilities](#6-context-utilities)
- [7. Keymap Structure](#7-keymap-structure)
- [8. Testing Your New Action](#8-testing-your-new-action)
- [9. Worked Example: Align Text](#9-worked-example-align-text)

---

## 1. Introduction

This document is the primary reference for developers who want to add new keybindings and actions to the P5-Gtk3-SourceEditor Vim emulation layer. It covers how actions are registered, how the dispatch system routes keys to actions, how to manipulate the text buffer through the VimBuffer interface, how the keymap is structured, and how to test everything without a running GTK display server.

Every editing operation in the editor is implemented as an action coderef registered in a central `%ACTIONS` hash. The dispatch system routes key events from GTK signal handlers to these actions through mode-specific keymaps. Actions never touch GTK widgets directly -- they operate exclusively through the VimBuffer abstract interface, which makes the entire system testable without a GUI.

---

## 2. Architecture Overview

### 2.1 The Three Layers

When a user presses a key, three layers process it in sequence:

```
GTK key-press-event signal
        |
        v
+------------------+     +------------------+     +------------------+
|  Signal Handler   | --> |  Dispatch System | --> |  Action Coderef  |
|  (VimBindings.pm) |     |  (_dispatch)     |     |  (Normal.pm etc) |
+------------------+     +------------------+     +------------------+
                                  |                         |
                                  v                         v
                         keymap lookup              $ctx->{vb}->method()
```

**Layer 1 -- Signal Handler.** Located in `VimBindings.pm`, the `key-press-event` signal handler on the text view receives every key press. It checks the current mode, extracts the GDK key name, handles Ctrl keys, and delegates to the appropriate mode handler (`handle_normal_mode`, `handle_insert_mode`, etc.).

**Layer 2 -- Dispatch System.** The mode handlers use `_dispatch()` to route keys. This function accumulates keys in a buffer, checks for numeric prefixes (like `3j`), matches against the dispatch table, handles `_immediate` keys that bypass accumulation, and manages `_char_actions` that wait for a second character.

**Layer 3 -- Action Coderef.** The final target is a named coderef stored in `%ACTIONS`. The action receives the context object (`$ctx`) and an optional numeric count, then operates on the text buffer through `$ctx->{vb}` (the VimBuffer interface). The action has no knowledge of GTK widgets.

### 2.2 File Inventory

| File | Role |
|------|------|
| `lib/Gtk3/SourceEditor/VimBindings.pm` | Central dispatcher, signal handler, mode setter, context builder. Contains the `%ACTIONS` hash. |
| `lib/Gtk3/SourceEditor/VimBindings/Normal.pm` | Normal-mode action coderefs and default keymap. Largest sub-module. |
| `lib/Gtk3/SourceEditor/VimBindings/Insert.pm` | Insert-mode actions, replace-mode keymap, replace-mode actions. |
| `lib/Gtk3/SourceEditor/VimBindings/Visual.pm` | Visual-mode actions (yank/delete/change/indent/toggle) and navigation keys. |
| `lib/Gtk3/SourceEditor/VimBindings/Command.pm` | Ex-command parser and handlers (`:w`, `:q`, `:e`, `:r`, `:s`, `:bindings`, `:browse`, `:set cursor=`, goto line). |
| `lib/Gtk3/SourceEditor/VimBindings/Search.pm` | Search actions (`search_next`, `search_prev`, `search_set_pattern`). |
| `lib/Gtk3/SourceEditor/VimBindings/PluginLoader.pm` | Plugin discovery, loading, unloading, reloading. Standalone (not auto-wired). |
| `lib/Gtk3/SourceEditor/VimBindings/Completion.pm` | Path completion engine for `:e` and `:r` commands. |
| `lib/Gtk3/SourceEditor/VimBindings/CompletionUI.pm` | Completion display widget for the command entry. |
| `lib/Gtk3/SourceEditor/Config.pm` | INI-style config file parser. Used by `SourceEditor->new()`. |
| `lib/Gtk3/SourceEditor/VimBuffer.pm` | Abstract interface: 27 methods that die on the base class. |
| `lib/Gtk3/SourceEditor/VimBuffer/Gtk3.pm` | Production backend: wraps Gtk3::SourceBuffer/View. |
| `lib/Gtk3/SourceEditor/VimBuffer/Test.pm` | Test backend: pure-Perl, no GTK dependency. |
| `bindings/AlignText.pm` | Example plugin demonstrating the plugin system (gal, gar, :align, :alignr). |

---

## 3. Creating a New Action

### 3.1 Choose the Sub-Module

Pick the file that matches the mode where the action should live:

| Mode | File |
|------|------|
| Normal | `VimBindings/Normal.pm` |
| Insert | `VimBindings/Insert.pm` |
| Replace | `VimBindings/Insert.pm` (via `register_replace_actions`) |
| Visual (char/line/block) | `VimBindings/Visual.pm` |
| Ex-command (`:xxx`) | `VimBindings/Command.pm` |
| Search (`/`, `?`, `n`, `N`) | `VimBindings/Search.pm` |

If the action is a utility that multiple modes share (like undo or redo), put it in the mode where it is primarily triggered and reference the action name from other keymaps.

### 3.2 Write the Action Coderef

Every action coderef receives the same first two arguments:

```perl
$ACTIONS->{my_action} = sub {
    my ($ctx, $count, @extra) = @_;
    # ...
};
```

- `$ctx` -- the context hash (see Section 4.1 for every field)
- `$count` -- numeric prefix from the user (e.g. `3` from `3j`), or `undef` if no prefix was typed. Always default: `$count ||= 1;`
- `@extra` -- additional arguments depending on how the action was triggered:
  - `_char_actions` (like `r`, `f`, `m`): one extra element, the character typed next (e.g. `'x'` from `rx`)
  - `search_set_pattern`: one extra element, a hashref `{ pattern => '...', direction => '...' }`
  - Most actions: empty `@extra`

Return value: `TRUE` (1) if the key was consumed, `FALSE` (0) if it should pass through. Most actions should return nothing (implicitly `undef`), which the dispatch system treats as TRUE.

### 3.3 Register the Action

Inside the `register()` function of the chosen sub-module, add the action to the `%ACTIONS` hash:

```perl
# Inside Normal.pm's register(\%ACTIONS):
$ACTIONS->{my_action} = sub {
    my ($ctx, $count, @extra) = @_;
    $count ||= 1;
    my $vb = $ctx->{vb};
    # ... do work using $vb methods ...
};
```

The action name is a string key in `%ACTIONS`. Use a lowercase, descriptive name with underscores (e.g. `delete_line`, `scroll_half_up`, `enter_insert`).

### 3.4 Add the Key Mapping

The `register()` function returns a keymap hashref. Add the key-to-action mapping:

```perl
# In the returned hashref:
my_action => 'my_action',   # single key
g        => { ... },        # multi-key prefix (see Section 7.3)
```

The key names on the left side are GDK key names (the strings returned by `Gtk3::Gdk::keyval_name()`). Common examples:

| Physical Key | GDK Key Name |
|--------------|-------------|
| `a` | `'a'` |
| `A` (Shift+a) | `'A'` |
| `:` | `'colon'` |
| `/` | `'slash'` |
| `?` | `'question'` |
| `$` | `'dollar'` |
| `^` | `'caret'` (also `'asciicircum'` on some systems) |
| `>` | `'greater'` |
| `<` | `'less'` |
| `Backspace` | `'BackSpace'` |
| `Escape` | `'Escape'` |
| `Left` | `'Left'` |
| `Page Down` | `'Page_Down'` |
| `` ` `` | `'grave'` |
| `'` | `'apostrophe'` |

### 3.5 Minimal Working Example

Here is a complete minimal example: a `toggle_comment` action bound to `gc` in normal mode.

Step 1 -- Add the action in `Normal.pm`:

```perl
$ACTIONS->{toggle_comment} = sub {
    my ($ctx, $count) = @_;
    $count ||= 1;
    my $vb = $ctx->{vb};
    my $line = $vb->cursor_line;
    for my $ln ($line .. $line + $count - 1) {
        last if $ln >= $vb->line_count;
        my $text = $vb->line_text($ln);
        if ($text =~ /^\s*#/) {
            $text =~ s/^\s*#\s*//;
        } else {
            $text = '# ' . $text;
        }
        $vb->delete_range($ln, 0, $ln, $vb->line_length($ln));
        $vb->insert_text($text);
        $vb->set_cursor($ln, 0) if $ln < $line + $count - 1;
    }
    $vb->set_cursor($line, $vb->first_nonblank_col($line));
};
```

Step 2 -- Add to the keymap. The `g` prefix already exists in `_prefixes`, and `gc` would be derived automatically. Add `gc => 'toggle_comment'` to the returned hashref:

```perl
return {
    _prefixes => [qw(g d y c greater less)],
    # ...
    gc => 'toggle_comment',
    # ...
};
```

---

## 4. Action Coderef Reference

### 4.1 The $ctx (Context) Object

The context hash is created once in `add_vim_bindings()` (or `create_test_context()` for testing) and passed to every action coderef. It carries all runtime state.

**Buffer and UI (stable references):**

| Key | Type | Description |
|-----|------|-------------|
| `vb` | `VimBuffer` instance | The buffer adapter (Gtk3 or Test). All text operations go through this. |
| `gtk_view` | `Gtk3::SourceView` or `undef` | The GTK text view widget. Used for scrolling. `undef` in test contexts. |
| `mode_label` | `Gtk3::Label` or `MockLabel` | Status bar label. Use `set_text()` to display messages to the user. |
| `cmd_entry` | `Gtk3::Entry` or `MockEntry` | Command/search entry widget. |
| `is_readonly` | `boolean` | Whether the buffer is read-only. Check before modifying. |

**Mutable state:**

| Key | Type | Description |
|-----|------|-------------|
| `yank_buf` | `scalarref` | Dereference to read/write the unnamed yank register (`${$ctx->{yank_buf}}`). |
| `desired_col` | `integer` | Virtual column for vertical movement. Set after horizontal motions. Read by `move_vert`. |
| `last_find` | `hashref` or `undef` | Last f/F/t/T find for `;` and `,` repeat. `{ cmd, char, count }`. |
| `marks` | `hashref` | Named mark positions. Keys are characters, values are `{ line, col }`. |
| `line_snapshots` | `hashref` | Saved line text for `U` (line-undo). Keys are line numbers. |
| `search_pattern` | `string` or `undef` | Last search pattern. |
| `search_direction` | `'forward'` or `'backward'` or `undef` | Last search direction. |
| `visual_start` | `hashref` or `undef` | Visual mode anchor `{ line, col }`. |
| `visual_type` | `'char'`, `'line'`, or `'block'` | Current visual mode type. |
| `last_visual` | `hashref` or `undef` | Saved last visual selection for `gv`. |
| `block_insert_info` | `hashref` or `undef` | Block-insert state for visual block `I`/`A`. |

**Configuration (immutable):**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `page_size` | `integer` | 20 | Lines per viewport page. |
| `shiftwidth` | `integer` | 4 | Columns per indent level. |
| `scrolloff` | `integer` or `undef` | `undef` | Scroll margin. `undef` = center. |
| `tab_string` | `string` | `"\t"` | String inserted by Tab key. |
| `use_clipboard` | `boolean` | 0 | Copy yanked text to system clipboard. |
| `filename_ref` | `scalarref` | `\""` | Reference to filename string. Update for `:w`/`:e`. |

**Closures (stable):**

| Key | Type | Description |
|-----|------|-------------|
| `set_mode` | `coderef` | `set_mode($mode)` -- switch modes, update UI, grab focus. |
| `move_vert` | `coderef` | `move_vert($count)` -- vertical movement with virtual column tracking and viewport scroll. |
| `after_move` | `coderef` | `after_move($ctx)` -- scroll viewport to keep cursor visible. No-op without `gtk_view`. |

### 4.2 The $count Parameter

The numeric prefix typed before the command key. `undef` when no prefix was given. Always default it:

```perl
$count ||= 1;
```

When a user types `3dd`, the dispatch system extracts `3` as the count and routes `dd` to the `delete_line` action with `$count = 3`.

### 4.3 The @extra Parameter

Additional arguments depending on the dispatch path:

| Dispatch type | @extra content | Example |
|---------------|---------------|---------|
| Normal key | `()` (empty) | `j` calls `move_down($ctx, 1)` |
| `_char_actions` prefix | `($char)` | `rx` calls `replace_char($ctx, 1, 'x')` |
| Ex-command | `($parsed)` | `:w` calls `cmd_save($ctx, 1, { cmd => 'w', ... })` |
| Search set | `({ pattern, direction })` | `/foo` calls `search_set_pattern($ctx, 1, { pattern => 'foo', direction => 'forward' })` |

### 4.4 Showing Status Messages

Use `$ctx->{mode_label}->set_text(...)` to display a message in the status bar. The message persists until the next mode change or keypress that updates the label. After an ex-command action returns, the `handle_command_entry` function preserves non-empty label text, so messages from actions are visible to the user.

```perl
$ctx->{mode_label}->set_text("Error: something went wrong");
$ctx->{mode_label}->set_text("Saved: myfile.txt");
```

### 4.5 Switching Modes

Call `$ctx->{set_mode}->($mode_name)` to switch modes. Valid mode names: `'normal'`, `'insert'`, `'replace'`, `'visual'`, `'visual_line'`, `'visual_block'`, `'command'`.

```perl
$ctx->{set_mode}->('insert');   # enter insert mode
$ctx->{set_mode}->('normal');   # return to normal mode
```

The mode setter handles: updating the mode label, showing/hiding the command entry, setting the text view editable state, grabbing focus, and recording visual mode start position.

---

## 5. VimBuffer Interface -- Complete Method Reference

The VimBuffer abstract interface (`lib/Gtk3/SourceEditor/VimBuffer.pm`) defines 27 abstract methods. All text manipulation in actions goes through these methods. The two backends that implement them are:

- `VimBuffer::Gtk3` (`lib/Gtk3/SourceEditor/VimBuffer/Gtk3.pm`) -- production backend, wraps Gtk3::SourceBuffer/View
- `VimBuffer::Test` (`lib/Gtk3/SourceEditor/VimBuffer/Test.pm`) -- test backend, pure-Perl array storage

**Important:** The Gtk3 backend uses GTK text iterators. Every call to `$buf->delete()` or `$buf->insert()` invalidates all existing iterators. If you need an iterator position after a buffer modification, get a fresh one via `$self->_iter()` (internal method in the Gtk3 backend) or recalculate from line/column coordinates. The Test backend does not have this limitation.

### 5.1 Cursor Accessors

**cursor_line()**

```perl
my $line = $vb->cursor_line;   # 0-based line number
```

Returns the 0-based line number where the cursor currently resides.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**cursor_col()**

```perl
my $col = $vb->cursor_col;     # 0-based column
```

Returns the 0-based column offset within the cursor line. In GTK, this is the byte offset returned by `get_line_offset`. In Test, it is the character offset.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**set_cursor( $line, $col )**

```perl
$vb->set_cursor(5, 0);         # go to line 6, column 1 (0-based)
```

Moves the cursor to the given position. Both arguments are 0-based. Implementations clamp to valid ranges (line >= 0, line < line_count, col >= 0, col <= line_length).

Cursor behavior: the cursor moves to the specified position. The viewport is NOT scrolled automatically -- call `$ctx->{after_move}->($ctx)` after `set_cursor` if you want the viewport to follow the cursor (for navigation actions). For editing actions that stay on the same visible line, you usually do not need to call `after_move`.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.2 Line Accessors

**line_count()**

```perl
my $n = $vb->line_count;       # total number of lines
```

Returns the total number of lines in the buffer. An empty buffer has 1 line (the single empty line). After inserting `"hello\nworld"`, the count is 2.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**line_text( $line )**

```perl
my $text = $vb->line_text(3);  # text of line 4 (0-based), no trailing newline
```

Returns the text of the given line (0-based) WITHOUT a trailing newline. Returns `undef` if the line is out of range (Test backend) or may crash (Gtk3 backend -- always clamp before calling).

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**line_length( $line )**

```perl
my $len = $vb->line_length(3); # number of characters in line 4
```

Returns the number of characters in the given line, NOT counting the trailing newline. An empty line returns 0.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**char_at( $line, $col )**

```perl
my $ch = $vb->char_at(3, 5);  # character at line 4, column 6
```

Returns the character at the given position as a single-character string. Returns `''` (empty string) if the position is out of bounds. Useful for checking what character is under the cursor or at a specific offset.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.3 Buffer-Level Operations

**text()**

```perl
my $whole = $vb->text;         # entire buffer as one string
```

Returns the entire buffer contents as a single string, including all line breaks. The string ends with a newline if the buffer has a trailing newline.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**set_text( $text )**

```perl
$vb->set_text("hello\nworld"); # replace entire buffer
```

Replaces the entire buffer contents with the given string. The cursor is moved to the start of the buffer (line 0, col 0). The modified flag is NOT automatically changed -- callers should call `set_modified()` if needed.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**get_range( $l1, $c1, $l2, $c2 )**

```perl
my $chunk = $vb->get_range(0, 5, 2, 10);  # text from (0,5) to (2,10)
```

Returns the text between two positions. The range is inclusive at the start and exclusive at the end (like Perl `substr`). The positions are line/column pairs, both 0-based. This is the standard way to extract text for yanking or inspection.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**modified()** and **set_modified( $bool )**

```perl
if ($vb->modified) { ... }       # check dirty flag
$vb->set_modified(0);            # mark as clean (after save)
$vb->set_modified(1);            # mark as dirty
```

Check or set the modified (dirty) flag. Used by `:q` to warn about unsaved changes, and by `:w` to clear the flag after saving.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.4 Editing Operations

**insert_text( $text )**

```perl
$vb->insert_text("hello");       # insert at cursor position
$vb->insert_text("\n");          # insert newline (splits line)
$vb->insert_text($ctx->{tab_string});  # insert configured tab
```

Inserts the given string at the current cursor position and advances the cursor past the inserted text. The cursor ends up positioned after the last inserted character. This is the primary way to add text to the buffer in actions.

Cursor behavior: cursor moves to after the inserted text.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**delete_range( $l1, $c1, $l2, $c2 )**

```perl
$vb->delete_range(3, 0, 5, 0);  # delete lines 4 and 5 entirely
$vb->delete_range(0, 5, 0, 10); # delete columns 6-10 on line 1
```

Deletes the text between two positions. The range is inclusive at the start and exclusive at the end. After deletion, the cursor is moved to `($l1, $c1)`.

**Important (Gtk3 backend):** After calling `delete_range`, all GTK text iterators that existed before the call are invalidated. Do not use any previously-obtained iterator after a delete. If you need to do a delete followed by an insert, get a fresh position reference (the cursor is at `$l1, $c1` after the delete).

Cursor behavior: cursor moves to the start of the deleted range (`$l1, $c1`).

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**replace_char( $char )**

```perl
$vb->replace_char('x');         # replace character under cursor with 'x'
```

Replaces the single character under the cursor with the given character. The cursor stays at its current position (does NOT advance). If the cursor is at the end of the line (past all characters), this is a no-op.

Cursor behavior: cursor stays at current position.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**join_lines( $count )**

```perl
$vb->join_lines(1);             # join current line with next
$vb->join_lines(3);             # join 3 lines together
```

Joins the current line with the next `$count - 1` lines. A single space is inserted between lines unless the current line already ends with whitespace or the next line starts with `)`. Leading whitespace on the joined line is removed. The cursor is placed at the join point.

Cursor behavior: cursor moves to the join point (where the lines were concatenated).

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**indent_lines( $count, $width, $direction )**

```perl
$vb->indent_lines(1, 4, 1);     # indent current line right by 4 spaces
$vb->indent_lines(5, 4, -1);    # indent 5 lines left by 4 spaces
```

Adds (`$direction > 0`) or removes (`$direction < 0`) `$width` spaces at the beginning of `$count` lines starting from the current line. When removing, only removes up to `$width` leading spaces (does not remove non-space characters). Works from bottom to top to keep line numbers valid during the operation.

Cursor behavior: cursor moves to the first non-blank column of the starting line.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.5 Navigation

**word_forward()**

```perl
$vb->word_forward;               # move to start of next word
```

Moves the cursor forward to the start of the next word. Skips the rest of the current word (non-whitespace characters) and any trailing whitespace. Wraps to the beginning of the next line when necessary.

Cursor behavior: cursor moves to the first character of the next word.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**word_end()**

```perl
$vb->word_end;                  # move to last character of current/next word
```

Moves the cursor to the last character of the current or next word. Advances at least one position, skips whitespace, then skips non-whitespace, and backs up one character to land on the final character of the word.

Cursor behavior: cursor moves to the last character of the word.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**word_backward()**

```perl
$vb->word_backward;             # move to start of previous/current word
```

Moves the cursor backward to the start of the previous (or current) word. Moves back one position first, then skips whitespace backwards (crossing line boundaries), then skips backward through non-whitespace characters.

Cursor behavior: cursor moves to the first character of the word.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**first_nonblank_col( $line )**

```perl
my $col = $vb->first_nonblank_col(3);  # first non-space column on line 4
```

Returns the column of the first non-whitespace character on the given line. Returns 0 if the line is empty or entirely whitespace. This is a query method that does NOT move the cursor.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.6 Search

**search_forward( $pattern, $start_line, $start_col )**

```perl
my $match = $vb->search_forward('hello');
# $match = { line => 5, col => 10 }   or undef if not found
```

Searches forward for `$pattern` (a `qr//` or plain string) starting from the given position (defaults to one character after the cursor). Wraps around the buffer if the pattern is not found before the end. Returns a hashref `{ line => $l, col => $c }` on success, or `undef` if not found.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**search_backward( $pattern, $start_line, $start_col )**

```perl
my $match = $vb->search_backward('hello');
```

Same as `search_forward` but searches backward. Wraps to the end of the buffer if not found.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.7 Undo/Redo

**undo()** and **redo()**

```perl
$vb->undo;                      # undo last editing operation
$vb->redo;                      # redo last undone operation
```

Undo/redo the last editing operation. In the Gtk3 backend, this delegates to Gtk3::SourceBuffer's native undo manager. In the Test backend, `undo()` restores the previous snapshot from the internal undo stack, and `redo()` is a no-op stub.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.8 Transform

**toggle_case( $l1, $c1, $l2, $c2 )**

```perl
$vb->toggle_case(0, 5, 0, 10);  # toggle case of columns 6-10 on line 1
```

Toggles the case (upper/lower) of all characters in the given range. After the operation, the cursor is at `($l1, $c1)`.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

---

**transform_range( $l1, $c1, $l2, $c2, $how )**

```perl
$vb->transform_range(0, 0, 0, 5, 'upper');   # uppercase first 5 chars
$vb->transform_range(0, 0, 0, 5, 'lower');   # lowercase first 5 chars
$vb->transform_range(0, 0, 0, 5, 'toggle');  # toggle case
```

Transforms characters in the given range. `$how` is one of `'upper'`, `'lower'`, or `'toggle'` (default). After the operation, the cursor is at `($l1, $c1)`.

Defined in: `VimBuffer.pm` (abstract), `Gtk3.pm`, `Test.pm`

### 5.9 Predicates

**at_line_start()** -- true when `cursor_col == 0`

**at_line_end()** -- true when `cursor_col >= line_length(cursor_line)`

**at_buffer_end()** -- true when on the last line AND at the end of that line

These are implemented in the base class `VimBuffer.pm` using the abstract cursor and line accessors, so they work on all backends without additional code. They do NOT move the cursor.

---

## 6. Context Utilities

These are closures stored in the `$ctx` hash, set up by `_init_utilities()` and `_init_mode_setter()` in `VimBindings.pm`.

### 6.1 move_vert($count)

```perl
$ctx->{move_vert}->(5);   # move down 5 lines
$ctx->{move_vert}->(-3);  # move up 3 lines
```

Moves the cursor vertically by `$count` lines (positive = down, negative = up). Uses `$ctx->{desired_col}` for the target column position, so vertical movement preserves the virtual column position across lines of different lengths (just like Vim's `j` and `k` keys). Clamps to valid buffer bounds. Automatically calls `after_move` to scroll the viewport.

Use this for all vertical navigation in actions instead of manually calculating positions. Example from `move_up`:

```perl
$ACTIONS->{move_up} = sub {
    my ($ctx, $count) = @_;
    $count ||= 1;
    $ctx->{move_vert}->(-$count);
};
```

### 6.2 after_move($ctx)

```perl
$ctx->{after_move}->($ctx) if $ctx->{after_move};
```

Scrolls the GTK viewport to keep the cursor visible after a cursor movement. The scrolling behavior depends on `$ctx->{scrolloff}`:

| scrolloff value | Behavior |
|-----------------|----------|
| `undef` (default) | Center the cursor in the viewport |
| `0` | Natural scrolling -- cursor reaches the edge before scrolling starts |
| `'center'` | Explicit centering (same as undef) |
| N (positive integer) | Keep at least N lines of context above and below the cursor |

This is a no-op when `$ctx->{gtk_view}` is `undef` (test context). The `move_vert` closure calls this automatically. For manual `set_cursor` calls, call `after_move` explicitly when you want the viewport to follow the cursor.

### 6.3 set_mode($mode_name)

```perl
$ctx->{set_mode}->('insert');
$ctx->{set_mode}->('normal');
```

Switches the current editing mode. Handles all the side effects:

- Updates `$ctx->{vim_mode}` scalar reference
- Sets the text view editable state (editable in insert/replace, read-only in other modes)
- Records visual mode start position and type when entering visual modes
- Updates the mode label text
- Shows/hides the command entry widget
- Grabs keyboard focus (text view for editing modes, command entry for command mode)

### 6.4 desired_col

```perl
$ctx->{desired_col} = $vb->cursor_col;   # save after horizontal motion
# vertical motion automatically uses desired_col via move_vert
```

Not a closure, but a mutable integer that represents the "virtual column" -- the horizontal position the user intended to be at. Set it after any horizontal cursor movement (left, right, word motions, end-of-line, etc.) so that subsequent vertical movement (`j`, `k`, `Ctrl-d`, `Ctrl-u`, `Page Up/Down`) maintains the column position across lines of different lengths.

### 6.5 last_find

```perl
$ctx->{last_find} = { cmd => 'f', char => 'x', count => 1 };
```

Stores the state of the last `f`/`F`/`t`/`T` motion for `;` (repeat) and `,` (repeat reverse). The `cmd` field is one of `'f'`, `'F'`, `'t'`, `'T'`. Set this after a successful find-char motion. The `find_repeat` and `find_repeat_reverse` actions read it.

---

## 7. Keymap Structure

Each mode's keymap is a hashref with regular key-to-action mappings plus special metadata keys prefixed with underscore.

### 7.1 Regular Keys

```perl
h  => 'move_left',
j  => 'move_down',
dd => 'delete_line',
yy => 'yank_line',
```

The left side is a GDK key name (string). The right side is an action name (string) that must exist as a key in `%ACTIONS`. When the user presses the key, the dispatch system looks up the action name in `%ACTIONS` and calls the coderef.

Single-character keys can also map to action names directly if the key is a printable character.

### 7.2 _immediate -- Bypass Accumulation Buffer

```perl
_immediate => ['Escape', 'Tab', 'BackSpace'],
```

Keys listed in `_immediate` bypass the key accumulation buffer. When pressed, the accumulated buffer is cleared and the action is executed immediately. This is used for keys that must always respond instantly regardless of what was typed before (like Escape to exit insert mode).

An `_immediate` key MUST also have a regular mapping in the keymap hash (e.g. `Escape => 'exit_to_normal'`).

### 7.3 _prefixes -- Multi-Key Sequences

```perl
_prefixes => [qw(g d y c greater less)],
```

Strings listed in `_prefixes` define multi-key sequences. The dispatch system derives all valid prefixes from these. For example, `'greater'` derives prefixes `'g'`, `'gr'`, `'gre'`, ..., `'greatergreater'`. When the user types a prefix, the key is accumulated and the system waits for more input.

A complete multi-key command (like `'gg'`, `'dd'`, `'greatergreater'`) must have a mapping in the keymap:

```perl
gg            => 'file_start',
dd            => 'delete_line',
greatergreater => 'indent_right',
lessless     => 'indent_left',
```

### 7.4 _char_actions -- Keys Needing a Following Character

```perl
_char_actions => {
    r           => 'replace_char',
    m           => 'set_mark',
    grave       => 'jump_mark',
    apostrophe  => 'jump_mark_line',
    f           => 'find_char_forward',
    F           => 'find_char_backward',
    t           => 'till_char_forward',
    T           => 'till_char_backward',
},
```

When a key in `_char_actions` is pressed, the dispatch system waits for one more keypress and passes it to the action as an `@extra` argument. The special key `_any` matches any single printable character (used in replace mode to intercept all typing).

Example: pressing `rx` dispatches `replace_char($ctx, 1, 'x')` where `'x'` is the extra character.

### 7.5 _ctrl -- Ctrl-Key Bindings

```perl
_ctrl => {
    u => 'scroll_half_up',
    d => 'scroll_half_down',
    f => 'page_down',
    b => 'page_up',
    y => 'scroll_line_up',
    e => 'scroll_line_down',
    r => 'redo',
},
```

Ctrl-key bindings are handled separately from regular keys. The signal handler intercepts all Ctrl combinations (detected via `control-mask`), constructs a key name like `'Control-u'`, and looks it up in the Ctrl dispatch table. The action name in the hash maps to the `%ACTIONS` registry.

Ctrl keys are only dispatched in normal and visual modes. In insert, replace, and command modes, all Ctrl keys are suppressed (return TRUE).

### 7.6 Removing a Binding

Set a key's value to `undef` in a user keymap override to remove it from the defaults:

```perl
keymap => {
    normal => {
        K => undef,    # remove the 'K' binding
        j => 'page_down',  # remap 'j' to page_down
    },
}
```

---

## 8. Testing Your New Action

### 8.1 Using create_test_context and simulate_keys

The test infrastructure uses `VimBuffer::Test` (a pure-Perl array-based buffer) and mock UI objects. No GTK display server is needed.

```perl
use Test::More;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# Create a test context with a buffer containing sample text
my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
    text => "hello world\nfoo bar\nbaz qux\n",
);
my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
    vim_buffer => $vb,
);

# Simulate keypresses
Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
is($vb->text, "ello world\nfoo bar\nbaz qux\n", 'x deletes first char');

Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'd');
is($vb->text, "foo bar\nbaz qux\n", 'dd deletes first line');
```

### 8.2 Creating a Test File

Test files go in the `t/` directory. Use this template:

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib 'lib', 't/lib';   # t/lib contains mock Gtk3/Glib modules
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# --- Test: my new action ---
subtest 'my_action does the right thing' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => "line one\nline two\nline three\n",
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );

    # Simulate the key sequence that triggers the action
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'c');

    # Check the result
    is($vb->cursor_line, 0, 'cursor stays on correct line');
    is($vb->cursor_col, 0, 'cursor at correct column');
    is($vb->text, "expected buffer content\n", 'buffer modified correctly');
};

done_testing;
```

### 8.3 Running Tests

```bash
cd /home/z/my-project/P5-Gtk3-SourceEditor

# Run a single test file
perl -Ilib -It/lib t/vim_dispatch.t

# Run all test files
for f in t/vim_*.t; do echo "=== $f ===" && perl -Ilib -It/lib $f 2>&1 | tail -1; done
```

The `t/lib/` directory contains mock modules for `Gtk3`, `Glib`, `Gtk3::Gdk`, and `Gtk3::MessageDialog` that provide just enough API surface to load the VimBindings modules without a real GTK installation.

### 8.4 Accessing Internal State

The mock objects provide basic introspection:

```perl
# Check the mode label text (for status message tests)
my $label_text = $ctx->{mode_label}->get_text();

# Check current mode
my $mode = ${$ctx->{vim_mode}};   # 'normal', 'insert', etc.

# Check command entry text
my $cmd_text = $ctx->{cmd_entry}->get_text();
```

---

## 9. Worked Example: Align Text

### 9.1 Goal

Implement a `\al` binding (backslash + `al`) that removes leading whitespace from the current line and the next N-1 lines. This is a multi-key command using a prefix, operating on multiple lines via the `$count` parameter.

### 9.2 The Action Coderef

Add this to `Normal.pm` inside `register(\%ACTIONS)`:

```perl
$ACTIONS->{align_lines} = sub {
    my ($ctx, $count) = @_;
    $count ||= 1;
    my $vb = $ctx->{vb};
    my $start_line = $vb->cursor_line;

    for my $ln ($start_line .. $start_line + $count - 1) {
        last if $ln >= $vb->line_count;
        my $text = $vb->line_text($ln);
        my $col = 0;
        while ($col < length($text) && substr($text, $col, 1) =~ /^\s$/) {
            $col++;
        }
        next if $col == 0;    # nothing to strip
        $vb->set_cursor($ln, 0);
        $vb->delete_range($ln, 0, $ln, $col);
    }

    # Position cursor at first non-blank of the starting line
    $vb->set_cursor($start_line, $vb->first_nonblank_col($start_line));
    $ctx->{after_move}->($ctx) if $ctx->{after_move};
};
```

Explanation of the logic:

1. Default `$count` to 1 (operate on current line only if no numeric prefix).
2. Record the starting line (cursor may move during the loop, so we save it upfront).
3. For each line in the range, read the text, find how many leading whitespace characters there are, and delete them.
4. Skip lines that have no leading whitespace (avoids unnecessary buffer modifications).
5. After the loop, position the cursor on the first non-blank character of the starting line.
6. Call `after_move` to scroll the viewport.

### 9.3 Registering the Action

The action is already registered by adding it to `%ACTIONS` in step 9.2. The action name is `'align_lines'`.

### 9.4 Adding to the Keymap

The backslash `\` key maps to the GDK key name `'backslash'`. Since `\al` is a multi-key sequence, we need to register `'backslash'` as a prefix and `'backslashal'` (or however GDK emits it) as the complete mapping.

However, GDK may not always produce the key name `'backslashal'` -- multi-character key names are unusual. The safer approach is to use a key that is already a known GDK key name. Let us use `\` as a char_action prefix instead, waiting for the next character:

```perl
_char_actions => {
    # ... existing entries ...
    backslash => 'align_lines',    # \ followed by 'a' triggers align
},
```

With this approach, `\a` triggers `align_lines`, and `\` followed by anything else is silently discarded (no matching action). If you want `\al` specifically (two characters after `\`), you would need a more complex dispatch mechanism, but for most practical purposes a single following character is sufficient.

For this example, let us use a simpler single-character binding. Remove `backslash` from `_char_actions` and instead bind it directly, assuming we want `\` to align the current line:

```perl
# In the returned keymap hashref:
backslash => 'align_lines',
```

Or, if you prefer a two-key prefix approach with `g`, add `gal => 'align_lines'` alongside the existing `g` prefix:

```perl
# The 'g' prefix is already registered in _prefixes.
# Just add the complete mapping:
gal => 'align_lines',
```

### 9.5 Full Test

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib 'lib', 't/lib';
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

subtest 'gal aligns current line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => "  hello\n  world\n    foo\n",
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
    );

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'a', 'l');
    is($vb->text, "hello\n  world\n    foo\n", 'leading spaces removed from line 1');
    is($vb->cursor_line, 0, 'cursor stays on line 1');
};

subtest '3gal aligns 3 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => "  aaa\n  bbb\n  ccc\n  ddd\n",
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
    );

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'g', 'a', 'l');
    is($vb->text, "aaa\nbbb\nccc\n  ddd\n", 'first 3 lines aligned');
};

subtest 'gal on already-aligned line is no-op' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => "hello\n  world\n",
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
    );

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'a', 'l');
    is($vb->text, "hello\n  world\n", 'no change on already-aligned line');
};

done_testing;
```

Run with:

```bash
perl -Ilib -It/lib t/vim_align.t
```
