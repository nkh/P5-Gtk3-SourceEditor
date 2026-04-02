---
name: p5-sourceeditor-dev
description: >
  Development reference for the P5-Gtk3-SourceEditor Perl project — a modular,
  embeddable Vim-like text editor widget built on Gtk3::SourceView. Use this skill
  whenever working on this project: adding features, fixing bugs, understanding
  architecture, creating plugins, writing tests, modifying themes, or building
  releases. Also use when the user mentions "SourceEditor", "VimBuffer", "VimBindings",
  "Gtk3 SourceView", "vim mode", "syntax highlighting", or "editor widget".
---

# P5-Gtk3-SourceEditor Developer Guide

A modular, embeddable Vim-like text editor widget for Gtk3 Perl applications.
Version 0.04, requires Perl 5.020+.

## Project Layout

```
src/
├── Build.PL              # Module::Build, version 0.04
├── MANIFEST              # All distributed files
├── README.md             # User documentation (405 lines)
├── editor.conf           # Default config file
├── lib/
│   └── Gtk3/
│       └── SourceEditor.pm           # Main widget (588 lines)
│           ├── Config.pm             # key=value config parser
│           ├── ThemeManager.pm       # GtkSourceView XML theme loader
│           ├── VimBuffer.pm          # Abstract editing interface (311 lines)
│           ├── VimBindings.pm        # Mode dispatcher (1100+ lines)
│           └── VimBindings/
│               ├── Normal.pm         # Normal mode (hjkl, dd, yy, etc.)
│               ├── Insert.pm         # Insert mode (typing, Esc, Ctrl-O/W)
│               ├── Visual.pm         # Visual mode (char/line/block select)
│               ├── Command.pm        # Command-line mode (:w, :q, :%s, etc.)
│               ├── Search.pm         # / and ? search, n/N
│               ├── Completion.pm     # Ctrl-N/Ctrl-P word completion
│               ├── CompletionUI.pm   # Popup completion widget
│               └── PluginLoader.pm  # .pm plugin system
│           └── VimBuffer/
│               ├── Gtk3.pm           # Real GTK backend (wraps GtkSourceView)
│               └── Test.pm           # Headless backend (arrays of text lines)
├── t/
│   ├── lib/                # Mock objects (14 files, see perl-compile-check skill)
│   ├── mock_strict/        # Strict mocks for specific tests
│   └── *.t                 # 18 test files (all headless, no X11 needed)
├── script/
│   ├── source-editor       # Standalone editor
│   ├── source-dialog-editor # Dialog-embedded editor demo
│   ├── source-editor-cursor-demo # Block cursor demo
│   ├── test-syntax-colors.pl  # Syntax highlighting test
│   ├── test_lang_color.pl     # Language color test
│   └── check-api-methods.pl   # Static API verification
├── themes/
│   ├── default.xml
│   ├── theme_dark.xml
│   ├── theme_light.xml
│   └── theme_solarized.xml
├── doc/                 # Architecture, bindings, developer docs
├── api-registry/        # GTK API method registry (JSON, 474 classes)
└── bindings/            # AlignText.pm plugin
```

## Architecture Overview

The editor has three key design decisions that affect all development:

### 1. VimBuffer Abstraction Layer

`VimBuffer.pm` defines a **pure-Perl abstract interface** with 27 methods for
text editing (cursor movement, text manipulation, search, undo/redo). Two
backends implement this:

- **`VimBuffer::Gtk3`** — Wraps real `Gtk3::SourceView::Buffer` + `View`.
  Used in production with a GTK display.
- **`VimBuffer::Test`** — Pure Perl using arrays of text lines. Used in
  headless tests. No X11/GTK needed.

All VimBindings code operates through `VimBuffer` — never calls GTK directly.
This means **all 210+ tests run without a display server**.

### 2. Safe-Call Dispatch (`$_call`)

`SourceEditor.pm` uses an internal `$_call` helper that wraps method calls:

```perl
my $_call = sub {
    my ($obj, $method, @args) = @_;
    if ($obj->can($method)) {
        return $obj->$method(@args);
    } else {
        warn "SourceEditor: skipping unsupported method '$method'";
        return;
    }
};
```

This provides **graceful degradation** — if a method doesn't exist on the
installed GTK version, it's silently skipped rather than crashing. This is why
all mock objects must implement `sub can { return 1 }`.

### 3. Mode Dispatcher

`VimBindings.pm` receives all keystrokes and dispatches to mode-specific
handlers based on current mode state. Each mode module is a separate class:

```
VimBindings.pm → {Normal,Insert,Visual,Command,Search,Completion,CompletionUI}
```

Modes can transition: Normal↔Insert, Normal↔Visual, Normal↔Command, etc.

## Adding a New Feature

### Adding a New Vim Command

1. **Determine the mode**: Is it a Normal mode command? Insert? Command-line?
2. **Implement in the mode module** (e.g., `VimBindings/Normal.pm`):
   ```perl
   sub _cmd_gg {
       my ($self, $vb, $count) = @_;
       $count //= 1;
       $vb->set_cursor($count - 1, $vb->first_nonblank_col($count - 1));
   }
   ```
3. **Register in the keymap** in the mode module's `_init_keymap` or handler
   dispatch table
4. **Write headless tests** using `VimBuffer::Test`:
   ```perl
   use Gtk3::SourceEditor::VimBuffer::Test;
   my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
   # ... execute command, assert state
   ```
5. **Run**: `perl -Ilib -It/lib t/vim_normal.t`
6. **Run API check**: `perl script/check-api-methods.pl`

### Adding a New Constructor Option

1. Add to `_build_ui()` in `SourceEditor.pm`
2. Add default handling and config-file mapping in the `%map` hash
3. Use `$_call` for GTK method calls: `$_call->($self->{textview}, 'set_new_option', $val)`
4. Document in `README.md` and `editor.conf`
5. Run `perl -c` and `check-api-methods.pl`

### Creating a Plugin

Plugins are `.pm` files with a `register($ACTIONS, $config)` entry point:

```perl
package MyPlugin;
use strict;
sub register {
    my ($actions, $config) = @_;
    push @$actions, {
        name => 'align-text',
        type => 'ex_command',
        handler => sub { ... },
    };
}
1;
```

Loaded via `plugin_dirs` or `plugin_files` constructor options.

## Key Conventions

### Method Ownership (Buffer vs View)

This is the #1 source of runtime errors. Memorize this:

| Method | On Buffer | On View |
|--------|-----------|---------|
| `set_highlight_syntax` | ✅ | ❌ |
| `set_highlight_matching_brackets` | ✅ | ❌ |
| `set_language` | ✅ | ❌ |
| `set_style_scheme` | ✅ | ❌ |
| `set_show_line_numbers` | ❌ | ✅ |
| `set_highlight_current_line` | ❌ | ✅ |
| `set_auto_indent` | ❌ | ✅ |
| `set_tab_width` | ✅ (via property) | ✅ |

When in doubt, run `perl script/check-api-methods.pl` before shipping.

### Coordinate System

- Lines and columns are **0-based** throughout the codebase
- `cursor_line()` / `cursor_col()` return 0-based values
- `set_cursor($line, $col)` expects 0-based values

### The `$_call` Pattern

When adding GTK method calls in `SourceEditor.pm`, always use `$_call`:

```perl
# CORRECT - graceful degradation
$_call->($self->{buffer}, 'set_highlight_syntax', TRUE);

# WRONG - will crash if method doesn't exist on older GTK
$self->{buffer}->set_highlight_syntax(TRUE);
```

Exception: In `VimBuffer::Gtk3.pm`, direct calls are fine since that module
explicitly targets the real GTK backend.

### Test Conventions

- Tests use `VimBuffer::Test` for headless operation
- Test files follow naming: `vim_<feature>.t` (e.g., `vim_search.t`, `vim_undo.t`)
- Each test file uses `Test::More` and imports from `t/lib`
- Run all tests: `prove -Ilib -It/lib t/*.t` (but many need `perl -c` only
  since mock objects have limited behavior)

### Theme Format

Themes are GtkSourceView XML files with `<style-scheme>` root element. Four
built-in themes ship in `themes/`. The `ThemeManager` resolves theme names
like `"dark"` → `themes/theme_dark.xml`.

## Build and Release

```bash
cd src

# Compile check
find lib t \( -name "*.pm" -o -name "*.t" \) -exec perl -Ilib -It/lib -c {} \;

# API check
perl script/check-api-methods.pl

# Generate tarball (from project root)
# Suffix encodes version + contents: v{VERSION}-{description}
VER=$(perl -Ilib -It/lib -ne 'print $1 if /VERSION.*?([\d.]+)/' lib/Gtk3/SourceEditor.pm)
tar czf ../download/P5-Gtk3-SourceEditor-v${VER}-full-source.tar.gz \
    -C src Build.PL editor.conf MANIFEST README.md \
    lib/ bindings/ themes/ doc/ script/ t/ api-registry/
```

## Known Gotchas

1. **Perl 5.36+ bareword changes** — `GtkStateFlags` must be strings, not barewords
2. **`get_tags()` returns unblessed array refs** — In GtkSourceView 3.x, TextIter's
   `get_tags()` returns raw array refs, not blessed objects
3. **Mock `can()` must return 1** — SourceEditor's `$_call` checks `$obj->can($method)`
   before dispatching. If `can()` returns false, the method is silently skipped.
4. **Block cursor is Cairo-drawn** — Not a native GTK feature; the block cursor
   is implemented via `signal_connect_after('draw')` with Cairo rendering
5. **Config values are defaults** — Explicit constructor options always override
   config file values (config is loaded first, then merged with ` %opts`)
