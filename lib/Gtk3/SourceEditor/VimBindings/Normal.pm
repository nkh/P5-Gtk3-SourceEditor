package Gtk3::SourceEditor::VimBindings::Normal;

use strict;
use warnings;

our $VERSION = '0.04';

# register(\%ACTIONS) -- populate %ACTIONS with all normal-mode action coderefs,
# and return the default normal-mode keymap hashref.
sub register {
    my ($ACTIONS) = @_;

    # --- helper: optionally copy yanked text to GTK clipboard ---
    my $_set_yank;
    $_set_yank = sub {
        my ($ctx, $text) = @_;
        ${$ctx->{yank_buf}} = $text;
        # Copy to system clipboard if enabled
        if ($ctx->{use_clipboard} && defined $text && length $text) {
            my $view = $ctx->{gtk_view};
            if ($view) {
                eval {
                    my $clipboard = Gtk3::Clipboard::get_default(
                        $view->get_display
                    );
                    $clipboard->set_text($text, length($text));
                };
            }
        }
    };

    # --- helper: save line snapshot for U (line-undo) ---
    my $_save_line_snapshot;
    $_save_line_snapshot = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        $ctx->{line_snapshots} //= {};
        $ctx->{line_snapshots}{$line} = $vb->line_text($line)
            unless exists $ctx->{line_snapshots}{$line};
    };

    # ================================================================
    #  Navigation
    # ================================================================

    $ACTIONS->{move_left} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $col = $vb->cursor_col;
        $col -= $count;
        $col = 0 if $col < 0;
        my $line = $vb->cursor_line;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $col);
        } else {
            $vb->set_cursor($line, $col);
        }
        $ctx->{desired_col} = $vb->cursor_col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{move_right} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $col = $vb->cursor_col;
        my $max = $vb->line_length($vb->cursor_line);
        $col += $count;
        my $line = $vb->cursor_line;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            # In visual mode, allow cursor one past the last character
            # so the last character is included in the selection.
            $col = $max if $col > $max;
            $vb->move_cursor($line, $col);
        } else {
            # In normal mode, stop at the last character (Vim behavior).
            my $limit = $max > 0 ? $max - 1 : 0;
            $col = $limit if $col > $limit;
            $vb->set_cursor($line, $col);
        }
        $ctx->{desired_col} = $vb->cursor_col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{move_up} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        $ctx->{move_vert}->(-$count);
    };

    $ACTIONS->{move_down} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        $ctx->{move_vert}->($count);
    };

    $ACTIONS->{page_up} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $ps = $ctx->{page_size} // 20;
        my $target = $vb->cursor_line - ($ps * $count);
        $target = 0 if $target < 0;
        # Use desired_col for Vim virtual-column behavior (like move_vert).
        my $col = $ctx->{desired_col} // $vb->cursor_col;
        my $max = $vb->line_length($target);
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $col = $max if $col > $max;
            $vb->move_cursor($target, $col);
        } else {
            my $limit = $max > 0 ? $max - 1 : 0;
            $col = $limit if $col > $limit;
            $vb->set_cursor($target, $col);
        }
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{page_down} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $ps = $ctx->{page_size} // 20;
        my $target = $vb->cursor_line + ($ps * $count);
        my $last = $vb->line_count - 1;
        $target = $last if $target > $last;
        # Use desired_col for Vim virtual-column behavior (like move_vert).
        my $col = $ctx->{desired_col} // $vb->cursor_col;
        my $max = $vb->line_length($target);
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $col = $max if $col > $max;
            $vb->move_cursor($target, $col);
        } else {
            my $limit = $max > 0 ? $max - 1 : 0;
            $col = $limit if $col > $limit;
            $vb->set_cursor($target, $col);
        }
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ================================================================
    #  Ctrl-Key Scroll and Paging (C5) -- Ctrl-u/d/f/b/y/e
    # ================================================================

    $ACTIONS->{scroll_half_up} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $half = int(($ctx->{page_size} // 20) / 2) || 10;
        $ctx->{move_vert}->(-$half * $count);
    };

    $ACTIONS->{scroll_half_down} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $half = int(($ctx->{page_size} // 20) / 2) || 10;
        $ctx->{move_vert}->($half * $count);
    };

    # Ctrl-y: scroll viewport up one line without moving cursor
    $ACTIONS->{scroll_line_up} = sub {
        my ($ctx, $count) = @_;
        my $view = $ctx->{gtk_view};
        return unless $view;
        $count ||= 1;
        eval {
            # Use actual line height from font metrics if available,
            # otherwise fall back to the GTK step_increment.
            my $step = $ctx->{_line_height};
            if (!$step) {
                my $vadj = $view->get_vadjustment();
                $step = $vadj->get_step_increment() || 20;
            }
            my $vadj = $view->get_vadjustment();
            my $val = $vadj->get_value();
            $vadj->set_value($val - ($step * $count));
        };
    };

    # Ctrl-e: scroll viewport down one line without moving cursor
    $ACTIONS->{scroll_line_down} = sub {
        my ($ctx, $count) = @_;
        my $view = $ctx->{gtk_view};
        return unless $view;
        $count ||= 1;
        eval {
            # Use actual line height from font metrics if available,
            # otherwise fall back to the GTK step_increment.
            my $step = $ctx->{_line_height};
            if (!$step) {
                my $vadj = $view->get_vadjustment();
                $step = $vadj->get_step_increment() || 20;
            }
            my $vadj = $view->get_vadjustment();
            my $val = $vadj->get_value();
            $vadj->set_value($val + ($step * $count));
        };
    };

    # Ctrl-r: redo (delegates to buffer backend)
    $ACTIONS->{redo} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        # _dispatch wraps every action in begin/end_user_action.
        # For redo we must close the group FIRST, otherwise the redo
        # call is absorbed into the group and has no net effect.
        $ctx->{vb}->end_user_action if $ctx->{vb}->can('end_user_action');
        $ctx->{vb}->redo() for 1 .. $count;
    };

    $ACTIONS->{word_forward} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        $vb->word_forward() for 1 .. $count;
        # In normal mode, collapse any selection that the buffer's word
        # motion may have created.  The Gtk3 backend uses
        # move_mark_by_name('insert') which preserves selection_bound,
        # creating a visible GTK selection.  place_cursor (via set_cursor)
        # collapses both marks to the same position.
        my $mode = ${$ctx->{vim_mode}};
        if ($mode ne 'visual' && $mode ne 'visual_line' && $mode ne 'visual_block') {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col);
        }
        $ctx->{desired_col} = $vb->cursor_col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{word_backward} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        $vb->word_backward() for 1 .. $count;
        # Collapse selection in normal mode (see word_forward comment).
        my $mode = ${$ctx->{vim_mode}};
        if ($mode ne 'visual' && $mode ne 'visual_line' && $mode ne 'visual_block') {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col);
        }
        $ctx->{desired_col} = $vb->cursor_col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{word_end} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        $vb->word_end() for 1 .. $count;
        # Collapse selection in normal mode (see word_forward comment).
        my $mode = ${$ctx->{vim_mode}};
        if ($mode ne 'visual' && $mode ne 'visual_line' && $mode ne 'visual_block') {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col);
        }
        $ctx->{desired_col} = $vb->cursor_col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{line_start} = sub {
        my ($ctx) = @_;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, 0);
        } else {
            $vb->set_cursor($line, 0);
        }
        $ctx->{desired_col} = 0;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{line_end} = sub {
        my ($ctx) = @_;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col = $vb->line_length($line) - 1;
        $col = 0 if $col < 0;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $col);
        } else {
            $vb->set_cursor($line, $col);
        }
        $ctx->{desired_col} = $vb->cursor_col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{first_nonblank} = sub {
        my ($ctx) = @_;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col = $vb->first_nonblank_col($line);
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $col);
        } else {
            $vb->set_cursor($line, $col);
        }
        $ctx->{desired_col} = $col;
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{file_start} = sub {
        my ($ctx, $count) = @_;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $target = 0;
        $target = $count - 1 if $count && $count > 1;
        $target = 0 if $target < 0;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($target, 0);
        } else {
            $vb->set_cursor($target, 0);
        }
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{file_end} = sub {
        my ($ctx, $count) = @_;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $last = $vb->line_count - 1;
        my $target = $last;
        if ($count && $count > 1) {
            $target = $count - 1;
            $target = $last if $target > $last;
        }
        $target = 0 if $target < 0;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($target, 0);
        } else {
            $vb->set_cursor($target, 0);
        }
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{goto_line} = sub {
        my ($ctx, $count) = @_;
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $last = $vb->line_count - 1;
        my $target = $count - 1;
        $target = 0     if $target < 0;
        $target = $last if $target > $last;
        my $col = $vb->cursor_col;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($target, $col);
        } else {
            $vb->set_cursor($target, $col);
        }
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ================================================================
    #  Find-Character Motions (f/F/t/T and ;/,) -- C2
    # ================================================================

    $ACTIONS->{find_char_forward} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $char = $extra[0];
        my $vb = $ctx->{vb};
        $count ||= 1;
        my $line = $vb->cursor_line;
        my $text = $vb->line_text($line);
        my $col = $vb->cursor_col;
        my $found = 0;
        for (1 .. $count) {
            my $pos = index($text, $char, $col + 1);
            if ($pos < 0) {
                $ctx->{last_find} = undef;
                return;
            }
            $col = $pos;
            $found = 1;
        }
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $col);
        } else {
            $vb->set_cursor($line, $col);
        }
        $ctx->{desired_col} = $col;
        $ctx->{last_find} = { cmd => 'f', char => $char, count => $count };
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{find_char_backward} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $char = $extra[0];
        my $vb = $ctx->{vb};
        $count ||= 1;
        my $line = $vb->cursor_line;
        my $text = $vb->line_text($line);
        my $col = $vb->cursor_col;
        my $found = 0;
        for (1 .. $count) {
            my $pos = rindex($text, $char, $col - 1);
            if ($pos < 0) {
                $ctx->{last_find} = undef;
                return;
            }
            $col = $pos;
            $found = 1;
        }
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $col);
        } else {
            $vb->set_cursor($line, $col);
        }
        $ctx->{desired_col} = $col;
        $ctx->{last_find} = { cmd => 'F', char => $char, count => $count };
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{till_char_forward} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $char = $extra[0];
        my $vb = $ctx->{vb};
        $count ||= 1;
        my $line = $vb->cursor_line;
        my $text = $vb->line_text($line);
        my $col = $vb->cursor_col;
        for (1 .. $count) {
            my $pos = index($text, $char, $col + 1);
            if ($pos < 0) {
                $ctx->{last_find} = undef;
                return;
            }
            $col = $pos;
        }
        # t lands one character before the target
        my $target_col = $col - 1;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $target_col);
        } else {
            $vb->set_cursor($line, $target_col);
        }
        $ctx->{desired_col} = $target_col;
        $ctx->{last_find} = { cmd => 't', char => $char, count => $count };
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{till_char_backward} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $char = $extra[0];
        my $vb = $ctx->{vb};
        $count ||= 1;
        my $line = $vb->cursor_line;
        my $text = $vb->line_text($line);
        my $col = $vb->cursor_col;
        for (1 .. $count) {
            my $pos = rindex($text, $char, $col - 1);
            if ($pos < 0) {
                $ctx->{last_find} = undef;
                return;
            }
            $col = $pos;
        }
        # T lands one character after the target
        my $target_col = $col + 1;
        my $mode = ${$ctx->{vim_mode}};
        if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
            $vb->move_cursor($line, $target_col);
        } else {
            $vb->set_cursor($line, $target_col);
        }
        $ctx->{desired_col} = $target_col;
        $ctx->{last_find} = { cmd => 'T', char => $char, count => $count };
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{find_repeat} = sub {
        my ($ctx, $count) = @_;
        my $lf = $ctx->{last_find};
        return unless $lf;
        $count ||= $lf->{count};
        my $action = 'find_char_forward';
        $action = 'find_char_backward'  if $lf->{cmd} eq 'F';
        $action = 'till_char_forward'    if $lf->{cmd} eq 't';
        $action = 'till_char_backward'   if $lf->{cmd} eq 'T';
        $ACTIONS->{$action}->($ctx, $count, $lf->{char});
        # Restore so ;/, don't oscillate (the underlying action overwrites
        # last_find with the reversed direction, which would flip on next repeat)
        $ctx->{last_find} = $lf;
    };

    $ACTIONS->{find_repeat_reverse} = sub {
        my ($ctx, $count) = @_;
        my $lf = $ctx->{last_find};
        return unless $lf;
        $count ||= $lf->{count};
        # Reverse the direction
        my %rev = ( f => 'find_char_backward', F => 'find_char_forward',
                    t => 'till_char_backward',  T => 'till_char_forward' );
        my $action = $rev{$lf->{cmd}};
        return unless $action;
        $ACTIONS->{$action}->($ctx, $count, $lf->{char});
        # Restore original last_find
        $ctx->{last_find} = $lf;
    };

    # ================================================================
    #  Bracket Matching (% Motion) -- C7
    # ================================================================

    $ACTIONS->{percent_motion} = sub {
        my ($ctx, $count) = @_;
        my $vb = $ctx->{vb};
        my ($line, $col) = ($vb->cursor_line, $vb->cursor_col);
        my $total_lines = $vb->line_count;

        my %pairs = (
            '(' => ')', ')' => '(',
            '[' => ']', ']' => '[',
            '{' => '}', '}' => '{',
        );
        my %openers = ('(' => 1, '[' => 1, '{' => 1);
        my %closers = (')' => 1, ']' => 1, '}' => 1);

        # If cursor is not on a bracket, scan forward to find the next one
        my $char = $vb->char_at($line, $col);
        if (!$pairs{$char}) {
            # Scan forward from cursor to find the next bracket character
            my $found = 0;
            for my $ln ($line .. $total_lines - 1) {
                my $text = $vb->line_text($ln);
                my $start_c = ($ln == $line) ? $col : 0;
                for my $c ($start_c .. length($text) - 1) {
                    if ($pairs{ substr($text, $c, 1) }) {
                        $line = $ln;
                        $col = $c;
                        $char = substr($text, $c, 1);
                        $found = 1;
                        last;
                    }
                }
                last if $found;
            }
            return unless $found;
        }

        return unless $pairs{$char};
        my $target = $pairs{$char};

        my $depth = 1;
        if ($openers{$char}) {
            # Scan forward
            my $c_line = $line;
            my $c_col = $col + 1;
            while ($c_line < $total_lines) {
                my $text = $vb->line_text($c_line);
                while ($c_col < length($text)) {
                    my $ch = substr($text, $c_col, 1);
                    if ($ch eq $char) {
                        $depth++;
                    } elsif ($ch eq $target) {
                        $depth--;
                        if ($depth == 0) {
                            my $mode = ${$ctx->{vim_mode}};
                            if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
                                $vb->move_cursor($c_line, $c_col);
                            } else {
                                $vb->set_cursor($c_line, $c_col);
                            }
                            $ctx->{desired_col} = $c_col;
                            $ctx->{after_move}->($ctx) if $ctx->{after_move};
                            return;
                        }
                    }
                    $c_col++;
                }
                $c_line++;
                $c_col = 0;
            }
        } else {
            # Scan backward
            my $c_line = $line;
            my $c_col = $col - 1;
            while ($c_line >= 0) {
                my $text = $vb->line_text($c_line);
                while ($c_col >= 0) {
                    my $ch = substr($text, $c_col, 1);
                    if ($ch eq $char) {
                        $depth++;
                    } elsif ($ch eq $target) {
                        $depth--;
                        if ($depth == 0) {
                            my $mode = ${$ctx->{vim_mode}};
                            if ($mode eq 'visual' || $mode eq 'visual_line' || $mode eq 'visual_block') {
                                $vb->move_cursor($c_line, $c_col);
                            } else {
                                $vb->set_cursor($c_line, $c_col);
                            }
                            $ctx->{desired_col} = $c_col;
                            $ctx->{after_move}->($ctx) if $ctx->{after_move};
                            return;
                        }
                    }
                    $c_col--;
                }
                $c_line--;
                last if $c_line < 0;
                $c_col = length($vb->line_text($c_line)) - 1;
            }
        }

        # No match found - do nothing (Vim behavior)
    };

    # ================================================================
    #  Insert mode entry
    # ================================================================

    $ACTIONS->{enter_insert} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{enter_insert_after} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        unless ($vb->at_line_end) {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col + 1);
        }
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{enter_insert_eol} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        $vb->set_cursor($vb->cursor_line, $vb->line_length($vb->cursor_line));
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{enter_insert_bol} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        $vb->set_cursor($vb->cursor_line, $vb->first_nonblank_col($vb->cursor_line));
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{open_below} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $vb = $ctx->{vb};
        $vb->set_cursor($vb->cursor_line, $vb->line_length($vb->cursor_line));
        $vb->insert_text("\n") for 1 .. $count;
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{open_above} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $vb = $ctx->{vb};
        for (1 .. $count) {
            $vb->set_cursor($vb->cursor_line, 0);
            $vb->insert_text("\n");
            $vb->set_cursor($vb->cursor_line - 1, 0);
        }
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{enter_replace_mode} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('replace');
    };

    # ================================================================
    #  Editing
    # ================================================================

    $ACTIONS->{exit_to_normal} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('normal');
        my $vb = $ctx->{vb};
        my $col = $vb->cursor_col;
        if ($col > 0) {
            $vb->set_cursor($vb->cursor_line, $col - 1);
        }
    };

    $ACTIONS->{delete_char} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        my $len  = $vb->line_length($line);
        my $del  = $count;
        if ($col + $del > $len) {
            $del = $len - $col;
        }
        return if $del <= 0;
        my $text = $vb->get_range($line, $col, $line, $col + $del);
        $vb->delete_range($line, $col, $line, $col + $del);
        $_set_yank->($ctx, $text);
        # clamp cursor
        $len = $vb->line_length($line);
        if ($col >= $len && $len > 0) {
            $vb->set_cursor($line, $len - 1);
        } elsif ($len == 0) {
            $vb->set_cursor($line, 0);
        }
    };

    $ACTIONS->{delete_line} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $last = $vb->line_count - 1;
        my $end = $line + $count - 1;
        $end = $last if $end > $last;
        # build yanked text
        my @parts;
        for my $l ($line .. $end) {
            push @parts, $vb->line_text($l);
        }
        my $yanked = join("\n", @parts) . "\n";
        $_set_yank->($ctx, $yanked);
        # delete lines (from line start to end-of-last-line + newline)
        my $next_line = $end + 1;
        if ($next_line <= $last) {
            $vb->delete_range($line, 0, $next_line, 0);
        } else {
            # deleting to end of buffer
            my $del_end_col = $vb->line_length($end);
            $vb->delete_range($line, 0, $end, $del_end_col);
        }
        # place cursor
        $last = $vb->line_count - 1;
        if ($line > $last) {
            $line = $last;
        }
        $vb->set_cursor($line, $vb->first_nonblank_col($line));
    };

    $ACTIONS->{delete_word} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        # remember start position
        my $start_line = $line;
        my $start_col  = $col;
        # advance word_forward $count times
        $vb->word_forward() for 1 .. $count;
        my $end_line = $vb->cursor_line;
        my $end_col  = $vb->cursor_col;
        # extract and delete
        my $text = $vb->get_range($start_line, $start_col, $end_line, $end_col);
        $_set_yank->($ctx, $text);
        $vb->delete_range($start_line, $start_col, $end_line, $end_col);
        # restore cursor to start
        $vb->set_cursor($start_line, $start_col);
        # clamp if line shortened
        my $len = $vb->line_length($start_line);
        if ($start_col >= $len && $len > 0) {
            $vb->set_cursor($start_line, $len - 1);
        } elsif ($len == 0) {
            $vb->set_cursor($start_line, 0);
        }
    };

    $ACTIONS->{change_line} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        # yank current line
        $_set_yank->($ctx, $vb->line_text($line) . "\n");
        # delete entire line content but leave empty line
        my $len = $vb->line_length($line);
        if ($len > 0) {
            $vb->delete_range($line, 0, $line, $len);
        }
        $vb->set_cursor($line, 0);
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{change_word} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        my $start_line = $line;
        my $start_col  = $col;
        # advance word_forward $count times
        $vb->word_forward() for 1 .. $count;
        my $end_line = $vb->cursor_line;
        my $end_col  = $vb->cursor_col;
        # delete range
        $vb->delete_range($start_line, $start_col, $end_line, $end_col);
        # position cursor at start
        $vb->set_cursor($start_line, $start_col);
        $ctx->{set_mode}->('insert');
    };

    $ACTIONS->{change_to_eol} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        my $len  = $vb->line_length($line);
        if ($col < $len) {
            $_set_yank->($ctx, $vb->get_range($line, $col, $line, $len));
            $vb->delete_range($line, $col, $line, $len);
        }
        $vb->set_cursor($line, $col);
        $ctx->{set_mode}->('insert');
    };

    # ================================================================
    #  Delete to end of line (d$)
    # ================================================================

    $ACTIONS->{delete_to_eol} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        my $len  = $vb->line_length($line);
        if ($col < $len) {
            $_set_yank->($ctx, $vb->get_range($line, $col, $line, $len));
            $vb->delete_range($line, $col, $line, $len);
        }
        # clamp cursor like Vim does for d$
        $len = $vb->line_length($line);
        if ($len > 0) {
            $vb->set_cursor($line, $len - 1);
        } else {
            $vb->set_cursor($line, 0);
        }
    };

    # ================================================================
    #  Delete backwards (Backspace in normal mode)
    # ================================================================

    $ACTIONS->{backspace} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        for (1 .. $count) {
            if ($col > 0) {
                $col--;
            } elsif ($line > 0) {
                $line--;
                $col = $vb->line_length($line);
            } else {
                last;
            }
        }
        if ($col < $vb->cursor_col || $line < $vb->cursor_line) {
            my $cur_line = $vb->cursor_line;
            my $cur_col  = $vb->cursor_col;
            $_set_yank->($ctx, $vb->get_range($line, $col, $cur_line, $cur_col));
            $vb->delete_range($line, $col, $cur_line, $cur_col);
            $vb->set_cursor($line, $col);
        }
    };

    # ================================================================
    #  Yank inner word (yiw)
    # ================================================================

    $ACTIONS->{yank_inner_word} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $col  = $vb->cursor_col;
        my $text = $vb->line_text($line);

        # Find word boundaries
        my $start = $col;
        # Walk back to start of current word
        while ($start > 0 && substr($text, $start - 1, 1) =~ /\S/) { $start--; }
        my $end = $start;
        # Walk forward to end of current word (and repeat for count)
        for (1 .. $count) {
            while ($end < length($text) && substr($text, $end, 1) =~ /\S/) { $end++; }
            # Skip whitespace to next word (unless last iteration)
            if ($_ < $count) {
                while ($end < length($text) && substr($text, $end, 1) =~ /\s/) { $end++; }
            }
            $start = $end if $_ < $count;
        }
        $_set_yank->($ctx, substr($text, $start, $end - $start)) if $end > $start;
    };

    $ACTIONS->{replace_char} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $char = $extra[0];
        my $vb = $ctx->{vb};
        $count //= 1;
        $vb->replace_char($char);
    };

    $ACTIONS->{join_lines} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        # save line snapshot for U
        $_save_line_snapshot->($ctx);
        $vb->join_lines($count);
    };

    # ================================================================
    #  Yank / Paste
    # ================================================================

    $ACTIONS->{yank_line} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        my $last = $vb->line_count - 1;
        my $end = $line + $count - 1;
        $end = $last if $end > $last;
        my @parts;
        for my $l ($line .. $end) {
            push @parts, $vb->line_text($l);
        }
        $_set_yank->($ctx, join("\n", @parts) . "\n");
    };

    $ACTIONS->{yank_word} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $start_line = $vb->cursor_line;
        my $start_col  = $vb->cursor_col;
        $vb->word_forward() for 1 .. $count;
        my $end_line = $vb->cursor_line;
        my $end_col  = $vb->cursor_col;
        my $text = $vb->get_range($start_line, $start_col, $end_line, $end_col);
        $_set_yank->($ctx, $text);
        # restore cursor
        $vb->set_cursor($start_line, $start_col);
    };

    $ACTIONS->{paste} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $text = ${$ctx->{yank_buf}};
        return unless defined $text && length $text;
        my $vb = $ctx->{vb};
        
        if ($text =~ /\n/) {
            # linewise yank -- insert below current line
            my $cur_line = $vb->cursor_line;
            # Strip trailing newline for clean insertion, then prepend \n
            my $clean = $text;
            $clean =~ s/\n$//;
            $vb->set_cursor($cur_line, $vb->line_length($cur_line));
            $vb->insert_text("\n" . $clean) for 1 .. $count;
            $vb->set_cursor($cur_line + 1, $vb->first_nonblank_col($cur_line + 1));
        } else {
            # characterwise -- insert after cursor
            unless ($vb->at_line_end) {
                $vb->set_cursor($vb->cursor_line, $vb->cursor_col + 1);
            }
            $vb->insert_text($text) for 1 .. $count;
        }
    };

    $ACTIONS->{paste_before} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $text = ${$ctx->{yank_buf}};
        return unless defined $text && length $text;
        my $vb = $ctx->{vb};
        
        if ($text =~ /\n/) {
            # linewise yank -- insert above current line
            my $cur_line = $vb->cursor_line;
            my $clean = $text;
            $clean =~ s/\n$//;
            $vb->set_cursor($cur_line, 0);
            $vb->insert_text($clean . "\n") for 1 .. $count;
            $vb->set_cursor($cur_line, $vb->first_nonblank_col($cur_line));
        } else {
            # characterwise -- insert before cursor
            $vb->insert_text($text) for 1 .. $count;
        }
    };

    # Swap current word with yank buffer ( Vim's xp ).
    # Yanks the current word into yank_buf, deletes it, then pastes
    # the previous yank buffer content.  Net effect: replaces the word
    # under the cursor with the yank buffer contents.
    $ACTIONS->{swap_word} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $vb = $ctx->{vb};
        my $prev_yank = ${$ctx->{yank_buf}} // '';

        # Yank current word
        my $start_line = $vb->cursor_line;
        my $start_col  = $vb->cursor_col;
        $vb->word_forward() for 1 .. $count;
        my $end_line = $vb->cursor_line;
        my $end_col  = $vb->cursor_col;
        my $word = $vb->get_range($start_line, $start_col, $end_line, $end_col);
        ${$ctx->{yank_buf}} = $word;

        # Delete the word
        $vb->delete_range($start_line, $start_col, $end_line, $end_col);

        # Paste the previous yank buffer
        if (length $prev_yank) {
            $vb->insert_text($prev_yank);
        }

        # Position cursor at the start of the inserted text
        my $len = $vb->line_length($start_line);
        if ($start_col >= $len && $len > 0) {
            $vb->set_cursor($start_line, $len - 1);
        } elsif ($len == 0) {
            $vb->set_cursor($start_line, 0);
        }
    };

    # ================================================================
    #  Indentation
    # ================================================================

    $ACTIONS->{indent_right} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $vb = $ctx->{vb};
        my $sw = $ctx->{shiftwidth} // 4;
        $vb->indent_lines($count, $sw, 1);
    };

    $ACTIONS->{indent_left} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $vb = $ctx->{vb};
        my $sw = $ctx->{shiftwidth} // 4;
        $vb->indent_lines($count, $sw, -1);
    };

    # ================================================================
    #  Undo
    # ================================================================

    $ACTIONS->{undo} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        # _dispatch wraps every action in begin/end_user_action.
        # For undo we must close the group FIRST, otherwise the undo
        # call is absorbed into the group and has no net effect.
        $ctx->{vb}->end_user_action if $ctx->{vb}->can('end_user_action');
        $ctx->{vb}->undo() for 1 .. $count;
    };

    $ACTIONS->{line_undo} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $line = $vb->cursor_line;
        return unless exists $ctx->{line_snapshots}{$line};
        my $snapshot = $ctx->{line_snapshots}{$line};
        delete $ctx->{line_snapshots}{$line};
        # replace entire line content with snapshot
        my $cur_text = $vb->line_text($line);
        my $cur_len = length($cur_text);
        my $snap_len = length($snapshot);
        $vb->set_cursor($line, 0);
        if ($cur_len > 0) {
            $vb->delete_range($line, 0, $line, $cur_len);
        }
        if ($snap_len > 0) {
            $vb->insert_text($snapshot);
        }
        $vb->set_cursor($line, $vb->first_nonblank_col($line));
    };

    # ================================================================
    #  Search / Command entry
    # ================================================================

    $ACTIONS->{enter_search} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('command');
        if ($ctx->{cmd_entry}) {
            $ctx->{cmd_entry}->set_text('/');
            $ctx->{cmd_entry}->set_position(-1);
        }
    };

    $ACTIONS->{enter_search_backward} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('command');
        if ($ctx->{cmd_entry}) {
            $ctx->{cmd_entry}->set_text('?');
            $ctx->{cmd_entry}->set_position(-1);
        }
    };

    $ACTIONS->{enter_command} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('command');
        if ($ctx->{cmd_entry}) {
            $ctx->{cmd_entry}->set_text(':');
            $ctx->{cmd_entry}->set_position(-1);
        }
    };

    # ================================================================
    #  Marks
    # ================================================================

    $ACTIONS->{set_mark} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $mark = $extra[0];
        my $vb = $ctx->{vb};
        $ctx->{marks}{$mark} = {
            line => $vb->cursor_line,
            col  => $vb->cursor_col,
        };
    };

    $ACTIONS->{jump_mark} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $mark = $extra[0];
        return unless exists $ctx->{marks}{$mark};
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $m = $ctx->{marks}{$mark};
        $vb->set_cursor($m->{line}, $m->{col});
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    $ACTIONS->{jump_mark_line} = sub {
        my ($ctx, $count, @extra) = @_;
        return unless @extra;
        my $mark = $extra[0];
        return unless exists $ctx->{marks}{$mark};
        $_save_line_snapshot->($ctx);
        my $vb = $ctx->{vb};
        my $m = $ctx->{marks}{$mark};
        my $col = $vb->first_nonblank_col($m->{line});
        $vb->set_cursor($m->{line}, $col);
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ================================================================
    #  Visual mode entry
    # ================================================================

    $ACTIONS->{enter_visual} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('visual');
    };

    $ACTIONS->{enter_visual_line} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('visual_line');
    };

    $ACTIONS->{enter_visual_block} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('visual_block');
    };

    $ACTIONS->{reselect_visual} = sub {
        my ($ctx) = @_;
        return unless $ctx->{last_visual};
        my $lv = $ctx->{last_visual};
        my $mode = $lv->{type} eq 'block' ? 'visual_block'
                 : $lv->{type} eq 'line'  ? 'visual_line'
                 : 'visual';
        $ctx->{set_mode}->($mode);
        # Set visual_start AFTER set_mode (which overwrites it)
        $ctx->{visual_type} = $lv->{type};
        $ctx->{visual_start} = { line => $lv->{start_line}, col => $lv->{start_col} };
        # Use move_cursor to preserve the GTK selection, then let
        # after_move re-establish the full selection range.
        $ctx->{vb}->move_cursor($lv->{end_line}, $lv->{end_col});
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ================================================================
    #  Scroll Mode Toggle (Mode 3 -- scroll lock)
    # ================================================================

    $ACTIONS->{toggle_scroll_lock} = sub {
        my ($ctx) = @_;
        if ($ctx->{_scroll_lock_active}) {
            # Deactivate: restore the previous scroll mode
            $ctx->{_scroll_lock_active} = 0;
            $ctx->{_scroll_mode} = $ctx->{_scroll_lock_prev} // 'edge';
            $ctx->{_scroll_lock_prev} = undef;
            my $mode_label = $ctx->{_scroll_mode} eq 'center' ? 'CENTER' : 'EDGE';
            $ctx->{show_status}->("Scroll lock OFF (mode: $mode_label)")
                if $ctx->{show_status};
        } else {
            # Activate: save current mode and switch to scroll_lock
            $ctx->{_scroll_lock_prev} = $ctx->{_scroll_mode};
            $ctx->{_scroll_lock_active} = 1;
            $ctx->{show_status}->("Scroll lock ON (cursor frozen)")
                if $ctx->{show_status};
        }
    };

    # ================================================================
    #  Return the default normal-mode keymap
    # ================================================================

    return {
        _immediate => [qw(Page_Up Page_Down caret asciicircum dead_circumflex Home End)],
        _prefixes  => [qw(g d y c greater less z)],
        _char_actions => {
            r      => 'replace_char',
            m      => 'set_mark',
            grave  => 'jump_mark',
            apostrophe => 'jump_mark_line',
            f      => 'find_char_forward',
            F      => 'find_char_backward',
            t      => 'till_char_forward',
            T      => 'till_char_backward',
        },
        _ctrl => {
            u => 'scroll_half_up',
            d => 'scroll_half_down',
            f => 'page_down',
            b => 'page_up',
            y => 'scroll_line_up',
            e => 'scroll_line_down',
            r => 'redo',
        },
        # Arrow keys are mapped to h/j/k/l in handle_normal_mode()
        # before dispatch, so they reach the h/j/k/l entries above.
        # The entries below are kept for _build_dispatch completeness
        # (e.g., if a future code path dispatches the raw GDK key name).
        Up            => 'move_up',
        Down          => 'move_down',
        Left          => 'move_left',
        Right         => 'move_right',
        Page_Up       => 'page_up',
        Page_Down     => 'page_down',
        h             => 'move_left',
        j             => 'move_down',
        k             => 'move_up',
        l             => 'move_right',
        w             => 'word_forward',
        b             => 'word_backward',
        e             => 'word_end',
        0             => 'line_start',
        Home          => 'line_start',
        End           => 'line_end',
        dollar        => 'line_end',
        caret             => 'first_nonblank',
        asciicircum       => 'first_nonblank',
        dead_circumflex   => 'first_nonblank',
        G             => 'file_end',
        gg            => 'file_start',
        i             => 'enter_insert',
        a             => 'enter_insert_after',
        A             => 'enter_insert_eol',
        I             => 'enter_insert_bol',
        o             => 'open_below',
        O             => 'open_above',
        R             => 'enter_replace_mode',
        x             => 'delete_char',
        Delete        => 'delete_char',
        BackSpace     => 'backspace',
        dd            => 'delete_line',
        dw            => 'delete_word',
        d_dollar      => 'delete_to_eol',
        cc            => 'change_line',
        cw            => 'change_word',
        C             => 'change_to_eol',
        yy            => 'yank_line',
        yw            => 'yank_word',
        yiw           => 'yank_inner_word',
        p             => 'paste',
        P             => 'paste_before',
        greatergreater => 'indent_right',
        lessless       => 'indent_left',
        J             => 'join_lines',
        u             => 'undo',
        U             => 'line_undo',
        n             => 'search_next',
        N             => 'search_prev',
        v             => 'enter_visual',
        V             => 'enter_visual_line',
        gv            => 'reselect_visual',
        semicolon         => 'find_repeat',
        comma             => 'find_repeat_reverse',
        percent           => 'percent_motion',
        zx            => 'toggle_scroll_lock',
        colon         => 'enter_command',
        slash         => 'enter_search',
        question      => 'enter_search_backward',
        P             => 'paste_before',
        J             => 'join_lines',
        u             => 'undo',
        U             => 'line_undo',
        greatergreater => 'indent_right',
        lessless     => 'indent_left',
        colon         => 'enter_command',
        slash         => 'enter_search',
        question      => 'enter_search_backward',
        v             => 'enter_visual',
        V             => 'enter_visual_line',
        gv            => 'reselect_visual',
        semicolon     => 'find_repeat',
        comma         => 'find_repeat_reverse',
        percent       => 'percent_motion',
    };
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::Normal - Normal-mode actions and keymap for Vim bindings

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBindings::Normal;
    my %actions;
    my $keymap = Gtk3::SourceEditor::VimBindings::Normal::register(\%actions);

=head1 DESCRIPTION

Registers all normal-mode action coderefs into the given hashref and returns
the default normal-mode keymap mapping GDK key names to action names.

=cut
