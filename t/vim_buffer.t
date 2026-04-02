#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer;
use Gtk3::SourceEditor::VimBuffer::Test;

# ==========================================================================
# VimBuffer::Test — unit tests for the in-memory buffer implementation
# ==========================================================================

# --- Construction -----------------------------------------------------------
subtest 'Construction: empty buffer' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new();
    is($vb->line_count, 1, 'empty buffer has 1 line');
    is($vb->text, '', 'empty buffer text is empty');
    is($vb->cursor_line, 0, 'cursor starts at line 0');
    is($vb->cursor_col, 0, 'cursor starts at col 0');
};

subtest 'Construction: from text' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    is($vb->line_count, 3, 'two-newline text has 3 lines');
    is($vb->line_text(0), 'hello', 'first line');
    is($vb->line_text(1), 'world', 'second line');
    is($vb->line_text(2), '', 'third line is empty (trailing newline)');
};

subtest 'Construction: no trailing newline' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld");
    is($vb->line_count, 2, 'no trailing newline has 2 lines');
    is($vb->line_text(0), 'hello', 'first line');
    is($vb->line_text(1), 'world', 'second line');
};

# --- Cursor -----------------------------------------------------------------
subtest 'Cursor: set_cursor clamping' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");

    $vb->set_cursor(0, 3);
    is($vb->cursor_line, 0, 'set_cursor line');
    is($vb->cursor_col, 3, 'set_cursor col');

    $vb->set_cursor(-1, 0);
    is($vb->cursor_line, 0, 'negative line clamped to 0');

    $vb->set_cursor(99, 0);
    is($vb->cursor_line, 2, 'overflow line clamped to last');

    $vb->set_cursor(0, 99);
    is($vb->cursor_col, 5, 'overflow col clamped to line length');

    $vb->set_cursor(1, -1);
    is($vb->cursor_col, 0, 'negative col clamped to 0');
};

subtest 'Cursor: predicates' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");

    $vb->set_cursor(0, 0);
    ok($vb->at_line_start, 'col 0 is line start');
    ok(!$vb->at_line_end, 'col 0 is not line end');

    $vb->set_cursor(0, 5);
    ok($vb->at_line_end, 'col at line length is line end');
    ok(!$vb->at_buffer_end, 'line 0 end is not buffer end');

    $vb->set_cursor(2, 0);
    ok($vb->at_buffer_end, 'last line col 0 is buffer end');

    $vb->set_cursor(0, 0);
    ok(!$vb->at_buffer_end, 'line 0 is not buffer end');
};

# --- Lines ------------------------------------------------------------------
subtest 'Lines: line_text and line_length' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcdef\nhi\n");

    is($vb->line_text(0), 'abcdef', 'line_text(0)');
    is($vb->line_length(0), 6, 'line_length(0)');
    is($vb->line_text(1), 'hi', 'line_text(1)');
    is($vb->line_length(1), 2, 'line_length(1)');
    is($vb->line_text(2), '', 'line_text(2) - trailing empty');
    is($vb->line_length(2), 0, 'line_length(2) - trailing empty');
};

# --- Insert -----------------------------------------------------------------
subtest 'Insert: basic insert' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 5);
    $vb->insert_text("X");
    is($vb->text, "helloX\n", 'insert at end of line');
    is($vb->cursor_col, 6, 'cursor advances after insert');
};

subtest 'Insert: in middle of line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 2);
    $vb->insert_text("XY");
    is($vb->text, "heXYllo\n", 'insert in middle');
    is($vb->cursor_col, 4, 'cursor advances correctly');
};

subtest 'Insert: newline splits line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    $vb->set_cursor(0, 2);
    $vb->insert_text("\n");
    is($vb->line_count, 4, 'line count increases (3 -> 4)');
    is($vb->line_text(0), 'he', 'first half of split');
    is($vb->line_text(1), 'llo', 'second half of split');
    is($vb->line_text(2), 'world', 'rest preserved');
    is($vb->cursor_line, 1, 'cursor on new line');
    is($vb->cursor_col, 0, 'cursor at col 0');
};

subtest 'Insert: multi-line text' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ab\ncd\n");
    $vb->set_cursor(0, 1);
    $vb->insert_text("XY\nZZ");
    is($vb->text, "aXY\nZZb\ncd\n", 'multi-line insert');
    is($vb->cursor_line, 1, 'cursor on second new line');
    is($vb->cursor_col, 2, 'cursor at end of ZZ');
};

subtest 'Insert: sets modified flag' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    ok(!$vb->modified, 'initially not modified');
    $vb->insert_text("X");
    ok($vb->modified, 'modified after insert');
};

# --- Delete range ------------------------------------------------------------
subtest 'Delete range: single line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->delete_range(0, 1, 0, 4);
    is($vb->text, "ho\n", 'deleted middle chars');
    is($vb->cursor_line, 0, 'cursor stays on line');
    is($vb->cursor_col, 1, 'cursor at deletion point');
};

subtest 'Delete range: cross-line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    $vb->delete_range(0, 2, 1, 3);
    is($vb->text, "held\n", 'cross-line delete removes llo\\nwor');
    is($vb->line_count, 2, 'line count reduced');
};

subtest 'Delete range: full line including newline' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aaa\nbbb\nccc\n");
    $vb->delete_range(1, 0, 2, 0);
    is($vb->text, "aaa\nccc\n", 'delete line with newline');
};

# --- Undo -------------------------------------------------------------------
subtest 'Undo: single operation' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 5);
    $vb->insert_text("X");
    is($vb->text, "helloX\n", 'after insert');
    $vb->undo();
    is($vb->text, "hello\n", 'undo restores text');
    is($vb->cursor_line, 0, 'undo restores cursor line');
    is($vb->cursor_col, 5, 'undo restores cursor col');
};

subtest 'Undo: multiple operations' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\n");
    $vb->insert_text("X");
    $vb->undo();
    is($vb->text, "abc\n", 'undo first insert');
    $vb->insert_text("Y");
    $vb->undo();
    is($vb->text, "abc\n", 'undo second insert');
};

subtest 'Undo: empty stack is no-op' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\n");
    $vb->undo();
    is($vb->text, "abc\n", 'no-op undo');
};

# --- Get range --------------------------------------------------------------
subtest 'Get range: single line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    is($vb->get_range(0, 1, 0, 4), 'ell', 'get_range single line');
};

subtest 'Get range: cross-line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    is($vb->get_range(0, 2, 1, 3), "llo\nwor", 'get_range cross-line');
};

# --- Word movement ----------------------------------------------------------
subtest 'Word movement: forward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    $vb->set_cursor(0, 0);
    $vb->word_forward();
    is($vb->cursor_line, 0, 'word_forward stays on line');
    is($vb->cursor_col, 6, 'word_forward to start of next word (after space)');
};

subtest 'Word movement: forward across lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    $vb->set_cursor(0, 3);
    $vb->word_forward();
    is($vb->cursor_line, 1, 'word_forward crosses lines');
    is($vb->cursor_col, 0, 'word_forward to start of next line word');
};

subtest 'Word movement: backward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    $vb->set_cursor(0, 7);
    $vb->word_backward();
    is($vb->cursor_col, 6, 'word_backward');
};

subtest 'Word movement: end' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    $vb->set_cursor(0, 0);
    $vb->word_end();
    is($vb->cursor_col, 4, 'word_end to last char of word');
};

# --- Modified flag -----------------------------------------------------------
subtest 'Modified flag' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    ok(!$vb->modified, 'initially not modified');

    $vb->insert_text("X");
    ok($vb->modified, 'modified after insert');

    $vb->set_modified(0);
    ok(!$vb->modified, 'set_modified(0) clears flag');

    $vb->delete_range(0, 0, 0, 1);
    ok($vb->modified, 'modified after delete');
};

done_testing;
