# File Completion for :e and :r Commands

## Status: Proposal (not yet implemented)

## Motivation

The `:e` (edit) and `:r` (read) ex-commands currently require the user to type
the full file path.  In a Vim-like editor, file path completion is expected
behaviour: pressing Tab while typing a path should expand it to the longest
common prefix of matching files and directories, and display possible
completions.

## Scope

This proposal covers the design for filename completion in the command entry
widget when the user is typing a `:e` or `:r` command.  The design is
intentionally modular so that the completion backend can be swapped out later
(e.g., replaced by a full file picker dialog or an external command like fzf).

## Architecture Overview

```
+------------------+     +-------------------+     +-------------------+
| Command Entry    |---->| Completion        |---->| Completion        |
| (Gtk3::Entry)    |     | Engine            |     | Backend           |
|                  |     | (Perl module)     |     | (pluggable)       |
| key-press-event  |     |                   |     |                   |
| -> intercept Tab |     | complete($path)   |     | list_dir($dir)    |
| -> insert text   |     | candidates()      |     |                   |
|                  |     |                   |     +-------------------+
+------------------+     +-------------------+               |
                                  |                         |
                                  v                         v
                         +-------------------+     +-------------------+
                         | Display           |     | Future:           |
                         | (status label or  |     | - File picker GUI |
                         |  popup)           |     | - fzf integration |
                         +-------------------+     | - Project index   |
                                                    +-------------------+
```

## Key Components

### 1. Completion Engine (Gtk3::SourceEditor::VimBindings::Completion)

A lightweight Perl module that handles the completion logic without touching
GTK directly.  It receives the current partial path and returns a list of
candidate completions.

```perl
package Gtk3::SourceEditor::VimBindings::Completion;

sub new {
    my ($class, %opts) = @_;
    return bless {
        backend => $opts{backend} // 'filesystem',
    }, $class;
}

# Given a partial path like "/home/user/do" or "lib/Gtk",
# return the longest common prefix and remaining candidates.
# Returns: { prefix => "/home/user/doc", candidates => ["docs/", "dotfiles/"] }
#          or { prefix => $input, candidates => [] } if no match.
sub complete {
    my ($self, $partial_path) = @_;
    # ... implementation ...
}

# Return the directory component of a partial path for listing.
sub _list_dir {
    my ($self, $dir) = @_;
    # Uses opendir/readdir or the configured backend.
}

1;
```

### 2. Integration Point: Command Entry Handler

The command entry key-press handler in VimBindings.pm needs to intercept
the Tab key when in command mode and the command is `:e` or `:r`.  This is
the minimal integration surface:

```perl
# In handle_command_entry, before returning FALSE:
if ($k eq 'Tab') {
    my $text = $ce->get_text;
    if ($text =~ /^(:e\s+|:r\s+)(.*)/) {
        my $prefix = $1;
        my $partial = $2;
        my $result = $ctx->{completer}->complete($partial);
        if (@{$result->{candidates}}) {
            if (scalar @{$result->{candidates}} == 1) {
                # Single match: insert it
                $ce->set_text($prefix . $result->{candidates}[0]);
            } else {
                # Multiple matches: insert common prefix
                $ce->set_text($prefix . $result->{prefix});
                # Show candidates in status label
                $ctx->{mode_label}->set_text(
                    join("  ", @{$result->{candidates}})
                );
            }
            $ce->set_position(-1);
        }
        return TRUE;
    }
}
```

### 3. Pluggable Backend Interface

The completion backend is a simple object with a `list_dir` method.  The
default backend uses Perl's built-in `opendir`/`readdir`.  The interface is
designed so that a future file picker module or external command can be
dropped in:

```perl
# Backend interface (role-like contract)
package Gtk3::SourceEditor::VimBindings::Completion::Backend::Filesystem;

sub list_dir {
    my ($self, $dir) = @_;
    $dir //= '.';
    opendir(my $dh, $dir) or return [];
    my @entries = sort grep { !/^\./ } readdir($dh);
    closedir($dh);
    return \@entries;
}

# Future backend example (not implemented):
package Gtk3::SourceEditor::VimBindings::Completion::Backend::Fzf;

sub list_dir {
    my ($self, $dir, $partial) = @_;
    # Pipe to fzf and return results
}
```

### 4. Future: File Picker Dialog

The architecture leaves room for a separate file picker project.  When a
file picker module is available, it could be invoked via a dedicated key
binding (e.g., `:e ` with no arguments, or a new `:browse` command) that
opens a native GTK file chooser dialog or an external tool.  The completion
engine described above handles the inline path completion case; a file
picker would handle the browse-and-select case.

The extension point would be in the `cmd_edit` action:

```perl
$ACTIONS->{cmd_edit} = sub {
    my ($ctx, $count, $parsed) = @_;
    my $file = $parsed->{args}[0];

    # No file argument: invoke file picker if available
    unless (defined $file && length $file) {
        if ($ctx->{file_picker}) {
            $file = $ctx->{file_picker}->pick($ctx);
            return unless defined $file;
        } else {
            $ctx->{mode_label}->set_text("Error: No filename");
            return;
        }
    }
    # ... existing logic ...
};
```

## Implementation Plan

### Phase 1: Inline Completion (this project)

1. Create `lib/Gtk3/SourceEditor/VimBindings/Completion.pm` with the
   completion engine.
2. Modify `handle_command_entry` in `VimBindings.pm` to intercept Tab for
   `:e` and `:r` commands.
3. Instantiate the completer in `add_vim_bindings` and `create_test_context`.
4. Add tests for the completion logic (pure Perl, no GTK needed).
5. Handle edge cases: spaces in filenames, symlinks, hidden files,
   UNC paths on Windows.

### Phase 2: File Picker Integration (future project)

1. Create `Gtk3::SourceEditor::FilePicker` as a standalone distribution.
2. Implement a native GTK3 file chooser dialog backend.
3. Implement an external command backend (e.g., fzf, ranger).
4. Wire the file picker into `:e` and `:r` as an optional component via
   a constructor option or `:set filepicker=...`.

## Key Design Decisions

**No popup widget for completions in Phase 1.**  Showing completions in the
existing status label keeps the implementation simple and avoids creating a
custom popup overlay.  A popup can be added later without changing the
completion engine interface.

**Completion only triggers on `:e` and `:r`.**  Other commands like `:w`
and `:s` do not benefit from file completion.  The trigger check is a simple
regex match on the command entry text.

**The completer is a separate object, not baked into VimBindings.**  This
allows users to disable completion, swap backends, or configure behaviour
without modifying the core binding logic.  It also makes testing easier.

**Hidden files are excluded by default.**  Matching Vim behaviour, dotfiles
are not shown unless the partial path explicitly starts with `.`.  This can
be made configurable later via a `:set` option.

## Notes

- The Tab key in the command entry currently falls through to the default
  GTK behaviour (which may move focus).  The new handler must return TRUE
  to prevent this.
- Completion must work with both absolute paths and relative paths.
- The completer should handle the case where the partial path ends with a
  directory separator (list the directory contents directly).
