---
name: perl-compile-check
description: >
  Run syntax checking (perl -c) on all Perl modules, scripts, and test files in
  the P5-Gtk3-SourceEditor project using mock objects for missing GTK/X11 modules.
  Use this skill whenever you modify any .pm, .pl, or .t file; when the user asks
  to "check compilation", "run perl -c", "verify syntax", or "check for errors".
  Also use when creating new mock modules or when test files fail to compile. This
  skill ensures every file passes syntax checking before shipping.
---

# Perl Compile Check with Mock Objects

The P5-Gtk3-SourceEditor project depends on GTK3, GtkSourceView, Pango, and
other X11/GNOME libraries that may not be installed in the current environment.
All files must pass `perl -c` using the mock infrastructure in `t/lib/`.

## Quick Check

```bash
cd src

# Check ALL files (lib + t + script)
find lib t \( -name "*.pm" -o -name "*.t" \) -exec perl -Ilib -It/lib -c {} \;

# Check only lib modules
find lib -name "*.pm" -exec perl -Ilib -It/lib -c {} \;

# Check a single file
perl -Ilib -It/lib -c lib/Gtk3/SourceEditor.pm
perl -Ilib -It/lib -c script/test-syntax-colors.pl
perl -Ilib -It/lib -c t/vim_bindings.t
```

The key is the **include path order**: `-Ilib -It/lib`. This makes Perl find
the real project modules under `lib/` first, then the mock objects under `t/lib/`
to satisfy missing dependencies.

## Expected Result

All files should print `syntax OK`. As of the latest check:

- **15 lib modules**: all pass
- **2 scripts**: all pass  
- **18 test files**: all pass (2 benign warnings about "used only once")
- **Total: 35 files**, 0 failures

## Mock Architecture

The mock files in `t/lib/` provide stub implementations for modules that
require GTK3/X11 at runtime but are only needed for compilation or headless
testing.

### Mock Files

| File | What It Mocks | Key Contents |
|------|---------------|--------------|
| `Gtk3.pm` | `Gtk3` namespace | `import()`, 50+ widget stubs, `TRUE`/`FALSE`/`EVENT_PROPAGATE`/`EVENT_STOP` |
| `Gtk3/SourceView.pm` | `Gtk3::SourceView::*` | 28 sub-packages (View, Buffer, LanguageManager, Completion, etc.) |
| `Gtk3/Gdk.pm` | `Gtk3::Gdk::*` | Event, RGBA, Atom, Window, Screen, Display |
| `Gtk3/MessageDialog.pm` | `Gtk3::MessageDialog` | `new()`, `run()`, `format_secondary_text()` |
| `Gtk3/CssProvider.pm` | `Gtk3::CssProvider` | `new()`, `load_from_data()`, `load_from_path()` |
| `Gtk3/CellRendererText.pm` | `Gtk3::CellRendererText` | `new()`, property stubs |
| `Gtk3/FileChooserDialog.pm` | `Gtk3::FileChooserDialog` | `new()`, `get_filename()`, `run()` |
| `Gtk3/TreeView.pm` | `Gtk3::TreeView` | `new()`, `append_column()`, `get_selection()` |
| `Gtk3/TreeViewColumn.pm` | `Gtk3::TreeViewColumn` | `new()`, `pack_start()` |
| `Gtk3/TreeStore.pm` | `Gtk3::TreeStore` | `new()`, `append()`, `set()` |
| `Gtk3/Clipboard.pm` | `Gtk3::Clipboard` | `get()`, `set_text()`, `request_text()` |
| `Glib.pm` | `Glib` | `TRUE`, `FALSE`, `timeout_add`, `idle_add`, `source_remove` |
| `Pango.pm` | `Pango::*` | `FontDescription`, `Layout`, `Cairo::show_layout` |
| `File/Slurper.pm` | `File::Slurper` | `read_text()`, `write_text()` |

### AUTOLOAD Pattern

Every mock package implements this defense-in-depth pattern:

```perl
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self  if $method =~ /^(set_|new|signal_connect)/;  # chaining
    return undef  if $method =~ /^get_/;                        # getter
    return;                                                     # void
}
sub can { return 1 }
```

This ensures:
- Any method call compiles and runs without dying
- `set_*` methods return `$self` for method chaining
- `get_*` methods return `undef` (safe default)
- `->can('any_method')` always returns true (critical for SourceEditor.pm's
  `$_call` safe-dispatch helper which checks `$obj->can($method)` before calling)
- `DESTROY` is silently ignored (no crash on cleanup)

## Adding a New Mock

When a new dependency is needed:

1. Create the file at `t/lib/New/Module.pm` (or `t/lib/NewModule.pm`)
2. Use the AUTOLOAD pattern above as the fallback
3. Add any concrete methods that tests rely on returning specific values
4. Add `sub can { return 1 }` so SourceEditor's `$_call` helper doesn't skip it
5. Verify with `perl -Ilib -It/lib -c <file-that-uses-it>`

## Common Compile Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Can't locate Gtk3.pm` | Missing mock or wrong -I path | Ensure `-It/lib` is in the include path |
| `Bareword "FALSE" not allowed` | Missing `use Glib ('TRUE','FALSE')` | Add the import to the file |
| `Prototype mismatch` | Glib mock defines conflicting constant | Check `t/lib/Glib.pm` doesn't use `use constant` |
| `Global symbol "$VAR" requires explicit package name` | Missing `my` declaration | Add `my` to the variable declaration |
| `syntax error at ... near "..."` | Regex/string escaping issue | Check quoting, use `m{}` for regex with `/` |

## Strict vs. Permissive Mocks

There are two mock levels:

- **`t/lib/`** — Permissive mocks with AUTOLOAD. Used for compilation and
  headless test runs. Accept any method call.
- **`t/mock_strict/`** — Strict mocks that only allow explicitly defined methods.
  Used to catch accidental calls to non-existent methods in specific tests.
  Currently contains `Gtk3/SourceView.pm` and `Gtk3/CssProvider.pm`.
