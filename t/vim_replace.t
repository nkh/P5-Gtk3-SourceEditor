#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# Replace mode — entry, character replacement, backspace, edge cases
# ==========================================================================

subtest 'Replace: enter replace mode (R)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    is(${$ctx->{vim_mode}}, 'replace', 'R enters replace mode');
};

subtest 'Replace: exit replace mode (Escape)' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    is(${$ctx->{vim_mode}}, 'replace', 'in replace mode');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'Escape exits replace mode');
};

subtest 'Replace: single character replacement' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'X');
    is($vb->text, "Xello\n", 'R replaces first char');
    is($vb->cursor_col, 1, 'cursor advances after replace');
};

subtest 'Replace: multiple character replacement' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'H');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'I');
    is($vb->text, "HIllo\n", 'R replaces two characters sequentially');
    is($vb->cursor_col, 2, 'cursor at col 2 after two replacements');
};

subtest 'Replace: backspace in replace mode' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'X');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Y');
    is($vb->cursor_col, 2, 'cursor at col 2');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'BackSpace');
    is($vb->cursor_col, 1, 'backspace moves cursor back');
    is($vb->text, "XYllo\n", 'backspace does not undo the replacement');
};

subtest 'Replace: backspace at line start does nothing' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'BackSpace');
    is($vb->cursor_col, 0, 'backspace at col 0 stays at 0');
    is(${$ctx->{vim_mode}}, 'replace', 'still in replace mode');
};

subtest 'Replace: replace at end of line stops' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ab\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(0, 1);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'X');
    is($vb->text, "aX\n", 'replaced char at col 1');
    is($vb->cursor_col, 2, 'cursor at end of line');
    # Replace another — cursor is at end of line, replace_char does nothing
    # but do_replace_char still advances cursor only if not at line end
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Y');
    is($vb->cursor_col, 2, 'cursor stays at end of line');
};

subtest 'Replace: mode label shows REPLACE' => sub {
    my $ml = Gtk3::SourceEditor::VimBindings::MockLabel->new();
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb, mode_label => $ml,
    );

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    is($ml->get_text, '-- REPLACE --', 'replace mode label');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is($ml->get_text, '-- NORMAL --', 'back to normal label');
};

subtest 'Replace: replace entire word' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    for my $c (split //, 'XXXXX') {
        Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, $c);
    }
    is($vb->text, "XXXXX world\n", 'replaced entire word');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is(${$ctx->{vim_mode}}, 'normal', 'back to normal after replace');
    is($vb->cursor_col, 4, 'cursor stepped back after Escape');
};

subtest 'Replace: undo after replace' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'R');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'X');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is($vb->text, "Xello\n", 'replaced before undo');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "hello\n", 'undo restores original text');
};

done_testing;
