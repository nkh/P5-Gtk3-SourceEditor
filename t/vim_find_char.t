#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# C2. Find-Character Motions (f/F/t/T and ;/,)
# ==========================================================================

subtest 'f — find char forward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'o');
    is($vb->cursor_col, 4, 'fo lands on first o');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'o');
    is($vb->cursor_col, 7, 'fo again lands on second o');

    # f should not find before cursor
    $vb->set_cursor(0, 8);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'o');
    is($vb->cursor_col, 8, 'fo with no match stays put');
};

subtest 'F — find char backward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 7);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'F', 'o');
    is($vb->cursor_col, 4, 'Fo finds first o to the left');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'F', 'o');
    is($vb->cursor_col, 4, 'Fo with no more matches stays at last found');

    # F should not find after cursor
    $vb->set_cursor(0, 2);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'F', 'o');
    is($vb->cursor_col, 2, 'Fo with no match before cursor stays put');
};

subtest 't — till char forward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 't', 'o');
    is($vb->cursor_col, 3, 'to lands one before o');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 't', 'w');
    is($vb->cursor_col, 5, 'tw lands one before w');
};

subtest 'T — till char backward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 7);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'T', 'o');
    is($vb->cursor_col, 5, 'To lands one after o');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'T', 'e');
    is($vb->cursor_col, 2, 'Te lands one after e');
};

subtest '; — repeat last find' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ababab\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'b');
    is($vb->cursor_col, 1, 'fb finds first b');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'semicolon');
    is($vb->cursor_col, 3, '; repeats fb');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'semicolon');
    is($vb->cursor_col, 5, '; repeats fb again');
};

subtest ', — reverse repeat last find' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ababab\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 5);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'F', 'b');
    is($vb->cursor_col, 3, 'Fb finds b backward');

    # , reverses Fb -> does fb -> search forward from col 4 -> finds b at col 5
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'comma');
    is($vb->cursor_col, 5, ', reverses Fb direction (finds b forward)');

    # , reverses again (same original Fb -> forward) -> finds b at col... but
    # we're at col 5 (end of text), so no more forward matches.  Cursor stays.
    # In Vim, , always reverses the ORIGINAL find direction, it does NOT
    # alternate.  The last_find is restored after each , to prevent oscillation.
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'comma');
    is($vb->cursor_col, 5, ', stays (no forward match from end of line)');
};

subtest '; and , with t/T' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aXXaXXa\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 't', 'X');
    is($vb->cursor_col, 0, 'tX lands one before first X');

    # ; repeats tX: searches from cursor+1=1, finds X at 1, lands at 0 (no-op)
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'semicolon');
    is($vb->cursor_col, 0, '; repeats tX but stays (target at cursor+1)');

    # Another ;: same result — stuck at first X
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'semicolon');
    is($vb->cursor_col, 0, '; again still stuck at first X');

    # Use fX to advance past the first X, then tX to get to position before second X
    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'X');
    is($vb->cursor_col, 1, 'fX lands on first X');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 't', 'X');
    is($vb->cursor_col, 1, 'tX from col 1 lands before second X at col 1');

    # Now ; from col 1 should find X at col 2 and land at col 1 (stuck again)
    # This is standard Vim behavior for t when target is adjacent
};

subtest '; with no prior find is no-op' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 2);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'semicolon');
    is($vb->cursor_col, 2, '; with no last_find is no-op');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'comma');
    is($vb->cursor_col, 2, ', with no last_find is no-op');
};

subtest 'f stores last_find and desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcdef\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'd');
    is($vb->cursor_col, 3, 'fd lands on d');
    is($ctx->{desired_col}, 3, 'desired_col updated');
    is($ctx->{last_find}{cmd}, 'f', 'last_find cmd is f');
    is($ctx->{last_find}{char}, 'd', 'last_find char is d');
};

subtest '2f — find second occurrence with count' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ababa\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    # 2fa: find 2nd 'a' forward. 1st at col 2, 2nd at col 4
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'f', 'a');
    is($vb->cursor_col, 4, '2fa lands on 2nd occurrence (col 4)');

    # 3fa: no 3rd 'a' exists after col 4, stays at col 4
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'f', 'a');
    is($vb->cursor_col, 4, '3fa fails (no match), cursor stays');
};

subtest '3F — find third occurrence backward with count' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abababa\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 6);  # on last 'a'

    # 3Fa: find 3rd 'a' backward. 1st at col 4, 2nd at col 2, 3rd at col 0
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'F', 'a');
    is($vb->cursor_col, 0, '3Fa lands on 3rd occurrence backward (col 0)');
};

# ==========================================================================
# C3. Virtual Column Tracking
# ==========================================================================

subtest 'Virtual column: j/k preserves column across lines of varying length' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcdefghij\nxyz\nABCDEFGHIJ\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 7);
    $ctx->{desired_col} = 7;

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 1, 'moved to line 1');
    is($vb->cursor_col, 2, 'clamped to last char of line (length-1)');
    is($ctx->{desired_col}, 7, 'desired_col still 7');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_line, 2, 'moved to line 2');
    is($vb->cursor_col, 7, 'restored to desired_col 7');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 1, 'back to line 1');
    is($vb->cursor_col, 2, 'clamped again to last char');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_line, 0, 'back to line 0');
    is($vb->cursor_col, 7, 'restored to desired_col 7');
};

subtest 'Virtual column: horizontal motions update desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "longline\nshort\nlongline\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l', 'l', 'l', 'l');
    is($ctx->{desired_col}, 5, 'desired_col updated by l');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_col, 4, 'j uses desired_col (clamped to last char)');
    is($ctx->{desired_col}, 5, 'desired_col preserved across j');

    # Now move horizontally — should update desired_col
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'h');
    is($ctx->{desired_col}, 3, 'h updates desired_col to 3');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_col, 3, 'j uses new desired_col 3');
};

subtest 'Virtual column: w updates desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\nshort\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'w');
    is($ctx->{desired_col}, 6, 'w updates desired_col to new position');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_col, 4, 'j clamps to last char of shorter line');
    is($ctx->{desired_col}, 6, 'desired_col preserved');
};

subtest 'Virtual column: 0 and $ update desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\nlongtext\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 4);
    $ctx->{desired_col} = 4;

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '0');
    is($ctx->{desired_col}, 0, '0 resets desired_col');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'dollar');
    is($ctx->{desired_col}, 4, '$ updates desired_col to line end');
};

subtest 'Virtual column: ^ updates desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "  hello\n  world\n  longtext\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 4);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'caret');
    is($ctx->{desired_col}, 2, '^ updates desired_col to first nonblank');
};

subtest 'Virtual column: f updates desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nshort\nworld\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'f', 'o');
    is($ctx->{desired_col}, 4, 'f updates desired_col');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_col, 4, 'j uses desired_col from f');
    is($ctx->{desired_col}, 4, 'desired_col preserved');
};

# ==========================================================================
# C7. Bracket Matching (% Motion)
# ==========================================================================

subtest '% — match parenthesis on same line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "(hello)\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 6, '% jumps from ( to )');
    is($vb->cursor_line, 0, 'stays on same line');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 0, '% jumps back from ) to (');
};

subtest '% — match square brackets' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "[hello]\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 6, '% jumps from [ to ]');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 0, '% jumps back from ] to [');
};

subtest '% — match curly braces' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "{hello}\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 6, '% jumps from { to }');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 0, '% jumps back from } to {');
};

subtest '% — nested brackets (multi-line)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "func() {\n  if (x) {\n    foo();\n  }\n}\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 7);  # on the opening {

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_line, 4, '% jumps to closing }');
    is($vb->cursor_col, 0, 'at start of last line');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_line, 0, '% jumps back to opening {');
    is($vb->cursor_col, 7, 'back at original position');
};

subtest '% — nested same-type brackets' => sub {
    # ((nested)) — indices: (0,(1,n(2),e(3),s(4),t(5),e(6),d(7),)(8),)(9)
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "((nested))\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # From outer ( at col 0, jumps to outer ) at col 9
    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 9, '% from outer ( jumps to outer )');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 0, '% jumps back to outer (');

    # From inner ( at col 1, jumps to inner ) at col 8
    $vb->set_cursor(0, 1);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 8, '% from inner ( jumps to inner )');
};

subtest '% — cursor not on bracket, scans forward' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello (world)\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);  # on 'h'

    # Scans forward to find ( at col 6, then jumps to matching ) at col 12
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 12, '% scans to ( and jumps to matching )');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 6, '% jumps back to (');
};

subtest '% — no bracket found is no-op' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 3);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 3, '% with no brackets stays put');
    is($vb->cursor_line, 0, 'line unchanged');
};

subtest '% — mixed bracket types' => sub {
    # func(a, [b, c], d) — [ at col 8, ] at col 13
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "func(a, [b, c], d)\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 8);  # on [

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 13, '% from [ jumps to ]');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($vb->cursor_col, 8, '% from ] jumps back to [');
};

subtest '% — updates desired_col' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "(hello)\nshort\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'percent');
    is($ctx->{desired_col}, 6, '% updates desired_col');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');
    is($vb->cursor_col, 4, 'j clamps to last char');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'k');
    is($vb->cursor_col, 6, 'k restores desired_col from %');
};

done_testing;
