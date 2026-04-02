---
name: perl-gtk-api-verify
description: >
  Verify Perl GTK3 and GtkSourceView method calls against the real C API to catch
  runtime "Can't locate object method" errors BEFORE they happen. Use this skill
  whenever you modify .pm files in the P5-Gtk3-SourceEditor project, add new GTK
  method calls, create new mock objects, or need to check whether a method exists
  on a specific GTK class. Also use when the user mentions runtime method errors,
  "Can't locate object method", mock objects, or API verification. This skill
  ensures code changes won't cause runtime dispatch failures on GTK objects.
---

# Perl GTK API Verification

This skill provides static analysis to catch the class of runtime errors where
Perl code calls a method on a GTK object that doesn't actually have that method
in the real C library. `perl -c` cannot detect these — it only checks syntax.

## Why This Matters

In Perl's GTK bindings (via `Glib::Object::Introspection`), methods are resolved
at runtime from the underlying C library's typelib. If you call
`$view->set_highlight_matching_brackets()` but that method only exists on
`Gtk3::SourceView::Buffer` (not on `View`), `perl -c` passes but the program
crashes at runtime with: `Can't locate object method "set_highlight_matching_brackets"
via package "Gtk3::SourceView::View"`.

## Quick Check

Run the API checker from the project root (`src/`):

```bash
cd src && perl script/check-api-methods.pl
```

- Exit 0 = all method calls valid
- Exit 1 = issues found (wrong object, missing methods)

The checker analyzes all 15 lib/ `.pm` files, extracts ~470 method calls, and
cross-references each against the real GTK/SourceView/Pango API registry.

## API Registry

The registry lives at `api-registry/full_api.json` (included in the tarball).
It contains 474 Perl packages with their methods, extracted from the actual
`.typelib` binary files:
- `GtkSource-3.0.typelib` → `Gtk3::SourceView::*` classes
- `Gtk-3.0.typelib` → `Gtk3::*` classes
- `Pango-1.0.typelib` → `Pango::*` classes

### Regenerating the Registry

If you need to update the registry (e.g., after adding a new GTK dependency):

```bash
# 1. Get the typelib binary (from Ubuntu packages or system install)
apt install gir1.2-gtksource-3.0   # provides GtkSource-3.0.typelib

# 2. Extract method names using the bundled helper script
perl project_skills/perl-gtk-api-verify/scripts/extract-typelib-api.pl \
    /usr/lib/x86_64-linux-gnu/girepository-1.0/GtkSource-3.0.typelib \
    GtkSource Gtk3::SourceView \
    > src/api-registry/full_api.json.tmp

# 3. The script outputs JSON; merge into the existing registry (manual step)
```

## How the Checker Works

The checker (`script/check-api-methods.pl`) uses three strategies to resolve types:

1. **Constructor tracking** — Scans for `$var = Gtk3::SourceView::View->new()` and
   records the type
2. **File-context maps** — Known mappings like `$self->{textview}` → `View` in
   `SourceEditor.pm`, `$self->{buffer}` → `Buffer`
3. **Variable naming conventions** — 80+ mappings: `$view` → View, `$buffer` →
   Buffer, `$lm` → LanguageManager, `$iter` → TextIter, etc.

It then checks each `(type, method)` pair against the registry with full
inheritance traversal (e.g., View → TextView → Container → Widget).

## Key GTK Class Hierarchy (SourceView 3.x)

Knowing the inheritance chain is critical when adding method calls:

```
Gtk3::SourceView::View  →  Gtk3::TextView  →  Gtk3::Container  →  Gtk3::Widget
Gtk3::SourceView::Buffer → Gtk3::TextBuffer
```

Common mistake: methods like `set_highlight_matching_brackets`,
`set_highlight_syntax`, `set_language`, `set_style_scheme` are on **Buffer**,
NOT on View. View has `set_show_line_numbers`, `set_auto_indent`,
`set_highlight_current_line`, etc.

## When to Run

- After modifying any file in `lib/`
- After adding new method calls on GTK objects
- Before creating a tarball / release
- When a runtime "Can't locate object method" error is reported

## Adding New Known-Good Methods

If the checker reports a false positive for a method that genuinely exists but
isn't in the extracted API, add it to the `%KNOWN_GOOD` hash in
`script/check-api-methods.pl` (around line 81). This is a common occurrence for
methods provided by `Glib::Object::Introspection` infrastructure (like
`signal_connect`, `set_property`) or methods from parent classes not fully
represented in the typelib.

## Interpreting Output

- **WRONG OBJECT** — Method exists in the API but on a different class.
  This is almost certainly a bug (like calling a Buffer method on a View).
- **NOT FOUND** — Method doesn't exist anywhere in the GTK API. Either a
  typo, a method from a different library, or a method that's been removed.
- **UNKNOWN TYPE** — The checker couldn't infer what type the variable is.
  These are informational only (usually variables inside `eval` blocks).
