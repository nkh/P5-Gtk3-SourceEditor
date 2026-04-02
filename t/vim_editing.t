#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# Editing operations — cc, cw, C, J, >>, <<, xp, O, o, r, count prefixes,
# boundary conditions
# ==========================================================================

# --- cc (change line) ---
subtest 'Edit: cc changes current line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(1, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'c', 'c');
    is(${$ctx->{vim_mode}}, 'insert', 'cc enters insert mode');
    is(${$ctx->{yank_buf}}, "line2\n", 'cc yanks the line');
    is($vb->text, "line1\n\nline3\n", 'cc clears the line content');
    is($vb->cursor_col, 0, 'cursor at start of cleared line');
};

# --- cw (change word) ---
subtest 'Edit: cw changes word' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'c', 'w');
    is(${$ctx->{vim_mode}}, 'insert', 'cw enters insert mode');
    is($vb->text, "world\n", 'cw deletes word');
    is($vb->cursor_col, 0, 'cursor at start');
};

# --- C (change to end of line) ---
subtest 'Edit: C changes to end of line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 5);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'C');
    is(${$ctx->{vim_mode}}, 'insert', 'C enters insert mode');
    is($vb->text, "hello\n", 'C deletes from cursor to end of line');
    is($vb->cursor_col, 5, 'cursor stays at position 5');
};

# --- C at start of line ---
subtest 'Edit: C at start of line clears entire line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'C');
    is($vb->text, "\n", 'C at col 0 clears line');
    is(${$ctx->{vim_mode}}, 'insert', 'C enters insert mode');
};

# --- J (join lines) ---
subtest 'Edit: J joins current and next line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'J');
    is($vb->text, "line1 line2\nline3\n", 'J joins two lines with space');
};

subtest 'Edit: 2J joins 3 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\ndd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'J');
    is($vb->text, "aa bb cc\ndd\n", '2J joins 3 lines');
};

# --- >> (indent right) ---
subtest 'Edit: >> indents current line right' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb, shiftwidth => 2);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'greater', 'greater');
    is($vb->line_text(0), "  line1", '>> indents with 2 spaces');
};

subtest 'Edit: 2>> indents 2 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb, shiftwidth => 4);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'greater', 'greater');
    is($vb->line_text(0), "    line1", 'first line indented');
    is($vb->line_text(1), "    line2", 'second line indented');
    is($vb->line_text(2), "line3", 'third line unchanged');
};

# --- << (indent left) ---
subtest 'Edit: << unindents current line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "    line1\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb, shiftwidth => 4);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'less', 'less');
    is($vb->line_text(0), "line1", '<< removes indentation');
};

# --- r (replace character) ---
subtest 'Edit: r replaces character under cursor' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'r', 'X');
    is($vb->text, "Xello\n", 'r replaces char at cursor');
};

subtest 'Edit: r at end of line does nothing' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ab\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 2);  # at end of line

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'r', 'Z');
    is($vb->text, "ab\n", 'r at end of line is no-op');
};

# --- xp (swap adjacent characters) ---
# x deletes char under cursor into yank_buf, then p pastes after cursor.
subtest 'Edit: xp swaps adjacent characters' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x', 'p');
    # x at (0,0): deletes 'h' → "ello", yank_buf="h", cursor at (0,0)
    # p: charwise, not at line_end → move to (0,1), insert 'h' → "ehllo"
    is($vb->line_text(0), "ehllo", 'xp swapped h and e');
};

# --- yw (yank word) ---
subtest 'Edit: yw yanks word with trailing space' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y', 'w');
    # word_forward: skip "hello" (cols 0-4), skip space (col 5) → col 6
    # get_range(0, 0, 0, 6) = "hello " (word + trailing space)
    is(${$ctx->{yank_buf}}, "hello ", 'yw yanked word with trailing space');
    is($vb->cursor_col, 0, 'yw restores cursor position');
};

# --- o (open below) ---
subtest 'Edit: o opens line below and enters insert' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'o');
    is(${$ctx->{vim_mode}}, 'insert', 'o enters insert mode');
    is($vb->cursor_line, 1, 'cursor on new line below');
};

# --- O (open above) ---
subtest 'Edit: O opens line above and enters insert' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(1, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'O');
    is(${$ctx->{vim_mode}}, 'insert', 'O enters insert mode');
    is($vb->cursor_line, 1, 'cursor on new line above former line 1');
    is($vb->line_count, 4, 'buffer has 4 lines after O');
};

# --- I (insert at first non-blank) ---
subtest 'Edit: I enters insert at first non-blank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "    hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'I');
    is(${$ctx->{vim_mode}}, 'insert', 'I enters insert mode');
    is($vb->cursor_col, 4, 'I places cursor at first non-blank');
};

# --- dollar (end of line) ---
subtest 'Edit: dollar goes to end of line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'dollar');
    is($vb->cursor_col, 4, 'dollar goes to last char');
};

# --- caret (first non-blank) ---
subtest 'Edit: caret goes to first non-blank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "   hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'caret');
    is($vb->cursor_col, 3, 'caret goes to first non-blank');
};

# --- P (paste before) ---
subtest 'Edit: P pastes before current line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y', 'y');
    is(${$ctx->{yank_buf}}, "line1\n", 'yy yanked line');
    $vb->set_cursor(1, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'P');
    is($vb->text, "line1\nline1\nline2\n", 'P pastes above cursor line');
};

# --- boundary: empty buffer ---
subtest 'Edit: x on empty buffer' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "\n", 'x on empty line does nothing');
};

# --- boundary: dd on last remaining line ---
# "only line\n" → ["only line", ""], 2 lines. dd on line 0 removes it,
# leaving [""], whose text() returns "" (single empty line, no trailing \n).
subtest 'Edit: dd on single line leaves empty buffer' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "only line\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'd');
    is($vb->text, "", 'dd on last line leaves empty buffer');
    is(${$ctx->{yank_buf}}, "only line\n", 'dd yanked the line');
};

# --- 2cw changes 2 words ---
subtest 'Edit: 2cw changes 2 words' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "one two three\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'c', 'w');
    is(${$ctx->{vim_mode}}, 'insert', '2cw enters insert mode');
    is($vb->text, "three\n", '2cw deletes two words');
};

# --- count + x ---
subtest 'Edit: 3x deletes 3 characters' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'x');
    is($vb->line_text(0), "lo", '3x deletes 3 characters');
    is(${$ctx->{yank_buf}}, "hel", '3x yanks 3 characters');
};

# --- count + dd ---
subtest 'Edit: 2dd deletes 2 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\ndd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'd', 'd');
    is(${$ctx->{yank_buf}}, "aa\nbb\n", '2dd yanks 2 lines');
    is($vb->text, "cc\ndd\n", '2dd deletes 2 lines');
};

# --- count + yy ---
subtest 'Edit: 2yy yanks 2 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'y', 'y');
    is(${$ctx->{yank_buf}}, "aa\nbb\n", '2yy yanks 2 lines');
    is($vb->cursor_line, 0, 'cursor stays on original line');
};

# --- count + p (linewise) ---
subtest 'Edit: 2p pastes 2 lines below' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y', 'y');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'p');
    is($vb->text, "aa\naa\naa\nbb\ncc\n", '2p pastes yanked line twice below');
};

# --- dw at end of line ---
subtest 'Edit: dw at last word' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 6);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'w');
    is($vb->line_text(0), "hello ", 'dw on last word deletes to end');
};

# --- J on last content line joins with trailing empty ---
subtest 'Edit: J on last content line' => sub {
    # "only line\n" → ["only line", ""]. J joins line 0 with empty line 1.
    # The empty line contributes nothing meaningful.
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "only line\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'J');
    ok($vb->line_count == 1, 'J reduces line count by 1');
};

# --- gg goes to file start ---
subtest 'Edit: gg goes to first line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(2, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'g');
    is($vb->cursor_line, 0, 'gg goes to first line');
};

# --- G goes to last line ---
subtest 'Edit: G goes to last line' => sub {
    # "aa\nbb\ncc\n" → ["aa", "bb", "cc", ""] — 4 lines. G → line 3.
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'G');
    is($vb->cursor_line, $vb->line_count - 1, 'G goes to last line (including trailing empty)');
};

done_testing;
