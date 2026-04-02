#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBindings;
use Gtk3::SourceEditor::VimBuffer::Test;

# ==========================================================================
# Scroll mode tests -- verify the three scrolling modes
# ==========================================================================
#
# Mode 1 (edge, default): cursor moves freely; GTK handles scrolling.
#   In the test backend (no GTK view), move_vert simply moves the cursor.
#
# Mode 2 (center): cursor moves normally but after_move would call
#   scroll_to_mark with yalign=0.5 on the real view.  In tests we
#   verify the mode flag is set correctly.
#
# Mode 3 (scroll_lock): move_vert scrolls the buffer without moving
#   the cursor.  In the test backend (gtk_view=undef), the scroll
#   adjustment calls are silently caught by eval, and the cursor stays
#   put.
#
# The toggle_scroll_lock action (zx) activates/deactivates Mode 3.
# ==========================================================================

# --- Helper: create a test context with scroll_mode option ---------------
sub make_ctx {
    my (%opts) = @_;
    my $text = $opts{text} // "line 01\nline 02\nline 03\nline 04\nline 05\n"
                          . "line 06\nline 07\nline 08\nline 09\nline 10\n";

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => $text);

    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
        page_size  => $opts{page_size} // 5,
    );

    # Apply scroll mode if specified
    if ($opts{scroll_mode}) {
        $ctx->{_scroll_mode} = $opts{scroll_mode};
    }
    if ($opts{scroll_lock}) {
        $ctx->{_scroll_lock_active} = 1;
        $ctx->{_scroll_lock_prev}  = $opts{scroll_lock_prev};
    }

    return $ctx;
}

# ==========================================================================
#  Mode defaults
# ==========================================================================

subtest 'Default scroll mode is edge' => sub {
    my $ctx = make_ctx();
    is($ctx->{_scroll_mode}, undef, '_scroll_mode not set by default in test context');
    is($ctx->{_scroll_lock_active}, undef, 'scroll lock not active by default');
};

subtest 'scroll_mode can be set to center' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    is($ctx->{_scroll_mode}, 'center', 'scroll_mode set to center');
    is($ctx->{_scroll_lock_active}, undef, 'scroll lock not active');
};

subtest 'scroll_mode can be set to edge' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    is($ctx->{_scroll_mode}, 'edge', 'scroll_mode set to edge');
};

# ==========================================================================
#  Mode 1: edge-scroll (default)
# ==========================================================================

subtest 'Edge mode: move_vert moves cursor normally' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $vb = $ctx->{vb};

    is($vb->cursor_line, 0, 'cursor at line 0');
    $ctx->{move_vert}->(3);
    is($vb->cursor_line, 3, 'cursor moved to line 3');

    $ctx->{move_vert}->(-2);
    is($vb->cursor_line, 1, 'cursor moved back to line 1');
};

subtest 'Edge mode: move_vert respects desired_col' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $vb = $ctx->{vb};

    $vb->set_cursor(0, 3);
    $ctx->{desired_col} = 3;

    $ctx->{move_vert}->(1);
    is($vb->cursor_line, 1, 'moved down one line');
    is($vb->cursor_col, 3, 'desired_col preserved');
};

subtest 'Edge mode: move_vert clamps at buffer boundaries' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $vb = $ctx->{vb};
    my $last = $vb->line_count - 1;

    $ctx->{move_vert}->(-999);
    is($vb->cursor_line, 0, 'clamped to line 0');

    $ctx->{move_vert}->(999);
    is($vb->cursor_line, $last, 'clamped to last line');
};

# ==========================================================================
#  Mode 2: center
# ==========================================================================

subtest 'Center mode: move_vert still moves cursor normally' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    my $vb = $ctx->{vb};

    $ctx->{move_vert}->(5);
    is($vb->cursor_line, 5, 'cursor moved to line 5 in center mode');

    $ctx->{move_vert}->(-3);
    is($vb->cursor_line, 2, 'cursor moved back in center mode');
};

# ==========================================================================
#  Mode 3: scroll-lock
# ==========================================================================

subtest 'Scroll-lock: move_vert skips scroll branch when gtk_view is undef' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    $ctx->{_scroll_lock_active} = 1;
    my $vb = $ctx->{vb};

    # In the test context gtk_view is undef, so the scroll-lock branch
    # (which requires gtk_view) is not taken.  move_vert falls through
    # to normal cursor movement.  This is expected -- cursor freezing is
    # inherently a visual/GTK behavior that requires a real view.
    is($vb->cursor_line, 0, 'cursor at line 0 before move');
    $ctx->{move_vert}->(5);
    is($vb->cursor_line, 5, 'cursor moves normally (no gtk_view to scroll)');
};

subtest 'Scroll-lock: state preserved even without gtk_view' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    $ctx->{_scroll_lock_active} = 1;
    $ctx->{_scroll_lock_prev}  = 'center';

    ok($ctx->{_scroll_lock_active}, 'scroll lock flag is set');
    is($ctx->{_scroll_lock_prev}, 'center', 'prev mode preserved');
    # The actual cursor freeze requires gtk_view (tested via integration
    # with a real GTK view, not in the unit-test backend).
};

# ==========================================================================
#  toggle_scroll_lock action
# ==========================================================================

subtest 'Toggle scroll lock: activate from edge mode' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    ok(!$ctx->{_scroll_lock_active}, 'scroll lock initially off');

    $ACTIONS->{toggle_scroll_lock}->($ctx);
    ok($ctx->{_scroll_lock_active}, 'scroll lock activated');
    is($ctx->{_scroll_lock_prev}, 'edge', 'previous mode saved as edge');

    $ACTIONS->{toggle_scroll_lock}->($ctx);
    ok(!$ctx->{_scroll_lock_active}, 'scroll lock deactivated');
    is($ctx->{_scroll_mode}, 'edge', 'restored to edge mode');
    is($ctx->{_scroll_lock_prev}, undef, 'prev cleared');
};

subtest 'Toggle scroll lock: activate from center mode' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    $ACTIONS->{toggle_scroll_lock}->($ctx);
    ok($ctx->{_scroll_lock_active}, 'scroll lock activated from center');
    is($ctx->{_scroll_lock_prev}, 'center', 'previous mode saved as center');

    $ACTIONS->{toggle_scroll_lock}->($ctx);
    ok(!$ctx->{_scroll_lock_active}, 'scroll lock deactivated');
    is($ctx->{_scroll_mode}, 'center', 'restored to center mode');
};

subtest 'Toggle scroll lock: double toggle restores original' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    # Toggle on
    $ACTIONS->{toggle_scroll_lock}->($ctx);
    # Toggle off
    $ACTIONS->{toggle_scroll_lock}->($ctx);
    # Toggle on again
    $ACTIONS->{toggle_scroll_lock}->($ctx);

    ok($ctx->{_scroll_lock_active}, 'scroll lock active after second toggle');
    is($ctx->{_scroll_lock_prev}, 'center', 'prev still center');
};

subtest 'Toggle scroll lock: state management' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();
    my $vb = $ctx->{vb};

    $vb->set_cursor(4, 2);

    # Activate scroll lock
    $ACTIONS->{toggle_scroll_lock}->($ctx);
    ok($ctx->{_scroll_lock_active}, 'scroll lock active');
    is($vb->cursor_line, 4, 'cursor at line 4');

    # Deactivate scroll lock
    $ACTIONS->{toggle_scroll_lock}->($ctx);
    ok(!$ctx->{_scroll_lock_active}, 'scroll lock off');

    # Movement works after unlock
    $ctx->{move_vert}->(2);
    is($vb->cursor_line, 6, 'cursor moves normally after unlock');
};

# ==========================================================================
#  Key sequence: zx dispatches toggle_scroll_lock
# ==========================================================================

subtest 'zx key sequence dispatches toggle_scroll_lock' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'z', 'x');

    ok($ctx->{_scroll_lock_active}, 'zx activated scroll lock');

    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'z', 'x');
    ok(!$ctx->{_scroll_lock_active}, 'zx deactivated scroll lock');
    is($ctx->{_scroll_mode}, 'edge', 'mode restored to edge');
};

# ==========================================================================
#  :set scroll_mode= ex-command
# ==========================================================================

subtest ':set scroll_mode=edge' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    $ACTIONS->{cmd_set}->($ctx, 1, { args => ['scroll_mode=edge'] });
    is($ctx->{_scroll_mode}, 'edge', 'scroll_mode changed to edge');
    is($ctx->{_scroll_lock_active}, 0, 'scroll lock deactivated');
};

subtest ':set scroll_mode=center' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    $ACTIONS->{cmd_set}->($ctx, 1, { args => ['scroll_mode=center'] });
    is($ctx->{_scroll_mode}, 'center', 'scroll_mode changed to center');
};

subtest ':set scroll_mode=invalid shows error' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    my $status = '';
    $ctx->{show_status} = sub { $status = $_[0] };

    $ACTIONS->{cmd_set}->($ctx, 1, { args => ['scroll_mode=invalid'] });
    is($ctx->{_scroll_mode}, 'edge', 'scroll_mode unchanged');
    like($status, qr/Error.*invalid scroll_mode/, 'error status set');
};

subtest ':set scroll_mode (query) shows current value' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    my $status = '';
    $ctx->{show_status} = sub { $status = $_[0] };

    $ACTIONS->{cmd_set}->($ctx, 1, { args => ['scroll_mode'] });
    is($status, 'scroll_mode=center', 'status shows current mode');
};

subtest ':set scroll_mode query shows scroll_lock when active' => sub {
    my $ctx = make_ctx(scroll_mode => 'edge');
    $ctx->{_scroll_lock_active} = 1;
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    my $status = '';
    $ctx->{show_status} = sub { $status = $_[0] };

    $ACTIONS->{cmd_set}->($ctx, 1, { args => ['scroll_mode'] });
    is($status, 'scroll_mode=scroll_lock', 'status shows scroll_lock when active');
};

# ==========================================================================
#  :set scroll_mode= deactivates scroll_lock
# ==========================================================================

subtest ':set scroll_mode= deactivates scroll_lock' => sub {
    my $ctx = make_ctx(scroll_mode => 'center');
    $ctx->{_scroll_lock_active} = 1;
    $ctx->{_scroll_lock_prev}  = 'center';
    my $ACTIONS = Gtk3::SourceEditor::VimBindings::get_actions();

    $ACTIONS->{cmd_set}->($ctx, 1, { args => ['scroll_mode=edge'] });
    is($ctx->{_scroll_mode}, 'edge', 'scroll_mode changed');
    is($ctx->{_scroll_lock_active}, 0, 'scroll lock deactivated');
    is($ctx->{_scroll_lock_prev}, undef, 'prev cleared');
};

done_testing;
