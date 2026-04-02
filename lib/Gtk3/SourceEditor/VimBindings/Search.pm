package Gtk3::SourceEditor::VimBindings::Search;
use strict;
use warnings;

our $VERSION = '0.04';

sub register {
    my ($ACTIONS) = @_;

    # Search next (repeat last search in same direction)
    $ACTIONS->{search_next} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $pattern = $ctx->{search_pattern};
        unless (defined $pattern && length $pattern) {
            $ctx->{show_status}->("Error: No previous search pattern") if $ctx->{show_status};
            return;
        }
        my $dir = $ctx->{search_direction} // 'forward';
        my $vb = $ctx->{vb};

        for (1 .. $count) {
            my $result;
            if ($dir eq 'forward') {
                $result = $vb->search_forward($pattern);
            } else {
                $result = $vb->search_backward($pattern);
            }
            if ($result) {
                $vb->set_cursor($result->{line}, $result->{col});
                $ctx->{after_move}->($ctx) if $ctx->{after_move};
            } else {
                $ctx->{show_status}->("Pattern not found: $pattern") if $ctx->{show_status};
                last;
            }
        }
    };

    # Search prev (repeat last search in opposite direction)
    $ACTIONS->{search_prev} = sub {
        my ($ctx, $count) = @_;
        $count //= 1;
        my $pattern = $ctx->{search_pattern};
        unless (defined $pattern && length $pattern) {
            $ctx->{show_status}->("Error: No previous search pattern") if $ctx->{show_status};
            return;
        }
        my $dir = $ctx->{search_direction} // 'forward';
        my $opposite = $dir eq 'forward' ? 'backward' : 'forward';
        my $vb = $ctx->{vb};

        for (1 .. $count) {
            my $result;
            if ($opposite eq 'forward') {
                $result = $vb->search_forward($pattern);
            } else {
                $result = $vb->search_backward($pattern);
            }
            if ($result) {
                $vb->set_cursor($result->{line}, $result->{col});
                $ctx->{after_move}->($ctx) if $ctx->{after_move};
            } else {
                $ctx->{show_status}->("Pattern not found: $pattern") if $ctx->{show_status};
                last;
            }
        }
    };

    # Set search pattern (called from command entry handler after / or ? input)
    $ACTIONS->{search_set_pattern} = sub {
        my ($ctx, $count, $extra) = @_;
        my $pattern = $extra->{pattern} // '';
        my $direction = $extra->{direction} // 'forward';

        unless (length $pattern) {
            $ctx->{show_status}->("Error: Empty search pattern") if $ctx->{show_status};
            $ctx->{set_mode}->('normal');
            return;
        }

        $ctx->{search_pattern}   = $pattern;
        $ctx->{search_direction} = $direction;

        my $vb = $ctx->{vb};
        my $result;
        if ($direction eq 'forward') {
            $result = $vb->search_forward($pattern);
        } else {
            $result = $vb->search_backward($pattern);
        }

        $ctx->{set_mode}->('normal');

        if ($result) {
            $vb->set_cursor($result->{line}, $result->{col});
            $ctx->{after_move}->($ctx) if $ctx->{after_move};
        } else {
            $ctx->{show_status}->("Pattern not found: $pattern") if $ctx->{show_status};
        }
    };

    return {};  # No keymap entries for search (n/N are in normal keymap)
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::Search - Search actions (/, ?, n, N)

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBindings::Search;
    Gtk3::SourceEditor::VimBindings::Search->register($ACTIONS);

=head1 DESCRIPTION

Registers vim-style search actions into the editor's action dispatch table.
Supports forward/backward searching, repeat last search (n), and reverse
search (N).

=head1 ACTIONS

=over 4

=item search_next ($ctx, $count)

Repeat the last search in the same direction.

=item search_prev ($ctx, $count)

Repeat the last search in the opposite direction.

=item search_set_pattern ($ctx, $count, $extra)

Set a new search pattern and direction, then jump to the first match.

C<$extra> is a hashref with C<pattern> and C<direction> keys.

=back

=head1 AUTHOR

Auto-generated for Gtk3::SourceEditor.

=cut
