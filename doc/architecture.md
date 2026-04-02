# Architecture -- P5-Gtk3-SourceEditor

> Version 0.04

---

## 1. Overview

**P5-Gtk3-SourceEditor** is a modular, embeddable Vim-like text editor widget for Gtk3 Perl applications. It is built on top of `Gtk3::SourceView` and provides full modal editing through a decoupled action-registry architecture that enables complete headless testing without a running GTK display server. The module is designed to be dropped into any Gtk3 application as a self-contained editor component, requiring only a single `new()` call and a `get_widget()` call to embed a fully functional editor with syntax highlighting, Vim keybindings, theming, and ex-command support.

The design philosophy centers on four core principles that permeate every layer of the architecture:

1. **GUI Decoupling** -- All editing logic operates exclusively through the `VimBuffer` abstract interface. No action coderef ever touches a GTK widget directly. This enables headless unit testing via `VimBuffer::Test` and potential reuse with other widget toolkits (Tk, Qt, etc.) by implementing a new adapter. The only modules that know about GTK widgets are `SourceEditor.pm` (widget factory), `VimBuffer::Gtk3` (adapter), and the signal connection code in `VimBindings.pm`.

2. **Action Registry** -- Every editing operation (move cursor, delete line, search, change case) is registered as a named coderef in a module-level `%ACTIONS` hash inside `VimBindings.pm`. Mode-specific sub-modules (`Normal.pm`, `Insert.pm`, `Visual.pm`, `Command.pm`, `Search.pm`) populate this registry at compile time via their `register()` functions. Actions receive `($ctx, $count, @extra)` and operate entirely through `$ctx->{vb}` (the VimBuffer interface), never accessing GTK widgets.

3. **Configurable Dispatch** -- Key events are routed through mode-specific dispatch tables that map GDK key names to action names. Each mode has a keymap hashref with regular key-to-action mappings plus four special metadata keys (`_immediate`, `_prefixes`, `_char_actions`, `_ctrl`). Users can pass a custom `keymap` option to override any binding without modifying core code -- setting a key's value to `undef` removes it from the defaults.

4. **Configurable via Files and CLI** -- Editor behavior is configurable through a `key = value` config file (parsed by `Config.pm`) with CLI override precedence. All GtkSourceView properties (line numbers, tab width, indent, margin, bracket matching, etc.) are exposed as config keys. Config file values serve as defaults; explicit constructor options always take precedence.

The current version is **0.04**. The module is distributed under the Artistic License 2.0 and authored by nkh.

---

## 2. Component Diagram (ASCII Art)

The following diagram shows the complete component hierarchy and all relationships between modules. Arrows indicate "uses" or "delegates to" relationships. Dashed lines indicate inheritance.

```
+--------------------------------------------------------------------+
|                         EMBEDDING APPLICATION                        |
|                                                                     |
|   use Gtk3::SourceEditor;                                           |
|   my $editor = Gtk3::SourceEditor->new( file => 'script.pl' );      |
|   $vbox->pack_start( $editor->get_widget(), TRUE, TRUE, 0 );        |
+-----------------------------------+--------------------------------+
                                    | creates
                                    v
+--------------------------------------------------------------------+
|                      Gtk3::SourceEditor  [0.04]                    |
|                    (Main Widget Factory / Orchestrator)              |
|                                                                     |
|   Constructor Options: file, config_file, theme_file, font_family,  |
|   font_size, wrap, read_only, window, on_close, keymap, vim_mode,  |
|   force_language, show_line_numbers, highlight_current_line,        |
|   block_cursor, plugin_dirs, plugin_files, on_ready, key_handler    |
|                                                                     |
|   +-------------------+    +-----------------------------------+     |
|   |                   |    |  Gtk3::SourceEditor::ThemeManager |     |
|   | Internal UI Tree  |    |  [0.04]                          |     |
|   |                   |    |                                  |     |
|   | Gtk3::Box         |    |  * Parses XML theme files         |     |
|   | +- Gtk3::Scrolled |    |  * Extracts fg/bg from <style>    |     |
|   | |  +- Gtk3::     |    |  * Injects <style name="cursor"> |     |
|   | |     SourceView |<---|  * Writes temp XML for SchemeMgr  |     |
|   | |     ::View     |    |  * Generates CSS for mode_label   |     |
|   | |     ::Buffer   |    |    and cmd_entry                  |     |
|   | |                |    +-----------------------------------+     |
|   | +- Gtk3::Box     |                                           |
|   |    +- Gtk3::Entry | Loads:                                   |
|   |    | (cmd_entry)  | * Config (key=value parser)             |
|   |    +- Gtk3::EventBox                                          |
|   |       +- Gtk3::Box (horizontal, status)                     |
|   |          +- Gtk3::Label (mode_lbl, left)                     |
|   |          +- Gtk3::Label (pos_lbl, right)                     |
|   +-------------------+   Accessor Methods:                       |
|                             get_widget(), get_text(), get_buffer()  |
+-----------------------------------+--------------------------------+
                                    | wires via add_vim_bindings()
                                    v
+--------------------------------------------------------------------+
|             Gtk3::SourceEditor::VimBindings  [0.04]                |
|                 (Central Dispatcher + Signal Router)                |
|                                                                     |
|   Public Entry Point:                                               |
|     add_vim_bindings( $textview, $mode_label, $cmd_entry,         |
|                       $filename_ref, $is_readonly, %opts )         |
|         Required option:  vim_buffer => $vb                        |
|         Optional options: keymap, ex_commands, page_size,           |
|                           shiftwidth                                |
|                                                                     |
|   Testing Entry Point:                                              |
|     create_test_context( %opts )   -- headless, no GTK needed      |
|     simulate_keys( $ctx, @keys )   -- deterministic key sequences  |
|                                                                     |
|   Signal Handlers:                                                  |
|     textview  key-press-event  --> handle_normal/insert/visual/    |
|     cmd_entry key-press-event  --> handle_command_entry()           |
|                                                                     |
|   Mode Handlers:                                                    |
|     handle_normal_mode()    handle_insert_mode()                    |
|     handle_visual_mode()    handle_replace_mode()                   |
|     handle_ctrl_key()       handle_command_entry()                  |
|                                                                     |
|   Internal Routing:                                                 |
|     _dispatch()             _resolve_keymap()                       |
|     _extract_count()        _derive_prefixes()                      |
|     _build_dispatch()       _build_ctrl_dispatch()                  |
|     _init_utilities()       _init_mode_setter()                     |
|                                                                     |
|   Mock Objects (for testing):                                       |
|     MockLabel    MockEntry                                           |
+-------+---------------+---------------+---------------+--------------+
        |               |               |               |
        | register()    | register()    | register()    | register()
        v               v               v               v
+--------------+ +--------------+ +--------------+ +--------------+
| Normal.pm    | | Insert.pm    | | Visual.pm    | | Command.pm   |
| [0.04]       | | [0.04]       | | [0.04]       | | [0.04]       |
|              | |              | |              | |              |
| Navigation:  | | Escape->norm | | yank/delete/ | | :w :q :wq    |
| h,j,k,l,     | | Replace:     | | change/toggle| | :e :r :s      |
| w,b,e,gg,G,  | | _any->replac | | case/indent  | | :%s  :N      |
| 0,$,^,f/F/   | | BackSpace    | | format/join  | | :bindings    |
| t/T,;/,%,    | | block insert | | block ops    | |              |
|              | | replay       | | gv reselect  | | parse_ex_    |
| Editing:     | |              | |              | | command()    |
| x,dd,cc,cw,  | | get_replace_ | | navigation_ | |              |
| C,J,r,>>,<   | | keymap()     | | keys()       | |              |
|              | |              | |              | |              |
| Yank/Paste:  | | register_    | |              | |              |
| yy,yw,p,P,xp | | replace_     | |              | |              |
|              | | actions()    | |              | |              |
| Mode Entry:  | |              | |              | |              |
| i,a,I,A,o/O  | |              | |              | |              |
| R,v,V,Ctrl-v | |              | |              | |              |
| :,/,?        | |              | |              | |              |
|              | |              | |              | |              |
| Undo: u, U   | |              | |              | |              |
| Marks: m,`, '| |              | |              | |              |
+--------------+ +--------------+ +--------------+ +--------------+
                     |                                              |
                     | register()                                    |
                     v                                              |
              +--------------+                                         |
              | Search.pm    |                                         |
              | [0.04]       |                                         |
              |              |                                         |
              | search_next  |                                         |
              | search_prev  |                                         |
              | search_set_  |                                         |
              | pattern      |                                         |
              +--------------+                                         |
                                                                     |
                    ALL actions populate the %ACTIONS registry       |
                    (hash of name -> coderef, scoped in VimBindings)  |
                                                                     |
                    All actions operate through VimBuffer interface    |
                                                                     v
+--------------------------------------------------------------------+
|             Gtk3::SourceEditor::VimBuffer  [0.04]                  |
|                  (Abstract Interface)                              |
|                                                                     |
|   Every method dies with "Unimplemented in ..." on the base class. |
|   Subclasses MUST override all abstract methods.                    |
|                                                                     |
|   Abstract Methods:                                                 |
|     cursor_line()  cursor_col()  set_cursor($l,$c)  line_count()  |
|     line_text($l)  line_length($l)  text()                         |
|     get_range($l1,$c1,$l2,$c2)  delete_range($l1,$c1,$l2,$c2)   |
|     insert_text($text)  undo()  redo()  modified()  set_modified()|
|     word_forward()  word_end()  word_backward()                    |
|     first_nonblank_col($l)  join_lines($count)                    |
|     indent_lines($count,$w,$dir)  replace_char($char)             |
|     char_at($l,$c)  search_forward($pat)  search_backward($pat)   |
|     toggle_case()  transform_range()                                |
|                                                                     |
|   Predicate Methods (implemented in base class):                    |
|     at_line_start()  at_line_end()  at_buffer_end()                |
+--------------------------------+-------------------------------------+
                                | inherits
                  +--------------+--------------+
                  |                             |
                  v                             v
+---------------------------+  +---------------------------+
| VimBuffer::Gtk3 [0.04]    |  | VimBuffer::Test  [0.04]    |
| @ISA(VimBuffer)            |  | @ISA(VimBuffer)            |
|                           |  |                            |
| Production adapter.        |  | Pure-Perl test adapter.    |
| Wraps:                    |  | Stores text as array of    |
|   Gtk3::SourceBuffer      |  | line strings (no \n).      |
|   Gtk3::SourceView        |  |                            |
|                           |  | Features:                  |
| Constructor:              |  |   text => $string          |
|   buffer => $buf (req)    |  |   snapshot undo stack      |
|   view   => $view (req)   |  |   redo: stub (no-op)       |
|                           |  |                            |
| Delegates to GTK:         |  | No external deps beyond    |
|   _iter() -> insert mark  |  | the VimBuffer base.        |
|   get_iter_at_line_*     |  |                            |
|   forward_search()        |  | Used by t/vim_*.t tests    |
|   backward_search()       |  | via create_test_context     |
|   delete_range()          |  |                            |
|   insert()                |  +---------------------------+
|   undo/redo               |
+---------------------------+
```

---

## 3. Module Inventory

### 3.1 Core Modules

| Module | File Path | VERSION | Purpose | Key Methods / API |
|--------|-----------|---------|---------|-------------------|
| `Gtk3::SourceEditor` | `lib/Gtk3/SourceEditor.pm` | 0.04 | Main widget factory and entry point for the entire library. Accepts configuration options, builds the complete GTK widget tree (scrolled text view, command entry, mode label), loads themes, configures syntax highlighting, initializes the VimBuffer adapter, and wires up VimBindings if enabled. This is the only module an embedding application needs to `use`. | `new(%opts)`, `_build_ui(%opts)`, `get_widget()`, `get_text()`, `get_buffer()` |
| `Gtk3::SourceEditor::ThemeManager` | `lib/Gtk3/SourceEditor/ThemeManager.pm` | 0.04 | Parses GtkSourceView XML theme files, extracts foreground and background colors from the `<style name="text">` element, injects a cursor color style if missing, writes a temporary XML file, registers it with the `StyleSchemeManager`, and generates CSS to style the `mode_label` and `cmd_entry` widgets. | `load(file => $path)` -> returns `{ scheme, css_provider, fg, bg }` |

### 3.2 Configuration and Utilities

| Module | File Path | VERSION | Purpose | Key Methods / API |
|--------|-----------|---------|---------|-------------------|
| `Gtk3::SourceEditor::Config` | `lib/Gtk3/SourceEditor/Config.pm` | 0.04 | Parses INI-style configuration files (key = value format). Supports comments (`#`), blank lines, boolean values (`true/false/1/0`), integers, and quoted strings. Used by `SourceEditor->new()` to load defaults from `config_file` before applying explicit constructor options. | `parse_editor_config($file_path)` -> returns hashref |

### 3.3 Plugin System

| Module | File Path | VERSION | Purpose | Key Methods / API |
|--------|-----------|---------|---------|-------------------|
| `Gtk3::SourceEditor::VimBindings::PluginLoader` | `lib/Gtk3/SourceEditor/VimBindings/PluginLoader.pm` | 0.05 | Standalone plugin discovery and lifecycle management. Scans directories for `.pm` files, extracts package names, calls `register($ACTIONS, $config)` on each plugin, merges returned keymaps and ex-commands into the dispatch system. Supports collision detection, namespaced actions, hooks, and hot-reload. Not yet wired into the SourceEditor constructor (plugins must be loaded manually via `on_ready`). | `load_plugins(\\%ACTIONS, %opts)`, `unload_plugin($pkg, \\%ACTIONS)`, `reload_plugin($pkg, \\%ACTIONS)`, `list_plugins()`, `get_plugin_hooks()` |
| `Gtk3::SourceEditor::VimBindings::Completion` | `lib/Gtk3/SourceEditor/VimBindings/Completion.pm` | 0.01 | Path completion engine. Given a partial file path, returns matching candidates and the longest common prefix. Supports directory traversal, hidden file visibility toggle, and absolute/relative path resolution. | `new(%opts)`, `complete($partial_path)` -> returns `{ prefix, candidates }` |
| `Gtk3::SourceEditor::VimBindings::CompletionUI` | `lib/Gtk3/SourceEditor/VimBindings/CompletionUI.pm` | 0.01 | Completion display widget for the command entry. Integrates with `Completion` to provide Tab-completion for `:e` and `:r` ex-commands. Shows candidates inline, cycles through them with Left/Right arrows, accepts on Enter, cancels on Escape. | `new($ctx, $completer)`, `handle_key($key)` |

### 3.4 VimBindings System

| Module | File Path | VERSION | Purpose | Key Methods / API |
|--------|-----------|---------|---------|-------------------|
| `Gtk3::SourceEditor::VimBindings` | `lib/Gtk3/SourceEditor/VimBindings.pm` | 0.04 | Central dispatcher and orchestrator for the entire Vim emulation layer. Connects GTK `key-press-event` signals to mode-specific handlers. Builds dispatch tables from resolved keymaps. Manages mode transitions via `_init_mode_setter()`. Provides vertical movement with virtual column tracking via `_init_utilities()`. Contains the `%ACTIONS` registry populated by all sub-modules. Provides testing API (`create_test_context`, `simulate_keys`) and public accessors (`get_actions`, `get_default_keymap`, `get_default_ex_commands`). Also defines `MockLabel` and `MockEntry` classes inline. | `add_vim_bindings($tv, $ml, $ce, $fn_ref, $ro, %opts)`, `create_test_context(%opts)`, `simulate_keys($ctx, @keys)`, `get_actions()`, `get_default_keymap()`, `get_default_ex_commands()`, `handle_normal_mode($ctx, $k)`, `handle_insert_mode($ctx, $k)`, `handle_visual_mode($ctx, $k)`, `handle_replace_mode($ctx, $k)`, `handle_ctrl_key($ctx, $key)`, `handle_command_entry($ctx, $k)`, `_dispatch($ctx, $dispatch, $prefixes, $char_actions, $key, $on_miss)`, `_resolve_keymap($user_km, $user_ex)`, `_derive_prefixes($km)`, `_build_dispatch($km)`, `_build_ctrl_dispatch($km)`, `_extract_count($buf)`, `_init_utilities($ctx)`, `_init_mode_setter($ctx)` |
| `Gtk3::SourceEditor::VimBindings::Normal` | `lib/Gtk3/SourceEditor/VimBindings/Normal.pm` | 0.04 | Registers all normal-mode action coderefs into `%ACTIONS` and returns the default normal-mode keymap hashref. This is the largest sub-module, containing 45+ actions covering navigation, editing, yank/paste, indentation, undo, marks, mode entry, and find-character motions. | `register(\%ACTIONS)` -> returns keymap hashref |
| `Gtk3::SourceEditor::VimBindings::Insert` | `lib/Gtk3/SourceEditor/VimBindings/Insert.pm` | 0.04 | Registers insert-mode actions (Escape exits to normal with cursor backup) and replace-mode actions (`do_replace_char`, `replace_backspace`). Also provides the replace-mode keymap via `get_replace_keymap()` which uses `_char_actions => { _any => 'do_replace_char' }` to intercept all printable characters. Handles block-insert replay on exit. | `register(\%ACTIONS)`, `get_replace_keymap()`, `register_replace_actions(\%ACTIONS)` |
| `Gtk3::SourceEditor::VimBindings::Visual` | `lib/Gtk3/SourceEditor/VimBindings/Visual.pm` | 0.04 | Registers all visual-mode actions (yank, delete, change, swap ends, toggle/upper/lower case, join, format, block insert start/end, indent). Also provides `navigation_keys()` returning a hashref of keys shared between normal and visual modes (h/j/k/l/w/b/e/G/gg/0/$/^ and page keys). Contains internal helpers for block bounds calculation, block text extraction, block deletion, selection range normalization, and last-visual-save. | `register(\%ACTIONS)` -> returns base keymap, `navigation_keys()` -> returns nav hashref |
| `Gtk3::SourceEditor::VimBindings::Command` | `lib/Gtk3/SourceEditor/VimBindings/Command.pm` | 0.04 | Registers ex-command action handlers and provides the ex-command parser. Handles `:w` (save), `:q` (quit with modified check), `:q!` (force quit), `:wq` (save and quit), `:e` (open file), `:r` (read/insert file), `:s` (substitute with range support), `:bindings` (show help dialog), and bare line-number goto. The `parse_ex_command()` function parses raw command strings into structured hashes with `cmd`, `args`, `bang`, `range`, `line_number` fields. | `register(\%ACTIONS)`, `parse_ex_command($raw)` -> returns hashref |
| `Gtk3::SourceEditor::VimBindings::Search` | `lib/Gtk3/SourceEditor/VimBindings/Search.pm` | 0.04 | Registers search actions: `search_next` (repeat last search in same direction, bound to `n`), `search_prev` (repeat in opposite direction, bound to `N`), and `search_set_pattern` (set new pattern and jump to first match, called from command entry after `/pattern` or `?pattern`). Returns an empty keymap hashref since `n` and `N` are added to the normal keymap directly in `VimBindings.pm`. | `register(\%ACTIONS)` -> returns empty hashref |

### 3.5 VimBuffer Adapters

| Module | File Path | VERSION | Purpose | Key Methods / API |
|--------|-----------|---------|---------|-------------------|
| `Gtk3::SourceEditor::VimBuffer` | `lib/Gtk3/SourceEditor/VimBuffer.pm` | 0.04 | Abstract base class defining the complete interface that all buffer backends must implement. Contains 27 abstract methods that `die "Unimplemented in ..."` when called on the base class. Also provides 3 predicate methods (`at_line_start`, `at_line_end`, `at_buffer_end`) implemented in terms of the abstract accessors. | See Section 8 for complete method reference |
| `Gtk3::SourceEditor::VimBuffer::Gtk3` | `lib/Gtk3/SourceEditor/VimBuffer/Gtk3.pm` | 0.04 | Production adapter that wraps a `Gtk3::SourceView::Buffer` and `Gtk3::SourceView::View` pair. All text operations are delegated to GTK text iterators and buffer methods. Implements search via `Gtk3::TextIter::forward_search`/`backward_search` with wrap-around. Provides `undo`/`redo` via the SourceBuffer's native undo manager. Constructor requires `buffer` and `view` options. Exposes `gtk_buffer()` and `gtk_view()` accessors. | `new(buffer => $buf, view => $view)`, `gtk_buffer()`, `gtk_view()`, plus all 27 abstract methods |
| `Gtk3::SourceEditor::VimBuffer::Test` | `lib/Gtk3/SourceEditor/VimBuffer/Test.pm` | 0.04 | Pure-Perl test adapter that stores the document as an array of line strings (without trailing newlines). Implements all VimBuffer methods without any external dependencies beyond the base class. Features snapshot-based undo (each editing operation saves a full copy of the lines array to `_undo_stack`). `redo()` is a stub (no-op) as noted in the source. Duplicates predicate methods for reliable inheritance when `t/lib` mock Gtk3 is loaded. | `new(text => $string)`, plus all 27 abstract methods, `redo()` is a stub |

---

## 4. Gtk3::SourceEditor -- Main Widget Factory

### 4.1 Constructor Options (Complete Reference)

The constructor `Gtk3::SourceEditor->new(%opts)` accepts the following options. Every option is carefully documented below with its type, default value, required status, and detailed behavior.

| Option | Type | Default | Required | Description |
|--------|------|---------|----------|-------------|
| `file` | `string` or `undef` | `undef` | No | Path to the file to load into the editor. If the file exists, its contents are read via `File::Slurper::read_text()` and displayed in the buffer. The filename is stored as a **scalar reference** (`\$self->{filename}`) so that ex-commands like `:w` (save) and `:e` (edit/open) can update it in place. The filename is also used by `Gtk3::SourceView::LanguageManager->guess_language()` to determine syntax highlighting when `force_language` is not set. If omitted or `undef`, the editor starts with an empty buffer and `guess_language()` will return `undef`, falling back to Perl highlighting. |
| `config_file` | `string` or `undef` | `undef` | No | Path to an INI-style configuration file (key = value format, see `config/editor.conf`). Parsed by `Config.pm` and merged as defaults -- explicit constructor options always take precedence. Supports boolean (`true/false/1/0`), integer, and quoted string values. See `Config.pm` for the full list of recognized keys. |
| `theme_file` | `string` | `'themes/default.xml'` | No | Path to a GtkSourceView XML theme file. The file is parsed by `ThemeManager::load()` which extracts foreground (`fg`) and background (`bg`) colors from the `<style name="text" ...>` element, injects a cursor color if the theme lacks a `<style name="cursor">` element, writes a temporary XML file, registers it with the `StyleSchemeManager`, and generates CSS for the mode_label and cmd_entry widgets. Four built-in themes are shipped in the `themes/` directory: `default.xml`, `theme_dark.xml`, `theme_light.xml`, and `theme_solarized.xml`. The ThemeManager will `die` if the specified file does not exist. |
| `font_family` | `string` | `'Monospace'` | No | Pango font family name for the editor text. Default is `'Monospace'`. Use any installed Pango font family (e.g., `'DejaVu Sans Mono'`, `'Courier New'`). Applied via `Pango::FontDescription->from_string()` and `modify_font()`. |
| `font_size` | `integer` | `0` | No | Font point size for the editor text. When set to `0` (the default), the system's default monospace font size is used -- the font string is simply the `font_family` with no size suffix. When set to a positive integer (e.g., `12`), the font is set to `"Monospace 12"` via `Pango::FontDescription->from_string()` and applied to the Gtk3::SourceView widget via `modify_font()`. |
| `wrap` | `boolean` | `1` (true) | No | Controls line wrapping in the text view. When true (the default), lines that exceed the widget width wrap at word boundaries -- the wrap mode is set to `'word'`. When false, long lines scroll horizontally without wrapping -- the wrap mode is set to `'none'`. Note: the option is tested with `defined $opts{wrap}` to distinguish between explicitly passing `0` and not passing the option at all, so `wrap => 0` is correctly honored. |
| `read_only` | `boolean` | `0` (false) | No | When set to a true value, the buffer is opened in read-only mode. The `is_readonly` flag is passed through to `VimBindings::add_vim_bindings()` which stores it in the context. When the user attempts to enter insert mode (via `i`, `a`, `I`, `A`, `o`, `O`) or replace mode (via `R`), the mode setter checks `is_readonly` and blocks the transition, displaying `"-- READ ONLY --"` in the mode label instead. The user can still navigate, search, and use ex-commands like `:q`. The modified flag is never set in read-only mode. |
| `vim_mode` | `boolean` | `1` (true) | No | Controls whether Vim-like modal keybindings are loaded. When set to `1` (the default), the full Vim emulation layer is attached: Normal, Insert, Replace, Visual (char/line/block), and Command modes are all available with their complete keybinding sets. A `VimBuffer::Gtk3` adapter is created and passed to `add_vim_bindings()`. When set to `0`, no Vim bindings are attached; the `Gtk3::SourceView` widget uses its native GTK keybindings (Ctrl+C/V/X for copy/paste/cut, Ctrl+Z for undo, Ctrl+A for select all, arrow keys, Tab for indentation, etc.). The mode label text is set to empty string and the command entry is hidden. |
| `show_line_numbers` | `boolean` | `1` (true) | No | Controls whether line numbers are displayed in the left gutter of the text view. Passed to `Gtk3::SourceView::View->set_show_line_numbers()`. |
| `highlight_current_line` | `boolean` | `1` (true) | No | Controls whether the background of the line containing the cursor is highlighted. Passed to `set_highlight_current_line()`. |
| `auto_indent` | `boolean` or `undef` | `undef` | No | When set, enables or disables automatic indentation of new lines to match the previous line's leading whitespace. Passed to `set_auto_indent()`. When `undef`, GTK's default behavior is used. |
| `tab_width` | `integer` or `undef` | `undef` | No | Width of a tab stop in character columns. Passed to `set_tab_width()`. When `undef`, GTK's default (8) is used. |
| `indent_width` | `integer` or `undef` | `undef` | No | Number of spaces per indent level for auto-indentation. Passed to `set_indent_width()`. |
| `insert_spaces_instead_of_tabs` | `boolean` | `0` (false) | No | When true, the Tab key inserts spaces instead of a literal tab character. Passed to `set_insert_spaces_instead_of_tabs()`. |
| `smart_home_end` | `boolean` or `undef` | `undef` | No | When enabled, Home/End first moves to the first/last non-whitespace character; a second press moves to the actual line start/end. Passed to `set_smart_home_end()`. |
| `show_right_margin` | `boolean` or `undef` | `undef` | No | Controls whether a vertical guide line is shown at the right margin position. Passed to `set_show_right_margin()`. |
| `right_margin_position` | `integer` or `undef` | `undef` | No | Column position of the right margin guide line. Only visible when `show_right_margin` is true. Passed to `set_right_margin_position()`. |
| `highlight_matching_brackets` | `boolean` | `1` (true) | No | Controls whether the bracket matching the one under the cursor is highlighted. Passed to `set_highlight_matching_brackets()`. |
| `show_line_marks` | `boolean` or `undef` | `undef` | No | Controls whether the line-marks gutter (for bookmarks, breakpoints, etc.) is displayed. Passed to `set_show_line_marks()`. |
| `block_cursor` | `boolean` | `0` (false) | No | Enables a Cairo-drawn block cursor instead of the default i-beam. The block cursor is drawn via the `draw` signal handler on the text view, using inverted theme colors (character drawn in background color). Only available when `vim_mode` is enabled. Can be toggled at runtime via `:set cursor=block` / `:set cursor=ibeam`. |
| `force_language` | `string` or `undef` | `undef` | No | Overrides automatic language detection for syntax highlighting. Accepts any language ID recognized by the system's GtkSourceView `LanguageManager` (e.g., `'perl'`, `'python'`, `'c'`, `'javascript'`, `'xml'`, `'json'`, `'sql'`, `'sh'`, `'markdown'`, `'makefile'`, `'html'`, `'css'`, `'ruby'`, `'java'`, etc.). If the specified language ID is not found, a warning is emitted and the editor falls back to auto-detection -> Perl. |
| `use_clipboard` | `boolean` | `0` (false) | No | When true, yank (copy) operations also place text on the system clipboard via `Gtk3::Clipboard`. When false (default), yanked text is stored only in the internal register. |
| `tab_string` | `string` | `"\t"` | No | The string inserted when the Tab key is pressed in insert mode. Default is a literal tab character. Can be set to spaces (e.g., `"    "` for 4 spaces). Passed through to the VimBindings layer. |
| `window` | `Gtk3::Window` or `Gtk3::Dialog` or `undef` | `undef` | No | A GTK window or dialog widget to which the editor belongs. When provided **together** with `on_close`, the window's `destroy` signal is connected to the `on_close` callback. Has no effect unless `on_close` is also specified. |
| `on_close` | `coderef` or `undef` | `undef` | No | A callback invoked when the window (specified by `window`) is destroyed. Receives the **complete buffer text** as its only argument. **Has no effect unless `window` is also specified.** |
| `keymap` | `hashref` or `undef` | `undef` | No | A hashref for customizing Vim keybindings. Structured by mode name, with each mode containing key-to-action-name mappings. Set a key's value to `undef` to remove it from defaults. Merged with built-in defaults by `_resolve_keymap()`. |
| `on_ready` | `coderef` or `undef` | `undef` | No | A callback invoked once after all VimBindings initialization is complete. Receives the context hash `$ctx` as its only argument, allowing embedding applications to query or modify editor state (e.g., load plugins, set custom marks). Errors are caught and warned. |
| `key_handler` | `coderef` or `undef` | `undef` | No | A pre-vim key interceptor connected to the text view's `key-press-event` signal **before** the Vim bindings handler. Must return `TRUE` to consume the event (preventing Vim from seeing it) or `FALSE` to pass it through to Vim. Useful for intercepting keys like Alt+Arrow that Vim does not handle. |

### 4.2 Internal UI Construction (`_build_ui`)

The `_build_ui(%opts)` method constructs the complete widget tree in the following order. This method is called automatically from `new()` and should not be called directly.

1. **Theme Loading** -- Calls `ThemeManager::load(file => $opts{theme_file})` to get `{ scheme, css_provider, fg, bg }`. Converts hex color strings to `GdkRGBA` objects via a local `$parse_hex` closure that manually sets red/green/blue/alpha components (for cross-version GTK3 compatibility).

2. **Main Container** -- Creates the root widget: `Gtk3::Box->new('vertical', 0)`.

3. **Language Detection** -- Obtains the `LanguageManager` default. If `force_language` is set, calls `$lm->get_language($self->{force_language})` with fallback to auto-detection + Perl. Otherwise, calls `$lm->guess_language($self->{filename}, undef)` with fallback to Perl.

4. **Text Buffer** -- Creates `Gtk3::SourceView::Buffer->new_with_language($lang)`. Enables syntax highlighting (`set_highlight_syntax(TRUE)`). If the file exists, reads its contents via `File::Slurper::read_text()` and sets the buffer text. Places the cursor at the start, clears the modified flag, and applies the style scheme.

5. **Text View** -- Creates `Gtk3::SourceView::View->new()`. Configures it with: line numbers (per `show_line_numbers`), current line highlighting (per `highlight_current_line`), auto-indent (per `auto_indent`), tab width (per `tab_width`), indent width (per `indent_width`), insert-spaces-instead-of-tabs (per `insert_spaces_instead_of_tabs`), smart home/end (per `smart_home_end`), right margin (per `show_right_margin` / `right_margin_position`), bracket matching (per `highlight_matching_brackets`), line marks (per `show_line_marks`), word wrap mode (based on `wrap` option), cursor visibility, and the Pango font (from `font_family` / `font_size`).

6. **Scrolled Window** -- Creates `Gtk3::ScrolledWindow->new()` with automatic scroll policy. Adds the text view. Packs into the main box with `expand=TRUE, fill=TRUE`.

7. **Bottom Bar** -- Creates a vertical `Gtk3::Box` containing (from top to bottom):
   - **Command Entry** (`Gtk3::Entry`) -- Hidden by default (`set_no_show_all(TRUE)`, `hide()`). Styled with theme fg/bg colors.
   - **Status Bar** (wrapped in `Gtk3::EventBox` for background color) -- A horizontal box containing:
     - **Mode Label** (`Gtk3::Label`, left-aligned) -- Shows `"-- NORMAL --"`. Styled with theme fg/bg.
     - **Position Label** (`Gtk3::Label`, right-aligned) -- Shows `"line:col"` (e.g. `"1:0"`). Updated via the buffer's `mark-set` signal on the `insert` mark.

8. **Key Handler** -- If `key_handler` is provided, connects it to the text view's `key-press-event` signal **before** the Vim bindings handler. The handler must return `TRUE` to consume the event or `FALSE` to pass it through.

9. **Position Tracking** -- Connects the buffer's `mark-set` signal to update the position label whenever the `insert` mark moves.

10. **VimBindings Wiring** -- If `vim_mode` is true:
   - Creates a `VimBuffer::Gtk3` adapter wrapping the buffer and view.
   - Calls `VimBindings::add_vim_bindings()` with the textview, mode_label, cmd_entry, pos_label, filename ref, read_only flag, tab_string, use_clipboard, theme colors, and optional keymap/on_ready.
   - Otherwise: hides the command entry and clears the mode label text.

11. **Window Close Hook** -- If both `window` and `on_close` are provided, connects the window's `destroy` signal to invoke `on_close` with the current buffer text.

### 4.3 Accessor Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `get_widget()` | `Gtk3::Box` | Returns the root `Gtk3::Box` widget containing the scrolled text view, command entry, and mode label. This is the widget that embedding applications should pack into their parent container (e.g., `$vbox->pack_start($editor->get_widget(), TRUE, TRUE, 0)`). |
| `get_text()` | `string` | Returns the entire buffer contents as a single string, including all line breaks. Internally calls `$self->{buffer}->get_text($start_iter, $end_iter, TRUE)`. This is typically used in the `on_close` callback or when saving programmatically. |
| `get_buffer()` | `Gtk3::SourceView::Buffer` | Returns the underlying `Gtk3::SourceView::Buffer` object, giving direct access to the GTK text buffer for advanced operations (signals, marks, tags, etc.). **Warning:** Operating on the buffer directly bypasses the Vim undo/redo stack and may interfere with the Vim bindings layer. |

---

## 5. VimBindings Dispatch System

### 5.1 Entry Point: `add_vim_bindings()`

```
add_vim_bindings($textview, $mode_label, $cmd_entry, $filename_ref, $is_readonly, %opts)
```

This is the main public function that wires the entire Vim emulation layer into a GTK application. It is called by `Gtk3::SourceEditor::_build_ui()` when `vim_mode` is enabled.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `$textview` | `Gtk3::SourceView` | Yes (production) | The text view widget. A `key-press-event` signal handler is connected to it. Can be `undef` in test contexts. |
| `$mode_label` | `Gtk3::Label` or `MockLabel` | Yes | Label widget showing current mode. Updated by `set_mode` closure. |
| `$cmd_entry` | `Gtk3::Entry` or `MockEntry` | Yes (production) | Command/search entry widget. A `key-press-event` signal handler is connected to it. Can be `undef`. |
| `$filename_ref` | `scalarref` | Yes | Reference to the filename string. Updated by `:w`, `:e` ex-commands. |
| `$is_readonly` | `boolean` | No (default 0) | Whether the buffer is read-only. Passed through to context. |
| `%opts` | hash | -- | Named options: |

**Named Options (`%opts`):**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vim_buffer` | `VimBuffer` instance | **Required** | The buffer adapter (Gtk3 or Test). The function `die`s if not provided. |
| `keymap` | `hashref` or `undef` | `undef` | Custom keymap overrides. Merged with defaults by `_resolve_keymap()`. |
| `ex_commands` | `hashref` or `undef` | `undef` | Custom ex-command overrides. Merged with defaults. |
| `page_size` | `integer` or `undef` | Auto-detected (20) | Lines per viewport page. If not provided and a textview is available, calculated from `get_visible_rect().{height} / 20`. Falls back to 20. |
| `shiftwidth` | `integer` | `4` | Number of columns per indent level. Used by `indent_lines()` actions. |

**What it does internally:**

1. Creates the context hash `$ctx` with all fields (see Section 5.2).
2. Calls `_init_utilities($ctx)` to set up `move_vert` and `after_move` closures.
3. Calls `_init_mode_setter($ctx)` to set up the `set_mode` closure.
4. Auto-detects `page_size` from GTK view if not provided.
5. Calls `_resolve_keymap()` to merge user keymaps with defaults.
6. Builds per-mode dispatch tables: `immediate`, `dispatch`, `prefixes`, `char_actions`, `ctrl_dispatch` -- for all 7 modes.
7. Connects `key-press-event` signal on `$textview` (if defined).
8. Connects `key-press-event` signal on `$cmd_entry` (if defined).
9. Sets initial mode to `'normal'` via `$ctx->{set_mode}->('normal')`.
10. Returns `1`.

### 5.2 Context Object (`$ctx`) -- Complete Reference

The context hash is the central state object passed to every action coderef. It is created once in `add_vim_bindings()` (or `create_test_context()`) and carries all runtime state.

| Key | Type | Mutability | Description |
|-----|------|------------|-------------|
| `vb` | `VimBuffer` instance | Reference (stable) | The buffer adapter (Gtk3 or Test). All text operations go through this. |
| `gtk_view` | `Gtk3::SourceView` or `undef` | Reference (stable) | The text view widget. Used for `scroll_to_mark`, `grab_focus`, `get_vadjustment`, `get_visible_rect`. `undef` in test contexts. |
| `mode_label` | `Gtk3::Label` or `MockLabel` | Reference (stable) | Status bar label. Updated by `set_mode` to show mode name. Used by actions to display error/info messages. |
| `cmd_entry` | `Gtk3::Entry` or `MockEntry` | Reference (stable) | Command/search entry widget. Shown/hidden by `set_mode`. Text is set when entering command mode. |
| `is_readonly` | `boolean` (0/1) | Immutable | Whether the buffer is read-only. Checked by `set_mode` to block insert/replace transitions. |
| `filename_ref` | `scalarref` | Mutable (deref) | Reference to the current filename string. Updated by `:w` (save-as) and `:e` (open) ex-commands. |
| `vim_mode` | `scalarref` | Mutable (deref) | Reference to the current mode string. Values: `'normal'`, `'insert'`, `'replace'`, `'visual'`, `'visual_line'`, `'visual_block'`, `'command'`. Read by signal handlers to route keys. |
| `cmd_buf` | `scalarref` | Mutable (deref) | Key accumulation buffer for multi-key commands. Cleared after each action execution. Used by `_dispatch()` for prefix accumulation (e.g., `g` waiting for `g` to complete `gg`). |
| `yank_buf` | `scalarref` | Mutable (deref) | The unnamed yank/paste register. Set by delete, yank, and change actions. Read by paste actions. |
| `page_size` | `integer` | Immutable | Lines per viewport page. Used by `page_up`, `page_down`, `scroll_half_up`, `scroll_half_down` actions. Default: 20. |
| `shiftwidth` | `integer` | Immutable | Number of columns per indent level. Used by `indent_right` and `indent_left` actions. Default: 4. |
| `marks` | `hashref` | Mutable | Named mark positions. Keys are single characters (a--z), values are `{ line => int, col => int }`. Set by `m` (set_mark), read by `` ` `` (jump_mark) and `'` (jump_mark_line). |
| `line_snapshots` | `hashref` | Mutable | Saved line text for `U` (line-undo). Keys are line numbers, values are line text strings. A snapshot is saved before the first editing operation on a line (navigation saves snapshot). Cleared after `U` restores the line. |
| `search_pattern` | `string` or `undef` | Mutable | Last search pattern. Set by `search_set_pattern` action (from `/pattern` or `?pattern`). Read by `search_next` (`n`) and `search_prev` (`N`). |
| `search_direction` | `'forward'` or `'backward'` or `undef` | Mutable | Last search direction. Set by `search_set_pattern`. Used by `n`/`N` to determine repeat direction. |
| `desired_col` | `integer` | Mutable | Virtual column for vertical movement. Set by horizontal movement actions (h, l, w, b, e, 0, $, ^). Used by `move_vert` to maintain the column position when moving between lines of different lengths. This implements Vim's "virtual cursor column" behavior. |
| `last_find` | `hashref` or `undef` | Mutable | Last f/F/t/T find-character motion for `;` and `,` repeat. Structure: `{ cmd => 'f'\|'F'\|'t'\|'T', char => string, count => int }`. Set by find-char actions, cleared when find fails. |
| `set_mode` | `coderef` | Stable | Closure to switch modes and update UI. Handles: updating `vim_mode` scalar, setting textview editable state, setting visual mode start/type, updating mode label text, showing/hiding cmd_entry, and grabbing focus. |
| `move_vert` | `coderef` | Stable | Closure for vertical movement with virtual column tracking. Moves cursor up/down by `$count` lines, uses `desired_col` for column position, clamps to buffer bounds. Calls `after_move` after moving. |
| `after_move` | `coderef` | Stable | Closure to scroll the GTK view after cursor movement. Calls `scroll_to_mark` on the buffer's insert mark to keep the cursor visible. No-op if `gtk_view` is `undef`. |
| `resolved_keymap` | `hashref` | Stable | The fully resolved keymap (defaults merged with user overrides). Keys are mode names, values are keymap hashrefs. Used by `:bindings` help dialog. |
| `ex_cmds` | `hashref` | Stable | The fully resolved ex-command map (defaults merged with user overrides). Keys are ex-command names (w, q, wq, e, r, s, bindings), values are action names. |
| `${mode}_immediate` | `hashref` | Stable | Per-mode immediate dispatch table. Keys are GDK key names, values are action coderefs. These keys bypass the accumulation buffer. Built by `_build_dispatch()` for keys listed in `_immediate`. |
| `${mode}_dispatch` | `hashref` | Stable | Per-mode dispatch table. Keys are GDK key names (including multi-key sequences like `dd`, `gg`), values are action coderefs. Used by `_dispatch()`. |
| `${mode}_prefixes` | `hashref` | Stable | Per-mode prefix set. Keys are all valid prefixes of multi-key sequences (derived from `_prefixes` list). Used by `_dispatch()` to determine if accumulated keys could still form a valid command. |
| `${mode}_char_actions` | `hashref` | Stable | Per-mode char-action map. Keys are GDK key names that need a following character (e.g., `r`, `f`, `m`), values are action names. Special key `_any` matches any single printable character (used in replace mode). |
| `${mode}_ctrl_dispatch` | `hashref` | Stable | Per-mode Ctrl-key dispatch table. Keys are `'Control-x'` strings (lowercase), values are action coderefs. |
| `visual_start` | `hashref` or `undef` | Mutable | Visual mode anchor position. `{ line => int, col => int }`. Set when entering visual mode. Cleared on exit. |
| `visual_type` | `'char'` or `'line'` or `'block'` | Mutable | Current visual mode selection type. Set by `set_mode` when entering visual/visual_line/visual_block. |
| `last_visual` | `hashref` or `undef` | Mutable | Saved last visual selection for `gv` (reselect). `{ type, start_line, start_col, end_line, end_col }`. Set by visual actions on yank/delete/change. |
| `block_insert_info` | `hashref` or `undef` | Mutable | Block-insert state for visual block mode `I`/`A` commands. `{ col, top, bottom, direction, inserted }`. Set when entering insert from visual block mode, consumed when exiting insert mode. |
| `_char_action_prefix` | `string` or `undef` | Mutable (internal) | Temporary state for pending char-action completion. Set by `_dispatch()` when a char_action key is recognized, cleared after the next key completes the action. |
| `_char_action_count` | `integer` or `undef` | Mutable (internal) | Numeric count from a char-action with prefix (e.g., `2f`). Set alongside `_char_action_prefix`. |

### 5.3 Key Dispatch Flow (Full Routing Diagram)

```
  GTK key-press-event fires
         |
         v
  +----------------------------------------------------------------+
  |  Signal handler in VimBindings::add_vim_bindings()             |
  |                                                                |
  |  $k = Gtk3::Gdk::keyval_name($e->keyval)                      |
  |                                                                |
  |  Is Ctrl held? ($e->state & 'control-mask')                    |
  |    +-- YES --> Build "Control-{lc($k)}"                        |
  |    |         |                                                 |
  |    |         | Current mode?                                   |
  |    |         +-- normal / visual / visual_line / visual_block  |
  |    |         |   +--> handle_ctrl_key($ctx, "Control-x")      |
  |    |         |         |                                      |
  |    |         |         +-- Found in ${mode}_ctrl_dispatch?    |
  |    |         |         |   +-- YES -> execute action, return TRUE  |
  |    |         |         +-- NO -> return FALSE (GTK handles)   |
  |    |         |                                                 |
  |    |         +-- insert / replace / command                    |
  |    |             +--> return FALSE (GTK handles Ctrl-C/V/Z)  |
  |    |                                                           |
  |    +-- NO ---> Route by current ${vim_mode}:                  |
  |              |                                                 |
  |              +-- 'normal'     -> handle_normal_mode($ctx, $k)  |
  |              +-- 'insert'     -> handle_insert_mode($ctx, $k)  |
  |              +-- 'visual'     -> handle_visual_mode($ctx, $k)  |
  |              +-- 'visual_line'-> handle_visual_mode($ctx, $k)  |
  |              +-- 'visual_block'-> handle_visual_mode($ctx,$k)  |
  |              +-- 'replace'    -> handle_replace_mode($ctx, $k) |
  +----------------------------------------------------------------+

  --- Normal mode handler ----------------------------------------

  handle_normal_mode($ctx, $k)
         |
         +-- $k in ${normal_immediate}?
         |   +-- YES -> clear cmd_buf, execute immediately, return TRUE
         |
         +-- _dispatch($ctx, normal_dispatch, normal_prefixes,
                       normal_char_actions, $k)
             |
             |  +-------- _dispatch() algorithm -----------------+
             |  |                                                |
             |  |  1. Append $k to $$cmd_buf                     |
             |  |  2. Purely numeric [1-9]\d*? -> keep accumulating|
             |  |  3. Exact match in dispatch table? -> execute    |
             |  |  4. Strip numeric prefix, match rest? -> execute |
             |  |  5. Strip numeric prefix, rest is prefix? -> wait|
             |  |  6. Strip numeric prefix, rest is char_action? |
             |  |     -> store _char_action_prefix, wait          |
             |  |  7. Known multi-key prefix? -> keep accumulating|
             |  |  8. _char_actions{_any} + single-char? -> execute|
             |  |  9. $key matches _char_actions? -> store prefix  |
             |  | 10. _char_action_prefix pending + single-char?  |
             |  |     -> execute with char as extra arg            |
             |  | 11. _char_action_prefix pending + multi-char?  |
             |  |     -> cancel prefix, clear buffer              |
             |  | 12. Nothing matched -> clear buffer, return TRUE |
             |  +------------------------------------------------+

  --- Insert mode handler ----------------------------------------

  handle_insert_mode($ctx, $k)
         |
         +-- _dispatch($ctx, insert_dispatch, insert_prefixes,
                       insert_char_actions, $k, FALSE)
             |
             +-- Only Escape is intercepted -> exit_to_normal
                 All other keys -> return FALSE (GTK inserts character)

  --- Visual mode handler ----------------------------------------

  handle_visual_mode($ctx, $k)
         |
         +-- _dispatch($ctx, visual_dispatch, visual_prefixes,
                       visual_char_actions, $k)
             |
             +-- Same algorithm as normal, but with visual keymap
                 (includes navigation + visual-specific actions)

  --- Replace mode handler ---------------------------------------

  handle_replace_mode($ctx, $k)
         |
         +-- $k in ${replace_immediate}? (Escape, BackSpace)
         |   +-- YES -> clear cmd_buf, execute immediately
         |
         +-- _dispatch($ctx, replace_dispatch, replace_prefixes,
                       replace_char_actions, $k)
             |
             +-- _any char_action catches all printable chars
                 -> do_replace_char($ctx, undef, $char)

  --- Command entry handler -------------------------------------

  handle_command_entry($ctx, $k)
         |
         +-- $k in ${command_immediate}? (Escape)
         |   +-- YES -> clear cmd_buf, execute exit_to_normal
         |
         +-- $k eq 'Return'?
         |   +-- Starts with '/'? -> forward search
         |   +-- Starts with '?'? -> backward search
         |   +-- Parse via parse_ex_command()
         |   |   +-- goto_line? -> execute directly
         |   |   +-- Known command? -> execute action
         |   |   +-- Unknown -> show error
         |   +-- Return to normal mode
         |
         +-- Return FALSE (GTK types character into entry)
```

### 5.4 Keymap Format Specification

Each mode's keymap is a hashref containing two types of entries:

**Regular key -> action name mappings:**
```perl
h           => 'move_left',       # single key
dd          => 'delete_line',     # multi-key sequence
gg          => 'file_start',      # multi-key sequence
```

**Special metadata keys (prefixed with `_`):**

| Metadata Key | Type | Description |
|-------------|------|-------------|
| `_immediate` | `arrayref` of GDK key names | Keys that bypass the accumulation buffer and execute immediately without waiting for a multi-key sequence to complete. Used for keys that must be responsive (e.g., arrow keys, Page_Up/Down in normal mode). These keys are built into a separate `${mode}_immediate` dispatch table for O(1) lookup. Example: `[qw(Up Down Page_Up Page_Down)]` in normal mode, `['Escape']` in insert mode, `['Escape', 'BackSpace']` in replace mode. |
| `_prefixes` | `arrayref` of GDK key names | Complete multi-key sequences that serve as prefixes for two-key commands. The dispatcher derives all valid partial prefixes from this list (e.g., `'greater'` from `'greatergreater'`). When the accumulated buffer matches any prefix, the dispatcher keeps accumulating. Example: `[qw(g d y c greater less)]` in normal mode. |
| `_char_actions` | `hashref` of key -> action name | Keys that need a following character to complete the action. When the accumulated buffer matches a char_action key, the dispatcher stores it in `_char_action_prefix` and waits for the next key. The next single-character key is passed as an `@extra` argument to the action. Special key `_any` matches any single printable character (used in replace mode). Example: `{ r => 'replace_char', m => 'set_mark', f => 'find_char_forward', _any => 'do_replace_char' }`. |
| `_ctrl` | `hashref` of single char -> action name | Ctrl-key combinations for the mode. Keys are lowercase single characters; the dispatcher prepends `'Control-'` to form the lookup key. Example: `{ u => 'scroll_half_up', d => 'scroll_half_down', f => 'page_down', b => 'page_up', y => 'scroll_line_up', e => 'scroll_line_down', r => 'redo' }`. |

### 5.5 Numeric Prefix Extraction Algorithm

The `_extract_count($buf)` function separates a numeric count from a command:

```perl
sub _extract_count {
    my ($buf) = @_;
    if ($buf =~ /^(\d+)(.+)$/) { return (0 + $1, $2); }
    return (undef, $buf);
}
```

**Behavior:**
- If the buffer starts with one or more digits followed by non-digit characters, returns `(numeric_value, remaining_string)`.
- If the buffer has no leading digits, returns `(undef, entire_buffer)`.
- Important: a leading `0` is treated as the `line_start` command, not a numeric prefix. This is handled in `_dispatch()` which only accumulates purely numeric buffers matching `^[1-9]\d*$` -- buffers starting with `0` fall through to the exact-match check, where `0 => 'line_start'` is found.

**Example extractions:**
- `"3j"` -> `(3, "j")` -- move down 3 lines
- `"10j"` -> `(10, "j")` -- move down 10 lines
- `"2dd"` -> `(2, "dd")` -- delete 2 lines
- `"j"` -> `(undef, "j")` -- move down 1 line (count defaults to 1 in action)
- `"0"` -> `(undef, "0")` -- line_start command

### 5.6 `_dispatch()` Algorithm (Step by Step)

The `_dispatch($ctx, $dispatch, $prefixes, $char_actions, $key, $on_miss)` function is the core key-routing engine. It is called by all mode handlers. Here is the exact step-by-step algorithm:

1. **Save original key** -- Stores `$key` in `$original_key` (needed for char_actions with multi-character GDK key names like `'grave'`, `'apostrophe'`).

2. **Append to buffer** -- `$$buf .= $key`.

3. **Purely numeric check** -- If `$$buf` matches `/^[1-9]\d*$/`, return `TRUE` (keep accumulating -- user is typing a count prefix like `"1"`, `"12"`, `"3"`).

4. **Exact match** -- If `$$buf` exists as a key in `$dispatch`, extract count via `_extract_count()`, clear buffer, execute the action handler with `($ctx, $count)`, return `TRUE`.

5. **Numeric prefix + exact match** -- If `$$buf` matches `/^(\d+)(.+)$/`, extract count and rest. If `$rest` exists in `$dispatch`, clear buffer, execute with count, return `TRUE`.

6. **Numeric prefix + known prefix** -- If the `$rest` (after stripping numeric prefix) exists in `$prefixes`, return `TRUE` (keep accumulating).

7. **Numeric prefix + char_action** -- If the `$rest` matches a key in `$char_actions`, store `$char_actions->{$rest}` in `$ctx->{_char_action_prefix}` and the count in `$ctx->{_char_action_count}`, return `TRUE` (wait for next key).

8. **Known multi-key prefix** -- If `$$buf` exists in `$prefixes`, return `TRUE` (keep accumulating).

9. **Char action `_any`** -- If `$char_actions` has a `_any` key AND `$original_key` is a single character, execute the `_any` action with `($ctx, undef, $original_key)`, clear buffer, return `TRUE`.

10. **Char action prefix match** -- If `$$buf` matches a key in `$char_actions`, store in `$ctx->{_char_action_prefix}`, return `TRUE` (wait for next key).

11. **Pending char action completion** -- If `$ctx->{_char_action_prefix}` is defined (set by step 7 or 10), retrieve the action name and count, clear the pending prefix, and:
    - If `$original_key` is a single character AND the action exists in `%ACTIONS`, execute with `($ctx, $count, $char)`, clear buffer, return `TRUE`.
    - Otherwise (multi-char key like `'Escape'`, `'Up'`), cancel the pending char action, clear buffer, return `TRUE`.

12. **Nothing matched** -- Clear buffer, return `$on_miss` (defaults to `TRUE`). For insert mode, `$on_miss` is `FALSE`, allowing GTK to handle the key natively.

### 5.7 Ctrl-Key Handling (`handle_ctrl_key`)

The `handle_ctrl_key($ctx, $key)` function dispatches Ctrl-key combinations. The `$key` parameter is already formatted as `'Control-x'` (lowercase).

**Behavior per mode:**
- **Normal mode**: Looks up `$key` in `$ctx->{normal_ctrl_dispatch}`. If found, executes the action (no count). If not found, returns `FALSE` (GTK handles natively).
- **Visual modes** (visual, visual_line, visual_block): Same as normal -- looks up in the visual mode's ctrl_dispatch table (which inherits from normal mode's `_ctrl` map).
- **Insert mode**: Not called -- the signal handler returns `FALSE` directly for all Ctrl keys in insert mode, letting GTK handle Ctrl+C/V/Z/A natively.
- **Replace mode**: Same as insert -- not called, returns `FALSE`.
- **Command mode**: Not applicable (command entry has its own signal handler).

**Default Ctrl-key bindings (normal mode):**

| Key | Action | Description |
|-----|--------|-------------|
| `Control-u` | `scroll_half_up` | Scroll up half a page (cursor moves with viewport) |
| `Control-d` | `scroll_half_down` | Scroll down half a page |
| `Control-f` | `page_down` | Full page forward |
| `Control-b` | `page_up` | Full page backward |
| `Control-y` | `scroll_line_up` | Scroll viewport up one line (cursor does NOT move) |
| `Control-e` | `scroll_line_down` | Scroll viewport down one line (cursor does NOT move) |
| `Control-r` | `redo` | Redo the last undone operation |

### 5.8 Keymap Resolution: How User Keymaps Merge with Defaults

The `_resolve_keymap($user_km, $user_ex)` function merges user-provided keymaps and ex-commands with the built-in defaults. The algorithm for each mode:

1. Start with the default keymap for that mode.
2. Copy all non-underscore-prefixed key->action mappings from the default.
3. Copy the default `_immediate`, `_prefixes`, `_char_actions`, and `_ctrl` values.
4. If the user provided a keymap for this mode:
   - For each key in the user's mode keymap:
     - If the key is `_immediate`, `_prefixes`, `_char_actions`, or `_ctrl`: **replace** the entire default value with the user's value.
     - If the user's value is `undef`: **delete** the key from the merged keymap (removes the binding).
     - Otherwise: **add or override** the key in the merged keymap.
5. For ex-commands: start with default ex-command map, then for each user ex-command:
   - If value is `undef`: delete the command.
   - Otherwise: add or override.

This means users can:
- **Remove** a binding: `{ normal => { j => undef } }`
- **Add** a binding: `{ normal => { ZZ => 'cmd_force_quit' } }`
- **Replace** all immediate keys: `{ normal => { _immediate => ['Escape'] } }`
- **Replace** all char actions: `{ normal => { _char_actions => { r => 'custom_replace' } } }`

### 5.9 Visual Mode Keymap Merging

The visual mode keymap is assembled in `VimBindings.pm` during module initialization:

1. `Visual::register(\%ACTIONS)` returns the **visual base keymap** -- contains visual-specific actions (yank, delete, change, swap ends, case toggle, etc.) plus prefixes (`g`, `greater`, `less`).
2. `Visual::navigation_keys()` returns the **navigation keymap** -- contains movement keys shared with normal mode (h, j, k, l, w, b, e, 0, $, ^, G, gg, Up, Down, Page_Up, Page_Down).
3. These are merged: `%visual_km = (%visual_base, %visual_nav)`.
4. Metadata keys are preserved from the visual base: `_immediate`, `_prefixes`, `_char_actions`.
5. **Ctrl-key inheritance**: `$visual_km{_ctrl} = $normal_km{_ctrl}` -- visual modes inherit all Ctrl-key bindings from normal mode.
6. **Visual line and block modes** are created as shallow copies: `%visual_line_km = %visual_km` and `%visual_block_km = %visual_km`.

This means all three visual modes share the same keymap (navigation + visual actions + normal ctrl keys).

### 5.10 Testing API

**`create_test_context(%opts)`** -- Creates a fully functional test context without requiring a running GTK display. Accepts:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vim_buffer` | `VimBuffer` instance | Auto-created `VimBuffer::Test` | The buffer adapter. If not provided, creates one with empty text. |
| `text` | `string` | `''` | Initial buffer text (passed to `VimBuffer::Test->new()` if `vim_buffer` not provided). |
| `mode_label` | `MockLabel` or custom | Auto-created `MockLabel` | Mode label mock. |
| `cmd_entry` | `MockEntry` or custom | Auto-created `MockEntry` | Command entry mock. |
| `is_readonly` | `boolean` | `0` | Read-only flag. |
| `filename_ref` | `scalarref` | `\"test.txt"` | Filename reference. |
| `page_size` | `integer` | `20` | Lines per page. |
| `shiftwidth` | `integer` | `4` | Indent width. |
| `keymap` | `hashref` | `undef` | Custom keymap overrides. |
| `ex_commands` | `hashref` | `undef` | Custom ex-command overrides. |

The function builds the same context hash and dispatch tables as `add_vim_bindings()`, but with `gtk_view => undef` and mock UI objects. The initial mode is set to `'normal'`.

**`simulate_keys($ctx, @keys)`** -- Feeds a sequence of GDK key names through the current mode handler. For each key:
- Ctrl-key combinations (`/^Control-(.+)$/`) in normal/visual modes are dispatched via `handle_ctrl_key()`.
- In normal mode: calls `handle_normal_mode()`.
- In insert mode: calls `handle_insert_mode()`.
- In visual modes: calls `handle_visual_mode()`.
- In replace mode: calls `handle_replace_mode()`.
- In command mode: `Return`/`Escape` call `handle_command_entry()`; other keys are appended to the cmd_entry text (simulating typing).

---

## 6. Mode System

### 6.1 All Modes

The editor supports 7 modes. Each mode has its own keymap, dispatch table, and behavior:

| Mode | String Identifier | Trigger Keys | Description |
|------|-------------------|-------------|-------------|
| **Normal** | `'normal'` | Default on startup; Escape from insert/visual/command | The primary navigation and command mode. The cursor is a block. All editing is done through command sequences (e.g., `dd` to delete a line, `x` to delete a character). The text view is set to non-editable. Navigation uses h/j/k/l, w/b/e, gg/G, f/F/t/T, and page keys. |
| **Insert** | `'insert'` | `i` (before cursor), `a` (after cursor), `I` (line start), `A` (line end), `o` (open below), `O` (open above), `c` commands (change) | Text insertion mode. The cursor becomes an I-beam. The text view is set to editable. Printable keystrokes are passed through to GTK for native text insertion. Only Escape is intercepted (exits to normal, moves cursor back one position). Ctrl keys (Ctrl+C/V/X/Z/A) pass through to GTK natively. |
| **Replace** | `'replace'` | `R` | Overtype mode. Similar to insert, but each printable character replaces the character under the cursor instead of inserting. The cursor advances one position after each replacement. BackSpace moves the cursor back one position. Escape exits to normal. Uses `_char_actions => { _any => 'do_replace_char' }` to intercept all printable characters. |
| **Visual (character-wise)** | `'visual'` | `v`, `gv` (reselect last) | Character-wise selection mode. Movement keys extend the selection from the anchor point (set when entering visual mode) to the cursor position. Operations (y/d/c) operate on the selection and return to normal mode. Case toggle (~) stays in visual mode. |
| **Visual Line** | `'visual_line'` | `V` | Line-wise selection mode. Entire lines between the anchor and cursor are selected. Operations (y/d/c) operate on whole lines. Shares the same keymap as visual mode. |
| **Visual Block** | `'visual_block'` | `Ctrl-V` | Block/rectangular selection mode. Selection spans a rectangular region defined by column and line ranges. Supports block-specific operations: `I` (insert at left edge), `A` (insert at right edge), yank/delete/change of rectangular region, and case toggle on the block. Shares the same keymap as visual mode. |
| **Command** | `'command'` | `:` (ex-command), `/` (forward search), `?` (backward search) | Command entry mode. The mode label is cleared, and the command entry widget is shown with the appropriate prompt (`:`, `/`, or `?`). The entry grabs keyboard focus. Typing fills the entry. Return executes the command. Escape returns to normal mode. After execution, the entry is hidden and focus returns to the text view. |

### 6.2 Mode Transition Rules

The following mode transitions are supported:

**From Normal:**
- -> Insert: `i`, `a`, `I`, `A`, `o`, `O`, `cc`, `cw`, `C` (via set_mode('insert'))
- -> Replace: `R` (via set_mode('replace'))
- -> Visual: `v` (via set_mode('visual'))
- -> Visual Line: `V` (via set_mode('visual_line'))
- -> Visual Block: Ctrl-V (via set_mode('visual_block'))
- -> Command: `:`, `/`, `?` (via set_mode('command'))

**From Insert/Replace:**
- -> Normal: `Escape` (via exit_to_normal action; cursor moves back one position unless at line start)

**From Visual/Visual Line/Visual Block:**
- -> Normal: `Escape` (via visual_exit action; clears selection)
- -> Insert: `c` (via visual_change action; deletes selection, enters insert)
- -> Command: `:` (via enter_command action; but visual selection is NOT cleared before entering command mode)

**From Command:**
- -> Normal: `Escape`, `Return` (after executing or cancelling the command)

**Read-only restrictions:**
- Insert and Replace mode transitions are blocked. The mode label shows `"-- READ ONLY --"` instead of changing mode.
- Normal, Visual, and Command modes work normally in read-only mode.

### 6.3 Mode-Specific UI Changes

When the mode changes (via the `set_mode` closure), the following UI updates occur:

1. **Text view editability**: In insert and replace modes (and NOT read-only), the text view is set to editable via `set_editable(TRUE)`. In all other modes, it is set to non-editable.

2. **Mode label text**: Updated to reflect the current mode:
   - Normal: `"-- NORMAL --"`
   - Insert: `"-- INSERT --"`
   - Replace: `"-- REPLACE --"`
   - Visual: `"-- VISUAL --"`
   - Visual Line: `"-- VISUAL LINE --"`
   - Visual Block: `"-- VISUAL BLOCK --"`
   - Command: Empty string (label is hidden by cmd_entry)
   - Read-only (blocked): `"-- READ ONLY --"`

3. **Command entry visibility**: In command mode, the entry is shown with the appropriate prompt (`:`, `/`, `?`) and grabs focus. In all other modes, the entry is hidden.

4. **Focus management**: In command mode, focus moves to the cmd_entry. In all other modes, focus moves to the textview (via `grab_focus()`).

5. **Visual mode state**: When entering any visual mode, `visual_start` is set to the current cursor position and `visual_type` is set to `'char'`, `'line'`, or `'block'`.

---

## 7. Action Registry -- Complete Reference

All actions are registered as coderefs in the `%ACTIONS` hash within `VimBindings.pm`. Actions receive `($ctx, $count, @extra)` and operate through `$ctx->{vb}`.

### 7.1 Normal.pm Actions

| Action Name | Key Binding(s) | Description |
|-------------|---------------|-------------|
| `move_left` | `h` | Move cursor left by `$count` (default 1) characters. Clamped to column 0. Updates `desired_col`. |
| `move_right` | `l` | Move cursor right by `$count` characters. Clamped to line end. Updates `desired_col`. |
| `move_up` | `k` | Move cursor up by `$count` lines. Uses `desired_col` for column position. |
| `move_down` | `j` | Move cursor down by `$count` lines. Uses `desired_col` for column position. |
| `page_up` | `Page_Up`, `Up`, `Ctrl-b` | Move cursor up by `$count` pages (default 1). |
| `page_down` | `Page_Down`, `Down`, `Ctrl-f` | Move cursor down by `$count` pages. |
| `scroll_half_up` | `Ctrl-u` | Scroll up half a page (cursor moves with viewport). |
| `scroll_half_down` | `Ctrl-d` | Scroll down half a page. |
| `scroll_line_up` | `Ctrl-y` | Scroll viewport up one line WITHOUT moving cursor. |
| `scroll_line_down` | `Ctrl-e` | Scroll viewport down one line WITHOUT moving cursor. |
| `redo` | `Ctrl-r` | Redo last undone operation (delegates to buffer backend). |
| `word_forward` | `w` | Move cursor forward to start of next word, `$count` times. |
| `word_backward` | `b` | Move cursor backward to start of previous word. |
| `word_end` | `e` | Move cursor to last character of current/next word. |
| `line_start` | `0` | Move cursor to column 0 of current line. |
| `line_end` | `$` (dollar) | Move cursor to last character of current line. |
| `first_nonblank` | `^` (caret) | Move cursor to first non-whitespace character of current line. |
| `file_start` | `gg` | Move cursor to line 1 (or line `$count` if given). |
| `file_end` | `G` | Move cursor to last line (or line `$count` if given). |
| `goto_line` | (via `:N`) | Move cursor to line `$count` (1-based). |
| `find_char_forward` | `f{char}` (char_action) | Move cursor forward to next occurrence of `{char}` on current line. |
| `find_char_backward` | `F{char}` (char_action) | Move cursor backward to previous occurrence of `{char}` on current line. |
| `till_char_forward` | `t{char}` (char_action) | Move cursor to one character BEFORE next `{char}` on current line. |
| `till_char_backward` | `T{char}` (char_action) | Move cursor to one character AFTER previous `{char}` on current line. |
| `find_repeat` | `;` | Repeat last f/F/t/T motion in the same direction. |
| `find_repeat_reverse` | `,` | Repeat last f/F/t/T motion in the opposite direction. |
| `percent_motion` | `%` | Jump to matching bracket `()`, `[]`, `{}`. Scans forward from cursor if not on a bracket. |
| `enter_insert` | `i` | Enter insert mode at current cursor position. |
| `enter_insert_after` | `a` | Move cursor right one position, then enter insert mode. |
| `enter_insert_eol` | `A` | Move cursor to end of line, then enter insert mode. |
| `enter_insert_bol` | `I` | Move cursor to first non-blank column, then enter insert mode. |
| `open_below` | `o` | Open `$count` new lines below current line, enter insert mode. |
| `open_above` | `O` | Open `$count` new lines above current line, enter insert mode. |
| `enter_replace_mode` | `R` | Enter replace mode. |
| `exit_to_normal` | `Escape` | Exit to normal mode (from insert). Moves cursor back one position. |
| `delete_char` | `x` | Delete `$count` characters at cursor. Deleted text goes to yank_buf. |
| `delete_line` | `dd` | Delete `$count` lines starting at cursor. Deleted text (with newlines) goes to yank_buf. Cursor placed at first non-blank of next line. |
| `delete_word` | `dw` | Delete from cursor to start of next word (`$count` times). Deleted text goes to yank_buf. |
| `change_line` | `cc` | Yank current line, delete its content (leaving empty line), enter insert mode at column 0. |
| `change_word` | `cw` | Delete from cursor to start of next word, enter insert mode. |
| `change_to_eol` | `C` | Delete from cursor to end of line, enter insert mode. |
| `replace_char` | `r{char}` (char_action) | Replace `$count` characters at cursor with `{char}`. |
| `join_lines` | `J` | Join current line with next `$count` lines. Space inserted between unless current line ends with whitespace or next starts with `)`. |
| `yank_line` | `yy` | Yank `$count` lines to yank_buf (without deleting). |
| `yank_word` | `yw` | Yank from cursor to start of next word to yank_buf. |
| `paste` | `p` | Paste yank_buf contents after cursor. Linewise paste inserts below current line; characterwise paste inserts after cursor. Repeats `$count` times. |
| `paste_before` | `P` | Paste yank_buf contents before cursor. Linewise paste inserts above current line. |
| `swap_word` | `xp` | Swap the word under cursor with yank_buf contents. Yanks current word, deletes it, pastes previous yank_buf. |
| `indent_right` | `>>` (greatergreater) | Indent `$count` lines right by `shiftwidth` spaces. |
| `indent_left` | `<<` (lessless) | Indent `$count` lines left by `shiftwidth` spaces. |
| `undo` | `u` | Undo `$count` operations (delegates to buffer backend). |
| `line_undo` | `U` | Restore current line to its state before any edits (line snapshot). |
| `enter_search` | `/` (slash) | Enter command mode with `/` prompt (forward search). |
| `enter_search_backward` | `?` (question) | Enter command mode with `?` prompt (backward search). |
| `enter_command` | `:` (colon) | Enter command mode with `:` prompt. |
| `set_mark` | `m{mark}` (char_action) | Set named mark at current position. |
| `jump_mark` | `` ` `` (grave) `{mark}` (char_action) | Jump to mark position (exact column). |
| `jump_mark_line` | `'` (apostrophe) `{mark}` (char_action) | Jump to mark position (first non-blank column of line). |
| `enter_visual` | `v` | Enter character-wise visual mode. |
| `enter_visual_line` | `V` | Enter line-wise visual mode. |
| `enter_visual_block` | `Ctrl-V` | Enter block-wise visual mode. |
| `reselect_visual` | `gv` | Reselect the last visual selection. |
| `search_next` | `n` (added to normal keymap in VimBindings.pm) | Repeat last search in same direction. |
| `search_prev` | `N` (added to normal keymap in VimBindings.pm) | Repeat last search in opposite direction. |

### 7.2 Insert.pm Actions

| Action Name | Key Binding(s) | Description |
|-------------|---------------|-------------|
| `exit_to_normal` | `Escape` | Exit insert mode, move cursor back one position unless at line start. If `block_insert_info` is set (from visual block I/A), replays the typed text on the remaining lines of the block (bottom to top to preserve positions). |
| `exit_replace_to_normal` | `Escape` | Exit replace mode, move cursor back one position unless at line start. |
| `do_replace_char` | Any printable char in replace mode (`_any` char_action) | Replace the character under the cursor with the given character and advance cursor right one position. |
| `replace_backspace` | `BackSpace` | Move cursor back one position in replace mode (does not restore character). |

### 7.3 Visual.pm Actions

| Action Name | Key Binding(s) | Description |
|-------------|---------------|-------------|
| `visual_exit` | `Escape` | Clear visual selection and return to normal mode. Deletes `visual_start` and `visual_type`. |
| `visual_yank` | `y` | Copy selected text to yank_buf (char/line/block depending on `visual_type`). Return to normal. |
| `visual_delete` | `d` | Copy selected text to yank_buf, then delete it. Return to normal. |
| `visual_change` | `c` | Copy selected text to yank_buf, delete it, enter insert mode. For line mode, inserts an empty line at deletion point. |
| `visual_swap_ends` | `o` | Swap cursor position with visual anchor (other end of selection). |
| `visual_toggle_case` | `~` (asciitilde) | Toggle case of all alphabetic characters in selection. Stays in visual mode (Vim behavior). |
| `visual_uppercase` | `U` | Convert all characters in selection to uppercase. |
| `visual_lowercase` | `u` | Convert all characters in selection to lowercase. Note: `u` is NOT undo in visual mode. |
| `visual_join` | `J` | Join all lines in the visual selection. Returns to normal. |
| `visual_format` | `gq` | Format/wrap all lines in the visual selection at 78-character width. Returns to normal. |
| `visual_block_insert_start` | `I` | (Block mode only) Insert at the left edge of the block on all selected lines. Enters insert mode. When exiting insert, the typed text is replayed on all other lines. |
| `visual_block_insert_end` | `A` | (Block mode only) Insert at the right edge of the block on all selected lines. Same replay mechanism as `I`. |
| `visual_indent_right` | `>>` (greatergreater) | Indent all lines in the visual selection right by `shiftwidth` spaces. Updates visual start and cursor positions. |
| `visual_indent_left` | `<<` (lessless) | Unindent all lines in the visual selection. |

### 7.4 Command.pm Actions (Ex-Commands)

| Action Name | Ex-Command | Description |
|-------------|-----------|-------------|
| `cmd_show_bindings` | `:bindings` | Opens a `Gtk3::MessageDialog` showing all key bindings for normal, insert, visual, and command modes. Returns to normal after dialog is closed. |
| `cmd_quit` | `:q` | Quit the application. If the buffer has been modified, displays an error: `"Error: No write since last change (use :q!)"`. |
| `cmd_force_quit` | `:q!` | Force quit the application without saving, regardless of modified state. |
| `cmd_save` | `:w [filename]` | Save the buffer to the current filename (or specified filename). Clears the modified flag. Updates the filename reference. |
| `cmd_save_quit` | `:wq` | Save the buffer, then quit. |
| `cmd_edit` | `:e filename` | Open a file in the editor. Clears the current buffer, reads the new file, resets the modified flag, and updates the filename reference. Displays error if file not found. |
| `cmd_read` | `:r filename` | Insert the contents of a file below the current line. |
| `cmd_substitute` | `:s/pat/repl/[g]`, `:%s/pat/repl/[g]`, `:1,5s/pat/repl/[g]` | Substitute a pattern with replacement text. Supports `%` range (whole file), numeric ranges, and `g` flag for global replacement. |
| `cmd_goto_line` | `:N` (bare line number) | Jump to line number N (1-based). |

### 7.5 Search.pm Actions

| Action Name | Key Binding(s) | Description |
|-------------|---------------|-------------|
| `search_next` | `n` | Repeat the last search in the same direction. Searches `$count` times. Displays `"Pattern not found: ..."` if no match. |
| `search_prev` | `N` | Repeat the last search in the opposite direction. If last direction was forward, searches backward, and vice versa. |
| `search_set_pattern` | (called from command entry) | Set a new search pattern and direction, then jump to the first match. `$extra` is `{ pattern => $str, direction => 'forward'\|'backward' }`. Clears the search pattern on empty input. Returns to normal mode. |

---

## 8. VimBuffer Interface

### 8.1 Complete Method Reference

The `VimBuffer` abstract base class defines 27 abstract methods and 3 predicate methods. All abstract methods `die "Unimplemented in Gtk3::SourceEditor::VimBuffer"` when called on the base class.

#### Cursor Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `cursor_line` | `()` | `int` | Return the 0-based line number where the cursor currently resides. |
| `cursor_col` | `()` | `int` | Return the 0-based column (character offset) within the cursor line. |
| `set_cursor` | `($line, $col)` | `void` | Move the cursor to the given position. Implementations should clamp the values to valid ranges (line >= 0, line < line_count, col >= 0, col <= line_length). |

#### Line Access Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `line_count` | `()` | `int` | Return the total number of lines in the buffer. An empty buffer has 1 line (an empty string). |
| `line_text` | `($line)` | `string` | Return the text of line `$line` (0-based) **without** a trailing newline. Returns `''` for out-of-range lines in the Test adapter. |
| `line_length` | `($line)` | `int` | Return the number of characters in line `$line` (excluding the newline). The Gtk3 adapter subtracts 1 from `get_chars_in_line` for non-last lines (since GTK includes the newline in its count). |

#### Text Access Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `text` | `()` | `string` | Return the entire buffer contents as a single string. Lines are joined with `\n`. The Test adapter does NOT add a trailing newline. |
| `get_range` | `($l1, $c1, $l2, $c2)` | `string` | Return the text between positions `($l1,$c1)` and `($l2,$c2)`. The range is inclusive at the start and exclusive at the end (like Perl `substr`). Cross-line ranges include `\n` between lines. |
| `char_at` | `($line, $col)` | `string` (single char or `''`) | Return the character at the given position. Returns `''` if out of bounds. |

#### Editing Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `insert_text` | `($text)` | `void` | Insert `$text` at the current cursor position and advance the cursor past the inserted text. Multi-line text (containing `\n`) splits the current line. Sets the modified flag. |
| `delete_range` | `($l1, $c1, $l2, $c2)` | `void` | Delete the text between positions and move the cursor to `($l1, $c1)`. Cross-line deletes merge the remaining parts of the first and last lines. Sets the modified flag. |
| `replace_char` | `($char)` | `void` | Replace the single character under the cursor with `$char`. The cursor stays at its current position. Does nothing if cursor is past end of line. Sets the modified flag. |
| `join_lines` | `($count)` | `void` | Join the current line with the next `$count` lines (like Vim's `J`). A single space is inserted between lines unless the current line ends with whitespace or the next line starts with `)`. Leading whitespace on the joined line is removed. Cursor is placed at the join point. |
| `indent_lines` | `($count, $width, $direction)` | `void` | Add (`$direction > 0`) or remove (`$direction < 0`) `$width` spaces at the beginning of `$count` lines starting from the current line. Cursor moves to first non-blank column of current line. |

#### Undo/Redo Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `undo` | `()` | `void` | Undo the last editing operation. In Gtk3 adapter, delegates to `Gtk3::SourceBuffer->undo()`. In Test adapter, pops the last snapshot from the undo stack and restores the entire lines array. |
| `redo` | `()` | `void` | Redo the last undone operation. In Gtk3 adapter, delegates to `Gtk3::SourceBuffer->redo()`. In Test adapter, this is a **stub** (no-op) -- redo is not yet implemented. |

#### Modified Flag Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `modified` | `()` | `boolean` | Return true if the buffer has been modified since the last save/checkpoint. |
| `set_modified` | `($bool)` | `void` | Set the modified flag. `set_modified(0)` marks as clean; `set_modified(1)` marks as dirty. |

#### Word Motion Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `word_forward` | `()` | `void` | Move cursor forward to the start of the next word. Skips the rest of the current word (non-whitespace), then any whitespace. Wraps to the beginning of the next line when reaching the end of the current line. |
| `word_end` | `()` | `void` | Move cursor to the last character of the current or next word. Advances at least one position, skips whitespace, skips non-whitespace, backs up one to land on the final character. |
| `word_backward` | `()` | `void` | Move cursor backward to the start of the previous (or current) word. Moves back one position first, then skips whitespace backward (crossing line boundaries), then skips backward through non-whitespace. |

#### Search Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `search_forward` | `($pattern, $start_line, $start_col)` | `{ line => int, col => int }` or `undef` | Search forward for `$pattern` starting from `($start_line, $start_col)`. Wraps around the buffer. Returns match position or `undef`. |
| `search_backward` | `($pattern, $start_line, $start_col)` | `{ line => int, col => int }` or `undef` | Search backward for `$pattern`. Wraps around the buffer. Returns match position or `undef`. |

#### Transform Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `transform_range` | `($l1, $c1, $l2, $c2, $how)` | `void` | Transform the text in the range. `$how` is `'upper'`, `'lower'`, or `'toggle'`. |
| `toggle_case` | `($l1, $c1, $l2, $c2)` | `void` | Toggle case of all alphabetic characters in the range. Delegates to `transform_range` with `'toggle'`. |

#### Utility Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `first_nonblank_col` | `($line)` | `int` | Return the column of the first non-whitespace character on line `$line`. Returns 0 if the line is empty or entirely whitespace. |

#### Predicate Methods (implemented in base class)

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `at_line_start` | `()` | `boolean` | True when `cursor_col == 0`. |
| `at_line_end` | `()` | `boolean` | True when `cursor_col >= line_length(cursor_line)`. |
| `at_buffer_end` | `()` | `boolean` | True when on the last line AND at the end of that line. |

### 8.2 VimBuffer::Gtk3 Adapter Specifics

The Gtk3 adapter wraps a `Gtk3::SourceView::Buffer` (`$self->{_buffer}`) and a `Gtk3::SourceView::View` (`$self->{_view}`).

**Key implementation details:**
- **Internal helper `_iter()`**: Returns a `Gtk3::TextIter` at the insert mark (cursor position) via `$self->{_buffer}->get_iter_at_mark($self->{_buffer}->get_insert)`.
- **Cursor**: `cursor_line` uses `_iter->get_line()`, `cursor_col` uses `_iter->get_line_offset()`. `set_cursor` clamps values and calls `$buf->place_cursor($iter)`.
- **Line access**: `line_text` gets two iterators at line start and line end (`forward_to_line_end`), returns text between them. `line_length` uses `get_chars_in_line` and subtracts 1 for the trailing newline (except on the last line).
- **Range operations**: Use `get_iter_at_line_offset` for start/end positions, then `get_text`, `delete_range`, or `insert` on the buffer.
- **Word motions**: `word_forward` uses `forward_word_end` then advances one more character. `word_end` uses `forward_word_end` then backs up one character. `word_backward` uses `backward_word_start`.
- **Search**: Uses `Gtk3::TextIter::forward_search` and `backward_search` with `'visible-only'` flag. Wraps around the buffer on miss.
- **Transform**: Gets range text, applies `uc`/`lc`/`tr/a-zA-Z/A-Za-z/`, deletes old text, inserts transformed text.
- **Undo/Redo**: Direct delegation to `$self->{_buffer}->undo()` and `$self->{_buffer}->redo()`.
- **Additional accessors**: `gtk_buffer()` returns the SourceBuffer, `gtk_view()` returns the SourceView.

### 8.3 VimBuffer::Test Adapter Specifics

The Test adapter stores the document as an array of line strings in `$self->{_lines}` (without trailing newlines). Other internal state: `_cur_line`, `_cur_col`, `_modified` (boolean), `_undo_stack` (array of snapshots).

**Key implementation details:**
- **Constructor**: Accepts `text => $string`. Splits on `/\n/` with `LIMIT = -1` so trailing newlines produce empty string elements. An empty result is replaced with `("")` to ensure at least one line.
- **Clamping**: `_clamp_cursor()` ensures `_cur_line` and `_cur_col` are within valid bounds after every `set_cursor` call.
- **Undo**: `_save_undo()` pushes a snapshot `{ _lines => [copy], _cur_line, _cur_col }` onto the undo stack before every `insert_text`, `delete_range`, `join_lines`, `indent_lines`, `replace_char`, and `transform_range` call. `undo()` pops and restores the snapshot. **`redo()` is a stub** -- it does nothing, as noted in the source comment: "Redo is not yet implemented in the test backend (requires A2: unified undo/redo)."
- **Word motions**: Pure-Perl implementations. `word_forward` skips non-whitespace then whitespace, crossing line boundaries. `word_end` moves forward at least one position, skips whitespace, skips non-whitespace, backs up one. `word_backward` moves back one position, skips whitespace backwards, skips non-whitespace backwards.
- **Search**: Pure-Perl regex search with wrapping. `search_forward` iterates lines from start position forward (modulo total lines), applying the regex to each line. `search_backward` iterates lines backward.
- **Join lines**: Joins `$count` lines starting from current. Trims leading whitespace from joined lines. Adds space separator unless current line ends with whitespace or joined line starts with `)`.
- **Indent**: Works from bottom to top. For indent-right, prepends spaces. For indent-left, removes up to `$width` leading spaces.
- **Predicate methods**: Duplicated from the base class "for reliable inheritance when t/lib mock Gtk3 is loaded first" (per source comment).

---

## 9. ThemeManager

### 9.1 Theme Loading Process

The `ThemeManager::load(file => $path)` function performs the following steps:

1. **Validate file**: Checks that the file exists; dies with `"Error: Theme file '$path' not found!"` if not.

2. **Extract scheme ID**: Derives the scheme ID from the filename (e.g., `"theme_dark"` from `"themes/theme_dark.xml"`). Dies if the filename doesn't match `/([^\/\\]+)\.xml$/`.

3. **Read and parse XML**: Reads the entire file content via `File::Slurper::read_text()`.

4. **Extract colors**: Uses regex to find the foreground and background colors from the `<style name="text" ...>` element: `foreground="([^"]+)"` and `background="([^"]+)"`. Defaults to `"#000000"` (fg) and `"#FFFFFF"` (bg) if not found.

5. **Inject cursor style**: If the XML content does not already contain a `<style name="cursor"` element, one is injected immediately after the `<style name="text">` element: `<style name="cursor" foreground="$fg"/>`. This ensures the cursor color matches the foreground color.

6. **Register scheme**: Writes the (possibly modified) XML to a temporary file via `File::Temp::tempfile()`. Gets the temporary file's directory and prepends it to the `Gtk3::SourceView::StyleSchemeManager`'s search path. Retrieves the scheme via `$manager->get_scheme($scheme_id)`. Dies if the scheme cannot be loaded.

7. **Generate CSS**: Creates CSS for the `mode_label` and `cmd_entry` widgets using the extracted foreground and background colors. The CSS sets `color`, `background-color`, `background-image: none`, `padding`, and `border` properties. The CSS is loaded into a `Gtk3::CssProvider`.

8. **Return**: Returns a hashref `{ scheme => $scheme, css_provider => $provider, fg => $fg, bg => $bg }`.

### 9.2 CSS Generation

The dynamically generated CSS targets two widget IDs:

```css
GtkLabel#mode_label {
    color: $fg;
    background-color: $bg;
    background-image: none;
    padding: 4px 6px;
}
GtkEntry#cmd_entry {
    color: $fg;
    background-color: $bg;
    background-image: none;
    border-image: none;
    box-shadow: none;
    border: 1px solid $fg;
}
```

Note: In the current implementation, the CSS is generated but not explicitly applied to the widgets via `Gtk3::StyleContext`. Instead, the `SourceEditor.pm` uses `override_color()` and `override_background_color()` directly on the widgets. The CSS provider is returned but its application is not wired in the current code.

### 9.3 Built-in Themes

| Theme File | Description |
|------------|-------------|
| `themes/default.xml` | The default theme. Used when no `theme_file` option is specified. |
| `themes/theme_dark.xml` | Dark background theme for low-light environments. |
| `themes/theme_light.xml` | Light background theme. |
| `themes/theme_solarized.xml` | Solarized color scheme (popular in terminal emulators). |

### 9.4 Integration with GtkSourceView::StyleSchemeManager

The ThemeManager interacts with the `Gtk3::SourceView::StyleSchemeManager` singleton via:

1. `$manager = Gtk3::SourceView::StyleSchemeManager->get_default()` -- gets the default manager.
2. `$manager->prepend_search_path($theme_dir)` -- adds the temporary directory containing the (possibly modified) theme XML to the front of the search path, ensuring the custom theme takes precedence over system themes.
3. `$scheme = $manager->get_scheme($scheme_id)` -- retrieves the loaded scheme object.
4. `$buffer->set_style_scheme($scheme)` -- applies the scheme to the text buffer (called in `SourceEditor::_build_ui`).

---

## 10. CLI Scripts

### 10.1 `source-editor` -- Standalone Editor

**File:** `script/source-editor`

A standalone GTK application that creates a window with an embedded editor widget. Uses `Getopt::Long` for CLI argument parsing.

| CLI Option | Type | Default | Description |
|-----------|------|---------|-------------|
| `--theme=s` | string | `'default'` | Theme name (mapped to file: `"themes/theme_$name.xml"` or `"themes/default.xml"` for `'default'`). |
| `--read-only` | boolean flag | off | Open file in read-only mode. |
| `--font-size=i` | integer | `0` | Font point size (0 = system default). |
| `--wrap!` | boolean (negatable) | on | Enable/disable line wrapping (`--wrap` or `--no-wrap`). |
| `(positional)` | string | `''` | File path to open (first non-option argument). |

**Behavior:**
1. Parses CLI arguments.
2. Resolves theme file path.
3. Creates a `Gtk3::Window` (toplevel, 800x600, title = filename or "New File").
4. Creates a `Gtk3::SourceEditor` instance with all options.
5. Packs the editor widget into the window.
6. Sets up an `on_close` callback that prints `"--- WINDOW CLOSED ---"` and the captured text.
7. Connects `delete_event` to `Gtk3->main_quit()`.
8. Shows all widgets and enters the GTK main loop.

### 10.2 `source-dialog-editor` -- Dialog-Based Editor

**File:** `script/source-dialog-editor`

A GTK application that embeds the editor in a `Gtk3::Dialog` instead of a standalone window. Provides "Cancel" and "Save" buttons.

| CLI Option | Type | Default | Description |
|-----------|------|---------|-------------|
| `--theme=s` | string | `'default'` | Theme name (same resolution as `source-editor`). |
| `--colors=s` | string | `''` | Direct path to a custom theme XML file. Takes precedence over `--theme`. |
| `--read-only` | boolean flag | off | Open file in read-only mode. |
| `--font-size=i` | integer | `0` | Font point size. |
| `--wrap!` | boolean (negatable) | on | Enable/disable line wrapping. |
| `(positional)` | string | `''` | File path to open. |

**Behavior:**
1. Parses CLI arguments. The `--colors` option takes precedence over `--theme`.
2. Creates a main `Gtk3::Window` (hidden, used as dialog parent).
3. Creates a `Gtk3::Dialog` with title "Editor Preview", parent window, `destroy-with-parent` flag, and a "Cancel" button with `'cancel'` response.
4. Adds a "Save" button with `'ok'` response and sets it as the default response.
5. Creates a `Gtk3::SourceEditor` instance (does NOT pass `on_close` since the dialog handles responses).
6. Packs the editor widget into the dialog's content area.
7. Connects the dialog's `response` signal: on `'ok'`, prints status, content preview, and length; on `'cancel'`, prints cancelled status. Destroys dialog and quits main loop.
8. Shows the dialog and enters the GTK main loop.

---

## 11. Testing Infrastructure

### 11.1 Mock GTK Stubs

The `t/lib/` directory contains minimal stub modules that satisfy `use` statements without loading the real GTK libraries. This enables the entire test suite to run headless (without a display server).

| File | Package | Purpose | Key Stubs |
|------|---------|---------|-----------|
| `t/lib/Gtk3.pm` | `Gtk3` | Main GTK stub. Provides constructors and method stubs for all GTK widget types used by the module. | `new()`, `signal_connect()`, `show()`, `hide()`, `set_text()`, `get_text()`, `set_editable()`, `grab_focus()`, `pack_start()`, `pack_end()`, `set_policy()`, `add()`, `override_color()`, `override_background_color()`, `scroll_to_mark()`, `modify_font()`, `insert()`, `set_show_line_numbers()`, `set_highlight_current_line()`, `set_auto_indent()`, `set_wrap_mode()`, `set_highlight_syntax()`, `set_style_scheme()`, `place_cursor()`, `get_visible_rect()` (returns `{height => 400}`), `get_line_count()` (returns 1), `main_quit()`, `new_with_language()`, `get_default()` (LanguageManager), `guess_language()` (returns undef), `get_language()` (returns undef) |
| `t/lib/Gtk3/Gdk.pm` | `Gtk3::Gdk` | GDK stub. Provides `keyval_name()` mapping common GDK keyval integers to key name strings, and `RGBA` constructor. | `keyval_name($int)` -> string (maps 65361->Left, 65307->Escape, etc.; returns the argument directly if not a number), `RGBA->new()` |
| `t/lib/Gtk3/MessageDialog.pm` | `Gtk3::MessageDialog` | Message dialog stub. Used by the `:bindings` help command. | `new()`, `set_title()`, `set_default_size()`, `get_message_area()`, `get_children()`, `run()` (returns 'ok'), `destroy()` |
| `t/lib/Glib.pm` | `Glib` | GLib stub. Provides TRUE/FALSE constants and an `import()` method for `use Glib qw(TRUE FALSE)`. | `TRUE` (1), `FALSE` (0), `import()` |

### 11.2 Mock Objects in VimBindings

In addition to `t/lib/`, the `VimBindings.pm` module defines two lightweight mock classes inline:

**`Gtk3::SourceEditor::VimBindings::MockLabel`:**
- Stores text in `$self->{_text}`.
- Methods: `new()`, `set_text($text)`, `get_text()`.

**`Gtk3::SourceEditor::VimBindings::MockEntry`:**
- Stores text and cursor position in `$self->{_text}` and `$self->{_pos}`.
- Methods: `new()`, `set_text($text)`, `get_text()`, `show()`, `hide()`, `grab_focus()`, `set_position($pos)`.

### 11.3 Test Context Creation

The `create_test_context(%opts)` function (described in Section 5.10) creates a fully initialized context with:
- A `VimBuffer::Test` instance (or custom `vim_buffer`)
- `MockLabel` and `MockEntry` (or custom mocks)
- All dispatch tables built identically to production
- `vim_mode` set to `'normal'`

This means tests exercise the exact same dispatch logic as production code, just with a different buffer backend.

### 11.4 Key Simulation

The `simulate_keys($ctx, @keys)` function feeds GDK key name strings through the mode handlers. For example:

```perl
simulate_keys($ctx, 'd', 'd');    # delete line
simulate_keys($ctx, '2', 'j');    # move down 2 lines
simulate_keys($ctx, ':', 'w');    # enter command mode, type 'w' (simulated in cmd_entry)
simulate_keys($ctx, 'Control-d'); # scroll half page down
```

### 11.5 Test File Inventory

| File | Coverage Description |
|------|---------------------|
| `t/vim_dispatch.t` | Core dispatch logic: mode transitions (normal->insert->normal, normal->command), navigation (h/j/k/l, 0, G, gg, w, b, e), numeric prefixes (3j, 5x, 2dd, 10j, 3p, 2o), insert mode entry/exit, editing (x, dd, yy, p, dw, u, 3u), multi-key prefix accumulation (g+g, d+d, unknown key reset), read-only mode blocking, ex-command parsing. |
| `t/vim_editing.t` | Editing operations: dd, cc, cw, C, J (join lines), >> (indent right), << (indent left), xp (swap word), boundary conditions (empty lines, single line, end of buffer). |
| `t/vim_ex_commands.t` | Ex-command parser and execution: `:w` (save), `:q` (quit with modified check), `:q!` (force quit), `:wq` (save and quit), `:e` (open file), `:r` (read file), `:s` and `:%s` (substitute with range and global flag), bare line-number goto (`:42`), empty command handling. |
| `t/vim_visual.t` | Visual mode: character-wise yank/delete/change, line-wise yank/delete, block-wise operations, indent (>>/<<), case toggle (~), uppercase (U), lowercase (u), join (J), reselect (gv). |
| `t/vim_search.t` | Search: forward search (/pattern), backward search (?pattern), n (repeat same direction), N (repeat opposite direction), wrapping around buffer, pattern not found handling. |
| `t/vim_replace.t` | Replace mode: entry via R, character replacement, cursor advancement, BackSpace, exit via Escape, cursor backup on exit. |
| `t/vim_find_char.t` | Find-character motions: f/F/t/T with various characters, ; (repeat), , (reverse repeat), count prefixes (2fa), failure handling (character not found), multi-step sequences. |
| `t/vim_marks.t` | Marks: set mark (m), jump to mark (`), jump to mark first-non-blank ('), mark persistence across operations, invalid mark handling. |
| `t/vim_ctrl_keys.t` | Ctrl-key handling: Ctrl-u/d/f/b/y/e/r in normal mode, Ctrl keys in visual mode, Ctrl key passthrough in insert mode. |
| `t/vim_buffer.t` | VimBuffer::Test adapter: cursor positioning, line access, insert/delete operations, word motions, text retrieval, undo/redo. |
| `t/vim_buffer_abstract.t` | Abstract interface contract: verifies that all abstract methods die with "Unimplemented in ..." when called on the base class. |

---

## 12. Vim Mode Toggle

The editor supports disabling Vim bindings entirely via the `vim_mode` constructor option:

```perl
my $editor = Gtk3::SourceEditor->new(
    file     => 'my_script.pl',
    vim_mode => 0,    # default is 1
);
```

### What happens when `vim_mode => 0`:

1. **No VimBindings attached** -- The `if ($self->{vim_mode})` block in `_build_ui()` is skipped entirely. `VimBuffer::Gtk3` is not created. `VimBindings::add_vim_bindings()` is not called. No `key-press-event` signal handler is connected.

2. **Native GTK keybindings preserved** -- The `Gtk3::SourceView` widget uses its built-in GTK text editing keybindings:
   - `Ctrl+C` -- Copy
   - `Ctrl+V` -- Paste
   - `Ctrl+X` -- Cut
   - `Ctrl+Z` -- Undo
   - `Ctrl+A` -- Select all
   - `Ctrl+Y` -- Redo (GTK default)
   - Arrow keys -- Navigation
   - `Tab` / `Shift+Tab` -- Indent/unindent
   - `Home` / `End` -- Line start/end
   - `Page Up` / `Page Down` -- Scroll
   - Standard text selection with mouse and Shift+arrow keys

3. **UI elements hidden/cleared**:
   - The command entry (`cmd_entry`) is hidden: `$self->{cmd_entry}->hide()`.
   - The mode label text is cleared: `$self->{mode_label}->set_text('')`.
   - The bottom bar container still exists in the widget tree but is effectively invisible.

4. **Text view is always editable** -- Since there is no mode system to control editability, the text view remains in its default editable state. The `read_only` option is not wired when `vim_mode` is 0 (the VimBuffer adapter is not created).

5. **No ex-commands** -- The colon command entry is non-functional.

### What is NOT disabled:

- Syntax highlighting still works (SourceBuffer with language).
- Theme loading and styling still work.
- Line numbers, current line highlighting, and auto-indent still work.
- File loading still works.
- The `on_close` callback still works (if `window` is provided).
- The `get_widget()`, `get_text()`, and `get_buffer()` accessors still work.

---

## 13. File Tree

```
P5-Gtk3-SourceEditor/
+-- Build.PL                              # Module::Build config: deps, scripts, metadata
+-- MANIFEST                              # Distribution file list
+-- README.md                             # Project overview, installation, usage examples
+-- doc/
|   +-- architecture.md                   # THIS DOCUMENT -- comprehensive architecture reference
|   +-- bindings.md                       # Complete Vim keybindings reference card
|   +-- improvement-suggestions.md        # Feature roadmap with 20+ items and status tracking
+-- lib/
|   +-- Gtk3/
|       +-- SourceEditor.pm               # Main widget factory -- new(), _build_ui(), accessors
|       +-- SourceEditor/
|           +-- ThemeManager.pm           # XML theme parser, cursor injection, CSS generation
|           +-- VimBindings.pm            # Central dispatcher: signal routing, _dispatch(), context
|           +-- VimBindings/
|               +-- Normal.pm             # Normal mode: 45+ actions (nav, edit, yank, indent, marks)
|               +-- Insert.pm             # Insert/Replace mode: exit, replace_char, block-insert replay
|               +-- Visual.pm             # Visual mode: yank/delete/change/case/indent/block ops
|               +-- Command.pm            # Ex-commands: :w/:q/:e/:r/:s parser and action handlers
|               +-- Search.pm             # Search actions: /, ?, n, N
+-- lib/Gtk3/SourceEditor/
|   +-- VimBuffer/
|       +-- VimBuffer.pm                  # Abstract interface: 27 methods + 3 predicates
|       +-- Gtk3.pm                       # Production adapter: wraps Gtk3::SourceBuffer/View
|       +-- Test.pm                       # Test adapter: pure-Perl, array-of-lines, snapshot undo
+-- script/
|   +-- source-editor                     # Standalone CLI editor (window-based)
|   +-- source-dialog-editor              # Dialog-based CLI editor with Save/Cancel buttons
+-- t/
|   +-- lib/                              # Mock GTK stubs for headless testing
|   |   +-- Glib.pm                       # TRUE/FALSE constants, import() for 'use Glib'
|   |   +-- Gtk3.pm                       # Comprehensive GTK widget stub (Box, Window, Entry, etc.)
|   |   +-- Gtk3/
|   |       +-- Gdk.pm                    # keyval_name() mapping, RGBA constructor
|   |       +-- MessageDialog.pm          # Dialog stub for :bindings help
|   +-- vim_buffer.t                      # VimBuffer::Test adapter unit tests
|   +-- vim_buffer_abstract.t             # Abstract interface contract tests (methods die)
|   +-- vim_dispatch.t                    # Core dispatch, modes, numeric prefixes, char actions
|   +-- vim_editing.t                     # Editing: dd/cc/cw/C/J/>>/<</xp, boundaries
|   +-- vim_ex_commands.t                 # Ex-commands: :w/:q/:wq/:e/:r/:s/:%s/:N
|   +-- vim_visual.t                      # Visual mode: char/line/block yank/delete/change
|   +-- vim_search.t                      # Search: /pattern, ?pattern, n, N, wrapping
|   +-- vim_replace.t                     # Replace mode: entry/exit, char overwrite, backspace
|   +-- vim_find_char.t                   # Find-char motions: f/F/t/T, ;/, repeat
|   +-- vim_marks.t                       # Marks: set/jump/line-jump, persistence
|   +-- vim_ctrl_keys.t                   # Ctrl-key handling: u/d/f/b/y/e/r per mode
+-- themes/
    +-- default.xml                       # Default theme (used when no theme_file specified)
    +-- theme_dark.xml                    # Dark background theme
    +-- theme_light.xml                   # Light background theme
    +-- theme_solarized.xml               # Solarized color scheme
```

---

## 14. Dependencies

### 14.1 Runtime Dependencies (from Build.PL `requires`)

| Module | Minimum Version | Description |
|--------|----------------|-------------|
| `perl` | `5.020` | Perl 5.20+ required (for postfix dereference, 24-bit Unicode, etc.) |
| `Gtk3` | `0` | Perl bindings for GTK+ 3. Provides Window, Box, Entry, Label, ScrolledWindow, EventBox, Signal handling. |
| `Glib` | `0` | Perl bindings for GLib. Provides TRUE/FALSE constants used by GTK methods. |
| `Pango` | `0` | Perl bindings for Pango text layout. Used for `Pango::FontDescription->from_string()` to set the editor font. |
| `File::Slurper` | `0` | Efficient file reading/writing. Used to read theme XML files and editor file contents via `read_text()`. |
| `Encode` | `0` | Character encoding. Used by ThemeManager to encode UTF-8 CSS bytes before loading into `Gtk3::CssProvider`. |

### 14.2 Build/Test Dependencies (from Build.PL `build_requires`)

| Module | Minimum Version | Description |
|--------|----------------|-------------|
| `Test::More` | `0` | Core testing framework. Provides `ok()`, `is()`, `subtest()`, `done_testing()`, etc. |
| `Test::Exception` | `0` | Testing exception throwing. Used for testing that abstract methods die correctly. |

### 14.3 Recommended Dependencies (from Build.PL `recommends`)

| Module | Minimum Version | Description |
|--------|----------------|-------------|
| `Getopt::Long` | `0` | CLI argument parsing. Used by `script/source-editor` and `script/source-dialog-editor`. |

### 14.4 Indirect Dependencies (used by sub-modules at runtime)

These are not declared in Build.PL but are used by the GTK adapter and CLI scripts:

| Module | Description |
|--------|-------------|
| `Gtk3::SourceView` | GtkSourceView 3 bindings. Provides SourceBuffer, SourceView, LanguageManager, StyleSchemeManager. The main module `use`s this but it's not in Build.PL -- likely assumed to be installed alongside Gtk3. |
| `File::Temp` | Temporary file creation. Used by ThemeManager to write modified theme XML. Core module (since Perl 5.6.1). |
| `File::Basename` | File path manipulation. Used by ThemeManager to extract directory from temp file path. Core module. |

---

*End of architecture document. Last updated for version 0.04.*
