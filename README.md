# Gtk3::SourceEditor

A modular, embeddable Vim-like text editor widget for Gtk3 Perl applications.
Built on Gtk3::SourceView with full modal editing, plugin system, theme support,
syntax highlighting, and configuration file support. Version 0.04.

## Highlights

- **Drop-in widget** -- embed a full-featured editor with a single `new()` call
- **6 editing modes** -- Normal, Insert, Replace, Visual (char/line/block), Command
- **210+ headless tests** -- no GTK display server needed; pure Perl test backend
- **GUI-decoupled architecture** -- all editing logic operates through the abstract
  `VimBuffer` interface, enabling headless testing and potential reuse with other
  widget toolkits
- **Plugin system** -- load `.pm` plugins at runtime with action and ex-command
  registration, hot-reload, and per-plugin configuration
- **Config file support** -- `key = value` format with boolean/integer conversion,
  comments, and CLI override precedence
- **Themed UI** -- GtkSourceView XML themes drive both the editor and the
  status bar/command entry styling, with four built-in themes
- **Block cursor** -- optional Cairo-drawn block cursor with theme-correct colors

## Quick Start

```perl
use Gtk3 -init;
use Gtk3::SourceEditor;

my $window = Gtk3::Window->new('toplevel');
$window->signal_connect(delete_event => sub { Gtk3->main_quit; });

my $editor = Gtk3::SourceEditor->new(
    file       => 'my_script.pl',
    theme_file => 'themes/theme_dark.xml',
    font_size  => 14,
    window     => $window,
    on_close   => sub {
        my $text = shift;
        print "Final text: $text";
    },
);

$window->add($editor->get_widget);
$window->show_all;
Gtk3->main;
```

## Standalone Scripts

Three ready-to-use scripts ship with the distribution:

| Script | Description |
|--------|-------------|
| `source-editor` | Full editor window with CLI options |
| `source-dialog-editor` | Editor embedded in a Gtk3::Dialog with Alt+Arrow/F11/F12 |
| `source-editor-cursor-demo` | Demonstrates `on_ready` callback and block cursor |

```bash
# Launch with a dark theme and block cursor
perl -Ilib script/source-editor -t dark -b myfile.pl

# Use a config file (CLI options override config values)
perl -Ilib script/source-editor -C editor.conf myfile.pl

# Dialog editor, minimal chrome
perl -Ilib script/source-dialog-editor -m myfile.pl
```

CLI options common to both `source-editor` and `source-dialog-editor`:

```
-C, --config=FILE            Load settings from a configuration file
-t, --theme=NAME             Theme name (default, dark, light, solarized)
-c, --colors=FILE            Path to a custom theme XML file
-r, --read-only              Open file in read-only mode
-f, --font-size=N            Set font point size
-w, --[no-]wrap              Enable/disable word wrap (default: on)
-n, --no-line-numbers        Hide line number gutter
-h, --help                   Show help message
```

Options unique to `source-editor`: `-b/--cursor-block`, `-H/--[no-]highlight-current-line`

Options unique to `source-dialog-editor`: `-b/--no-border`, `-B/--no-buttons`, `-m/--minimal`

## Architecture

```
+-------------------+       +----------------------------+       +-------------------+
| SourceEditor.pm   | uses  | ThemeManager.pm            |       | Config.pm         |
| (widget factory)  +------>| (XML theme → CSS + colors) |       | (key=value parser)|
+--------+----------+       +----------------------------+       +-------------------+
         | uses                                                               ^
         v                                                                    |
+-------------------+       +----------------------------+       +-----------+---+
| VimBindings.pm    | uses  | VimBindings/               |       | VimBuffer/ |   |
| (dispatch + %ACTIONS)|   |  Normal.pm   Insert.pm     |       |  Gtk3.pm  |   |
| (signal handler,  +------>|  Visual.pm   Command.pm    |       |  Test.pm  |   |
|  test context)    |       |  Search.pm   Completion.pm  |       +-----------+---+
+-------------------+       |  CompletionUI.pm           |
                            |  PluginLoader.pm           |
                            +----------------------------+
```

**Key design principles:**

1. **GUI Decoupling** -- every editing action operates through the `VimBuffer`
   abstract interface (27 methods). The `Test` backend stores text as a Perl
   array of lines with zero GTK dependency, enabling complete headless testing.
2. **Action Registry** -- every editing operation is a named coderef in a
   central `%ACTIONS` hash, registered at compile time by mode-specific
   sub-modules. The dispatch system maps key events to action names.
3. **Configurable Dispatch** -- per-mode keymaps map GDK key names to action
   names. Special metadata keys (`_immediate`, `_prefixes`, `_char_actions`,
   `_ctrl`) control dispatch behavior. Users can override any binding via the
   `keymap` constructor option or `undef` to remove a default.

## Features

### Editing Modes

| Mode | Entry | Description |
|------|-------|-------------|
| Normal | (default) | Navigation, editing, mode transitions |
| Insert | `i/a/I/A/o/O` | Text input; Escape returns to Normal |
| Replace | `R` | Overtype characters; Escape returns to Normal |
| Visual | `v/V/Ctrl-V` | Character/line/block selection |
| Command | `:` | Ex-commands, search (`/`, `?`) |

### Normal Mode Keybindings

**Movement:** `h/j/k/l`, `w/b/e`, `gg/G`, `0/$`, `^`, `Page Up/Down`,
`f/F/t/T`, `;/,`, `%`

**Ctrl-key navigation:** `Ctrl-u/d` (half-page), `Ctrl-f/b` (full-page),
`Ctrl-y/e` (line scroll), `Ctrl-r` (redo)

**Editing:** `x`, `dd`, `cc`, `cw`, `C`, `J`, `r{c}`, `>>`, `<<`, `U`, `BackSp`

**Yank/Paste:** `yy`, `yw`, `yiw`, `p`, `P`, `xp` (swap word)

**Visual mode:** `v/V/Ctrl-v`, `y/d/c`, `>>/<<`, `~/U/u`, `I/A` (block),
`gq` (format), `gv` (reselect)

**Search:** `/pattern`, `?pattern`, `n`, `N`

**Marks:** `m{a-z}`, `` `{a-z} ``, `'{a-z}`

### Ex-Commands

| Command | Description |
|---------|-------------|
| `:w [file]` | Save file (optionally to a new path) |
| `:q` / `:q!` | Quit / force quit |
| `:wq` / `:wq!` | Save and quit |
| `:e <file>` | Open file (Tab-completion) |
| `:r <file>` | Insert file contents below current line |
| `:s/pat/repl/[g]` | Substitute on current line |
| `:%s/pat/repl/g` | Substitute across entire file |
| `:N` | Jump to line N |
| `:set cursor=block` | Switch to block cursor |
| `:set cursor=ibeam` | Switch to i-beam cursor |
| `:bindings` | Show key bindings dialog |
| `:browse` | GTK file chooser dialog |
| `:plugin list` | List loaded plugins |
| `:plugin unload <name>` | Remove a plugin |
| `:plugin reload <name>` | Hot-reload a plugin |

Numeric prefixes work on most commands: `3dd`, `5j`, `2yy`, `3p`, `5x`.

### Plugin System

Load `.pm` plugin files at runtime. Each plugin implements a `register($ACTIONS, $config)`
function that adds actions and returns an optional descriptor with keymaps and
ex-commands:

```perl
# In your plugin file:
sub register {
    my ($ACTIONS, $config) = @_;
    $ACTIONS->{my_action} = sub { ... };
    return {
        meta => { name => 'MyPlugin', namespace => 'my' },
        modes => { normal => { 'mp' => 'my_action' } },
        ex_commands => { mycmd => 'my_action' },
    };
}
```

Plugins are loaded via constructor options:
```perl
my $editor = Gtk3::SourceEditor->new(
    file         => 'script.pl',
    plugin_dirs  => ['plugins/'],
    plugin_files => ['plugins/AlignText.pm'],
);
```

A bundled `bindings/AlignText.pm` plugin demonstrates the system.

### Configuration File

Settings can be loaded from a `key = value` config file. Boolean values
(`true/false/yes/no/1/0`) and integers are auto-converted. Comments start
with `#`. Values with spaces may be quoted.

```bash
# Pass via CLI (CLI options take precedence)
perl -Ilib script/source-editor -C editor.conf myfile.pl
```

```perl
# Pass via constructor (constructor options take precedence)
my $editor = Gtk3::SourceEditor->new(
    config_file => 'editor.conf',
    file        => 'script.pl',
);
```

The distributed `editor.conf` documents all 20+ available keys including
theme, font, editor behavior, cursor, language, and clipboard settings.

### Block Cursor

An optional Cairo-drawn block cursor replaces the default i-beam. The block
uses theme foreground/background colors with inverted text for visibility.
Activate at runtime with `:set cursor=block` or at launch with the
`-b/--cursor-block` CLI option.

### Theming

Four GtkSourceView XML themes ship in the `themes/` directory:

| Theme | Description |
|-------|-------------|
| `default.xml` | Default GtkSourceView colors |
| `theme_dark.xml` | Dark background, light text |
| `theme_light.xml` | Light background, dark text |
| `theme_solarized.xml` | Solarized color palette |

The `ThemeManager` parses the XML, extracts `text` style colors, injects a
`cursor` style if missing, and generates CSS to theme the status bar and
command entry. Custom themes can be any valid GtkSourceView XML file.

## API Reference

### `Gtk3::SourceEditor->new(%opts)`

**Core options:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `file` | string | -- | File path to load |
| `config_file` | string | -- | Config file (values used as defaults) |
| `theme_file` | string | `themes/default.xml` | GtkSourceView XML theme |
| `vim_mode` | bool | 1 | 0 = native GTK keybindings (no Vim) |
| `window` | Gtk3::Window | -- | Parent window (for `on_close`) |
| `on_close` | coderef | -- | Callback receiving final buffer text |

**Font and display:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `font_family` | string | `Monospace` | Pango font family |
| `font_size` | int | 0 | Font pt size (0 = system default) |
| `wrap` | bool | 1 | Word wrap on/off |
| `show_line_numbers` | bool | 1 | Show line number gutter |
| `highlight_current_line` | bool | 1 | Highlight cursor line |

**Editor behavior:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `read_only` | bool | 0 | Block editing |
| `auto_indent` | bool | -- | Auto-indent new lines |
| `tab_width` | int | -- | Tab stop width in columns |
| `indent_width` | int | -- | Auto-indent width |
| `insert_spaces_instead_of_tabs` | bool | 0 | Tab inserts spaces |
| `smart_home_end` | bool | -- | Smart Home/End behavior |
| `show_right_margin` | bool | -- | Show right margin guide |
| `right_margin_position` | int | -- | Right margin column |
| `highlight_matching_brackets` | bool | 1 | Highlight matching bracket |
| `show_line_marks` | bool | -- | Show line-marks gutter |
| `force_language` | string | -- | Override syntax language ID |
| `tab_string` | string | `"\t"` | String inserted by Tab key |
| `block_cursor` | bool | 0 | Start with block cursor |
| `use_clipboard` | bool | 0 | Copy yanked text to clipboard |

**Vim customization:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `keymap` | hashref | -- | Per-mode key overrides |
| `scrolloff` | int | -- | Scroll margin lines |
| `page_size` | int | auto | Lines per viewport page |
| `shiftwidth` | int | 4 | Indent level width |

**Plugins:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `plugin_dirs` | arrayref | -- | Directories to scan for plugins |
| `plugin_files` | arrayref | -- | Specific plugin files to load |
| `plugin_config` | hashref | -- | Per-plugin config hash |
| `plugin_warnings` | bool | 1 | Warn on action name collisions |

**Callbacks:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key_handler` | coderef | Pre-vim key intercept (`$widget, $event`); return TRUE to consume |
| `on_ready` | coderef | Called after init with vim context `$ctx` |

### Accessors

| Method | Returns | Description |
|--------|---------|-------------|
| `get_widget()` | Gtk3::Box | Main widget to pack into your application |
| `get_text()` | string | Current buffer contents |
| `get_buffer()` | Gtk3::SourceBuffer | Underlying buffer (direct access) |
| `get_textview()` | Gtk3::SourceView | The text view widget |

## Testing

All 210+ tests run without a display server using mock objects and `VimBuffer::Test`:

```bash
# Run a single test file
perl -Ilib -It/lib t/vim_dispatch.t

# Run the config parser tests
perl -Ilib -It/lib t/editor_config.t

# Run all 17 test files
prove -Ilib -It/lib t/
```

Test infrastructure:
- `VimBuffer::Test` -- pure-Perl array-backed buffer, no GTK dependency
- `create_test_context(%opts)` -- builds a full vim context for testing
- `simulate_keys($ctx, @keys)` -- feeds deterministic key sequences
- Mock modules in `t/lib/` stub Gtk3, Glib, and Gdk

## Documentation

| Document | Description |
|----------|-------------|
| [doc/architecture.md](doc/architecture.md) | Component diagram, dispatch flow, module inventory, context object reference |
| [doc/bindings.md](doc/bindings.md) | Complete Vim bindings reference with all keymaps and custom binding examples |
| [doc/developer-guide.md](doc/developer-guide.md) | Step-by-step guide for adding new keybindings, actions, and tests |
| [doc/feature-reference.md](doc/feature-reference.md) | Complete feature catalog with constructor options, modes, ex-commands |
| [doc/improvement-suggestions.md](doc/improvement-suggestions.md) | 13-item improvement roadmap with status tracking (7/20 done) |
| [doc/proposal-treeview-bindings.md](doc/proposal-treeview-bindings.md) | Design proposal for the `:bindings` TreeView dialog |

## Dependencies

**Runtime:** Perl 5.020+, Gtk3, Gtk3::SourceView, Glib, Pango, File::Slurper, Encode

**Block cursor:** Cairo, Pango::Cairo (graceful degradation if unavailable)

**Plugins:** File::Find, File::Basename (core modules)

**Testing:** Test::More, Test::Exception

**CLI scripts:** Getopt::Long

## Installation

```bash
perl Build.PL
./Build
./Build test
./Build install
```

Or with cpanm:

```bash
cpanm .
```

## Module Inventory

| Module | Purpose |
|--------|---------|
| `Gtk3::SourceEditor` | Main widget factory and entry point |
| `Gtk3::SourceEditor::Config` | `key = value` config file parser |
| `Gtk3::SourceEditor::ThemeManager` | XML theme loader and CSS generator |
| `Gtk3::SourceEditor::VimBindings` | Central dispatcher, signal handler, test API |
| `Gtk3::SourceEditor::VimBindings::Normal` | Normal-mode actions (45+) |
| `Gtk3::SourceEditor::VimBindings::Insert` | Insert/replace mode actions |
| `Gtk3::SourceEditor::VimBindings::Visual` | Visual mode actions (char/line/block) |
| `Gtk3::SourceEditor::VimBindings::Command` | Ex-command parser and handlers |
| `Gtk3::SourceEditor::VimBindings::Search` | Search actions (forward/backward) |
| `Gtk3::SourceEditor::VimBindings::Completion` | File path completion logic |
| `Gtk3::SourceEditor::VimBindings::CompletionUI` | Completion dropdown UI |
| `Gtk3::SourceEditor::VimBindings::PluginLoader` | Runtime plugin management |
| `Gtk3::SourceEditor::VimBuffer` | Abstract buffer interface (27 methods) |
| `Gtk3::SourceEditor::VimBuffer::Gtk3` | Production GTK adapter |
| `Gtk3::SourceEditor::VimBuffer::Test` | Pure-Perl test adapter |

## License

Artistic License 2.0.
