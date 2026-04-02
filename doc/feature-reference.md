# P5-Gtk3-SourceEditor Feature Reference

**v0.04** — Embeddable Vim-like text editor for Gtk3/Perl

---

## 1. Overview

P5-Gtk3-SourceEditor is a modular Vim-like text editor widget for Gtk3
applications, written in Perl. It provides modal editing with seven modes,
Vim keybindings, plugin system, theme support, syntax highlighting via
Gtk3::SourceView, and standalone CLI scripts.

Core modules: SourceEditor.pm (widget factory), ThemeManager.pm (theme
loader), VimBindings.pm (keybinding dispatch), VimBuffer (abstract buffer
with Gtk3/Test backends), Completion.pm/CompletionUI.pm (file completion),
PluginLoader.pm (runtime plugin management).

---

## 2. Constructor Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `file` | String | `undef` | File path to load |
| `config_file` | String | `undef` | INI-style config file path |
| `theme_file` | String | `'themes/default.xml'` | XML theme file |
| `font_family` | String | `'Monospace'` | Pango font family name |
| `font_size` | Int | `0` | Font pt size (0=system) |
| `wrap` | Bool | `1` | Word wrap on/off |
| `read_only` | Bool | `0` | Block editing |
| `vim_mode` | Bool | `1` | 0=native GTK keys |
| `show_line_numbers` | Bool | `1` | Show line gutter |
| `highlight_current_line` | Bool | `1` | Highlight cursor line bg |
| `auto_indent` | Bool | `undef` | Auto-indent new lines |
| `tab_width` | Int | `undef` | Tab stop width (columns) |
| `indent_width` | Int | `undef` | Auto-indent width (columns) |
| `insert_spaces_instead_of_tabs` | Bool | `0` | Tab key inserts spaces |
| `smart_home_end` | Bool | `undef` | Smart Home/End behavior |
| `show_right_margin` | Bool | `undef` | Show right margin line |
| `right_margin_position` | Int | `undef` | Right margin column |
| `highlight_matching_brackets` | Bool | `1` | Highlight matching bracket |
| `show_line_marks` | Bool | `undef` | Show line-marks gutter |
| `block_cursor` | Bool | `0` | 0=ibeam, 1=block (Cairo) |
| `force_language` | String | `undef` | Override syntax lang |
| `use_clipboard` | Bool | `0` | Copy to system clipboard |
| `tab_string` | String | `"\t"` | Tab insert text |
| `window` | Widget | `undef` | Parent for on_close |
| `on_close` | CodeRef | `undef` | Destroy callback |
| `keymap` | HashRef | `undef` | Per-mode key overrides |
| `on_ready` | CodeRef | `undef` | Post-init callback(\$ctx) |
| `key_handler` | CodeRef | `undef` | Pre-vim key interceptor |

---

## 3. Editor Modes

Seven modes. Mode shown in bottom bar label.

| Mode | Key | Label | Description |
|------|-----|-------|-------------|
| Normal | default | `-- NORMAL --` | Nav, edit, mode switches |
| Insert | `i/a/o/I/A/O` | `-- INSERT --` | Text input |
| Replace | `R` | `-- REPLACE --` | Overwrite chars |
| Visual | `v` | `-- VISUAL --` | Char selection |
| Vis Line | `V` | `-- VISUAL LINE --` | Line selection |
| Vis Block | `Ctrl-V` | `-- VISUAL BLOCK --` | Rect selection |
| Command | `:` | entry | Ex-commands, search |

Numeric count prefix works on most normal-mode commands.

---

## 4. Normal Mode Keybindings

### Movement

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `h`/Left | move left | `w` | next word start |
| `l`/Right | move right | `b` | prev word start |
| `j`/Down | line down | `e` | word end |
| `k`/Up | line up | `0`/Home | col 0 |
| `gg` | file start | `$`/End | line end |
| `G` | file end | `^` | first nonblank |
| PgUp | page up | PgDn | page down |

### Scrolling (Ctrl)

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| Ctrl-u | half up | Ctrl-d | half down |
| Ctrl-f | page down | Ctrl-b | page up |
| Ctrl-y | line up | Ctrl-e | line down |
| Ctrl-r | redo | | |

The page size (lines per page for Ctrl-f/b/Page_Up/Page_Down, half-page for
Ctrl-u/d) is calculated from the text widget's allocated height divided by the
font's line height.  A `size-allocate` signal handler on the text view
recalculates this value on every widget resize, ensuring the page size stays
accurate even when the initial computation runs before the widget is fully
realized.  The fallback default is 20 lines when no widget metrics are
available (e.g., in test contexts).

### Editing

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `x`/Del | delete char | `dd` | delete line |
| `dw` | delete word | `d$`/C | delete to EOL |
| `cc` | change line | `cw` | change word |
| `r{c}` | replace char | `J` | join lines |
| `>>` | indent right | `<<` | indent left |
| `u` | undo | `U` | line undo |
| BackSp | backspace | | |

### Yank & Paste

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `yy` | yank line | `yw` | yank word |
| `yiw` | yank inner word | `p` | paste after |
| `P` | paste before | `xp` | swap word |

### Mode Transitions

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `i` | insert at pos | `a` | insert after |
| `A` | insert EOL | `I` | insert BOL |
| `o` | open below | `O` | open above |
| `R` | replace mode | `v` | visual char |
| `V` | visual line | Ctrl-V | visual block |
| `gv` | reselect vis | `:` | command |
| `/` | fwd search | `?` | bwd search |

### Find Character & Marks

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `f{c}` | fwd to char | `F{c}` | bwd to char |
| `t{c}` | till char fwd | `T{c}` | till char bwd |
| `;` | repeat find | `,` | reverse find |
| `%` | match bracket | `m{c}` | set mark |
| `` `{c} `` | jump mark | `'{c}` | jump mark line |

---

## 5. Insert & Replace Modes

| Mode | Key | Action |
|------|-----|--------|
| Insert | Escape | to normal |
| Insert | Tab | insert tab_string |
| Replace | Escape | to normal |
| Replace | BackSp | move left |
| Replace | *(char)* | replace & advance |

Ctrl keys suppressed in both. GTK handles input natively.

---

## 6. Visual Mode

All three visual modes share navigation from normal mode plus:

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| Esc | cancel | `y` | yank |
| `x`/`d` | delete | `c` | change |
| `o` | swap ends | `~` | toggle case |
| `U` | uppercase | `u` | lowercase |
| `J` | join | `>>`/`<<` | indent |
| `I` | block ins left | `A` | block ins right |
| `gq` | format 78c | `gv` | reselect |

### Movement in Visual Mode

All normal-mode navigation keys (h, j, k, l, w, b, e, 0, $, ^, G, gg, f, t, ;, %,
Page_Up, Page_Down, Home, End) work within visual mode to extend the selection.
Arrow keys (Left, Down, Up, Right) alias to h, j, k, l respectively.

Key differences from normal mode:
- `l`/Right in char/block visual allows cursor one position past the last
  character (EOL+1) so the last character is included in the selection.
- `j`/k use `move_cursor()` (preserving the selection anchor) rather than
  `set_cursor()` (which would collapse the selection).
- `w`/`b`/`e` use `move_cursor()` in visual modes (preserving the
  selection anchor) and `set_cursor()` in normal mode (collapsing any
  spurious GTK selection that the Gtk3 backend's `move_mark_by_name`
  may create).  This ensures word motions never leave a visible selection
  in normal mode.
- Vertical movement preserves the virtual column position (`desired_col`)
  and restores it when returning to a longer line, clamping to EOL+1 on
  short lines in visual modes (vs. last-char in normal mode).

Block I/A: type text, Escape replays on all block lines.

---

## 7. Ex-Commands

| Cmd | Description | Cmd | Description |
|-----|-------------|-----|-------------|
| `:q` / `:q!` | quit / force | `:w [f]` | save |
| `:wq` | save & quit | `:e <f>` | open file |
| `:r <f>` | insert file | `:N` | goto line N |
| `:[range]s/p/r/g` | substitute | `:bindings` | show keys |
| `:set cursor=block` | block cursor | `:set cursor=ibeam` | ibeam cursor |
| `:browse` | GTK file picker | `/pat` | fwd search |
| `?pat` | bwd search | |

Substitute uses `qr//`. Range: `%` (all), `N,M` (lines).
Single undo group.

---

## 8. Search

`/` forward, `?` backward. `n`/`N` repeat. Wraps at buffer ends.
Uses GtkSourceView with `'visible-only'` flag.

---

## 9. Status Messages

Error and status messages (e.g. "Pattern not found", "Saved: file")
are displayed temporarily on the mode label.  They auto-clear after 3
seconds or on the next normal-mode keypress, restoring the current mode
display (`-- NORMAL --`, etc.).  This prevents messages from persisting
indefinitely and obscuring the mode indicator.

---

## 10. Marks

`m{c}` set, `` `{c} `` jump exact, `'{c}` jump line.
Session-only, not persisted.

---

## 11. File Path Completion

For `:e` and `:r`. Tab starts/recompletes. Left/Right cycles.
Enter accepts. Escape cancels. BackSpace deletes. Typing refines.

Directories shown with `/`. Select dir + Tab/Enter navigates in.

---

## 12. Plugin System

`.pm` files from `plugin_dirs` or `plugin_files`. Each implements
`register($ACTIONS, $config)`. Returns optional descriptor.

| Cmd | Description |
|-----|-------------|
| `:plugin list` | list loaded *(planned)* |
| `:plugin unload <p>` | remove *(planned)* |
| `:plugin reload <p>` | hot-reload *(planned)* |

Descriptor: `{ meta=>{name,namespace}, modes=>{normal=>{k=>a}}, ex_commands=>{cmd=>a} }`

---

## 13. Theme System

Loads GtkSourceView XML themes. Extracts fg/bg, injects cursor style,
generates CSS for label and entry. Built-in: `default.xml`,
`theme_dark.xml`, `theme_light.xml`, `theme_solarized.xml`.

---

## 14. VimBuffer Interface

Abstract interface. Gtk3 backend for production, Test for headless.

### Cursor & State

`cursor_line()`, `cursor_col()`, `set_cursor($l,$c)`,
`at_line_start()`, `at_line_end()`, `at_buffer_end()`,
`modified()`, `set_modified($b)`

### Buffer Access

`line_count()`, `line_text($l)`, `line_length($l)`,
`text()`, `set_text($t)`, `get_range(..)`, `delete_range(..)`,
`insert_text($t)`

### Editing

`word_forward()`, `word_backward()`, `word_end()`,
`join_lines($n)`, `indent_lines($n,$w,$dir)`,
`replace_char($c)`, `char_at($l,$c)`,
`transform_range(..,$how)` (upper/lower/toggle),
`first_nonblank_col($l)`

### Search & Undo

`search_forward($p,$l,$c)`, `search_backward($p,$l,$c)`
`undo()`, `redo()`, `begin_user_action()`, `end_user_action()`

### Selection (Gtk3 only)

`set_selection($al,$ac)`, `clear_selection()`

---

## 15. Block Cursor

Cairo-drawn block cursor via the draw signal handler.  Colours are
read from the GtkSourceView style scheme for theme-correct rendering.
Activated by `:set cursor=block`; deactivated by `:set cursor=ibeam`.
The character under the cursor is drawn in the background colour for
visibility (inverted text).

---

## 16. Custom Keymaps

Per-mode key→action overrides. Special: `_immediate`, `_prefixes`,
`_char_actions`, `_ctrl`. Set `undef` to remove default.

---

## 17. Accessors

`get_widget()` → Gtk3::Box, `get_text()` → String,
`get_buffer()` → SourceBuffer

---

## 18. CLI Scripts

`source-editor` — standalone editor window
`source-dialog-editor` — editor in Gtk3::Dialog
`source-editor-cursor-demo` — on_ready callback + block cursor demo

Short options: `-C` config, `-r` read-only, `-f` font-size,
`-w` wrap, `-n` no-line-numbers, `-b` cursor-block,
`-H` highlight-current-line, `-h` help.  Long: `--config`, `--theme`, `--read-only`, `--font-size`, `--wrap`, `--no-line-numbers`, `--cursor-block`, `--highlight-current-line`, `--help`.

---

## 19. Dependencies

**Runtime:** Perl 5.020+, Gtk3, Gtk3::SourceView, Glib, Pango,
File::Slurper, Encode, Getopt::Long

**Block cursor:** Cairo, Pango::Cairo (graceful degradation)

**Plugins:** File::Find, File::Spec, File::Basename (core)

**Testing:** Test::More; mock stubs in `t/lib/`

---

## 20. Testing

~290 tests across 15 files. `create_test_context(%opts)` builds
context; `simulate_keys($ctx, @keys)` feeds key sequences.
