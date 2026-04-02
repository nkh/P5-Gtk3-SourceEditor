#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# Marks — set, jump, line-jump, invalid marks, persistence
# ==========================================================================

subtest 'Marks: set mark with m{a}' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(1, 3);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'a');
    ok(exists $ctx->{marks}{a}, 'mark a is set');
    is($ctx->{marks}{a}{line}, 1, 'mark a line is 1');
    is($ctx->{marks}{a}{col}, 3, 'mark a col is 3');
};

subtest 'Marks: set mark with m{z}' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(2, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'z');
    ok(exists $ctx->{marks}{z}, 'mark z is set');
    is($ctx->{marks}{z}{line}, 2, 'mark z line is 2');
};

subtest 'Marks: jump to mark with `{a}' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # Set mark
    $vb->set_cursor(2, 4);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'b');

    # Move away
    $vb->set_cursor(0, 0);

    # Jump back — simulate_keys handles char_actions properly
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'grave', 'b');
    is($vb->cursor_line, 2, 'jumped to mark b line');
    is($vb->cursor_col, 4, 'jumped to mark b col');
};

subtest 'Marks: jump to mark line with \'{a}' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "  line1\nline2\n  line3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # Set mark on line 2 (0-based)
    $vb->set_cursor(2, 4);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'c');

    # Move away
    $vb->set_cursor(0, 0);

    # Jump to first non-blank of mark line — apostrophe key
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'apostrophe', 'c');
    is($vb->cursor_line, 2, 'jumped to mark c line');
    is($vb->cursor_col, 2, 'jumped to first non-blank of mark c line');
};

subtest 'Marks: jump to non-existent mark does nothing' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(1, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'grave', 'x');
    is($vb->cursor_line, 1, 'no jump for non-existent mark');
    is($vb->cursor_col, 0, 'cursor unchanged');
};

subtest 'Marks: multiple marks coexist' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "a\nb\nc\nd\ne\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'a');
    $vb->set_cursor(2, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'b');
    $vb->set_cursor(4, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'c');

    ok(exists $ctx->{marks}{a}, 'mark a exists');
    ok(exists $ctx->{marks}{b}, 'mark b exists');
    ok(exists $ctx->{marks}{c}, 'mark c exists');

    # Jump between them
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'grave', 'a');
    is($vb->cursor_line, 0, 'jumped to mark a');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'grave', 'b');
    is($vb->cursor_line, 2, 'jumped to mark b');
};

subtest 'Marks: overwrite existing mark' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'a');
    is($ctx->{marks}{a}{line}, 0, 'mark a at line 0');

    $vb->set_cursor(2, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'a');
    is($ctx->{marks}{a}{line}, 2, 'mark a overwritten to line 2');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'grave', 'a');
    is($vb->cursor_line, 2, 'jumped to updated mark a');
};

subtest 'Marks: persist across mode changes' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $vb->set_cursor(0, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'm', 'p');

    # Enter and exit insert mode
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i', 'Escape');
    ok(exists $ctx->{marks}{p}, 'mark p persists after insert mode');

    # Enter and exit visual mode
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'Escape');
    ok(exists $ctx->{marks}{p}, 'mark p persists after visual mode');
};

done_testing;
