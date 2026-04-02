---
name: binding-creation
description: >
  Structured worksheet-driven workflow for creating new Vim-style key bindings in
  P5-Gtk3-SourceEditor. A human developer fills out a worksheet with the new binding's
  specification, then hands it to an AI which generates all necessary code, tests,
  documentation, and integration instructions as an isolated tarball. Use this skill
  when the user asks to "add a binding", "create a new command", "implement a Vim key",
  "add a keybinding", or mentions any specific Vim command they want to implement.
  Also use when the user provides a worksheet (see BINDING WORKSHEET section below).
---

# Binding Creation Skill

Create new Vim-style key bindings for P5-Gtk3-SourceEditor through a structured
worksheet. The workflow is:

1. **Human developer** fills out the worksheet (section below)
2. **AI** reads the worksheet and generates all artifacts into an isolated tarball
3. **Human** reviews, tests, and merges into the main project

The tarball is fully isolated — it can be developed in a subdirectory without
touching the main codebase until the developer is ready to merge.

## Binding Worksheet Template

When a human wants to create a new binding, they must fill out ALL fields below.
If a field doesn't apply, write "N/A" with a brief explanation. The more complete
the worksheet, the more accurate the AI output will be.

```markdown
# Binding Worksheet: [action_name]

## 1. Basic Identity
- **Action name**: [snake_case identifier, e.g., delete_inner_word]
- **Key sequence**: [human-readable keys, e.g., diw, 3dw, gq]
- **GDK key name**: [dispatcher key, e.g., d_i, dollar — leave blank if unsure]

## 2. Mode & Dispatch
- **Mode(s)**: [normal / insert / visual / visual_line / visual_block / command / replace]
- **Dispatch type**: [simple / char_action / operator_motion / ex_command / mode_transition]
- **Text impact**: [motion / delete / change / yank / mode_switch / other:____]

## 3. Count Behavior
- **Count support**: [none / repeat_N_times / Nth_occurrence / custom:____]
- **Default count**: [1 / 0 / context-dependent:____]
- **Count edge case**: [what happens with count 0? very large count?]

## 4. Description
- **Short description**: [one-liner for :bindings help, e.g., "delete inner word (diw)"]
- **Detailed behavior**: [full specification of what the command does, step by step]

## 5. Code Templates
- **Similar existing bindings**: [list 2-3 action names, e.g., delete_word, yank_inner_word, change_word]
- **Additional context**: [any extra info the AI should know]

## 6. VimBuffer Methods Needed
- **Methods**: [list all $ctx->{vb}->method() calls needed, e.g., word_forward, get_range, delete_range]
- **Direct GTK access needed?**: [yes/no — if yes, which GTK objects and methods?]
- **ctx fields accessed**: [list $ctx->{...} fields beyond vb, e.g., yank_buf, desired_col, set_mode]

## 7. Test Scenarios

### Test: basic
- **Buffer**: [initial text, e.g., "hello world\nfoo bar\n"]
- **Cursor**: [line, col]
- **Mode**: [normal/insert/...]
- **Keys**: [key sequence to simulate]
- **Expected text**: [buffer text after command]
- **Expected cursor**: [line, col]
- **Expected yank_buf**: [content, or "unchanged"]

### Test: with count
- **Buffer**: [initial text]
- **Cursor**: [line, col]
- **Keys**: [count + key sequence]
- **Expected text**: [buffer text after command]
- **Expected cursor**: [line, col]

### Test: edge case 1
- **Scenario**: [description]
- **Buffer**: [initial text]
- **Cursor**: [line, col]
- **Keys**: [key sequence]
- **Expected**: [what should happen]

### Test: edge case 2
- **Scenario**: [description]
- **Buffer**: [initial text]
- **Cursor**: [line, col]
- **Keys**: [key sequence]
- **Expected**: [what should happen]

## 8. Edge Cases & Interactions
- **Empty buffer**: [what happens?]
- **EOF/BOF boundary**: [what happens at start/end of file?]
- **Read-only mode**: [should it be blocked by $ctx->{is_readonly}?]
- **Visual mode interaction**: [does it work in visual? should it?]
- **Undo behavior**: [single undo step? depends on count?]
- **Other**: [any other edge case or interaction with existing features]
```

## AI Workflow (What to Generate)

When you receive a completed worksheet, generate the following artifacts:

### Step 1: Determine the target files

Based on the dispatch type and mode:

| Dispatch Type | Target File(s) |
|---|---|
| `simple` (normal) | `lib/Gtk3/SourceEditor/VimBindings/Normal.pm` |
| `char_action` (normal) | `lib/Gtk3/SourceEditor/VimBindings/Normal.pm` |
| `operator_motion` (normal) | `lib/Gtk3/SourceEditor/VimBindings/Normal.pm` |
| `simple` (visual) | `lib/Gtk3/SourceEditor/VimBindings/Visual.pm` |
| `ex_command` | `lib/Gtk3/SourceEditor/VimBindings/Command.pm` |
| `mode_transition` | The mode module you're transitioning FROM |
| `simple` (insert) | `lib/Gtk3/SourceEditor/VimBindings/Insert.pm` |
| `simple` (replace) | Keymap in VimBindings.pm (replace uses `_any` char_action) |

### Step 2: Write the action handler

Follow the exact code pattern for the dispatch type. Read the "Similar existing
bindings" from the worksheet and mimic their structure precisely.

#### Simple action handler pattern:
```perl
$ACTIONS->{action_name} = sub {
    my ($ctx, $count) = @_;
    $count ||= 1;
    my $vb = $ctx->{vb};
    # ... implementation using $vb methods ...
    $ctx->{desired_col} = $vb->cursor_col;  # for motions
    $ctx->{after_move}->($ctx) if $ctx->{after_move};  # for motions
};
```

#### Char-action handler pattern:
```perl
$ACTIONS->{action_name} = sub {
    my ($ctx, $count, @extra) = @_;
    return unless @extra;  # guard: needs a following char
    my $char = $extra[0];
    $count ||= 1;
    my $vb = $ctx->{vb};
    # ... implementation ...
};
```

#### Operator+motion handler pattern (delete/change/yank):
```perl
$ACTIONS->{action_name} = sub {
    my ($ctx, $count) = @_;
    $count ||= 1;
    my $vb = $ctx->{vb};
    # Save start position
    my ($start_line, $start_col) = ($vb->cursor_line, $vb->cursor_col);
    # Perform motion
    # ...
    my ($end_line, $end_col) = ($vb->cursor_line, $vb->cursor_col);
    # Extract text, yank if delete/change, then delete
    my $text = $vb->get_range($start_line, $start_col, $end_line, $end_col);
    $_set_yank->($ctx, $text) if $is_delete_or_change;
    $vb->delete_range($start_line, $start_col, $end_line, $end_col) if $is_delete_or_change;
    # Restore cursor
    $vb->set_cursor($start_line, $start_col);
};
```

#### Ex-command handler pattern:
```perl
$ACTIONS->{cmd_commandname} = sub {
    my ($ctx, $count, $parsed) = @_;
    my $arg = $parsed->{args}[0];
    my $vb = $ctx->{vb};
    # ... implementation ...
    $ctx->{show_status}->("message") if $ctx->{show_status};
};
```

#### Mode transition pattern:
```perl
$ACTIONS->{enter_mode} = sub {
    my ($ctx) = @_;
    # optional: adjust cursor first
    $ctx->{set_mode}->('target_mode');
};
```

### Step 3: Register in the keymap

Add the key→action mapping to the keymap hash at the bottom of the module's
`register()` function's return statement.

For **char_actions**, add to `_char_actions`:
```perl
_char_actions => {
    # ... existing entries ...
    x => 'action_name',    # key 'x' waits for next char, dispatches action_name
},
```

For **multi-character keys** (operator+motion), ensure the first character is in
`_prefixes`:
```perl
_prefixes => [qw(g d y c greater less)],
# The dispatcher auto-derives additional prefixes from multi-char keys.
# If your new key starts with a character NOT in _prefixes, add it.
```

For **ex-commands**, add to the Command.pm return hash:
```perl
return {
    # ... existing entries ...
    cmdname => 'cmd_commandname',
};
```

### Step 4: Add the description to the help maps

In `lib/Gtk3/SourceEditor/VimBindings/Command.pm`, add to `_build_desc_map()`:
```perl
action_name => 'short description for :bindings help',
```

If the GDK key name needs a human-readable mapping, add to `_build_key_name_map()`:
```perl
d_i => 'diw',  # or whatever the human-readable form is
```

### Step 5: Generate the test file

Write a complete `t/vim_[feature].t` test file using the test scenarios from the
worksheet. Use this exact pattern:

```perl
#!perl
use strict;
use warnings;
use Test::More tests => N;  # set N to actual test count

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# --- Test: [description] ---
{
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "initial text\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    # Set up any needed state
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k', 'e', 'y', 's');

    is($vb->text, "expected text\n", "description");
    is($vb->cursor_line, 0, "cursor line");
    is($vb->cursor_col, 5, "cursor col");
    is(${$ctx->{yank_buf}}, "yanked text", "yank buffer") if check_yank;
}
```

Key test conventions:
- Use `VimBuffer::Test->new(text => ...)` for headless buffer creation
- Use `create_test_context()` for the vim context
- Use `simulate_keys()` to feed key sequences
- For char-actions that need a following char: `simulate_keys($ctx, 'r', 'x')`
- For ctrl keys: `simulate_keys($ctx, 'Control-u')`
- Each test gets its own block `{ ... }` with isolated `$vb` and `$ctx`
- Test file naming: `t/vim_[feature].t` (e.g., `t/vim_inner_word.t`)

### Step 6: Generate documentation

Create a documentation snippet for `doc/bindings.md`:

```markdown
| `[key]` | [short description] |
| `3[key]` | [description with count] |
```

### Step 7: Verify VimBuffer methods

Before finalizing, verify every `$ctx->{vb}->method()` call against the VimBuffer
API. The available methods are documented in
`project_skills/p5-sourceeditor-dev/references/vimbuffer-api.md`:

**Cursor Movement**: cursor_line, cursor_col, set_cursor, word_forward,
word_backward, word_end

**Text Access**: text, set_text, line_text, line_length, line_count,
get_range, char_at, first_nonblank_col

**Text Manipulation**: insert_text, delete_range, replace_char, join_lines,
indent_lines, toggle_case, transform_range

**Undo/Redo**: undo, redo, modified, set_modified

**Search**: search_forward, search_backward

**Predicates**: at_line_start, at_line_end, at_buffer_end

If a needed method is NOT in this list, flag it in the output — it may need to
be added to VimBuffer.pm first.

### Step 8: Generate MERGE.md

Write step-by-step merge instructions telling the developer exactly where to
insert each piece of code:

```markdown
# Merge Instructions for [action_name]

## Files Modified
- `lib/Gtk3/SourceEditor/VimBindings/Normal.pm` (or appropriate module)
- `lib/Gtk3/SourceEditor/VimBindings/Command.pm` (description maps only)
- `t/vim_[feature].t` (new file)
- `doc/bindings.md` (append row to table)

## Merge Steps

### 1. Add action handler to Normal.pm
Location: Inside `register()` function, after the [similar_action] handler (around line XXX)
```perl
[paste the complete $ACTIONS->{action_name} = sub { ... }; code here]
```

### 2. Add keymap entry to Normal.pm
Location: In the return hash at the end of register(), in alphabetical order
```perl
key_name => 'action_name',
```

### 3. Add description to Command.pm
Location: In _build_desc_map(), alphabetically
```perl
action_name => 'short description',
```

### 4. If char_action, add to _char_actions
Location: In the _char_actions hash in Normal.pm's return
```perl
x => 'action_name',
```

### 5. If new prefix needed, add to _prefixes
Location: In the _prefixes array
```perl
_prefixes => [qw(g d y c greater less NEW_PREFIX)],
```

### 6. Copy test file
Copy `t/vim_[feature].t` to the project's `t/` directory.

### 7. Run verification
```bash
cd src
# Syntax check
perl -Ilib -It/lib -c lib/Gtk3/SourceEditor/VimBindings/Normal.pm
perl -Ilib -It/lib -c t/vim_[feature].t

# Run the new test
perl -Ilib -It/lib t/vim_[feature].t

# API check
perl script/check-api-methods.pl
```
```

## Output Tarball Structure

Generate the tarball with this exact structure:

```
new-binding-[action_name]/
├── MERGE.md                    # Step-by-step integration instructions
├── src/
│   ├── patches/
│   │   └── [Module].diff       # Context diffs for each modified file
│   └── new_files/
│       └── t/
│           └── vim_[feature].t # New test file
├── doc/
│   └── bindings-addition.md   # Doc snippet for doc/bindings.md
└── api-check.txt              # List of VimBuffer methods used (for verification)
```

Name the tarball: `new-binding-[action_name].tar.gz`

## GDK Key Name Reference

When the developer leaves "GDK key name" blank in the worksheet, use this
reference to determine the correct dispatcher key:

| Human Key | GDK Key Name | Notes |
|---|---|---|
| `$` | `dollar` | End of line |
| `^` | `caret` or `asciicircum` | First non-blank |
| `~` | `asciitilde` | Toggle case |
| `` ` `` | `grave` | Jump to mark |
| `'` | `apostrophe` | Jump to mark line |
| `%` | `percent` | Match bracket |
| `;` | `semicolon` | Repeat find |
| `,` | `comma` | Reverse find |
| `:` | `colon` | Enter command mode |
| `/` | `slash` | Search forward |
| `?` | `question` | Search backward |
| `\` | `backslash` | |
| `<` | `less` | Shift + comma |
| `>` | `greater` | Shift + period |
| `!` | `exclam` | |
| `@` | `at` | |
| `#` | `numbersign` | |
| `&` | `ampersand` | |
| `*` | `asterisk` | |
| `(` | `parenleft` | |
| `)` | `parenright` | |
| `-` | `minus` | |
| `_` | `underscore` | |
| `=` | `equal` | |
| `+` | `plus` | |
| `{` | `braceleft` | |
| `}` | `braceright` | |
| `[` | `bracketleft` | |
| `]` | `bracketright` | |
| `\|` | `bar` | |
| `Backspace` | `BackSpace` | Note capital S |
| `Delete` | `Delete` | |
| `Escape` | `Escape` | |
| `Tab` | `Tab` | |
| `Enter` | `Return` | GDK uses "Return" |
| `Home` | `Home` | |
| `End` | `End` | |
| `Page Up` | `Page_Up` | |
| `Page Down` | `Page_Down` | |
| Arrow keys | `Up`, `Down`, `Left`, `Right` | |

For **multi-character sequences** (e.g., `dd`, `dw`, `gg`), the keymap entry
is the concatenation of the GDK names of each character. Examples:
- `dd` → key is `dd`
- `dw` → key is `dw`
- `d$` → key is `d_dollar` (because `$` becomes `dollar`)
- `>>` → key is `greatergreater`
- `<<` → key is `lessless`
- `ciw` → key is `ciw` (three simple characters)
- `gq` → key is `gq`

## Important Rules

1. **Never call GTK methods directly** in VimBindings action handlers. Always go
   through `$ctx->{vb}` (VimBuffer abstraction). The only exception is accessing
   `$ctx->{gtk_view}` for clipboard operations, which must be wrapped in `eval {}`.

2. **Always handle the count parameter**. Even if count doesn't apply, accept it
   and ignore it. The pattern `$count ||= 1;` is standard for "default to 1".

3. **For delete/change operators**: always yank the deleted text to `$ctx->{yank_buf}`
   using the `$_set_yank` helper pattern from Normal.pm.

4. **For motions**: always update `$ctx->{desired_col}` for vertical movements and
   call `$ctx->{after_move}->($ctx)` to scroll into view.

5. **For undo/redo**: if the action modifies text, it's automatically wrapped in
   `begin_user_action`/`end_user_action` by the dispatcher. Don't add your own.
   Exception: undo/redo actions themselves must call `end_user_action` first.

6. **For mode transitions**: call `$ctx->{set_mode}->('mode')` — never manipulate
   `${$ctx->{vim_mode}}` directly.

7. **Cursor clamping**: always clamp cursor positions after deletions. The common
   pattern is:
   ```perl
   my $len = $vb->line_length($line);
   if ($col >= $len && $len > 0) {
       $vb->set_cursor($line, $len - 1);
   } elsif ($len == 0) {
       $vb->set_cursor($line, 0);
   }
   ```

## Quick Reference: ctx Fields

| Field | Type | Description |
|---|---|---|
| `$ctx->{vb}` | VimBuffer | Text editing interface (NEVER call GTK directly) |
| `$ctx->{vb}->cursor_line` | int | 0-based current line |
| `$ctx->{vb}->cursor_col` | int | 0-based current column |
| `${$ctx->{vim_mode}}` | str ref | Current mode (read via `${...}`, change via `set_mode`) |
| `$ctx->{set_mode}->($mode)` | coderef | Switch modes + update UI |
| `${$ctx->{yank_buf}}` | str ref | Yank/paste register content |
| `${$ctx->{cmd_buf}}` | str ref | Key accumulation buffer |
| `$ctx->{desired_col}` | int | Virtual column for vertical movement |
| `$ctx->{last_find}` | hashref | `{ cmd, char, count }` for f/F/t/T repeat |
| `$ctx->{marks}{$ch}` | hashref | `{ line, col }` for named marks |
| `$ctx->{line_snapshots}{$ln}` | str | For U (line-undo) |
| `$ctx->{search_pattern}` | str | Last search regex |
| `$ctx->{search_direction}` | str | 'forward' or 'backward' |
| `$ctx->{visual_type}` | str | 'char', 'line', or 'block' |
| `$ctx->{visual_start}` | hashref | `{ line, col }` selection anchor |
| `$ctx->{last_visual}` | hashref | `{ type, start_line, start_col, end_line, end_col }` for gv |
| `$ctx->{block_insert_info}` | hashref | For block I/A replay |
| `$ctx->{move_vert}->($count)` | coderef | Vertical movement with virtual column |
| `$ctx->{after_move}->($ctx)` | coderef | Scroll into view (no-op in tests) |
| `$ctx->{show_status}->($msg)` | coderef | Display temp status (3s auto-clear) |
| `$ctx->{clear_status}->($ctx)` | coderef | Clear status message |
| `$ctx->{page_size}` | int | Lines per viewport (default 20) |
| `$ctx->{shiftwidth}` | int | Indent width (default 4) |
| `$ctx->{tab_string}` | str | Tab character (default "\t") |
| `$ctx->{use_clipboard}` | bool | Copy yanks to system clipboard (default 0) |
| `$ctx->{is_readonly}` | bool | Block insert/replace transitions |
| `$ctx->{filename_ref}` | str ref | Current filename |
| `$ctx->{gtk_view}` | GtkWidget | Real GTK view (undef in tests) |
| `$ctx->{mode_label}` | GtkWidget | Mode indicator label |
| `$ctx->{cmd_entry}` | GtkWidget | Command entry widget |
| `$ctx->{pos_label}` | GtkWidget | Line:col display label |
| `$ctx->{set_cursor_mode}->($mode)` | coderef | 'block' or 'ibeam' cursor |
| `$ctx->{theme}` | hashref | `{ fg, bg }` theme colors |
| `$ctx->{resolved_keymap}` | hashref | Full merged keymap (for :bindings) |
| `$ctx->{ex_cmds}` | hashref | Ex-command dispatch table |

## Related Skills

- `p5-sourceeditor-dev` — Full project developer guide
- `perl-compile-check` — Running `perl -c` with mock objects
- `perl-gtk-api-verify` — Static GTK API method verification
