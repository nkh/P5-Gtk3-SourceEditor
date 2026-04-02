package Gtk3::SourceEditor::VimBindings::Insert;
use strict;
use warnings;

our $VERSION = '0.04';

sub register {
    my ($ACTIONS) = @_;
    
    # Exit to normal from insert mode
    $ACTIONS->{exit_to_normal} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};

        # Handle block insert replay
        if ($ctx->{block_insert_info}) {
            my $info = delete $ctx->{block_insert_info};
            # The text the user typed while in insert mode is tracked via
            # the cursor position delta. For simplicity, we detect the inserted
            # text by comparing what changed on the first line.
            # Actually, we need to track what was typed. Let's use a simpler approach:
            # The block_insert_info has 'col' (original column) and we can measure
            # what was inserted by looking at the first line's column difference.
            my $top = $info->{top};
            my $bottom = $info->{bottom};
            my $col = $info->{col};
            my $dir = $info->{direction};

            # Figure out the inserted text from the first line
            my $first_line_text = $vb->line_text($top);
            my $inserted;
            if ($dir eq 'start') {
                # Text was inserted at $col; the new text starts at $col
                my $orig_part = substr($first_line_text, 0, $col);
                my $remaining = substr($first_line_text, $col);
                # Find where the remaining original text starts
                # We need to know the original line content... 
                # Simpler: compare current cursor position to where we started
                my $cur_col = $vb->cursor_col;
                my $cur_line = $vb->cursor_line;
                
                # The user typed from col on line top to wherever cursor is now
                # If they only typed on the first line:
                if ($cur_line == $top) {
                    $inserted = substr($first_line_text, $col, $cur_col - $col);
                } else {
                    # Multi-line insertion -- grab from start to end
                    $inserted = $vb->get_range($top, $col, $cur_line, $cur_col);
                }
            } else {
                # end direction: inserted at $col (right edge of block)
                my $cur_col = $vb->cursor_col;
                my $cur_line = $vb->cursor_line;
                if ($cur_line == $top) {
                    $inserted = substr($first_line_text, $col, $cur_col - $col);
                } else {
                    $inserted = $vb->get_range($top, $col, $cur_line, $cur_col);
                }
            }

            # Replay insertion on remaining lines (bottom to top to preserve positions)
            return unless defined $inserted && length $inserted;
            for my $ln (reverse $top + 1 .. $bottom) {
                my $insert_col = $dir eq 'start' ? $col : $col;
                $vb->set_cursor($ln, $insert_col);
                $vb->insert_text($inserted);
            }

            # Position cursor at end of first line's inserted text
            $vb->set_cursor($top, $col + length($inserted) - 1)
                if length($inserted) > 0;
        }

        $ctx->{set_mode}->('normal');
        unless ($vb->at_line_start) {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col - 1);
        }
    };
    
    # Exit to normal from replace mode
    $ACTIONS->{exit_replace_to_normal} = sub {
        my ($ctx) = @_;
        $ctx->{set_mode}->('normal');
        my $vb = $ctx->{vb};
        unless ($vb->at_line_start) {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col - 1);
        }
    };
    
    # Insert tab -- uses the configurable tab_string (default "\t")
    $ACTIONS->{insert_tab} = sub {
        my ($ctx) = @_;
        $ctx->{vb}->insert_text($ctx->{tab_string});
    };

    # Replace character under cursor (in replace mode)
    $ACTIONS->{do_replace_char} = sub {
        my ($ctx, $count, $char) = @_;
        return unless defined $char && length($char);
        $ctx->{vb}->replace_char($char);
        my $vb = $ctx->{vb};
        unless ($vb->at_line_end) {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col + 1);
        }
    };
    
    return {
        _immediate => ['Escape', 'Tab'],
        _prefixes  => [],
        _char_actions => {},
        Escape => 'exit_to_normal',
        Tab    => 'insert_tab',
    };
}

sub get_replace_keymap {
    return {
        _immediate => ['Escape', 'BackSpace'],
        _prefixes  => [],
        _char_actions => {
            _any => 'do_replace_char',
        },
        Escape => 'exit_replace_to_normal',
        BackSpace => 'replace_backspace',
    };
}

# Replace mode specific actions (registered separately since replace keymap
# references them differently)
sub register_replace_actions {
    my ($ACTIONS) = @_;
    
    $ACTIONS->{replace_backspace} = sub {
        my ($ctx) = @_;
        my $vb = $ctx->{vb};
        unless ($vb->at_line_start) {
            $vb->set_cursor($vb->cursor_line, $vb->cursor_col - 1);
        }
    };
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::Insert - Insert and replace mode actions

=head1 DESCRIPTION

Handles key bindings and actions for Vim-style insert mode and replace mode.

Insert mode returns FALSE from the key handler so that GTK processes printable
keystrokes directly. The only action intercepted is Escape, which exits to
normal mode and moves the cursor back one position.

Replace mode uses a separate keymap (see C<get_replace_keymap>) that intercepts
all printable characters via C<< _char_actions => { _any => 'do_replace_char' } >>,
replacing the character under the cursor instead of inserting.

=head1 FUNCTIONS

=head2 register($ACTIONS)

Registers insert mode actions and returns the insert mode keymap hashref.

=head2 get_replace_keymap()

Returns the replace mode keymap hashref. Uses C<_any> in C<_char_actions> to
indicate that any printable character triggers C<do_replace_char>.

=head2 register_replace_actions($ACTIONS)

Registers replace-mode-only actions (e.g. C<replace_backspace>).

=cut
