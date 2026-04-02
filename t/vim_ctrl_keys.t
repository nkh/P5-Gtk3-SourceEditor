#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# Ctrl-Key Scroll and Paging (C5) — Ctrl-u/d/f/b
# ==========================================================================

# --- Ctrl-d: scroll half-page down ---
subtest 'Ctrl-d scrolls half-page down' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-d');
    my $expected = int(20 / 2);  # half of page_size
    is($vb->cursor_line, $expected, "Ctrl-d moves cursor down by half page ($expected lines)");
};

# --- Ctrl-u: scroll half-page up ---
subtest 'Ctrl-u scrolls half-page up' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(15, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-u');
    my $half = int(20 / 2);
    is($vb->cursor_line, 15 - $half, "Ctrl-u moves cursor up by half page ($half lines)");
};

# --- Ctrl-u at top of buffer ---
subtest 'Ctrl-u at top of buffer does not go negative' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-u');
    is($vb->cursor_line, 0, 'Ctrl-u at line 0 stays at line 0');
};

# --- Ctrl-d at bottom of buffer ---
subtest 'Ctrl-d at bottom of buffer clamps' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "a\nb\nc\nd\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    my $last = $vb->line_count - 1;
    $vb->set_cursor($last, 0);  # last line

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-d');
    is($vb->cursor_line, $last, 'Ctrl-d at last line clamps to last line');
};

# --- Ctrl-f: full page forward ---
subtest 'Ctrl-f scrolls full page forward' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(5, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-f');
    is($vb->cursor_line, 25, 'Ctrl-f moves cursor down by full page (20 lines)');
};

# --- Ctrl-b: full page backward ---
subtest 'Ctrl-b scrolls full page backward' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(25, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-b');
    is($vb->cursor_line, 5, 'Ctrl-b moves cursor up by full page (20 lines)');
};

# --- Virtual column tracking with Ctrl-d/u ---
subtest 'Ctrl-d preserves desired column (virtual column tracking)' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(0, 4);  # col 4 on "line 1" (length 6)
    $ctx->{desired_col} = 4;

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-d');
    # All lines are "line N" (length 6 or 7), so col 4 is valid
    is($vb->cursor_col, 4, 'Ctrl-d preserves desired column');
};

# --- 2Ctrl-d: count prefix with ctrl key ---
subtest '2 Control-d scrolls two half-pages' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(0, 0);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-d', 'Control-d');
    my $half = int(20 / 2);
    is($vb->cursor_line, $half * 2, 'Two Ctrl-d moves by two half-pages');
};

# --- Ctrl-y and Ctrl-e: scroll line up/down (no gtk_view in test, no-op) ---
subtest 'Ctrl-y and Ctrl-e are no-ops without gtk_view' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    $vb->set_cursor(1, 2);

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-y');
    is($vb->cursor_line, 1, 'Ctrl-y does not move cursor (no gtk_view)');
    is($vb->cursor_col, 2, 'Ctrl-y does not change column (no gtk_view)');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Control-e');
    is($vb->cursor_line, 1, 'Ctrl-e does not move cursor (no gtk_view)');
};

# --- Unknown Ctrl key is silently consumed ---
subtest 'Unknown Ctrl key does not crash' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);

    my $result = Gtk3::SourceEditor::VimBindings::handle_ctrl_key($ctx, 'Control-z');
    is($result, 1, 'Unknown ctrl key returns TRUE (suppressed)');
};

# --- Ctrl-d in visual mode ---
subtest 'Ctrl-d works in visual mode' => sub {
    my $text = join("\n", map { "line $_" } 1 .. 40);
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => 20,
    );
    $vb->set_cursor(0, 0);

    # Enter visual mode, then Ctrl-d
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'v', 'Control-d');
    my $half = int(20 / 2);
    is($vb->cursor_line, $half, 'Ctrl-d moves cursor in visual mode');
    is(${$ctx->{vim_mode}}, 'visual', 'Still in visual mode after Ctrl-d');
};

done_testing;
