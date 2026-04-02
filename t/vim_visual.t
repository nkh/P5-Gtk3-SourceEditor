#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# Visual mode — comprehensive tests
# ==========================================================================

# ==========================================================================
# 1. Char-wise visual mode entry and exit
# ==========================================================================
subtest 'Char-wise visual: enter and exit' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    is(${$ctx->{vim_mode}}, 'visual', 'v enters visual mode');
    is($ctx->{visual_type}, 'char', 'visual_type is char');
    is($ctx->{visual_start}{line}, 0, 'visual_start line is 0');
    is($ctx->{visual_start}{col}, 0, 'visual_start col is 0');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape exits visual mode');
    ok(!exists $ctx->{visual_type}, 'visual_type cleaned up');
    ok(!exists $ctx->{visual_start}, 'visual_start cleaned up');
    is($vb->cursor_col, 0, 'cursor position preserved');
};

# ==========================================================================
# 2. Char-wise visual yank
# get_range is exclusive at end: get_range(0,0,0,3) returns "hel"
# ==========================================================================
subtest 'Char-wise visual: yank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'l', 'l', 'l', 'y');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after yank');
    is(${$ctx->{yank_buf}}, 'hell', 'yank_buf has selected chars (3 l presses = 4 chars inclusive)');
    is($vb->text, "hello\n", 'text unchanged after yank');
};

# ==========================================================================
# 3. Char-wise visual delete
# ==========================================================================
subtest 'Char-wise visual: delete' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'l', 'l', 'l', 'd');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after delete');
    is(${$ctx->{yank_buf}}, 'hell', 'yank_buf has deleted chars');
    is($vb->text, "o\n", 'text changed after delete');
};

# ==========================================================================
# 4. Char-wise visual change
# ==========================================================================
subtest 'Char-wise visual: change' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'l', 'l', 'l', 'c');
    is(${$ctx->{vim_mode}}, 'insert', 'entered insert mode after change');
    is(${$ctx->{yank_buf}}, 'hell', 'yank_buf has changed chars');
    is($vb->text, "o\n", 'text deleted after change');
};

# ==========================================================================
# 5. Line-wise visual mode (V)
# ==========================================================================
subtest 'Line-wise visual: enter and exit' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    is(${$ctx->{vim_mode}}, 'visual_line', 'V enters visual_line mode');
    is($ctx->{visual_type}, 'line', 'visual_type is line');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape exits visual_line mode');
};

subtest 'Line-wise visual: yank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    is(${$ctx->{yank_buf}} // '', '', 'yank_buf empty before yank');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j', 'y');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after yank');
    is(${$ctx->{yank_buf}}, "line1\nline2\n", 'yank_buf has full lines');
    is($vb->text, "line1\nline2\nline3\n", 'text unchanged after line yank');
};

subtest 'Line-wise visual: delete' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j', 'd');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after delete');
    is(${$ctx->{yank_buf}}, "line1\nline2\n", 'yank_buf has deleted lines');
    is($vb->text, "line3\n", 'lines deleted');
    is($vb->cursor_line, 0, 'cursor at start of remaining text');
};

subtest 'Line-wise visual: change' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'c');
    is(${$ctx->{vim_mode}}, 'insert', 'entered insert mode after change');
    is(${$ctx->{yank_buf}}, "line1\n", 'yank_buf has changed line');
};

# ==========================================================================
# 6. Block-wise visual mode (Ctrl-V)
# ==========================================================================
subtest 'Block-wise visual: enter and exit' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    is(${$ctx->{vim_mode}}, 'visual_block', 'entered block visual mode');
    is($ctx->{visual_type}, 'block', 'visual_type is block');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape exits block visual mode');
};

subtest 'Block-wise visual: yank rectangular region' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(1, 2);

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'y');
    is(${$ctx->{yank_buf}}, "abc\nefg\n", 'block yank gets rectangular region');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after block yank');
};

subtest 'Block-wise visual: delete rectangular region' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(1, 2);

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'd');
    is(${$ctx->{yank_buf}}, "abc\nefg\n", 'block delete yanks rectangular region');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after block delete');
    is($vb->text, "d\nh\nijkl\n", 'columns removed from first two lines');
};

subtest 'Block-wise visual: change rectangular region' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(1, 2);

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'c');
    is(${$ctx->{vim_mode}}, 'insert', 'entered insert mode after block change');
    is(${$ctx->{yank_buf}}, "abc\nefg\n", 'block change yanks rectangular region');
    is($vb->text, "d\nh\nijkl\n", 'columns removed after block change');
};

subtest 'Block-wise visual: yank with short lines padded' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\nxy\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(2, 3);

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'y');
    # Block bounds: left=0, right=4, top=0, bottom=2
    # "abc" (len=3) → "abc " (padded to width 4)
    # "xy"  (len=2) → "xy  " (padded to width 4)
    # "ijkl"(len=4) → "ijkl" (no padding needed, width exactly 4)
    is(${$ctx->{yank_buf}}, "abc \nxy  \nijkl\n", 'block yank pads short lines with spaces');
};

# ==========================================================================
# 7. Visual swap ends (o)
# ==========================================================================
subtest 'Visual swap ends (o)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    is($vb->cursor_col, 0, 'cursor starts at col 0');
    is($ctx->{visual_start}{col}, 0, 'anchor at col 0');

    $vb->set_cursor(0, 3);
    is($vb->cursor_col, 3, 'cursor at col 3');

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'o');
    is($vb->cursor_col, 0, 'cursor moved to anchor position');
    is($ctx->{visual_start}{col}, 3, 'anchor moved to cursor position');
    is(${$ctx->{vim_mode}}, 'visual', 'still in visual mode');
};

# ==========================================================================
# 8. Visual toggle case (~)
# ==========================================================================
subtest 'Visual toggle case (~)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "Hello World\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    $vb->set_cursor(0, 5);
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'asciitilde');
    is($vb->text, "hELLO World\n", 'toggle case works on char-wise selection');
    is(${$ctx->{vim_mode}}, 'visual', '~ stays in visual mode');
};

subtest 'Visual toggle case on line-wise' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "Hello\nWorld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'asciitilde');
    is($vb->text, "hELLO\nWorld\n", 'toggle case works on line-wise selection');
};

# ==========================================================================
# 9. Visual join (J)
# ==========================================================================
subtest 'Visual join (J)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'J');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after J');
    is($vb->text, "line1 line2\nline3\n", 'lines joined with space');
};

subtest 'Visual join three lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\nbb\ncc\ndd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j', 'j');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'J');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after J');
    is($vb->text, "aa bb cc\ndd\n", 'three lines joined');
};

# ==========================================================================
# 10. Visual indent (>>, <<)
# ==========================================================================
subtest 'Visual indent right (>>)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j');
    # Send >> via the accumulated key mechanism
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'greatergreater');
    is(${$ctx->{vim_mode}}, 'visual_line', 'stays in visual after indent');
    is($vb->line_text(0), '    line1', 'first line indented');
    is($vb->line_text(1), '    line2', 'second line indented');
    is($vb->line_text(2), 'line3', 'third line unchanged');
};

subtest 'Visual indent left (<<)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "    line1\n    line2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j');
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'lessless');
    is(${$ctx->{vim_mode}}, 'visual_line', 'stays in visual after indent');
    is($vb->line_text(0), 'line1', 'first line unindented');
    is($vb->line_text(1), 'line2', 'second line unindented');
    is($vb->line_text(2), 'line3', 'third line unchanged');
};

# ==========================================================================
# 11. gv re-select
# ==========================================================================
subtest 'gv re-select after yank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'l', 'l', 'l', 'y');
    is(${$ctx->{vim_mode}}, 'normal', 'in normal mode');
    # 3 l presses from col 0 → cursor at col 3; inclusive selection = cols 0..3 = "hell"
    is(${$ctx->{yank_buf}}, 'hell', 'yank_buf has selected chars');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'v');
    is(${$ctx->{vim_mode}}, 'visual', 'gv re-enters visual mode');
    is($ctx->{visual_type}, 'char', 'visual_type restored');
    is($ctx->{visual_start}{line}, 0, 'start line restored');
    is($ctx->{visual_start}{col}, 0, 'start col restored');
    is($vb->cursor_col, 3, 'end col restored');
};

subtest 'gv re-select after line-wise yank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j', 'y');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'v');
    is(${$ctx->{vim_mode}}, 'visual_line', 'gv re-enters visual_line mode');
    is($ctx->{visual_type}, 'line', 'visual_type is line');
};

subtest 'gv re-select after block-wise yank' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(1, 2);
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'y');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'v');
    is(${$ctx->{vim_mode}}, 'visual_block', 'gv re-enters visual_block mode');
    is($ctx->{visual_type}, 'block', 'visual_type is block');
};

# ==========================================================================
# 12. Visual uppercase (U) and lowercase (u)
# ==========================================================================
subtest 'Visual uppercase (U)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    $vb->set_cursor(0, 5);
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'U');
    is($vb->text, "HELLO world\n", 'U uppercases char-wise selection');
};

subtest 'Visual lowercase (u)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "HELLO World\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    $vb->set_cursor(0, 5);
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'u');
    is($vb->text, "hello World\n", 'u lowercases char-wise selection');
};

subtest 'Visual line-wise uppercase (U)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'U');
    is($vb->text, "HELLO\nworld\n", 'U uppercases line-wise selection');
};

subtest 'Visual line-wise lowercase (u)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "HELLO\nWORLD\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'u');
    is($vb->text, "hello\nWORLD\n", 'u lowercases line-wise selection');
};

# ==========================================================================
# 13. Visual format (gq)
# ==========================================================================
subtest 'Visual format (gq)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "This is a long line of text that should be wrapped\nwhen formatted\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V', 'j');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'q');
    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal after gq');
    ok(length($vb->line_text(0)) <= 78, 'first line wrapped within 78 chars');
};

# ==========================================================================
# 14. Block visual navigation
# ==========================================================================
subtest 'Block-wise visual: navigation within block mode' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'j');
    is($vb->cursor_line, 1, 'j works in block visual mode');
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'l');
    is($vb->cursor_col, 1, 'l works in block visual mode');
};

# ==========================================================================
# 15. Block visual indent
# ==========================================================================
subtest 'Block-wise visual: indent affects lines in block' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(1, 2);

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'greatergreater');
    is($vb->line_text(0), '    abcd', 'first line indented');
    is($vb->line_text(1), '    efgh', 'second line indented');
    is($vb->line_text(2), 'ijkl', 'third line unchanged');
};

# ==========================================================================
# 16. Visual mode label
# ==========================================================================
subtest 'Visual mode label' => sub {
    my $ml = Gtk3::SourceEditor::VimBindings::MockLabel->new();
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, mode_label => $ml,
    );

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    is($ml->get_text, '-- VISUAL --', 'visual mode label');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    is($ml->get_text, '-- VISUAL LINE --', 'visual_line mode label');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    $ctx->{set_mode}->('visual_block');
    is($ml->get_text, '-- VISUAL BLOCK --', 'visual_block mode label');
};

# ==========================================================================
# 17. Visual mode last_visual saves properly
# ==========================================================================
subtest 'last_visual saved on delete' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'l', 'l', 'l', 'd');
    ok(exists $ctx->{last_visual}, 'last_visual saved after delete');
    is($ctx->{last_visual}{type}, 'char', 'last_visual type saved');
    is($ctx->{last_visual}{start_line}, 0, 'last_visual start_line saved');
    is($ctx->{last_visual}{start_col}, 0, 'last_visual start_col saved');
    is($ctx->{last_visual}{end_line}, 0, 'last_visual end_line saved');
    is($ctx->{last_visual}{end_col}, 3, 'last_visual end_col saved');
};

# ==========================================================================
# 18. gv does nothing without prior visual selection
# ==========================================================================
subtest 'gv does nothing without prior selection' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'g', 'v');
    is(${$ctx->{vim_mode}}, 'normal', 'gv does nothing without last_visual');
};

# ==========================================================================
# 19. Block visual swap ends
# ==========================================================================
subtest 'Block-wise visual: swap ends' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $ctx->{set_mode}->('visual_block');
    $vb->set_cursor(1, 2);

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'o');
    is($vb->cursor_line, 0, 'cursor moved to anchor line');
    is($vb->cursor_col, 0, 'cursor moved to anchor col');
    is($ctx->{visual_start}{line}, 1, 'anchor moved to cursor line');
    is($ctx->{visual_start}{col}, 2, 'anchor moved to cursor col');
};

# ==========================================================================
# 20. Visual mode h/j/k/l and arrow key movement
# ==========================================================================
subtest 'Visual h/l movement (char-wise)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    is($ctx->{visual_start}{col}, 0, 'anchor at col 0');

    # l moves right, extending selection
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l');
    is($vb->cursor_col, 1, 'l moves to col 1');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l', 'l');
    is($vb->cursor_col, 4, 'l moves to col 4 (last char)');

    # l at EOL+1: in visual mode, move_right allows col = max (5)
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l');
    is($vb->cursor_col, 5, 'l allows one past EOL in visual mode (col=5, line_length=5)');

    # l again should stay at max
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l');
    is($vb->cursor_col, 5, 'l stays at max when already at EOL+1');

    # h moves back
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'h');
    is($vb->cursor_col, 4, 'h moves back to col 4');

    # h at col 0 stays
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'h', 'h', 'h', 'h', 'h');
    is($vb->cursor_col, 0, 'h stops at col 0');

    # At this point cursor (0,0) == visual_start (0,0).
    # Visual selection is always at least 1 char (inclusive), so yank = "h".
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'y');
    is(${$ctx->{yank_buf}}, 'h', 'yank single char when cursor equals anchor');
};

subtest 'Visual j/k movement (char-wise, multi-line)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    # Buffer has 4 lines: "abcd", "efgh", "ijkl", "" (trailing newline)
    my $last = $vb->line_count - 1;
    is($last, 3, 'buffer has 4 lines (0..3)');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    is($vb->cursor_line, 0, 'start on line 0');

    # j moves down
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 1, 'j moves to line 1');
    is($vb->cursor_col, 0, 'column preserved at 0');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 2, 'j moves to line 2');

    # j at last line stays (line 3 is the last)
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 3, 'j moves to line 3 (trailing empty line)');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 3, 'j stays at last line (3)');

    # k moves up
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 2, 'k moves to line 2');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 1, 'k moves to line 1');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 0, 'k moves to line 0');

    # k at first line stays
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 0, 'k stays at first line');
};

subtest 'Visual j/k preserves virtual column (desired_col)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcdefgh\nab\nabcdefghijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    # Move to col 5 on line 0
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l', 'l', 'l', 'l');
    is($vb->cursor_col, 5, 'cursor at col 5 on line 0');

    # j to line 1 (len=2): col should clamp to max in visual mode
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 1, 'moved to line 1');
    is($vb->cursor_col, 2, 'col clamped to line_length in visual mode (EOL+1)');

    # j to line 2 (len=12): col should restore to desired_col=5
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 2, 'moved to line 2');
    is($vb->cursor_col, 5, 'col restored to desired_col=5 on longer line');
};

subtest 'Visual arrow keys (Left/Right/Up/Down) alias to h/j/k/l' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');

    # Arrow Down = j
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Down');
    is($vb->cursor_line, 1, 'Down arrow moves to line 1');

    # Arrow Right = l
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Right');
    is($vb->cursor_col, 1, 'Right arrow moves to col 1');

    # Arrow Up = k
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Up');
    is($vb->cursor_line, 0, 'Up arrow moves to line 0');

    # Arrow Left = h
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Left');
    is($vb->cursor_col, 0, 'Left arrow moves to col 0');
};

subtest 'Visual h/l movement in line-wise mode' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\nfoo bar\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'V');
    is(${$ctx->{vim_mode}}, 'visual_line', 'in visual_line mode');

    # In Vim, h/l are not completely no-op in visual_line mode;
    # they move the cursor column which affects the "active end"
    # of the selection. Our implementation allows this, which is
    # a reasonable design choice.
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l', 'l');
    is($vb->cursor_col, 3, 'l moves column in visual_line mode');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'h');
    is($vb->cursor_col, 2, 'h moves column back in visual_line mode');
};

subtest 'Visual movement with Page_Up/Page_Down' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => join("\n", map { "line$_" } 1..50) . "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, page_size => 10,
    );

    $vb->set_cursor(25, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');

    # Page_Down in visual mode
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Page_Down');
    is($vb->cursor_line, 35, 'Page_Down moves down one page in visual mode');
    is(${$ctx->{vim_mode}}, 'visual', 'still in visual mode after Page_Down');

    # Page_Up in visual mode
    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Page_Up');
    is($vb->cursor_line, 25, 'Page_Up moves back up in visual mode');
    is(${$ctx->{vim_mode}}, 'visual', 'still in visual mode after Page_Up');
};

subtest 'Visual movement with Home/End' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l', 'l', 'l', 'l', 'l', 'l', 'l');
    ok($vb->cursor_col > 0, 'cursor not at start');

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'Home');
    is($vb->cursor_col, 0, 'Home moves to col 0 in visual mode');

    Gtk3::SourceEditor::VimBindings::handle_visual_mode($ctx, 'End');
    is($vb->cursor_col, 10, 'End moves to last char in visual mode');
};

subtest 'Visual numeric prefix with movement (3j, 2l)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "a\nb\nc\nd\ne\nf\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v');
    is($vb->cursor_line, 0, 'start at line 0');

    # 3j should move down 3 lines
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'j');
    is($vb->cursor_line, 3, '3j moves to line 3');

    # 2l should move right 2 columns
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'l');
    is($vb->cursor_col, 1, '2l moves to col 1 (single-char lines, clamped)');
};

done_testing;
