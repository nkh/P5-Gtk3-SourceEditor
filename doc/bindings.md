# Vim Bindings Documentation

> Version 0.04 -- P5-Gtk3-SourceEditor

---

## Normal Mode (Navigation)

| Binding     | Description                                                      |
| ----------- | ---------------------------------------------------------------- |
| `h`         | Move left one character. Stops at the beginning of the line.     |
| `j`         | Move down one line. Maintains virtual column position.           |
| `k`         | Move up one line. Maintains virtual column position.             |
| `l`         | Move right one character. Stops at the end of the line.          |
| `w`         | Move to the start of the next word.                              |
| `b`         | Move to the beginning of the current/previous word.              |
| `e`         | Move to the end of the current word.                             |
| `0`         | Move to the beginning of the line.                               |
| `$`         | Move to the end of the line.                                     |
| `^`         | Move to the first non-whitespace character of the line.          |
| `gg`        | Move to the first line of the buffer.                            |
| `G`         | Move to the last line of the buffer (or line N with count).      |
| `Page_Up`   | Scroll up one viewport page.                                     |
| `Page_Down` | Scroll down one viewport page.                                   |
| `f{c}`      | Jump forward to character `c` on the current line.               |
| `F{c}`      | Jump backward to character `c` on the current line.              |
| `t{c}`      | Jump forward to one character before `c` on the current line.    |
| `T{c}`      | Jump backward to one character after `c` on the current line.    |
| `;`         | Repeat the last f/F/t/T motion.                                  |
| `,`         | Repeat the last f/F/t/T motion in reverse direction.             |
| `%`         | Jump to matching bracket (`()`, `[]`, `{}`).                     |

### Ctrl-Key Navigation

| Binding   | Description                                                    |
| --------- | -------------------------------------------------------------- |
| `Ctrl-f`  | Scroll forward one full page.                                  |
| `Ctrl-b`  | Scroll backward one full page.                                 |
| `Ctrl-d`  | Scroll down half a page (half-page down).                      |
| `Ctrl-u`  | Scroll up half a page (half-page up).                          |
| `Ctrl-e`  | Scroll viewport down one line (cursor stays).                   |
| `Ctrl-y`  | Scroll viewport up one line (cursor stays).                     |
| `Ctrl-r`  | Redo the last undone operation.                                 |

---

## Insert Mode Entry

| Binding  | Description                                                    |
| -------- | -------------------------------------------------------------- |
| `i`      | Enter insert mode at current cursor position.                  |
| `a`      | Enter insert mode one character to the right.                  |
| `A`      | Enter insert mode at the end of the line.                      |
| `I`      | Enter insert mode at the first non-whitespace character.       |
| `o`      | Insert a newline below and enter insert mode.                  |
| `O`      | Insert a newline above and enter insert mode.                  |
| `R`      | Enter replace mode (overtype characters under cursor).          |

## Replace Mode

| Binding    | Description                                                    |
| ---------- | -------------------------------------------------------------- |
| Any char   | Replace the character under the cursor and advance.             |
| `BackSpace`| Move cursor back one position.                                  |
| `Escape`   | Exit replace mode, returning to Normal mode.                   |

## Insert / Replace Mode (shared)

| Binding  | Description                                                    |
| -------- | -------------------------------------------------------------- |
| `Escape` | Exit to Normal mode, moving cursor back one position.          |

> **Note:** Ctrl keys are fully available in native GTK mode (when `vim_mode => 0`). When vim mode is enabled, Ctrl keys are suppressed in insert, replace, and command modes. In normal and visual modes, recognized Ctrl keys (Ctrl-u, Ctrl-d, Ctrl-f, Ctrl-b, Ctrl-y, Ctrl-e, Ctrl-r) are handled by the Vim layer; all others are silently consumed.

---

## Edit Mode (Single Characters)

| Binding | Description                                                            |
| ------- | ---------------------------------------------------------------------- |
| `x`     | Delete the character under the cursor and place it in the yank buffer. |
| `r{c}`  | Replace a single character under the cursor with `c`.                   |
| `BackSp`| Delete the character before the cursor.                                |

## Edit Mode (Word Operations)

| Binding | Description                                                        |
| ------- | ------------------------------------------------------------------ |
| `dw`    | Delete from cursor to start of next word (yanked).                  |
| `cw`    | Change word under the cursor (delete + enter insert mode).          |
| `yw`    | Yank (copy) the word under the cursor into the yank buffer.        |

## Edit Mode (Line Operations)

| Binding | Description                                                              |
| ------- | ------------------------------------------------------------------------
| `dd`    | Delete the current line entirely and place it in the yank buffer.      |
| `cc`    | Clear the current line content and enter insert mode (line yanked).     |
| `C`     | Delete from cursor to end of line and enter insert mode.                |
| `U`     | Restore the current line to its state before the cursor last moved to it. |

## Yank (Copy/Paste)

| Binding | Description                                                                |
| ------- | -------------------------------------------------------------------------- |
| `yy`    | Yank (copy) the entire current line into the yank buffer.                  |
| `yw`    | Yank (copy) the current word into the yank buffer.                        |
| `yiw`   | Yank (copy) the inner word under the cursor into the yank buffer.         |
| `p`     | Paste the contents of the yank buffer after the cursor.                    |
| `P`     | Paste the contents of the yank buffer before the cursor.                   |

## Join & Indentation

| Binding | Description                                                        |
| ------- | ------------------------------------------------------------------ |
| `J`     | Join the current line with the next line (with smart spacing).     |
| `>>`    | Indent current line (and N-1 following lines with count) right.    |
| `<<`    | Indent current line (and N-1 following lines with count) left.     |

## Search

| Binding | Description                                                    |
| ------- | -------------------------------------------------------------- |
| `/`     | Enter search mode (forward).                                   |
| `?`     | Enter search mode (backward).                                  |
| `n`     | Repeat last search in the same direction.                      |
| `N`     | Repeat last search in the opposite direction.                  |

## Marks

| Binding   | Description                                                        |
| --------- | ------------------------------------------------------------------ |
| `m{a-z}`  | Set a mark at the current cursor position.                         |
| `` `{a-z} `` | Jump to the exact position of mark `a-z`.                         |
| `'{a-z}`  | Jump to the first non-whitespace of the line containing mark.      |

## Visual Mode

| Binding | Description                                                    |
| ------- | -------------------------------------------------------------- |
| `v`     | Enter character-wise visual mode (select text with motions).   |
| `V`     | Enter line-wise visual mode (select whole lines).              |
| `Ctrl-v`| Enter block-wise visual mode (select rectangular region).      |
| `gv`    | Reselect the last visual selection.                            |

### Visual Mode Operations

| Binding | Description                                                    |
| ------- | -------------------------------------------------------------- |
| `Escape` | Exit visual mode without action.                               |
| `y`     | Yank (copy) the selected text to the yank buffer.              |
| `d`     | Delete the selected text (yanked).                              |
| `c`     | Change the selected text (delete + enter insert mode).          |
| `>>`    | Indent selected lines right.                                    |
| `<<`    | Indent selected lines left.                                     |
| `~`     | Toggle case of selected text.                                   |
| `U`     | Upper-case selected text.                                       |
| `u`     | Lower-case selected text.                                       |
| `J`     | Join selected lines.                                            |
| `I`     | Insert at the start of each selected block line.                |
| `A`     | Append at the end of each selected block line.                 |
| `o`     | Go to other end of highlighted text.                            |
| `gq`    | Format (word-wrap) selected lines.                              |

All normal-mode navigation keys (h, j, k, l, w, b, e, 0, $, ^, G, gg, f, t, ;, %, etc.) work within visual mode to extend the selection. Ctrl-key scroll commands (Ctrl-d, Ctrl-u, Ctrl-f, Ctrl-b) also work in visual modes.

---

## Undo / Redo

| Binding | Description                                                    |
| ------- | -------------------------------------------------------------- |
| `u`     | Undo the last editing operation.                                |
| `Ctrl-r`| Redo the last undone operation.                                 |

## Command Mode

| Binding          | Description                                                       |
| ---------------- | ----------------------------------------------------------------- |
| `:`              | Enter command mode (focuses the bottom entry widget).             |
| `:w`             | Save the file.                                                    |
| `:w <filename>`  | Save the file to a new filename.                                  |
| `:q`             | Quit if no modifications have been made, otherwise errors out.    |
| `:q!`            | Force quit, discarding unsaved changes.                           |
| `:wq`            | Save and quit.                                                    |
| `:e <filename>`  | Open a file and replace the current buffer.                       |
| `:r <filename>`  | Insert file contents below the current line.                      |
| `:s/pat/repl/`   | Substitute first occurrence on current line.                      |
| `:s/pat/repl/g`  | Substitute all occurrences on current line.                       |
| `:%s/pat/repl/g` | Substitute all occurrences in the entire file.                    |
| `:{number}`      | Jump to line number.                                              |
| `:bindings`      | Show current key bindings in a dialog.                             |
| `:browse`        | Open a GTK file chooser dialog to select a file.                   |
| `:set cursor=block` | Switch to block cursor.                                          |
| `:set cursor=ibeam` | Switch to i-beam (default) cursor.                                |


---

## Numeric Prefixes

All normal-mode commands accept an optional numeric prefix to repeat the operation:

| Example  | Description                        |
| -------- | ---------------------------------- |
| `5j`     | Move down 5 lines.                 |
| `3dd`    | Delete 3 lines.                    |
| `2yy`    | Yank 2 lines.                      |
| `5x`     | Delete 5 characters.               |
| `3p`     | Paste 3 times.                     |
| `2o`     | Open 2 new lines below.            |
| `3u`     | Undo 3 times.                      |
| `3fx`    | Find the 3rd occurrence of 'x'.    |

---

## Module Architecture

Bindings are split into sub-modules under `Gtk3::SourceEditor::VimBindings::`:

| Module    | Responsibility                                        |
| --------- | ----------------------------------------------------- |
| `Normal`  | Normal-mode actions and keymap (navigation, editing, yank/paste, marks, visual entry, find-char motions, bracket matching, ctrl-key scroll) |
| `Insert`  | Insert mode (Escape to normal) and replace mode (char overwrite) |
| `Visual`  | Visual character-wise, line-wise, and block-wise selection (yank, delete, change, indent, case toggle, block I/A) |
| `Command` | Ex-command parser and handlers (`:w`, `:q`, `:e`, `:r`, `:s`, `:bindings`, goto line) |
| `Search`  | Search actions (forward/backward, repeat n/N, pattern set) |

All actions operate through the `VimBuffer` abstract interface, enabling testing without GTK and potential reuse with other widget toolkits.

---

## Custom Keybindings

Users can override keybindings by passing a `keymap` option. The keymap is a hash keyed by mode name, where `undef` removes a binding:

```perl
Gtk3::SourceEditor::VimBindings::add_vim_bindings(
    $textview, $mode_label, $cmd_entry, \$filename, 0,
    vim_buffer => $vb,
    keymap => {
        normal => {
            # Remap j/k to scroll (example)
            j => 'page_down',
            # Remove a binding
            K => undef,
            # Override Ctrl-key bindings
            _ctrl => {
                u => 'page_up',
                d => 'page_down',
                f => 'page_down',
                b => 'page_up',
                y => 'scroll_line_up',
                e => 'scroll_line_down',
                r => 'redo',
            },
        },
    },
);
```

Ex-commands can be similarly overridden via `ex_commands`:

```perl
    ex_commands => {
        q => 'my_custom_quit',
    },
```

---

## Disabling Vim Mode (Native GTK Bindings)

Set `vim_mode => 0` when constructing the editor to use the native Gtk3::SourceView keybindings instead of Vim modal editing. In this mode, the standard GTK text editing keys are available:

- **Ctrl+C / Ctrl+X / Ctrl+V** -- Copy, cut, paste
- **Ctrl+Z** -- Undo
- **Ctrl+A** -- Select all
- **Ctrl+Shift+Z** -- Redo
- **Arrow keys** -- Cursor navigation
- **Tab / Shift+Tab** -- Indent / unindent
- **Home / End** -- Line start / end

```perl
my $editor = Gtk3::SourceEditor->new(
    file     => 'my_script.pl',
    vim_mode => 0,    # Disable Vim bindings
);
```

The mode label and command entry are hidden in this mode, providing a clean native editing experience.
