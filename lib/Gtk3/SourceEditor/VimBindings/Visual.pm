package Gtk3::SourceEditor::VimBindings::Visual;
use strict;
use warnings;

our $VERSION = '0.04';

sub register {
    my ($ACTIONS) = @_;

    # ----------------------------------------------------------------
    # Helper: save last visual selection for gv (re-select)
    # ----------------------------------------------------------------
    my $_save_last_visual = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        return unless $ctx->{visual_start};
        $ctx->{last_visual} = {
            type       => $ctx->{visual_type},
            start_line => $ctx->{visual_start}{line},
            start_col  => $ctx->{visual_start}{col},
            end_line   => $vb->cursor_line,
            end_col    => $vb->cursor_col,
        };
    };

    # ----------------------------------------------------------------
    # Helper: normalize selection range for char/line modes
    # ----------------------------------------------------------------
    # get_range is exclusive at end, but visual selections are inclusive
    # on both ends.  We add 1 to the end column so that get_range
    # (exclusive end) returns exactly the characters the user selected.
    my $_selection_range = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $s = $ctx->{visual_start};
        my $e_line = $vb->cursor_line;
        my $e_col  = $vb->cursor_col;

        if ($s->{line} > $e_line || ($s->{line} == $e_line && $s->{col} > $e_col)) {
            return { l1 => $e_line, c1 => $e_col, l2 => $s->{line}, c2 => $s->{col} + 1 };
        }
        return { l1 => $s->{line}, c1 => $s->{col}, l2 => $e_line, c2 => $e_col + 1 };
    };

    # ----------------------------------------------------------------
    # Helper: get block bounds { left, top, right, bottom }
    # ----------------------------------------------------------------
    my $_block_bounds = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $s = $ctx->{visual_start};
        my $e_line = $vb->cursor_line;
        my $e_col  = $vb->cursor_col;

        my ($top, $bottom) = $s->{line} <= $e_line
            ? ($s->{line}, $e_line)
            : ($e_line, $s->{line});
        # Block selections are inclusive on both sides.
        # Add 1 to right so that substr(text, left, right - left)
        # includes the character at column (right - 1).
        my ($left, $right) = $s->{col} <= $e_col
            ? ($s->{col}, $e_col + 1)
            : ($e_col + 1, $s->{col});

        return { left => $left, top => $top, right => $right, bottom => $bottom };
    };

    # ----------------------------------------------------------------
    # Helper: get block text as rectangular region (lines joined with \n)
    # ----------------------------------------------------------------
    my $_block_text = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $b = $_block_bounds->($ctx);
        my @parts;
        for my $ln ($b->{top} .. $b->{bottom}) {
            my $line_text = $vb->line_text($ln);
            my $len = length($line_text);
            if ($len <= $b->{left}) {
                push @parts, ' ' x ($b->{right} - $b->{left});
            } else {
                my $end = $b->{right} > $len ? $len : $b->{right};
                my $slice = substr($line_text, $b->{left}, $end - $b->{left});
                if ($end < $b->{right}) {
                    $slice .= ' ' x ($b->{right} - $end);
                }
                push @parts, $slice;
            }
        }
        return join("\n", @parts) . "\n";
    };

    # ----------------------------------------------------------------
    # Helper: delete block columns from each line
    # ----------------------------------------------------------------
    my $_delete_block = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $b = $_block_bounds->($ctx);

        # Delete from bottom to top so line numbers remain valid
        for my $ln (reverse $b->{top} .. $b->{bottom}) {
            my $line_text = $vb->line_text($ln);
            my $len = length($line_text);
            if ($len > $b->{left}) {
                my $end = $b->{right} > $len ? $len : $b->{right};
                # Delete using the buffer's delete_range
                $vb->delete_range($ln, $b->{left}, $ln, $end);
            }
        }
        $vb->set_cursor($b->{top}, $b->{left});
    };

    # ----------------------------------------------------------------
    # Helper: exit visual mode, clean up state
    # ----------------------------------------------------------------
    my $_visual_cleanup = sub {
        my ($ctx) = @_;
        delete $ctx->{visual_type};
        delete $ctx->{visual_start};
    };

    # ----------------------------------------------------------------
    # visual_exit -- Escape
    # ----------------------------------------------------------------
    $ACTIONS->{visual_exit} = sub {
        my ($ctx) = @_;
        # Call set_mode FIRST so it can detect the transition from visual
        # to normal and properly clear the GTK selection.  Only clean up
        # our visual state after set_mode has run.
        $ctx->{set_mode}->('normal');
        $_visual_cleanup->($ctx);
    };

    # ----------------------------------------------------------------
    # visual_yank
    # ----------------------------------------------------------------
    $ACTIONS->{visual_yank} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        my $yanked = '';
        if ($vtype eq 'block') {
            $yanked = $_block_text->($ctx);
        } elsif ($vtype eq 'line') {
            my $s = $ctx->{visual_start};
            my $e = $vb->cursor_line;
            my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
            $yanked = '';
            $yanked .= $vb->line_text($_) . "\n" for $lo .. $hi;
        } else {
            my $r = $_selection_range->($ctx);
            $yanked = $vb->get_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2});
        }

        ${$ctx->{yank_buf}} = $yanked;

        # Copy to clipboard if enabled
        if ($ctx->{use_clipboard} && defined $yanked && length $yanked) {
            my $view = $ctx->{gtk_view};
            if ($view) {
                eval {
                    my $clipboard = Gtk3::Clipboard::get_default(
                        $view->get_display
                    );
                    $clipboard->set_text($yanked, length($yanked));
                };
            }
        }

        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('normal');
    };

    # ----------------------------------------------------------------
    # visual_delete
    # ----------------------------------------------------------------
    $ACTIONS->{visual_delete} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        if ($vtype eq 'block') {
            ${$ctx->{yank_buf}} = $_block_text->($ctx);
            $_delete_block->($ctx);
        } elsif ($vtype eq 'line') {
            my $s = $ctx->{visual_start};
            my $e = $vb->cursor_line;
            my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
            my $yank = '';
            $yank .= $vb->line_text($_) . "\n" for $lo .. $hi;
            ${$ctx->{yank_buf}} = $yank;

            if ($hi + 1 < $vb->line_count) {
                $vb->delete_range($lo, 0, $hi + 1, 0);
            } else {
                $vb->delete_range($lo, 0, $hi, $vb->line_length($hi));
            }
            $vb->set_cursor($lo, 0);
        } else {
            my $r = $_selection_range->($ctx);
            ${$ctx->{yank_buf}} = $vb->get_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2});
            $vb->delete_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2});
        }

        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('normal');
    };

    # ----------------------------------------------------------------
    # visual_change -- delete + enter insert
    # ----------------------------------------------------------------
    $ACTIONS->{visual_change} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        if ($vtype eq 'block') {
            ${$ctx->{yank_buf}} = $_block_text->($ctx);
            my $b = $_block_bounds->($ctx);
            $_delete_block->($ctx);
            $vb->set_cursor($b->{top}, $b->{left});
        } elsif ($vtype eq 'line') {
            my $s = $ctx->{visual_start};
            my $e = $vb->cursor_line;
            my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
            my $yank = '';
            $yank .= $vb->line_text($_) . "\n" for $lo .. $hi;
            ${$ctx->{yank_buf}} = $yank;

            if ($hi + 1 < $vb->line_count) {
                $vb->delete_range($lo, 0, $hi + 1, 0);
            } else {
                $vb->delete_range($lo, 0, $hi, $vb->line_length($hi));
            }
            $vb->set_cursor($lo, 0);
            $vb->insert_text('');
        } else {
            my $r = $_selection_range->($ctx);
            ${$ctx->{yank_buf}} = $vb->get_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2});
            $vb->delete_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2});
        }

        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('insert');
    };

    # ----------------------------------------------------------------
    # visual_swap_ends -- o (swap cursor and anchor)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_swap_ends} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $s = $ctx->{visual_start};
        # Swap: cursor goes to anchor, anchor becomes cursor position
        my $cur_line = $vb->cursor_line;
        my $cur_col  = $vb->cursor_col;
        # Use move_cursor to preserve the GTK selection while moving the
        # insert mark.  after_move will re-establish the selection with
        # the new visual_start.
        $vb->move_cursor($s->{line}, $s->{col});
        $ctx->{visual_start} = { line => $cur_line, col => $cur_col };
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ----------------------------------------------------------------
    # visual_toggle_case -- ~ (toggle case of selection)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_toggle_case} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        if ($vtype eq 'block') {
            my $b = $_block_bounds->($ctx);
            for my $ln ($b->{top} .. $b->{bottom}) {
                my $line_text = $vb->line_text($ln);
                my $len = length($line_text);
                next if $len <= $b->{left};
                my $end = $b->{right} > $len ? $len : $b->{right};
                my $slice = substr($line_text, $b->{left}, $end - $b->{left});
                $slice =~ tr/a-zA-Z/A-Za-z/;
                substr($line_text, $b->{left}, $end - $b->{left}) = $slice;
                # Replace the line content
                $vb->set_cursor($ln, 0);
                $vb->delete_range($ln, 0, $ln, $len);
                $vb->insert_text($line_text);
            }
            $vb->set_cursor($b->{bottom}, $b->{right} > $vb->line_length($b->{bottom})
                ? $vb->line_length($b->{bottom}) : $b->{right});
        } elsif ($vtype eq 'line') {
            my $s = $ctx->{visual_start};
            my $e = $vb->cursor_line;
            my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
            for my $ln ($lo .. $hi) {
                my $line_text = $vb->line_text($ln);
                my $orig_len = length($line_text);
                $line_text =~ tr/a-zA-Z/A-Za-z/;
                $vb->set_cursor($ln, 0);
                $vb->delete_range($ln, 0, $ln, $orig_len);
                $vb->insert_text($line_text);
            }
            $vb->set_cursor($lo, $vb->first_nonblank_col($lo));
        } else {
            my $r = $_selection_range->($ctx);
            $vb->transform_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2}, 'toggle');
        }
        # Stay in visual mode after ~ (Vim behavior)
    };

    # ----------------------------------------------------------------
    # visual_uppercase -- U (uppercase selection)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_uppercase} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        if ($vtype eq 'line') {
            my $s = $ctx->{visual_start};
            my $e = $vb->cursor_line;
            my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
            for my $ln ($lo .. $hi) {
                my $line_text = $vb->line_text($ln);
                my $orig_len = length($line_text);
                my $upper = uc $line_text;
                if ($upper ne $line_text) {
                    $vb->set_cursor($ln, 0);
                    $vb->delete_range($ln, 0, $ln, $orig_len);
                    $vb->insert_text($upper);
                }
            }
            $vb->set_cursor($lo, $vb->first_nonblank_col($lo));
        } else {
            my $r = $_selection_range->($ctx);
            $vb->transform_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2}, 'upper');
        }
    };

    # ----------------------------------------------------------------
    # visual_lowercase -- u (lowercase selection, NOT undo in visual)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_lowercase} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        if ($vtype eq 'line') {
            my $s = $ctx->{visual_start};
            my $e = $vb->cursor_line;
            my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
            for my $ln ($lo .. $hi) {
                my $line_text = $vb->line_text($ln);
                my $orig_len = length($line_text);
                my $lower = lc $line_text;
                if ($lower ne $line_text) {
                    $vb->set_cursor($ln, 0);
                    $vb->delete_range($ln, 0, $ln, $orig_len);
                    $vb->insert_text($lower);
                }
            }
            $vb->set_cursor($lo, $vb->first_nonblank_col($lo));
        } else {
            my $r = $_selection_range->($ctx);
            $vb->transform_range($r->{l1}, $r->{c1}, $r->{l2}, $r->{c2}, 'lower');
        }
    };

    # ----------------------------------------------------------------
    # visual_join -- J (join lines in selection)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_join} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        my $s = $ctx->{visual_start};
        my $e = $vb->cursor_line;
        my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});

        $vb->set_cursor($lo, 0);
        my $count = $hi - $lo;  # number of additional lines to join
        $vb->join_lines($count) if $count > 0;

        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('normal');
    };

    # ----------------------------------------------------------------
    # visual_format -- gq (format/wrap lines in selection)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_format} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $vtype = $ctx->{visual_type} // 'char';

        $_save_last_visual->($ctx);

        my $s = $ctx->{visual_start};
        my $e = $vb->cursor_line;
        my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});

        # Simple format: join all lines with spaces, then re-wrap at 80 chars
        my @words;
        for my $ln ($lo .. $hi) {
            my $line_text = $vb->line_text($ln);
            $line_text =~ s/^\s+//;
            $line_text =~ s/\s+$//;
            push @words, split /\s+/, $line_text if length $line_text;
        }

        my $formatted = '';
        my $col = 0;
        my $width = 78;
        for my $word (@words) {
            if ($col == 0) {
                $formatted = $word;
                $col = length($word);
            } elsif ($col + 1 + length($word) <= $width) {
                $formatted .= ' ' . $word;
                $col += 1 + length($word);
            } else {
                $formatted .= "\n" . $word;
                $col = length($word);
            }
        }

        # Replace lines $lo..$hi with formatted text
        my $last_line = $hi;
        if ($last_line + 1 < $vb->line_count) {
            $vb->delete_range($lo, 0, $last_line + 1, 0);
        } else {
            $vb->delete_range($lo, 0, $last_line, $vb->line_length($last_line));
        }
        $vb->set_cursor($lo, 0);
        $vb->insert_text($formatted) if length $formatted;

        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('normal');
    };

    # ----------------------------------------------------------------
    # visual_block_insert_start -- I (insert at left edge of block)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_block_insert_start} = sub {
        my ($ctx) = @_;
        my $vtype = $ctx->{visual_type} // 'char';
        return unless $vtype eq 'block';

        $_save_last_visual->($ctx);

        my $b = $_block_bounds->($ctx);
        $ctx->{block_insert_info} = {
            col       => $b->{left},
            top       => $b->{top},
            bottom    => $b->{bottom},
            direction => 'start',
            inserted  => '',
        };
        $ctx->{vb}->set_cursor($b->{top}, $b->{left});
        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('insert');
    };

    # ----------------------------------------------------------------
    # visual_block_insert_end -- A (insert at right edge of block)
    # ----------------------------------------------------------------
    $ACTIONS->{visual_block_insert_end} = sub {
        my ($ctx) = @_;
        my $vtype = $ctx->{visual_type} // 'char';
        return unless $vtype eq 'block';

        $_save_last_visual->($ctx);

        my $b = $_block_bounds->($ctx);
        $ctx->{block_insert_info} = {
            col       => $b->{right},
            top       => $b->{top},
            bottom    => $b->{bottom},
            direction => 'end',
            inserted  => '',
        };
        $ctx->{vb}->set_cursor($b->{top}, $b->{right});
        $_visual_cleanup->($ctx);
        $ctx->{set_mode}->('insert');
    };

    # ----------------------------------------------------------------
    # visual_indent_right -- >>
    # ----------------------------------------------------------------
    $ACTIONS->{visual_indent_right} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $s = $ctx->{visual_start};
        my $e = $vb->cursor_line;
        my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
        my $count = $hi - $lo + 1;
        my $sw = $ctx->{shiftwidth} // 4;
        $vb->set_cursor($lo, 0);
        $vb->indent_lines($count, $sw, 1);
        # Update visual start and cursor positions
        $ctx->{visual_start} = { line => $lo, col => 0 };
        $vb->set_cursor($hi, $vb->line_length($hi));
        # Re-establish GTK selection highlighting after indent_lines
        # which calls place_cursor internally (clearing selection)
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ----------------------------------------------------------------
    # visual_indent_left -- <<
    # ----------------------------------------------------------------
    $ACTIONS->{visual_indent_left} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        my $s = $ctx->{visual_start};
        my $e = $vb->cursor_line;
        my ($lo, $hi) = $s->{line} < $e ? ($s->{line}, $e) : ($e, $s->{line});
        my $count = $hi - $lo + 1;
        my $sw = $ctx->{shiftwidth} // 4;
        $vb->set_cursor($lo, 0);
        $vb->indent_lines($count, $sw, -1);
        $ctx->{visual_start} = { line => $lo, col => 0 };
        $vb->set_cursor($hi, $vb->line_length($hi));
        # Re-establish GTK selection highlighting after indent_lines
        # which calls place_cursor internally (clearing selection)
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ----------------------------------------------------------------
    # Return the keymap
    # ----------------------------------------------------------------
    return {
        _immediate     => [qw(Escape)],
        _prefixes      => ['g', 'greater', 'less'],
        _char_actions  => {},
        Escape         => 'visual_exit',
        x              => 'visual_delete',
        y              => 'visual_yank',
        d              => 'visual_delete',
        c              => 'visual_change',
        o              => 'visual_swap_ends',
        asciitilde     => 'visual_toggle_case',
        U              => 'visual_uppercase',
        u              => 'visual_lowercase',
        J              => 'visual_join',
        I              => 'visual_block_insert_start',
        A              => 'visual_block_insert_end',
        gq             => 'visual_format',
        greatergreater => 'visual_indent_right',
        lessless        => 'visual_indent_left',
    };
}

# Return navigation keys shared between normal and visual modes
sub navigation_keys {
    return {
        h => 'move_left', j => 'move_down', k => 'move_up', l => 'move_right',
        w => 'word_forward', b => 'word_backward', e => 'word_end',
        0 => 'line_start', dollar => 'line_end',
        caret => 'first_nonblank', asciicircum => 'first_nonblank',
        G => 'file_end', gg => 'file_start',
        Up => 'move_up', Down => 'move_down',
        Left => 'move_left', Right => 'move_right',
        Page_Up => 'page_up', Page_Down => 'page_down',
        Home => 'line_start', End => 'line_end',
    };
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::Visual - Visual mode bindings (char, line, and block-wise selection)

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBindings::Visual;

    my $mode = Gtk3::SourceEditor::VimBindings::Visual->register($actions);
    my $nav = Gtk3::SourceEditor::VimBindings::Visual->navigation_keys();

=head1 DESCRIPTION

This module implements the visual mode bindings for the Vim emulation layer
of L<Gtk3::SourceEditor>. Visual mode allows the user to select text
character-wise (C<v>), line-wise (C<V>), or block-wise (Ctrl-V) and then
operate on the selected region.

=head1 REGISTERED ACTIONS

=over 4

=item C<visual_exit> - Cancel selection and return to normal mode (Escape)

=item C<visual_yank> - Copy selected text to yank_buf (y)

=item C<visual_delete> - Copy and delete selected text (d)

=item C<visual_change> - Copy and delete selected text, enter insert mode (c)

=item C<visual_swap_ends> - Swap cursor and anchor (o)

=item C<visual_toggle_case> - Toggle case of selection (~)

=item C<visual_uppercase> - Uppercase selection (U)

=item C<visual_lowercase> - Lowercase selection (u)

=item C<visual_join> - Join lines in selection (J)

=item C<visual_format> - Format/wrap lines (gq)

=item C<visual_block_insert_start> - Insert at left edge of block (I)

=item C<visual_block_insert_end> - Insert at right edge of block (A)

=item C<visual_indent_right> - Indent lines right (>>)

=item C<visual_indent_left> - Indent lines left (<<)

=back

=head1 SEE ALSO

L<Gtk3::SourceEditor>, L<Gtk3::SourceEditor::VimBindings>

=head1 AUTHOR

Gtk3::SourceEditor Contributors

=cut
