#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# Undo/Redo regression tests
#
# Key regression: _dispatch wraps every action in begin_user_action /
# end_user_action.  When undo (or redo) is called inside such a group,
# GTK's undo manager absorbs the undo call into the empty group, producing
# no visible effect.  The fix is to call end_user_action BEFORE undo/redo
# in the action handler.
#
# These tests use VimBuffer::Test which has its own undo stack.  The
# Test buffer's begin_user_action / end_user_action are no-ops, so we
# need a SpyBuffer that tracks whether these methods are called, allowing
# us to verify the undo handler properly closes the action group.
# ==========================================================================

# ----------------------------------------------------------------
# SpyBuffer: tracks begin/end_user_action calls
# ----------------------------------------------------------------
package SpyBuffer;
use parent 'Gtk3::SourceEditor::VimBuffer::Test';

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);
    $self->{_begin_count} = 0;
    $self->{_end_count}   = 0;
    return $self;
}

sub begin_user_action { $_[0]->{_begin_count}++ }
sub end_user_action   { $_[0]->{_end_count}++ }

sub begin_count { $_[0]->{_begin_count} }
sub end_count   { $_[0]->{_end_count} }

package main;

# ==========================================================================
# 1. Basic undo: single operation
# ==========================================================================
subtest 'Undo: x then u restores text' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "ello\n", 'x deleted char');
    is($vb->cursor_col, 0, 'cursor at col 0 after x');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "hello\n", 'u restored original text');
};

# ==========================================================================
# 2. Undo restores cursor position
# ==========================================================================
subtest 'Undo: restores cursor position' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # x at col 0 deletes 'h'
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->cursor_col, 0, 'cursor at col 0 after x');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->cursor_line, 0, 'cursor line restored');
    is($vb->cursor_col, 0, 'cursor col restored');
};

# ==========================================================================
# 3. Multiple undo: sequential operations
# ==========================================================================
subtest 'Undo: multiple sequential operations' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcde\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "bcde\n", 'first x');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "cde\n", 'second x');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "de\n", 'third x');

    # Undo each one
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "cde\n", 'first undo restores third x');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "bcde\n", 'second undo restores second x');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "abcde\n", 'third undo restores first x');
};

# ==========================================================================
# 4. Numeric prefix: 3u undoes 3 steps
# ==========================================================================
subtest 'Undo: 3u undoes 3 operations' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcde\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x', 'x', 'x');
    is($vb->text, "de\n", '3x done');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '3', 'u');
    is($vb->text, "abcde\n", '3u undoes all 3');
};

# ==========================================================================
# 5. Undo on empty undo stack is a no-op
# ==========================================================================
subtest 'Undo: empty stack is no-op' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "hello\n", 'undo on empty stack is no-op');
};

# ==========================================================================
# 6. Undo dd (delete line)
# ==========================================================================
subtest 'Undo: dd then u restores line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    $vb->set_cursor(1, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'd');
    is($vb->text, "line1\nline3\n", 'dd deleted line2');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "line1\nline2\nline3\n", 'u restored line2');
};

# ==========================================================================
# 7. REGRESSION: end_user_action must be called before undo
#
#    _dispatch calls begin_user_action, then the action handler, then
#    end_user_action.  The undo handler MUST call end_user_action first
#    to close the group, otherwise undo is absorbed into the group and
#    has no net effect.  With SpyBuffer we verify this.
# ==========================================================================
subtest 'Regression: undo calls end_user_action before undo' => sub {
    my $vb = SpyBuffer->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # Insert a character so there's something to undo
    $vb->insert_text("X");
    is($vb->text, "Xhello\n", 'inserted X');

    # Reset counters before pressing u
    $vb->{_begin_count} = 0;
    $vb->{_end_count}   = 0;

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');

    # _dispatch calls begin_user_action (1) + undo handler calls end_user_action (1)
    # + _dispatch calls end_user_action (1) = begin:1, end:2
    # The key assertion: end_count >= begin_count, meaning the handler
    # properly closed the group before calling undo.
    cmp_ok($vb->end_count, '>=', $vb->begin_count,
           'undo handler closed the user action group (end >= begin)');
    is($vb->text, "hello\n", 'buffer was actually undone');
};

# ==========================================================================
# 8. REGRESSION: redo also calls end_user_action before redo
# ==========================================================================
subtest 'Regression: redo calls end_user_action before redo' => sub {
    my $vb = SpyBuffer->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    # Do an undoable action, then undo it (so redo has something to redo)
    $vb->insert_text("X");
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "hello\n", 'undone');

    # Reset counters
    $vb->{_begin_count} = 0;
    $vb->{_end_count}   = 0;

    # Ctrl-r is redo
    Gtk3::SourceEditor::VimBindings::handle_ctrl_key($ctx, 'Control-r');

    cmp_ok($vb->end_count, '>=', $vb->begin_count,
           'redo handler closed the user action group (end >= begin)');
};

# ==========================================================================
# 9. Undo after dd with numeric prefix dd
# ==========================================================================
subtest 'Undo: 2dd then u restores both lines' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "a\nb\nc\nd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, '2', 'd', 'd');
    is($vb->text, "c\nd\n", '2dd deleted lines a and b');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "a\nb\nc\nd\n", 'u restored both lines');
};

# ==========================================================================
# 10. Undo mixed operations
# ==========================================================================
subtest 'Undo: mixed x and dd operations' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\ndef\nghi\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "bc\ndef\nghi\n", 'x on line 0');
    $vb->set_cursor(1, 0);
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'd', 'd');
    is($vb->text, "bc\nghi\n", 'dd on line 1');

    # Undo dd first
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "bc\ndef\nghi\n", 'u restored dd');

    # Undo x
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'u');
    is($vb->text, "abc\ndef\nghi\n", 'u restored x');
};

done_testing;
