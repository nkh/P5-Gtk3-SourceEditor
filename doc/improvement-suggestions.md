# P5-Gtk3-SourceEditor -- Module Improvement Suggestions

> 13 Actionable Recommendations: 5 Architecture * 2 Code Quality * 6 Functionality
>
> April 2026 (updated -- 7 items completed and removed)

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [A. Architecture Changes (5)](#a-architecture-changes-5)
  - [A1. Adopt an Event-Driven Plugin Architecture](#a1-adopt-an-event-driven-plugin-architecture)
  - [A2. Unified Undo/Redo Transaction Model](#a2-unified-undoredo-transaction-model)
  - [A3. Text Object Abstraction Layer](#a3-text-object-abstraction-layer)
  - [A4. Context Object Refactor to State Machine](#a4-context-object-refactor-to-state-machine)
  - [A5. Async Operation Framework](#a5-async-operation-framework)
- [B. Code Quality Improvements (2)](#b-code-quality-improvements-2)
  - [B1. Structured Exception Handling](#b1-structured-exception-handling)
  - [B2. Perlcritic Compliance and CI Enforcement](#b2-perlcritic-compliance-and-ci-enforcement)
- [C. Functionality Additions (6)](#c-functionality-additions-6)
  - [C1. Dot-Repeat Command (.)](#c1-dot-repeat-command-)
  - [C2. Named Registers](#c2-named-registers)
  - [C3. Macro Recording and Playback (q)](#c3-macro-recording-and-playback-q)
  - [C4. Auto-Indent and Smart Indentation](#c4-auto-indent-and-smart-indentation)
  - [C5. Increment/Decrement Motion (Ctrl-A / Ctrl-X)](#c5-incrementdecrement-motion-ctrl-a--ctrl-x)
  - [C6. Substitute with Confirmation (:s with c flag)](#c6-substitute-with-confirmation-s-with-c-flag)
- [Implementation Roadmap](#implementation-roadmap)
- [Summary of All Suggestions](#summary-of-all-suggestions)
- [Completed Items](#completed-items)

---

## Executive Summary

**P5-Gtk3-SourceEditor** is a Perl module that provides a Vim-like modal editing layer on top of Gtk3::SourceView. After a thorough review of the entire codebase (~5,400 lines across 16 source files, 4 support modules, and 15 test files), this document originally presented 20 actionable improvement suggestions organized into three categories. **Seven of those items have been completed** and removed from this document (see the [Completed Items](#completed-items) section at the bottom for details), leaving 13 remaining recommendations.

The codebase demonstrates several strong design decisions, most notably the VimBuffer abstract interface that enables complete headless testing, and the action registry dispatch pattern that keeps mode-specific logic cleanly separated. However, there are meaningful opportunities for improvement in how the module handles state, error reporting, undo/redo semantics, and user-facing features. Each suggestion below includes a rationale, implementation approach, and expected impact on the module.

**Priority Legend:**
- [CRIT] **Critical** -- bug fix or fundamental gap
- [HIGH] **High** -- significant user-facing improvement
- [MED] **Medium** -- enhances maintainability or extends features
- [LOW] **Low** -- nice-to-have polish

| Category | Count | Focus Area |
|---|---|---|
| Architecture | 5 | Extensibility, state management, abstraction layers |
| Code Quality | 2 | Error handling, standards |
| Functionality | 6 | Core Vim features, registers, automation |

---

## A. Architecture Changes (5)

These suggestions address the structural foundation of the module. They require moderate-to-significant refactoring effort but will yield long-term dividends in maintainability, extensibility, and correctness. Each recommendation targets a specific architectural limitation observed during the codebase review.

### A1. Adopt an Event-Driven Plugin Architecture

**Priority:** [HIGH] High

**Problem:** The current dispatch system operates as a closed loop: key events arrive, are routed through mode-specific dispatch tables, and action coderefs execute directly against the VimBuffer interface. There is no mechanism for external code to observe, intercept, or extend behavior without modifying the core modules. This means every new feature (syntax-aware indentation, auto-completion triggers, LSP integration) requires patching VimBindings.pm or one of the mode sub-modules.

**Proposal:** Introduce a lightweight event bus with named hooks that fire at well-defined points in the editing lifecycle. Each hook carries a structured event object with context about what triggered it and allows subscribers to return values that influence subsequent processing. The key insight is that the existing action registry pattern already separates "what happened" from "what to do about it" -- we just need to expose intermediate states to external listeners.

**Hook Points:**

- `before_action(action_name, count, ctx)`
- `after_action(action_name, result, ctx)`
- `mode_change(old_mode, new_mode, ctx)`
- `buffer_modify(change_type, range, ctx)`
- `search_exec(pattern, direction, result, ctx)`

**Implementation:** Add an EventEmitter role (a simple hash-based pub/sub) to VimBindings.pm. Each hook stores a list of coderefs. In the `_dispatch()` method, wrap action execution with before/after hook calls. Return a dedicated `VimEditor::Events` module. This enables plugins like auto-indenters, brace matchers, or file watchers to subscribe to buffer modifications without touching core code.

**Impact:** Transforms the module from a monolithic Vim emulator into an extensible editor framework. Third-party distributions could ship plugins (e.g., `Gtk3::SourceEditor::Plugin::AutoPair`, `::Plugin::GitGutter`) that compose cleanly with the base module.

---

### A2. Unified Undo/Redo Transaction Model

**Priority:** [CRIT] Critical

**Problem:** Undo semantics differ dramatically between the two backends. `VimBuffer::Gtk3` delegates entirely to Gtk3::SourceBuffer's built-in undo stack, which operates at the GTK text insertion granularity -- a single `dd` command may create multiple undo points (one per character deleted). Meanwhile, `VimBuffer::Test` maintains its own snapshot-based undo system that captures the entire buffer state per operation. This divergence means tests cannot accurately validate undo behavior, and the Gtk3 backend's undo feels "wrong" to Vim users who expect command-level granularity.

**Proposal:** Introduce a transaction-based undo model at the VimBuffer abstraction level. Group related buffer mutations into atomic "transactions" that map to single user-visible commands. Each transaction captures a before/after state pair. The VimBuffer interface gains `begin_transaction()`, `commit_transaction()`, and `rollback_transaction()` methods. The redo operation is simply "undo the last undo." This unified model works identically on both backends.

**Implementation Sketch:**

```perl
# In VimBuffer.pm (abstract)
sub begin_transaction  { die 'Unimplemented' }
sub commit_transaction { die 'Unimplemented' }
sub rollback_transaction { die 'Unimplemented' }
sub redo              { die 'Unimplemented' }

# In VimBindings.pm, wrap every action execution:
sub _execute_action {
    my ($ctx, $action_name, $count, @extra) = @_;
    $ctx->{vb}->begin_transaction;
    my $result = $ACTIONS{$action_name}->($ctx, $count, @extra);
    $ctx->{vb}->commit_transaction;
    return $result;
}
```

The Gtk3 backend would call Gtk3::SourceBuffer's `begin_user_action()`/`end_user_action()` (which GTK already provides for grouping edits). The Test backend would snapshot before/after as it currently does, but now with an explicit redo stack.

**Impact:** Eliminates the undo granularity mismatch between backends, enabling accurate cross-backend testing. Adds redo support (Ctrl-R) as a natural consequence. Makes the undo model predictable and Vim-faithful.

---

### A3. Text Object Abstraction Layer

**Priority:** [HIGH] High

**Problem:** Vim's power comes largely from text objects: the ability to operate on semantic units like words (`iw`), sentences (`is`), paragraphs (`ip`), quoted strings (`i"`), function arguments (`if`), and HTML tags (`it`). The current architecture has no concept of "text objects" -- actions operate on raw character positions and line ranges. Adding operators like `diw` (delete inner word), `ci"` (change inside quotes), or `dap` (delete around paragraph) would require special-casing each combination in Normal.pm, leading to combinatorial explosion.

**Proposal:** Introduce a `VimTextObject` namespace that defines text object providers. Each provider implements a single method: `get_range($vb, $cursor_line, $cursor_col, $mode)` returning `($start_line, $start_col, $end_line, $end_col)`. The `$mode` parameter distinguishes "inner" (`i`) from "around" (`a`) variants. The dispatch system gains a third layer: **operator + text object composition**. Any operator (`d`, `c`, `y`, `v`) can combine with any text object, and new text objects can be added independently of operators.

**Dispatch Extension:**

```perl
# Grammar:  count operator [count] text-object
# Examples: d2w, ci", yip, da(, 3di{

# In dispatch, after resolving operator:
if ($is_operator && $pending_text_object) {
    my ($sl, $sc, $el, $ec) =
        VimTextObject::resolve($ctx, $text_obj_name, $inner_vs_around);
    $ACTIONS{"${op}_range"}->($ctx, $sl, $sc, $el, $ec);
}
```

Built-in text objects to implement initially: `iw` (inner word), `aw` (around word), `i"/i'/i`` (inner quotes), `a"/a'/a`` (around quotes), `i(` (inner parens), `a(` (around parens), `ip` (inner paragraph), `ap` (around paragraph). Each is a self-contained module in `VimBindings/TextObject/`.

**Impact:** Unlocks the most powerful editing paradigm in Vim. A single architecture change enables dozens of editing combinations without writing each one manually. Makes the module dramatically more useful for daily editing tasks.

---

### A4. Context Object Refactor to State Machine

**Priority:** [MED] Medium

**Problem:** The current `$ctx` hash is a flat, mutable dictionary with 20+ keys that grows organically as features are added. It mixes concerns: UI widgets (`gtk_view`, `mode_label`, `cmd_entry`), buffer state (`vb`, `yank_buf`, `marks`), configuration (`page_size`, `shiftwidth`), and behavioral closures (`set_mode`, `move_vert`, `after_move`). Any part of the code can read or modify any key, making it difficult to reason about state transitions, test in isolation, or serialize the editor state (e.g., for sessions or macros).

**Proposal:** Replace the flat `$ctx` hash with a formal state machine object. The state machine has explicit states (each mode), defined transitions (with guards and effects), and encapsulated data. A `Mode::State` class holds mode-specific transient data (like the command buffer accumulation in Normal mode or the search direction in Search mode). Configuration becomes a separate immutable object passed at construction time.

```perl
# Proposed structure:
Gtk3::SourceEditor::EditorState {
    config   : EditorConfig  (immutable: page_size, shiftwidth, keymaps)
    buffer   : VimBuffer     (the buffer adapter)
    ui       : UIPort        (widget handles, mode_label updates)
    registers: RegisterStore (named yank/delete registers)
    marks    : MarkStore     (named position markers)
    history  : CommandHistory (ex-command and search history)
    mode     : Mode::State   (current mode + mode-local state)
}

# Mode transitions are explicit:
$state->transition('insert', trigger => 'i');
# Calls: exit_normal() -> enter_insert() -> update_ui()
```

This approach gives clear ownership semantics: only the state machine can change modes, only the register store manages registers, and so on. It also makes serialization trivial for session persistence or macro replay.

**Impact:** Improves testability (each component can be mocked independently), enables session persistence, and makes mode transitions auditable. The refactoring can be done incrementally by wrapping the existing `$ctx` hash behind accessor methods.

---

### A5. Async Operation Framework

**Priority:** [LOW] Low

**Problem:** Every action in the current architecture executes synchronously within the GTK key-press-event handler. This works for simple operations like cursor movement, but blocks the UI for potentially slow operations: reading large files (`:e`), executing external filters (`!`), running search/replace across thousands of lines, or integrating with external tools (LSP, linters). The GTK main loop freezes until the action completes, degrading the user experience.

**Proposal:** Introduce an asynchronous action pattern using Glib's `idle_add` and `IO::Async` or `AnyEvent`. Long-running operations yield control back to the GTK main loop periodically, showing progress in the status bar. The VimBuffer interface gains async variants of expensive methods (`async_load`, `async_save`, `async_search_replace`). Actions that complete quickly remain synchronous.

**Implementation:** Define an `async_action` wrapper that accepts a generator-style callback. The callback receives a "yield" function that returns control to the GTK loop and resumes on the next idle tick. For file I/O, use Glib::IO's async file operations. For search/replace, process N matches per idle tick. The command-line entry shows progress (e.g., `Replacing... 42/200`).

**Impact:** Future-proofs the editor for integration with language servers, background linters, async file operations, and large-file handling. Without this, adding features like `:!grep` or LSP integration would require threading hacks or risk UI freezes.

---

## B. Code Quality Improvements (2)

These suggestions address reliability issues and development workflow improvements. They are generally lower effort than architecture changes but high impact on correctness and developer confidence.

### B1. Structured Exception Handling

**Priority:** [MED] Medium

**Problem:** Error handling throughout the codebase is inconsistent. The VimBuffer abstract interface uses `die 'Unimplemented'` for method stubs, which provides no stack context. GTK operations are wrapped in bare `eval` blocks that silently swallow errors (e.g., in Gtk3.pm's search methods). The command parser in Command.pm returns `undef` for unrecognized commands with no diagnostic information. When something goes wrong, the user sees either nothing or a generic GTK warning.

**Proposal:** Introduce a lightweight exception hierarchy using `Exception::Class` or a custom implementation. Define exception types for each failure category:

- `VimBuffer::X::OutOfBounds`
- `VimBuffer::X::ReadOnly`
- `VimBuffer::X::NoSuchFile`
- `VimBuffer::X::InvalidCommand`
- `VimBuffer::X::SearchFailed`

Each carries structured data (method name, attempted values, relevant context) rather than just a string message. The GTK signal handlers catch these exceptions and display user-friendly messages via the status bar or a non-blocking notification.

```perl
package Gtk3::SourceEditor::X::ReadOnly;
use Moo; extends 'Gtk3::SourceEditor::X';
has action => (is => 'ro', required => 1);

# Usage in actions:
if ($ctx->{is_readonly}) {
    Gtk3::SourceEditor::X::ReadOnly->throw(
        action  => 'delete',
        message => 'Cannot delete in read-only mode',
    );
}

# In signal handler:
eval { $self->_dispatch($ctx, $key) };
if (my $err = $@) {
    $ctx->{mode_label}->set_text($err->user_message);
}
```

**Impact:** Transforms error handling from ad-hoc string matching to a structured, debuggable system. Users get clear feedback instead of silent failures. Developers can trace error origins precisely. Enables logging and telemetry integration.

---

### B2. Perlcritic Compliance and CI Enforcement

**Priority:** [MED] Medium

**Problem:** While the codebase consistently uses `strict` and `warnings`, there is no perlcritic configuration, no coding standard enforcement, and no CI pipeline. Several observed issues include: inconsistent brace style (some modules use cuddled elses, others don't), bare `return` statements without explicit `undef`, assignment in conditional contexts (`$count ||= 1`), mixed indentation (some files use tabs, others spaces), and inconsistent POD section ordering across modules. Without automated enforcement, these inconsistencies accumulate over time.

**Proposal:** Add a `.perlcriticrc` file targeting "gentle" severity (level 5) as a baseline, with specific policies enabled/disabled to match the project's style. Key policies to enable:

- `ProhibitUnusedVariables`
- `RequireExplicitPackage`
- `ProhibitPostfixControls`
- `RequireConsistentNewlines`

Integrate perlcritic into the test suite via `Test::Perl::Critic`, and add it to a GitHub Actions or similar CI workflow that runs on every push.

**Additional standards:** Standardize on 4-space indentation (no tabs), cuddled else style, explicit `return undef` for error cases, and consistent POD section ordering (NAME, SYNOPSIS, DESCRIPTION, METHODS, AUTHOR, LICENSE). Add a `.editorconfig` file to enforce these across editors. Document the coding standard in a `CONTRIBUTING.md` file.

**Impact:** Prevents style drift, catches common mistakes automatically, and makes contributions from external developers easier by providing clear, automated standards.

---

## C. Functionality Additions (6)

These suggestions add concrete Vim features that users expect. They are ordered roughly by impact and dependency, with foundational features (dot-repeat, registers) listed before those that build upon them (macros, text objects). Each includes the Vim keystrokes involved and how it integrates with the existing dispatch architecture.

### C1. Dot-Repeat Command (.)

**Priority:** [CRIT] Critical

**Problem:** The dot command (`.`) is one of Vim's most powerful features: it repeats the last editing command. Without it, users must manually re-execute complex change sequences, which is tedious and error-prone. Currently, pressing `.` in normal mode does nothing.

**Implementation:** Add a `$ctx->{last_edit}` field that records the action name, count, and any extra arguments (like the replacement character for `r`, or the inserted text for `o`/`O`) each time an editing action executes. When `.` is pressed, replay the stored action with the same count and arguments. The key design decision is which actions qualify as "edits" for dot-repeat: insert-entry actions (`i`, `a`, `o`, `O`) should capture all text typed until Escape, while single-key edits (`x`, `dd`, `r`, `J`, `>>`) replay immediately. This requires recording the text entered during insert mode as part of the "last edit" record.

```perl
# On action execution:
$ctx->{last_edit} = {
    action   => 'change_word',
    count    => $count,
    inserted => 'replacement text',  # for insert-mode chains
};

# Dot-repeat action:
dot_repeat => sub {
    my ($ctx, $count) = @_;
    my $last = $ctx->{last_edit} or return;
    my $c = $count > 1 ? $count : ($last->{count} || 1);
    $ACTIONS{$last->{action}}->($ctx, $c, @{$last->{args}});
},
```

**Impact:** This single feature dramatically improves editing efficiency. It is consistently cited as one of the top reasons Vim users prefer modal editing. Combined with the action registry architecture, the implementation is clean and doesn't require special-casing individual actions.

---

### C2. Named Registers

**Priority:** [HIGH] High

**Problem:** The current implementation stores only a single yank buffer (`$ctx->{yank_buf}`). This means every yank or delete overwrites the previous content. Vim provides 26 named registers (`"a` through `"z`), a system clipboard register (`"+`), a black-hole register (`"_` for discarding content), and the unnamed register (`"`) that captures the most recent operation. Without named registers, users cannot accumulate text from multiple regions or perform structured multi-step edits.

**Implementation:** Replace the scalar `$ctx->{yank_buf}` with a `RegisterStore` object. The RegisterStore manages: (1) 26 named registers (a-z) that can be appended to with uppercase letters (`"A` appends to `"a`), (2) a special `+` register that syncs with the system clipboard via Gtk3::Clipboard, (3) the unnamed register `"` that always mirrors the most recent yank/delete, and (4) the black-hole register `"_` that discards content. The dispatch system adds a `_register_prefix` to the normal mode keymap for the `"` key, which reads the next character as the register name before executing the operator.

```perl
Gtk3::SourceEditor::RegisterStore {
    named     => { a => '', b => '', ... },  # 26 registers
    unnamed   => '',                         # " (default)
    clipboard => '',                         # "+ (system)
    linewise  => {},                         # track line vs char

    sub store {
        my ($self, $reg, $text, $linewise) = @_;
        if ($reg =~ /[A-Z]/) {
            # Uppercase = append to lowercase version
            $self->{named}{lc $reg} .= $text;
        } else {
            $self->{named}{$reg} = $text;
        }
        $self->{unnamed} = $text;
        $self->{linewise}{$reg} = $linewise;
    }
}
```

**Impact:** Enables powerful multi-step editing workflows. Users can yank multiple regions into different registers and paste them selectively. The system clipboard integration (`"+`) makes copy-paste between the editor and other applications seamless.

---

### C3. Macro Recording and Playback (q)

**Priority:** [MED] Medium

**Problem:** Macros are Vim's automation mechanism: record a sequence of keystrokes into a named register, then replay it any number of times. This enables repetitive editing at scale (e.g., reformatting 200 lines, applying a pattern-based change across a file). The current module has no macro capability.

**Implementation:** Leverage the existing `_char_actions` mechanism for the `q` key (register name follows). Maintain a `$ctx->{macro_recording}` hash that maps register names to accumulated key sequences. During recording, append each key to the current macro's sequence. On playback (`@{reg}`), feed the stored sequence through `simulate_keys()`. A critical detail: the recorded sequence should store high-level actions (action names + arguments) rather than raw key names, so macros are semantically stable even if keybindings change.

```perl
# Recording (q{reg} to start, q to stop):
macro_start => sub {
    my ($ctx, $count, $reg) = @_;
    $ctx->{macro_recording} = $reg;
    $ctx->{macro_buffer} = [];
    $ctx->{set_mode}->('macro_record');
},

# Playback (@{reg}):
macro_play => sub {
    my ($ctx, $count) = @_;
    my $reg = $ctx->{macro_target};
    my $seq = $ctx->{macros}{$reg} or return;
    for (1..($count||1)) {
        simulate_keys($ctx, @$seq);
    }
},
```

**Impact:** Macros unlock batch editing capabilities that would otherwise require external scripting. Combined with the existing action registry and `simulate_keys` infrastructure, the implementation is remarkably compact.

---

### C4. Auto-Indent and Smart Indentation

**Priority:** [MED] Medium

**Problem:** The current indentation handling is limited to manual `>>` and `<<` operations. When the user presses Enter (`o`, `O`) or pastes multi-line text (`p`), the new lines receive no indentation context. Gtk3::SourceView provides built-in auto-indentation that the module currently relies on, but this indentation is not Vim-aware -- it doesn't respect `shiftwidth`, it doesn't handle dedent-after-closing-brace, and it doesn't support language-specific rules.

**Implementation:** Override the GTK default auto-indent behavior by intercepting line insertion events. When a new line is created (via `o`, `O`, or Enter in insert mode), compute the appropriate indentation based on the previous line's leading whitespace and language-specific rules. A basic indentation engine handles: (1) preserve previous indentation (baseline), (2) increase indent after lines ending with `{`, `(`, `[`, or language-specific keywords (`sub`, `if`, `for`, `while`, `package`), (3) decrease indent for lines starting with `}`, `)`, `]`. The `shiftwidth` setting from `$ctx` controls the indent unit.

```perl
# Indent rules configuration (per-language):
my %indent_rules = (
    perl => {
        increase_after => qr/\b(sub|if|unless|for|foreach|while|until|else|elsif|do|eval|BEGIN|END)\b.*[{;]?\s*$/,
        decrease_if   => qr/^\s*[})\]]/,
    },
    c    => {
        increase_after => qr/[{]\s*$/,
        decrease_if   => qr/^\s*[}]/,
    },
);

# On Enter / o / O:
my $indent = _compute_indent($ctx, $prev_line);
$vb->insert_text($new_line . (' ' x $indent) . "\n");
```

**Impact:** Dramatically improves the editing experience for code. Users spend significant time manually adjusting indentation, and smart auto-indent eliminates most of this work. The language-specific rule table makes it extensible for new languages.

---

### C5. Increment/Decrement Motion (Ctrl-A / Ctrl-X)

**Priority:** [LOW] Low

**Problem:** Ctrl-A and Ctrl-X increment and decrement the number under or next to the cursor. This is surprisingly useful when editing sequential data: version numbers, port numbers, array indices, test case numbers, and ID fields. Without it, users must manually delete and retype numbers, which is error-prone when changing many values.

**Implementation:** Add a `find_number_on_line()` helper to VimBuffer that scans the current line for the nearest number (checking under cursor first, then forward). The `ctrl_a` action increments this number by the count; `ctrl_x` decrements it. Handle decimal, octal (leading `0`), and hexadecimal (`0x` prefix) number formats. Negative numbers and numbers embedded in identifiers (`var123`) should be handled correctly -- increment only the numeric suffix.

```perl
increment_number => sub {
    my ($ctx, $count) = @_;
    $count ||= 1;
    my $vb = $ctx->{vb};
    my $line = $vb->cursor_line;
    my $text = $vb->line_text($line);
    # Find number under or after cursor
    my $col = $vb->cursor_col;
    if ($text =~ /^(.{0,$col})(-?0x[\da-fA-F]+|-?\d+)/) {
        my $num_str = $2;
        my $prefix_len = length($1);
        my $val = ($num_str =~ /^0x/) ? hex($num_str) : 0+$num_str;
        $val += $count;
        my $new_str = ($num_str =~ /^0x/) ? sprintf('0x%X', $val) : $val;
        # Replace in buffer
        $vb->delete_range($line, $prefix_len, $line, $prefix_len + length($num_str));
        $vb->insert_text($new_str, $line, $prefix_len);
    }
},
```

**Impact:** A small but frequently useful feature that saves significant time when editing structured data. The implementation is straightforward and self-contained, making it a good candidate for an early contribution.

---

### C6. Substitute with Confirmation (:s with c flag)

**Priority:** [MED] Medium

**Problem:** The current `:s/pattern/replacement/g` command applies all replacements at once. In Vim, adding the `c` flag (`:s/pattern/replacement/gc`) makes the editor prompt for confirmation at each match, showing the matched text with the proposed replacement and allowing the user to accept (`y`), reject (`n`), accept all remaining (`a`), or quit (`q`). Without this, bulk replacements are all-or-nothing, which is risky for large files where some matches should be skipped.

**Implementation:** Modify the ex_command handler for `:s` to support the `c` flag. When `c` is present, iterate through matches one at a time. For each match, highlight the matched region, show a confirmation prompt (`y/n/a/q`) in the command entry or status bar, and wait for user input before proceeding. The Gtk3 backend can use Gtk3::SourceBuffer's `create_source_mark()` or text tags to highlight the match. The Test backend can simply record accepted/rejected counts for testing.

```perl
# In Command.pm's substitute handler:
if ($flags =~ /c/) {
    my $pos = 0;
    while (my $match = $text =~ /$pattern/g) {
        # Highlight match in GTK
        $ctx->{vb}->highlight_range($match_start, $match_end);
        # Prompt user
        my $response = $ctx->{confirm_fn}->('Replace? (y/n/a/q)');
        if ($response eq 'y') { apply_replacement(); }
        elsif ($response eq 'a') { apply_all_remaining(); last; }
        elsif ($response eq 'q') { last; }
        # 'n' = skip this match, continue
    }
} else {
    # Current behavior: replace all at once
}
```

**Impact:** Makes search-and-replace safe for use on large files. Users can confidently perform bulk operations knowing they can review each change. This is a standard Vim feature that users expect and rely on.

---

## Implementation Roadmap

The remaining 13 suggestions vary in complexity and dependency. The following roadmap shows the planned phases alongside actual progress.

| Phase | Items | Status | Rationale |
|---|---|---|---|
| **Phase 1:** Foundation | A2 | 0/1 done | Establish unified undo model. (Original Phase 1 items B1, B3, B5 completed and removed.) |
| **Phase 2:** Core Editing | C1 | 0/1 done | Add dot-repeat. (Original Phase 2 items C2, C3, C5, C7 completed and removed.) |
| **Phase 3:** Advanced Features | C2, C3, C4, C6, A3 | 0/5 done | Named registers, macro recording, auto-indent, substitute-with-confirm, text objects. |
| **Phase 4:** Polish | A1, A4, A5, B1, B2, C5 | 0/6 done | Event-driven plugins, state machine refactor, async framework, structured exceptions, perlcritic CI, increment/decrement. |

**Bonus feature (not in original 20):** `vim_mode` toggle -- option to disable Vim bindings and use native Gtk3::SourceView keybindings (`vim_mode => 0`). Implemented in commit `fb61549`.

**Overall progress: 7 of 20 original suggestions completed (35%), 13 remaining, plus vim_mode option.**

---

## Summary of All Suggestions

| # | Pri | Suggestion | Category | Key Benefit |
|---|---|---|---|---|
| A1 | [HIGH] | Event-Driven Plugins | Architecture | Extensible plugin ecosystem |
| A2 | [CRIT] | Unified Undo/Redo | Architecture | Consistent cross-backend behavior |
| A3 | [HIGH] | Text Object Layer | Architecture | Operator+object composition |
| A4 | [MED] | State Machine Refactor | Architecture | Clean state management |
| A5 | [LOW] | Async Operations | Architecture | Non-blocking UI for slow ops |
| B1 | [MED] | Structured Exceptions | Code Quality | Clear error diagnostics |
| B2 | [MED] | Perlcritic + CI | Code Quality | Automated code standards |
| C1 | [CRIT] | Dot-Repeat (.) | Functionality | Most impactful Vim feature |
| C2 | [HIGH] | Named Registers | Functionality | Multi-step editing workflows |
| C3 | [MED] | Macro Recording | Functionality | Batch editing automation |
| C4 | [MED] | Auto-Indent | Functionality | Smart code indentation |
| C5 | [LOW] | Ctrl-A / Ctrl-X | Functionality | Number increment/decrement |
| C6 | [MED] | :s with Confirm | Functionality | Safe bulk replacement |

---

## Completed Items

The following items from the original 20 recommendations have been implemented and removed from the active suggestions above.

| Original # | Suggestion | Category | Commit | Description |
|---|---|---|---|---|
| B1 | Fix the Control-Mask Bug | Code Quality | `96270c2` | Fixed `['control-mask']` array ref bug in VimBindings.pm that caused unreliable Ctrl-key handling. |
| B3 | Comprehensive Test Coverage Expansion | Code Quality | `1036c4b` | Expanded test suite from 109 to ~290 subtests across 15 test files, covering visual mode, search, replace, editing, marks, buffer abstract interface, completion, ctrl keys, plugin loading, find-character motions, dispatch, and ex-commands. |
| B5 | Fix Module Naming and Version Synchronization | Code Quality | `96270c2` | Fixed Build.PL module name mismatch (`Gtk3::SourceViewEditor` -> `Gtk3::SourceEditor`) and centralized `$VERSION` across all sub-modules. |
| C2 | Find-Character Motions (f/F/t/T) | Functionality | `5bc5011` | Implemented `f`, `F`, `t`, `T` character-find motions plus `;` and `,` repeat motions via the existing `_char_actions` infrastructure. |
| C3 | Virtual Column Tracking | Functionality | `5bc5011` | Added `$ctx->{desired_col}` tracking so vertical navigation (`j`/`k`) preserves the intended horizontal position across lines of varying length. |
| C5 | Ctrl-Key Scroll and Paging | Functionality | `fb61549` | Implemented Ctrl-u/d (half-page), Ctrl-f/b (full page), Ctrl-y/e (line scroll), Ctrl-r (redo), Ctrl-o/i (jump list) via extended `_ctrl` keymap. Also added `vim_mode` toggle option. |
| C7 | Bracket Matching (% Motion) | Functionality | `5bc5011` | Implemented `%` motion for matching `()`, `[]`, `{}` brackets with nesting-aware multi-line scanning and operator support (`d%`, `y%`, `c%`). |
