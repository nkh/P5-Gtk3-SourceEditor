# VimBuffer Abstract Interface — Quick Reference

The `Gtk3::SourceEditor::VimBuffer` abstract class defines 27 methods + 3 predicates.
All VimBindings code operates exclusively through this interface.

## Cursor Movement

| Method | Returns | Description |
|--------|---------|-------------|
| `cursor_line()` | int | 0-based line number |
| `cursor_col()` | int | 0-based column |
| `set_cursor($line, $col)` | — | Move cursor (clamped) |
| `word_forward()` | — | Next word start |
| `word_backward()` | — | Previous word start |
| `word_end()` | — | Last char of current/next word |

## Text Access

| Method | Returns | Description |
|--------|---------|-------------|
| `text()` | str | Entire buffer contents |
| `set_text($text)` | — | Replace entire buffer |
| `line_text($line)` | str | Single line (no trailing \n) |
| `line_length($line)` | int | Character count of line |
| `line_count()` | int | Total number of lines |
| `get_range($l1,$c1,$l2,$c2)` | str | Range (start-inclusive, end-exclusive) |
| `char_at($line, $col)` | str | Character at position (empty if OOB) |
| `first_nonblank_col($line)` | int | First non-whitespace column |

## Text Manipulation

| Method | Returns | Description |
|--------|---------|-------------|
| `insert_text($text)` | — | Insert at cursor, advance cursor |
| `delete_range($l1,$c1,$l2,$c2)` | — | Delete range, cursor to ($l1,$c1) |
| `replace_char($char)` | — | Replace char under cursor |
| `join_lines($count)` | — | Join $count-1 lines (like `J`) |
| `indent_lines($count,$width,$dir)` | — | Add/remove indentation |
| `toggle_case()` | — | Toggle case of char under cursor |
| `transform_range(...)` | — | Transform case over a range |

## Undo/Redo

| Method | Returns | Description |
|--------|---------|-------------|
| `undo()` | — | Undo last edit |
| `redo()` | — | Redo last undone |
| `modified()` | bool | Modified flag |
| `set_modified($bool)` | — | Set modified flag |

## Search

| Method | Returns | Description |
|--------|---------|-------------|
| `search_forward($pattern, $line, $col)` | {line,col} or undef | Search forward, wraps |
| `search_backward($pattern, $line, $col)` | {line,col} or undef | Search backward, wraps |

## Predicates (implemented in base class)

| Method | Returns | Description |
|--------|---------|-------------|
| `at_line_start()` | bool | cursor_col == 0 |
| `at_line_end()` | bool | cursor_col >= line_length |
| `at_buffer_end()` | bool | last line AND at end |

## Backend Implementations

### VimBuffer::Test (headless)
- Constructor: `new(text => "line1\nline2\n")`
- Stores text as array of lines internally
- No external dependencies
- Used by all 18 test files

### VimBuffer::Gtk3 (production)
- Constructor: `new(buffer => $gtk_buffer, view => $gtk_view)`
- Wraps real `Gtk3::SourceView::Buffer` and `Gtk3::SourceView::View`
- Also exposes `gtk_buffer()` and `gtk_view()` accessors for direct GTK calls
