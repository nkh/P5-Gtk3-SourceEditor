#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# VimBindings dispatch, modes, numeric prefixes, keymap — full tests
# ==========================================================================

# ==========================================================================
# 1. Mode transitions
# ==========================================================================
subtest 'Mode: normal to insert (i)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    is(${$ctx->{vim_mode}}, 'normal', 'starts in normal');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i');
    is(${$ctx->{vim_mode}}, 'insert', 'i enters insert mode');
};

subtest 'Mode: insert back to normal (Escape)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i');
    is(${$ctx->{vim_mode}}, 'insert', 'i enters insert mode');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape returns to normal');
    is($vb->cursor_col, 0, 'cursor steps back in empty buffer');
};

subtest 'Mode: enter command with colon' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'colon');
    is(${$ctx->{vim_mode}}, 'command', 'colon enters command mode');
};

subtest 'Mode: Escape exits command mode' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'colon');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape exits command mode');
};

# ==========================================================================
# 2. Normal mode navigation
# ==========================================================================
subtest 'Navigation: h (left)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 3);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'h');
    is($vb->cursor_col, 2, 'h moves left');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'h', 'h');
    is($vb->cursor_col, 0, 'h stops at line start');
    is($vb->cursor_line, 0, 'h does not cross lines');
};

subtest 'Navigation: l (right)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l');
    is($vb->cursor_col, 1, 'l moves right');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l', 'l', 'l');
    # In normal mode, l stops at line_length - 1 (= col 4 for "hello")
    is($vb->cursor_col, 4, 'l stops at line end');
};

subtest 'Navigation: j (down)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 1, 'j moves down');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 2, 'j moves down again');
};

subtest 'Navigation: k (up)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j', 'j');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 1, 'k moves up once');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 0, 'k moves up again');
};

subtest 'Navigation: j maintains virtual column' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "longline\nshort\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 6);
    $ctx->{desired_col} = 6;
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    # Virtual column tracking: col is clamped to shorter line, but desired_col is remembered
    is($vb->cursor_col, 4, 'j clamps col to last char (length-1)');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    # Virtual column restoration: col snaps back to original desired column
    is($vb->cursor_col, 6, 'k restores original col via virtual column tracking');
};

subtest 'Navigation: 0 (line start)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 4);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '0');
    is($vb->cursor_col, 0, '0 goes to line start');
};

subtest 'Navigation: G (file end) and gg (file start)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'G');
    # Trailing newline creates empty 4th line (index 3)
    is($vb->cursor_line, 3, 'G goes to last line');
    is($vb->cursor_col, 0, 'G goes to col 0');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'g');
    is($vb->cursor_line, 0, 'gg goes to first line');
};

subtest 'Navigation: w (word forward)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'w');
    is($vb->cursor_col, 6, 'w skips to start of next word');
};

subtest 'Navigation: b (word backward)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 7);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'b');
    is($vb->cursor_col, 6, 'b goes back to word start');
};

subtest 'Navigation: e (word end)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'e');
    is($vb->cursor_col, 4, 'e goes to end of word');
};

# ==========================================================================
# 3. Numeric prefixes
# ==========================================================================
subtest 'Numeric prefix: 3j moves down 3 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "a\nb\nc\nd\ne\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'j');
    is($vb->cursor_line, 3, '3j moves down 3 lines');
};

subtest 'Numeric prefix: 5x deletes 5 chars' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcdefghij\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '5', 'x');
    is($vb->text, "fghij\n", '5x deletes 5 characters');
    is(${$ctx->{yank_buf}}, "abcde", '5x yanks 5 characters');
};

subtest 'Numeric prefix: 2dd deletes 2 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\nline4\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    # Cursor starts at line 0; 2dd deletes lines 0 and 1
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'd', 'd');
    is($vb->text, "line3\nline4\n", '2dd deletes 2 lines from current position');
    is(${$ctx->{yank_buf}}, "line1\nline2\n", '2dd yanks deleted lines');
};

subtest 'Numeric prefix: 0 is line_start, not a count' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 4);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '0');
    is($vb->cursor_col, 0, '0 is line_start command, not count prefix');
    is($vb->cursor_line, 0, '0 stays on current line');
};

subtest 'Numeric prefix: 10j moves 10 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => join("\n", map { "l$_" } 1..15) . "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '1', '0', 'j');
    is($vb->cursor_line, 10, '10j moves down 10 lines');
};

subtest 'Numeric prefix: 3p pastes 3 times' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y', 'y');
    is(${$ctx->{yank_buf}}, "hello\n", 'yy yanks line');
    # Move to line 1 before pasting
    $vb->set_cursor(1, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'p');
    # paste inserts 3 times at cursor, including original line
    is($vb->line_count, 6, '3p adds 3 lines');
};

subtest 'Numeric prefix: 2o opens 2 lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'o');
    is(${$ctx->{vim_mode}}, 'insert', '2o enters insert mode');
    is($vb->text, "aa\n\n\n", '2o opens 2 blank lines');
};

# ==========================================================================
# 4. Insert mode
# ==========================================================================
subtest 'Insert mode: typing text' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i');
    is(${$ctx->{vim_mode}}, 'insert', 'i enters insert mode');
    # In insert mode, keys are passed through (FALSE)
    # For testing, we manually insert at cursor position
    $vb->insert_text("HI");
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape returns to normal');
    is($vb->text, "HIhello\n", 'insert mode adds text at cursor (col 0)');
};

subtest 'Insert mode: a inserts after cursor' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 1);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'a');
    is(${$ctx->{vim_mode}}, 'insert', 'a enters insert mode');
    # a moves cursor forward first, then enters insert
    is($vb->cursor_col, 2, 'a advances cursor by one');
    $vb->insert_text("X");
    is($vb->text, "abXcd\n", 'a inserts after cursor position');
};

subtest 'Insert mode: A appends at end of line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'A');
    is(${$ctx->{vim_mode}}, 'insert', 'A enters insert mode');
    $vb->insert_text("X");
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is($vb->text, "abcX\n", 'A appends at end of line');
};

# ==========================================================================
# 5. Editing operations
# ==========================================================================
subtest 'Edit: x deletes char' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "bc\n", 'x deletes char under cursor');
    is(${$ctx->{yank_buf}}, "a", 'x yanks deleted char');
};

subtest 'Edit: x at line end does nothing' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ab\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 2);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "ab\n", 'x at line end is no-op');
};

subtest 'Edit: dd deletes line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(1, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'd');
    is($vb->text, "line1\nline3\n", 'dd deletes current line');
    is(${$ctx->{yank_buf}}, "line2\n", 'dd yanks line with newline');
};

subtest 'Edit: yy yanks line without deleting' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y', 'y');
    is($vb->text, "line1\nline2\n", 'yy does not delete');
    is(${$ctx->{yank_buf}}, "line1\n", 'yy yanks line');
};

subtest 'Edit: p pastes yanked content' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aaa\nbbb\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y', 'y');
    $vb->set_cursor(1, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'p');
    is($vb->text, "aaa\nbbb\naaa\n", 'p pastes below cursor line');
};

subtest 'Edit: dw deletes word' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'w');
    # dw deletes from cursor to start of next word
    is($vb->text, "world\n", 'dw deletes word under cursor');
    is(${$ctx->{yank_buf}}, "hello ", 'dw yanks word with trailing space');
};

subtest 'Edit: u undoes' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "ello\n", 'x deleted');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "hello\n", 'u undoes');
};

subtest 'Edit: 3u undoes 3 times' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcde\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x', 'x', 'x');
    is($vb->text, "de\n", '3x deletes 3 chars');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'u');
    is($vb->text, "abcde\n", '3u undoes 3 operations');
};

# ==========================================================================
# 6. Multi-key prefix accumulation
# ==========================================================================
subtest 'Prefix: g waits for second key (gg = file start)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # After 'g', command buffer has 'g' (it's a prefix waiting for second key)
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'g');
    is(${$ctx->{cmd_buf}}, 'g', 'g accumulated in buffer (prefix)');
    # Now 'g' + 'g' = gg
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'g');
    is(${$ctx->{cmd_buf}}, '', 'gg executed and buffer cleared');
    is($vb->cursor_line, 0, 'gg goes to file start');
};

subtest 'Prefix: d waits for second key (dd = delete line)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'd');
    is(${$ctx->{cmd_buf}}, 'd', 'd accumulated in buffer (prefix)');
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'd');
    is(${$ctx->{cmd_buf}}, '', 'dd executed');
    is($vb->text, "line2\n", 'dd deletes line');
};

subtest 'Prefix: unknown key resets' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Q');  # Q is not a key in normal mode
    is(${$ctx->{cmd_buf}}, '', 'unknown key resets buffer');
};

# ==========================================================================
# 7. Read-only mode
# ==========================================================================
subtest 'Read-only: blocks insert mode' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb, is_readonly => 1);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i');
    is(${$ctx->{vim_mode}}, 'normal', 'i blocked in read-only');
    is($vb->text, "hello\n", 'no text inserted');
};

# ==========================================================================
# 8. Ex-command parsing (tested through dispatch)
# ==========================================================================
subtest 'Ex-command: colon + Return in command mode' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # Enter command mode and type a command
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'colon');
    is(${$ctx->{vim_mode}}, 'command', 'entered command mode');
    $ctx->{cmd_entry}->set_text(':q');
    Gtk3::SourceEditor::VimBindings::handle_command_entry($ctx, 'Return');
    is(${$ctx->{vim_mode}}, 'normal', ':q returns to normal');
    is($vb->text, "hello\n", ':q does not modify buffer');
};

# ==========================================================================
# 9. Arrow keys produce identical results to h/j/k/l (no double movement)
# ==========================================================================
subtest 'Arrow keys: Down alias to j, not double movement' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # Press Down once — should move exactly one line
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Down');
    is($vb->cursor_line, 1, 'Down moves down exactly 1 line (not 2)');
    is($vb->cursor_col, 0, 'Down preserves column');

    # Press Down again — should move to line 2
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Down');
    is($vb->cursor_line, 2, 'Down again moves to line 2');

    # At last line (index 3), Down should stop
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Down');
    is($vb->cursor_line, 3, 'Down moves to last line');
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Down');
    is($vb->cursor_line, 3, 'Down stops at last line');
};

subtest 'Arrow keys: Up alias to k, not double movement' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(2, 0);

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Up');
    is($vb->cursor_line, 1, 'Up moves up exactly 1 line (not 2)');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Up');
    is($vb->cursor_line, 0, 'Up moves to line 0');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Up');
    is($vb->cursor_line, 0, 'Up stops at line 0');
};

subtest 'Arrow keys: Left alias to h, not double movement' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 4);

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Left');
    is($vb->cursor_col, 3, 'Left moves left exactly 1 col (not 2)');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Left');
    is($vb->cursor_col, 2, 'Left again moves to col 2');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Left');
    is($vb->cursor_col, 1, 'Left moves to col 1');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Left');
    is($vb->cursor_col, 0, 'Left moves to col 0');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Left');
    is($vb->cursor_col, 0, 'Left stops at col 0');
};

subtest 'Arrow keys: Right alias to l, not double movement' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Right');
    is($vb->cursor_col, 1, 'Right moves right exactly 1 col (not 2)');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Right');
    is($vb->cursor_col, 2, 'Right again moves to col 2');

    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Right');
    is($vb->cursor_col, 3, 'Right moves to col 3');

    # In normal mode, l stops at last char (col 4 for "hello")
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Right');
    is($vb->cursor_col, 4, 'Right moves to last char (col 4)');
    Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Right');
    is($vb->cursor_col, 4, 'Right stays at last char');
};

subtest 'Arrow keys: handle_normal_mode returns TRUE' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    my $r;
    $r = Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Down');
    ok($r, 'handle_normal_mode returns true for Down');

    $r = Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Up');
    ok($r, 'handle_normal_mode returns true for Up');

    $r = Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Left');
    ok($r, 'handle_normal_mode returns true for Left');

    $r = Gtk3::SourceEditor::VimBindings::handle_normal_mode($ctx, 'Right');
    ok($r, 'handle_normal_mode returns true for Right');
};

# ==========================================================================
# 10. Word motions must not create selection in normal mode
#     (Bug: Gtk3 backend uses move_mark_by_name which only moves the
#     insert mark, leaving selection_bound behind and creating a visible
#     GTK selection.  Fix: Normal.pm actions collapse selection via
#     set_cursor after word motion in non-visual modes.)
# ==========================================================================
subtest 'Word motions in normal mode: no selection after w' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world foo\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'w');
    is($vb->cursor_col, 6, 'w moves to start of next word');
    is(${$ctx->{vim_mode}}, 'normal', 'still in normal mode');
    ok(!defined($vb->get_selection), 'w does not create a selection');
};

subtest 'Word motions in normal mode: no selection after b' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world foo\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 6);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'b');
    is($vb->cursor_col, 0, 'b moves to start of previous word');
    ok(!defined($vb->get_selection), 'b does not create a selection');
};

subtest 'Word motions in normal mode: no selection after e' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world foo\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'e');
    is($vb->cursor_col, 4, 'e moves to end of word');
    ok(!defined($vb->get_selection), 'e does not create a selection');
};

subtest 'Word motions: 2w moves two words, no selection' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "one two three four\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'w');
    is($vb->cursor_col, 8, '2w moves two words forward');
    ok(!defined($vb->get_selection), '2w does not create a selection');
};

subtest 'Word motions: w/b/e sequence maintains no selection' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa bb cc dd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'w', 'w', 'b', 'e', 'b');
    is($vb->cursor_col, 3, 'w/w/b/e/b sequence ends at correct position');
    ok(!defined($vb->get_selection),
       'w/w/b/e/b sequence never creates a selection');
};

# ==========================================================================
# 11. Page scrolling uses correct page_size
#     (Bug: page_size computed before widget realized, giving too small
#     a value.  Fix: size-allocate signal handler recalculates on resize.)
# ==========================================================================
subtest 'Page scrolling: default page_size is 20 in test context' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    is($ctx->{page_size}, 20, 'default page_size is 20');
};

subtest 'Page scrolling: custom page_size is respected' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 30
    );
    is($ctx->{page_size}, 30, 'custom page_size is 30');
};

subtest 'Page scrolling: Page_Down moves page_size lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 20
    );
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Page_Down');
    is($vb->cursor_line, 20, 'Page_Down moves 20 lines (full page)');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Page_Down');
    is($vb->cursor_line, 40, 'Page_Down moves another 20 lines');

    # Near end of buffer, should stop at last line
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Page_Down');
    is($vb->cursor_line, 50, 'Page_Down stops at last line');
};

subtest 'Page scrolling: Page_Up moves page_size lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 20
    );
    $vb->set_cursor(40, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Page_Up');
    is($vb->cursor_line, 20, 'Page_Up moves 20 lines up');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Page_Up');
    is($vb->cursor_line, 0, 'Page_Up moves to line 0');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Page_Up');
    is($vb->cursor_line, 0, 'Page_Up stops at line 0');
};

subtest 'Page scrolling: Ctrl-f (page_down) moves full page' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 20
    );
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-f');
    is($vb->cursor_line, 20, 'Ctrl-f moves full page (20 lines)');
};

subtest 'Page scrolling: Ctrl-b (page_up) moves full page' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 20
    );
    $vb->set_cursor(40, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-b');
    is($vb->cursor_line, 20, 'Ctrl-b moves full page (20 lines)');
};

subtest 'Page scrolling: Ctrl-d moves half page' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 20
    );
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-d');
    is($vb->cursor_line, 10, 'Ctrl-d moves half page (10 lines)');
};

subtest 'Page scrolling: Ctrl-u moves half page up' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => join("\n", map { "line$_" } 1..50) . "\n"
    );
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 20
    );
    $vb->set_cursor(30, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-u');
    is($vb->cursor_line, 20, 'Ctrl-u moves half page up (10 lines)');
};

done_testing;
