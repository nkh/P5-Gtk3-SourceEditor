# Binding Creation Skill — Design Rationale

This document explains every design decision in the binding-creation skill in
depth. It exists so that future maintainers (both human and AI) can understand
*why* the worksheet is structured the way it is, *why* certain fields are
mandatory, and *why* the output format is an isolated tarball rather than
inline code patches.

If you are tempted to simplify the worksheet, remove a field, or change the
tarball structure, read the relevant section here first.

---

## 1. Why a Worksheet at All?

### The Problem: AI Context Limits

When an AI agent is asked to "add the `diw` binding", it must understand:

- The project's file organization (which of 15 `.pm` files to modify)
- The binding dispatch architecture (5 different dispatch mechanisms)
- The VimBuffer abstraction layer (27 methods, 2 backends)
- The keymap hash structure (`_prefixes`, `_char_actions`, `_immediate`, `_ctrl`)
- The test infrastructure (headless VimBuffer::Test, mock objects)
- The documentation system (`:bindings` help text, `doc/bindings.md`)
- GDK key name mappings (`$` → `dollar`, `^` → `caret`)
- The `_build_desc_map` and `_build_key_name_map` in Command.pm
- Edge cases specific to the project (0-based coordinates, cursor clamping, undo grouping)

Reading and understanding all of this from source code consumes a massive
amount of the AI's context window, leaving less capacity for actually writing
correct implementation code. The worksheet pre-digests all of this context into
a structured form that the AI can consume in seconds.

### The Zero-Context Principle

The worksheet is designed under the principle that the AI receiving it has
**zero prior knowledge** of the project. This is intentional for three reasons:

1. **Session isolation**: A new AI session may have no memory of previous work
   on this project. The worksheet must be self-contained.

2. **Cross-agent compatibility**: Different AI models or different agent
   implementations should all be able to produce correct output from the same
   worksheet.

3. **Human review**: A developer should be able to read the worksheet and
   verify that all necessary information is captured without needing to consult
   source code.

### Why Not Just "Add the diw Command"?

Free-form requests like "add diw" force the AI to make assumptions about:
- Which motion semantics to use (word boundaries? inner word? what about punctuation?)
- Whether `2diw` should delete 2 inner words or the inner word at column 2
- Whether the deleted text should go to yank_buf
- Whether it should work in visual mode
- What the cursor position should be after deletion

Each of these assumptions could be wrong, leading to code that must be revised.
The worksheet makes every decision explicit upfront, eliminating guesswork.

---

## 2. Why 14 Fields (Not Fewer, Not More)?

The worksheet has 14 fields organized into 8 sections. This number was arrived at
through analysis of every binding-related bug and ambiguity encountered during
the project's development.

### Fields That Were Almost Omitted (But Proved Essential)

**GDK Key Name (Field 3b)**: Initially we considered letting the AI determine
the GDK key name from the human key sequence. This failed because GDK names are
not always predictable: `$` becomes `dollar` but `d$` becomes `d_dollar` (with
an underscore separator), `>>` becomes `greatergreater`, and `^` can be either
`caret` or `asciicircum` depending on the keyboard layout. Making the developer
responsible for this field would require them to know GDK internals, so we made
it optional with "leave blank if unsure" — the AI can determine it from the key
sequence using the reference table.

**Dispatch Type (Field 2b)**: This field was added after we realized that "mode"
alone is insufficient. Within a single mode (normal), there are 5 completely
different code patterns: simple actions, char-actions, operator+motion
combinations, ex-commands, and mode transitions. Each has a different function
signature, different registration mechanism, and different test patterns. Without
this field, the AI must infer the dispatch type from the key sequence, which is
ambiguous (e.g., is `gq` a two-character simple action or a char-action?).

**Similar Existing Bindings (Field 5a)**: This is the single most impactful
field for code quality. By naming 2-3 existing bindings that are similar, the
developer gives the AI concrete code templates to mimic. This dramatically
reduces style inconsistencies, ensures proper use of helpers like `$_set_yank`
and `$_save_line_snapshot`, and means the AI doesn't need to invent the
implementation pattern from scratch. For example, if the developer says
"similar to: delete_word, delete_line", the AI knows to use `get_range` +
`delete_range` + `$_set_yank` + cursor clamping — because that's what both of
those existing handlers do.

### Fields That Were Considered (But Rejected)

**"Output file path"**: We considered asking the developer to specify exactly
where the code should go. Rejected because (a) the dispatch type + mode already
determines the target file unambiguously, and (b) the AI-generated MERGE.md
provides precise line-number-level merge instructions anyway.

**"Priority/urgency"**: Rejected because the worksheet is a specification, not
a task tracker. Priority is irrelevant to code generation.

**"Vim version compatibility"**: We briefly considered asking "does this match
Vim 7, Vim 8, or Neovim behavior?" Rejected because this project implements a
subset of Vim behavior that may intentionally differ from any specific Vim
version. The "Detailed behavior" field is sufficient for specifying exactly what
should happen.

**"Keyboard layout considerations"**: Rejected because GDK abstracts keyboard
layouts — the key names in the keymap are layout-independent GDK key names, not
physical key positions.

---

## 3. Why Dispatch Type Is a Separate Field from Mode

In Vim's keybinding system, a "mode" defines *when* a binding is active, while a
"dispatch type" defines *how* the binding is processed. These are orthogonal
concerns that happen to be correlated in practice (most char-actions are in
normal mode), but are not the same thing.

### The Five Dispatch Types Explained

**1. Simple action**: A single key (or fixed key sequence like `dd`, `gg`)
that maps directly to an action handler. The handler receives `($ctx, $count)`.
Most bindings fall into this category. Examples: `h`, `j`, `x`, `dd`, `yy`,
`>>`, `G`, `gg`.

**2. Char-action**: A two-step dispatch where the first key sets a "pending"
state and the second key is passed as an argument. The handler receives
`($ctx, $count, $extra_char)`. This mechanism exists because Vim has commands
like `f{char}` (find character), `r{char}` (replace character), `m{a-z}`
(set mark) where the second keystroke is data, not a command. Without this
distinction, the AI might generate a simple action handler that doesn't accept
the `@extra` parameter, causing the char argument to be silently lost.

**3. Operator+motion**: A composite command like `dw`, `d$`, `ciw`, `yiw`
that combines an operator (delete, change, yank) with a motion (word, end-of-
line, inner-word). In this project, these are implemented as individual simple
actions (not a compositional operator-pending mode), but they share a common
code pattern: save start position, perform motion, extract range, yank if
applicable, delete if applicable, restore cursor. The dispatch type tells the AI
to follow this pattern rather than a simple motion pattern.

**4. Ex-command**: Commands entered via the command line (`:w`, `:q`, `:s/foo/bar/`).
These have a completely different handler signature `($ctx, $count, $parsed)` where
`$parsed` is a hashref `{ cmd, args, bang, range, line_number }` produced by the
ex-command parser. They also register in a different keymap (the Command.pm
return hash, not the Normal.pm keymap).

**5. Mode transition**: Commands that switch the editor mode (e.g., `i` enters
insert mode, `v` enters visual mode). These are simple actions that primarily
call `$ctx->{set_mode}->(...)`, but they're distinguished because they often
need to adjust the cursor position before transitioning and must never modify
text (so no undo grouping concerns).

### Why This Matters for Code Generation

Each dispatch type produces code with a different function signature, different
registration mechanism, and different test pattern. If the AI guesses the wrong
dispatch type, it will generate code that:
- Has the wrong parameter list (missing `@extra` for char-actions)
- Registers in the wrong place (ex-command handler in the normal keymap)
- Has the wrong test structure (testing an ex-command with `simulate_keys` instead
  of `handle_command_entry`)
- Doesn't interact correctly with the key accumulation buffer

---

## 4. Why Text Impact Is Explicit

The "text impact" field (motion / delete / change / yank / mode_switch / other)
determines several critical implementation details that the AI must handle
correctly:

### Yank Buffer Interaction

Only `delete` and `change` operations should populate `$ctx->{yank_buf}`. A
common mistake is to have a `yank` operation overwrite the yank buffer with the
wrong scope (e.g., yanking the motion range instead of the text range). By
explicitly stating "yank", the developer signals that the AI should set
`${$ctx->{yank_buf}}` but NOT delete any text.

### Undo Grouping

All text modifications (delete, change) are automatically wrapped in
`begin_user_action`/`end_user_action` by the `_dispatch` method in
VimBindings.pm. Motions do NOT modify text, so they don't need undo grouping.
Mode transitions don't either. If the AI misidentifies a motion as a change, it
might add redundant undo grouping or forget to save line snapshots.

### Cursor Behavior

- **Motions**: Update `$ctx->{desired_col}`, call `$ctx->{after_move}->($ctx)`
- **Deletes**: Clamp cursor, restore to start position
- **Changes**: Place cursor at the modification point, enter insert mode
- **Yanks**: Restore cursor to original position (yank doesn't move cursor)
- **Mode transitions**: Adjust cursor if needed, then call `set_mode`

### The "other" Escape Hatch

The "other" option exists because some commands don't fit neatly into the
categories. For example, the `J` (join lines) command modifies text (it's not a
pure motion) but it's also not a standard delete/change pattern (it doesn't
yank the deleted whitespace). The `~` (toggle case) in visual mode is another
hybrid. By allowing "other:____", the worksheet doesn't force a false
categorization.

---

## 5. Why Count Behavior Is a Dedicated Field

Numeric count prefixes are one of Vim's most powerful features, but they have
subtly different semantics for different commands:

### The Three Common Patterns

**repeat_N_times**: The count means "do this N times". For example, `3dd` deletes
3 lines, `2j` moves down 2 lines, `5x` deletes 5 characters. The implementation
is typically a loop: `for (1 .. $count) { ... }`.

**Nth_occurrence**: The count means "find the Nth occurrence". For example,
`3fx` finds the 3rd 'x' on the line. The implementation is a search with a
counter, not a simple loop. This is semantically different from "repeat find
3 times" because the search should be stateless (the cursor doesn't move to
intermediate matches).

**None**: The count is ignored. For example, `G` (go to last line) uses the
count as a line number (not a repeat count), and `0` (go to line start) always
means column 0 regardless of any numeric prefix.

### Why "Default Count" Matters

The default count when no numeric prefix is given varies:
- Most commands default to 1 (`3dd` = 3, `dd` = 1)
- Some commands default to 0 (not common in this project)
- Some are context-dependent (`G` without count = last line, `5G` = line 5)

If the AI assumes `default 1` for a command that should be context-dependent,
the behavior will be wrong. Making this explicit in the worksheet prevents the
assumption.

---

## 6. Why Structured Test Scenarios (Not Free Text)

The test scenarios section uses a rigid structure:

```
Buffer → Cursor → Mode → Keys → Expected text → Expected cursor → Expected yank_buf
```

This is deliberately not free-form "describe what should happen" text. Here's why:

### Ambiguity Elimination

Free-text descriptions like "it should delete the word and leave the cursor at
the start" are ambiguous about:
- What counts as a "word"? (Alphanumeric only? Include underscores? Punctuation?)
- Where exactly is "the start"? (First character of the word? Character before it?)
- What happens to trailing whitespace?
- What's in the yank buffer after?

The structured format forces every aspect to be specified numerically, which is
unambiguous and directly translatable to test assertions.

### Direct Transcription to Test Code

The structured test scenario maps 1:1 to test code:

```
Buffer: "hello world\n"     → VimBuffer::Test->new(text => "hello world\n")
Cursor: line 0, col 6       → $vb->set_cursor(0, 6)
Keys: dw                    → simulate_keys($ctx, 'd', 'w')
Expected text: "hello \n"   → is($vb->text, "hello \n", "...")
Expected cursor: 0, 5       → is($vb->cursor_line, 0, "..."); is($vb->cursor_col, 5, "...")
```

An AI can generate complete, runnable test code from this without interpretation.

### Edge Case Coverage

By requiring separate "edge case" scenarios (in addition to "basic" and "with
count"), the worksheet forces the developer to think about boundary conditions
before the AI writes code. This is significantly cheaper than having the AI
write code, run it, discover edge case failures, and iterate.

---

## 7. Why the Output Is an Isolated Tarball (Not Inline Code)

### The Developer's Workflow

When a developer requests a new binding, they want to:
1. Review the proposed implementation in isolation
2. Run the tests in isolation (without risking the main codebase)
3. Iterate on the implementation if needed
4. Merge into the main project when satisfied

An isolated tarball supports this workflow. The developer can extract it to a
temporary directory, examine the patches, run the test file, and only merge when
ready. Inline code that's already been applied to the main project doesn't allow
this — you'd have to revert if something is wrong.

### The MERGE.md File

The `MERGE.md` file is the key innovation. It doesn't just say "add this code
to Normal.pm" — it says "add this code to Normal.pm, inside the `register()`
function, after the `delete_word` handler, around line 653." This precision is
critical because:

1. The Normal.pm file is 1160+ lines. Finding the right insertion point by
   searching is error-prone.
2. Bindings are organized in logical sections (Navigation, Editing, Yank/Paste,
   Indentation, etc.). Inserting in the wrong section breaks the organization.
3. The keymap entries at the bottom must be in a consistent order for
   readability.

### Why Patches Instead of Full Files

The tarball contains context diffs (not full replacement files) because:
1. The full Normal.pm is 1160 lines — including all of it in a patch would be
   noisy and hard to review.
2. Context diffs show exactly what changed and where, making review trivial.
3. If the main file has been modified since the patch was generated, a context
   diff is more likely to apply cleanly than a full file replacement (offsets
   can be adjusted by `patch`).

---

## 8. Why "Similar Existing Bindings" Is Required

This is the most important field for **code consistency**.

### The Problem Without It

Without naming similar bindings, the AI must choose a code style based on
general patterns. This leads to inconsistencies like:

```perl
# AI generates style A (using get_range + delete_range)
$ACTIONS->{my_delete} = sub {
    my ($ctx, $count) = @_;
    my $vb = $ctx->{vb};
    my $text = $vb->get_range(...);
    $vb->delete_range(...);
    ${$ctx->{yank_buf}} = $text;
};

# But existing code uses style B (via $_set_yank helper)
$ACTIONS->{delete_line} = sub {
    # ...
    $_set_yank->($ctx, $yanked);
};
```

Both are functionally correct, but mixing styles makes the codebase harder to
maintain. By pointing to `delete_line` as a similar binding, the AI will use
`$_set_yank` consistently.

### The Pattern Replication Benefit

Existing bindings encode dozens of project-specific conventions that aren't
documented anywhere:

- The `$_save_line_snapshot->($ctx)` call before navigation motions (for `U`
  line-undo support)
- The cursor clamping pattern after deletions
- The `$ctx->{desired_col}` update for vertical motions
- The `$ctx->{after_move}->($ctx)` call for scrolling
- The `eval { }` wrapper for GTK clipboard operations
- The `$_set_yank` helper that handles both yank_buf and system clipboard

A developer filling out the worksheet shouldn't need to know all of these. By
naming a similar existing binding, they delegate this knowledge to the AI, which
will read the existing handler and replicate its conventions.

---

## 9. Why VimBuffer Methods Are Listed Explicitly

The VimBuffer abstraction has 27 methods across 5 categories. When an AI
generates code, it might try to call methods that don't exist on VimBuffer:

```perl
# WRONG — VimBuffer has no "get_selection_bounds" method
my ($sl, $sc, $el, $ec) = $vb->get_selection_bounds;

# CORRECT — use $ctx->{visual_start} + cursor position
my $s = $ctx->{visual_start};
```

By listing the required methods in the worksheet, the AI can verify them against
the VimBuffer API reference before generating code. If a needed method isn't in
the VimBuffer interface, the AI can flag this in the output rather than
generating code that won't compile.

This field also serves as a dependency check: if the new binding needs
`search_forward` and `transform_range`, the AI knows to test both and ensure the
test file covers scenarios that exercise both methods.

---

## 10. Why "Direct GTK Access Needed?" Matters

The VimBuffer abstraction exists precisely to avoid direct GTK calls in binding
handlers. However, a few legitimate exceptions exist:

- **Clipboard operations**: `$ctx->{gtk_view}` is needed to access
  `Gtk3::Clipboard::get_default()` for system clipboard integration.
- **Scroll adjustments**: `Ctrl-y` and `Ctrl-e` need access to the view's
  vertical adjustment (`get_vadjustment`) to scroll without moving the cursor.
- **Dialog creation**: Ex-commands like `:browse` need to create GTK dialogs.

Each of these must be wrapped in `eval { }` because they won't work in the
headless test environment (`$ctx->{gtk_view}` is `undef` in tests). If the AI
generates a binding that accesses GTK directly without `eval { }`, the tests
will crash.

This field forces the developer to think about whether their binding needs GTK
access, and the AI can then add the appropriate `eval { }` guards and
`return unless $view` checks.

---

## 11. Why Edge Cases Are a Separate Section

Edge cases are separated from the main test scenarios because they test
different properties:

- **Basic test**: Does the command work correctly in the common case?
- **Count test**: Does the numeric prefix work correctly?
- **Edge cases**: Does the command handle boundary conditions gracefully?

Boundary conditions are where most binding bugs occur. Common ones in this
project:

**Empty buffer**: Many commands assume there's at least one line. `dd` on an
empty buffer, `cw` on an empty line, `J` on the last line — all have special
behavior.

**EOF/BOF**: `k` at line 0, `j` at the last line, `dw` at the end of the last
line, `gg` with count 99999 — the cursor must be clamped, not wrap around or
crash.

**Read-only mode**: The `$ctx->{is_readonly}` flag should block insert/replace
transitions. If a new command enters insert mode, it should check this flag.

**Visual mode interaction**: Some normal-mode commands should work differently
in visual mode (e.g., `U` is undo in normal but uppercase in visual). If a new
binding conflicts with an existing visual mode binding, this must be resolved.

**Undo behavior**: Should `3dd` be a single undo step or three? In this project,
the dispatcher wraps the entire action in one `begin_user_action`/`end_user_action`
pair, so `3dd` is one undo step. But if a new command has internal undo
implications (like the `U` line-undo which is independent of the main undo
stack), this needs special handling.

By making edge cases explicit, the developer is forced to consider these before
code is written. Post-hoc edge case discovery is expensive: it requires code
changes, test additions, and potential regression risks.

---

## 12. Why the Tarball Structure Is Opinionated

The tarball has a fixed directory layout:

```
new-binding-[action_name]/
├── MERGE.md
├── src/patches/[Module].diff
├── src/new_files/t/vim_[feature].t
├── doc/bindings-addition.md
└── api-check.txt
```

This layout was chosen for specific reasons:

**MERGE.md at root**: This is the first file the developer will open. It should
be immediately visible, not buried in a subdirectory.

**src/patches/ vs src/new_files/**: Separating patches (modifications to
existing files) from new files makes it clear what's a change and what's an
addition. The developer can review patches first (high risk) then look at new
files (lower risk).

**api-check.txt**: A plain text list of every VimBuffer method used by the new
binding. This allows the developer (or a CI script) to quickly verify that all
methods exist without reading the implementation code. This is especially useful
when adding methods to VimBuffer that don't exist yet.

**doc/bindings-addition.md**: A standalone markdown snippet with just the new
binding's documentation row. The developer can copy-paste this into
`doc/bindings.md` without manually writing documentation.

---

## 13. Why the GDK Key Name Reference Table Exists

GDK key names are not intuitive. Several common pitfalls:

| Human Key | Wrong Guess | Correct GDK Name |
|---|---|---|
| `$` | `dollar_sign` | `dollar` |
| `^` | `circumflex` | `caret` or `asciicircum` |
| `` ` `` | `backtick` | `grave` |
| `Backspace` | `backspace` | `BackSpace` (capital S) |
| `Enter` | `enter` | `Return` |
| `Page Up` | `pageup` | `Page_Up` |

Without a reference table, the AI would need to guess or look up the correct
GDK name for each key. Wrong guesses cause the binding to silently fail (the
key is pressed but doesn't match any keymap entry, so it's discarded by the
dispatcher's "miss" handler).

For multi-character sequences, the problem compounds. `d$` becomes `d_dollar`
(underscore-joined), `>>` becomes `greatergreater` (direct concatenation of the
GDK names for `>`), but `ciw` stays `ciw` (all simple characters). The rules
for when to use underscore joining vs direct concatenation are not documented
anywhere in GDK — they're a convention used by this project's dispatcher.

---

## 14. Why the Skill Has "Important Rules" Section

The 7 rules at the end of the skill document encode hard-won knowledge from
specific bugs that occurred during development:

**Rule 1 (Never call GTK directly)**: This was the motivation for the entire
`perl-gtk-api-verify` skill. A method call like
`$self->{buffer}->set_highlight_matching_brackets(TRUE)` that should have been
`$self->{view}->...` caused a runtime crash that `perl -c` couldn't catch. In
the binding system, this rule is even stricter because ALL binding handlers
operate through VimBuffer — they literally cannot access GTK objects except
through `$ctx->{gtk_view}` (which is for clipboard/scroll exceptions only).

**Rule 2 (Always handle count)**: The dispatcher's `_extract_count()` strips
the numeric prefix and passes the remainder. If a handler doesn't accept `$count`,
it will receive the key string as the first argument instead, causing confusing
behavior like `3dd` being interpreted as a bare `3` key press.

**Rule 3 (Yank on delete/change)**: Early implementations of `dw` forgot to
yank the deleted word, meaning `dw` followed by `p` would paste the previously
yanked text instead of the just-deleted word. This violated user expectations
based on real Vim behavior.

**Rule 4 (desired_col + after_move)**: Forgetting to update `desired_col` after
horizontal motions causes the cursor to "snap back" to its previous column when
moving vertically afterward (e.g., `llj` — move right twice, then down — would
place the cursor at column 0 instead of column 2 if `desired_col` wasn't set).

**Rule 5 (Undo grouping)**: The `undo` and `redo` actions must call
`end_user_action` before performing their operation. If they don't, the undo
call is absorbed into the current undo group (started by `_dispatch`) and has
no net effect. This was a real bug that caused `u` to appear broken.

**Rule 6 (Use set_mode, not direct assignment)**: `${$ctx->{vim_mode}}` is a
scalar ref that's shared with the SourceEditor widget (which uses it to update
the mode label). Changing it directly bypasses the `set_mode` closure which
updates the UI. The result is the mode label showing "INSERT" while the editor
is actually in normal mode.

**Rule 7 (Cursor clamping)**: After a deletion, the cursor column may exceed the
new line length. Without clamping, the cursor can end up "past the end" of the
line, which causes subsequent insertions to add characters at incorrect
positions.

---

## 15. Why This Skill Exists as a Separate Document

The binding-creation skill could have been a section in the `p5-sourceeditor-dev`
skill. It was separated for three reasons:

1. **Focus**: The developer guide covers the entire project. The binding
   creation skill covers exactly one workflow. When an AI agent needs to create
   a binding, loading the full developer guide wastes context. Loading just the
   binding creation skill is more efficient.

2. **Worksheet format**: The worksheet is a machine-readable template that the
   AI should follow step by step. Embedding it in a general developer guide would
   dilute its structure.

3. **Evolution**: The binding system may change independently of the rest of
   the project (e.g., adding operator-pending mode would change the dispatch
   types). Having a separate skill makes it easy to update the binding workflow
   without touching the general developer guide.

This rationale document exists as its own file (rather than comments in the
skill) because the rationale is long-form prose that would make the skill
document itself too large. When an AI needs to create a binding, it should read
the SKILL.md (concise instructions). When a human needs to understand or modify
the skill itself, they should read this file.
