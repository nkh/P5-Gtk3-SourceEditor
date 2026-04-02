package Gtk3::SourceEditor::VimBuffer::Test;

use strict;
use warnings;

use parent 'Gtk3::SourceEditor::VimBuffer';

our $VERSION = '0.04';

=head1 NAME

Gtk3::SourceEditor::VimBuffer::Test - In-memory buffer backend for testing

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBuffer::Test;

    my $buf = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => "hello world\nfoo bar\nbaz",
    );

    print $buf->line_text(0);            # "hello world"
    print $buf->cursor_line;             # 0
    $buf->set_cursor(1, 4);
    $buf->insert_text("INSERTED");
    $buf->undo;

=head1 DESCRIPTION

This is a lightweight, pure-Perl implementation of
L<Gtk3::SourceEditor::VimBuffer> intended for unit tests.  The entire
document is held in memory as an array of lines (without trailing newlines).

No external dependencies are required beyond the base VimBuffer class.

=head1 CONSTRUCTOR

=head2 new( %opts )

    my $buf = Gtk3::SourceEditor::VimBuffer::Test->new( text => $string );

Accepts the following options:

=over 4

=item * C<text> -- initial buffer content.  If omitted the buffer starts
with one empty line.

=back

The text is split on C</\n/> with a C<LIMIT> of C<-1> so that a trailing
newline produces a final empty string element (matching Vim behaviour).
If the resulting array is empty (i.e. the input was C<"">) it is replaced
with C<("")> so the buffer always contains at least one line.

=cut

sub new {
    my ( $class, %opts ) = @_;

    my $text = defined $opts{text} ? $opts{text} : '';

    # Split on newlines, keeping trailing empty strings.
    my @lines = split /\n/, $text, -1;

    # An empty buffer must still have one empty line.
    @lines = ("") if @lines == 0;

    my $self = bless {
        _lines     => \@lines,
        _cur_line  => 0,
        _cur_col   => 0,
        _modified  => 0,
        _undo_stack => [],
    }, $class;

    return $self;
}

# ----------------------------------------------------------------
# Internal helpers
# ----------------------------------------------------------------

sub _clamp_cursor {
    my ($self) = @_;

    my $max_line = $self->line_count - 1;
    $self->{_cur_line} = 0                         if $self->{_cur_line} < 0;
    $self->{_cur_line} = $max_line                 if $self->{_cur_line} > $max_line;

    my $max_col = $self->line_length( $self->{_cur_line} );
    $self->{_cur_col} = 0                          if $self->{_cur_col} < 0;
    $self->{_cur_col} = $max_col                   if $self->{_cur_col} > $max_col;
}

sub _save_undo {
    my ($self) = @_;
    push @{$self->{_undo_stack}}, {
        _lines    => [ @{$self->{_lines}} ],
        _cur_line => $self->{_cur_line},
        _cur_col  => $self->{_cur_col},
    };
}

# ----------------------------------------------------------------
# Cursor
# ----------------------------------------------------------------

sub cursor_line {
    my ($self) = @_;
    return $self->{_cur_line};
}

sub cursor_col {
    my ($self) = @_;
    return $self->{_cur_col};
}

sub set_cursor {
    my ( $self, $line, $col ) = @_;
    # set_cursor collapses the selection (mirrors GTK place_cursor which
    # moves both 'insert' and 'selection_bound' to the same position).
    $self->clear_selection;
    $self->{_cur_line} = $line;
    $self->{_cur_col}  = $col;
    $self->_clamp_cursor;
}

sub move_cursor {
    my ( $self, $line, $col ) = @_;
    # In the test backend, move_cursor preserves the selection anchor
    # (unlike set_cursor which collapses it to the new position).
    # Track _sel_bound separately so tests can verify selection behavior.
    $self->{_cur_line} = $line;
    $self->{_cur_col}  = $col;
    $self->_clamp_cursor;
}

# ----------------------------------------------------------------
# Line access
# ----------------------------------------------------------------

sub line_count {
    my ($self) = @_;
    return scalar @{$self->{_lines}};
}

sub line_text {
    my ( $self, $line ) = @_;
    return $self->{_lines}[$line] // '';
}

sub line_length {
    my ( $self, $line ) = @_;
    return length( $self->{_lines}[$line] // '' );
}

# ----------------------------------------------------------------
# Whole-buffer text
# ----------------------------------------------------------------

sub text {
    my ($self) = @_;
    return join( "\n", @{$self->{_lines}} );
}

sub set_text {
    my ( $self, $text ) = @_;
    $self->_save_undo;
    my @lines = split /\n/, $text, -1;
    @lines = ("") if @lines == 0;
    $self->{_lines}    = \@lines;
    $self->{_cur_line} = 0;
    $self->{_cur_col}  = 0;
}

# ----------------------------------------------------------------
# Range operations
# ----------------------------------------------------------------

sub get_range {
    my ( $self, $l1, $c1, $l2, $c2 ) = @_;

    if ( $l1 == $l2 ) {
        return substr( $self->{_lines}[$l1] // '', $c1, $c2 - $c1 );
    }

    # Cross-line range.
    my @parts;
    push @parts, substr( $self->{_lines}[$l1], $c1 );
    for my $ln ( $l1 + 1 .. $l2 - 1 ) {
        push @parts, $self->{_lines}[$ln];
    }
    push @parts, substr( $self->{_lines}[$l2] // '', 0, $c2 );
    return join( "\n", @parts );
}

sub insert_text {
    my ( $self, $text ) = @_;

    $self->_save_undo;

    my @parts = split /\n/, $text, -1;

    my $line = $self->{_cur_line};
    my $col  = $self->{_cur_col};
    my $cur  = $self->{_lines}[$line];

    if ( @parts == 1 ) {
        # Single line -- splice into the current line.
        substr( $cur, $col, 0 ) = $parts[0];
        $self->{_lines}[$line] = $cur;
        $self->{_cur_col} = $col + length( $parts[0] );
    }
    else {
        # Multi-line insert -- split the current line.
        my $before = substr( $cur, 0, $col );
        my $after  = substr( $cur, $col );

        my @new_lines = ( $before . $parts[0] );
        for my $i ( 1 .. $#parts - 1 ) {
            push @new_lines, $parts[$i];
        }
        push @new_lines, $parts[-1] . $after;

        splice @{$self->{_lines}}, $line, 1, @new_lines;

        # Cursor moves to end of inserted text.
        $self->{_cur_line} = $line + $#parts;
        $self->{_cur_col}  = length( $parts[-1] );
    }

    $self->{_modified} = 1;
}

sub delete_range {
    my ( $self, $l1, $c1, $l2, $c2 ) = @_;

    $self->_save_undo;

    if ( $l1 == $l2 ) {
        my $cur = $self->{_lines}[$l1];
        substr( $cur, $c1, $c2 - $c1 ) = '';
        $self->{_lines}[$l1] = $cur;
    }
    else {
        # Cross-line delete.
        my $first = $self->{_lines}[$l1];
        my $last  = $self->{_lines}[$l2];

        my $new_line = substr( $first, 0, $c1 )
                     . substr( $last // '', $c2 );

        splice @{$self->{_lines}}, $l1, $l2 - $l1 + 1, $new_line;
    }

    $self->{_cur_line} = $l1;
    $self->{_cur_col}  = $c1;
    $self->{_modified} = 1;
}

# ----------------------------------------------------------------
# Undo
# ----------------------------------------------------------------

sub undo {
    my ($self) = @_;
    return unless @{$self->{_undo_stack}};

    my $snap = pop @{$self->{_undo_stack}};
    $self->{_lines}    = $snap->{_lines};
    $self->{_cur_line} = $snap->{_cur_line};
    $self->{_cur_col}  = $snap->{_cur_col};
}

sub redo {
    # Redo is not yet implemented in the test backend (requires A2: unified undo/redo).
    # The Gtk3 backend uses $buffer->redo natively.
}

# ----------------------------------------------------------------
# Modified flag
# ----------------------------------------------------------------

sub modified {
    my ($self) = @_;
    return $self->{_modified};
}

sub set_modified {
    my ( $self, $bool ) = @_;
    $self->{_modified} = $bool ? 1 : 0;
}

# ----------------------------------------------------------------
# Word motions
# ----------------------------------------------------------------

sub word_forward {
    my ($self) = @_;
    my $line = $self->{_cur_line};
    my $col  = $self->{_cur_col};
    my $text = $self->{_lines}[$line];

    # Phase 1: skip non-whitespace characters on the current line.
    while ( $col < length($text) && $text =~ /\S/ && substr( $text, $col, 1 ) !~ /\s/ ) {
        $col++;
    }

    # Phase 2: skip whitespace characters on the current line.
    while ( $col < length($text) && substr( $text, $col, 1 ) =~ /\s/ ) {
        $col++;
    }

    # If we reached the end of the current line and there is a next line,
    # move to the next line and skip leading whitespace.
    if ( $col >= length($text) && $line < $self->line_count - 1 ) {
        $line++;
        $col = 0;
        $text = $self->{_lines}[$line];

        while ( $col < length($text) && substr( $text, $col, 1 ) =~ /\s/ ) {
            $col++;
        }
    }

    $self->set_cursor( $line, $col );
}

sub word_end {
    my ($self) = @_;
    my $line = $self->{_cur_line};
    my $col  = $self->{_cur_col};
    my $text = $self->{_lines}[$line];

    # Move forward at least one position so repeated 'e' presses always
    # make progress, even when already at the end of a word.
    $col++;
    if ( $col > length($text) ) {
        if ( $line < $self->line_count - 1 ) {
            $line++;
            $col = 0;
            $text = $self->{_lines}[$line];
        }
        else {
            # Already at buffer end -- stay put.
            $col = length($text);
            $self->set_cursor( $line, $col );
            return;
        }
    }

    # Skip non-word characters (whitespace, punctuation, symbols).
    # These act as word separators, matching the Gtk3 implementation.
    while (1) {
        while ( $col < length($text) && substr( $text, $col, 1 ) !~ /^\w$/ ) {
            $col++;
        }
        if ( $col < length($text) ) {
            last;
        }
        # End of line -- try next line.
        if ( $line < $self->line_count - 1 ) {
            $line++;
            $col = 0;
            $text = $self->{_lines}[$line];
        }
        else {
            # Buffer end.
            $col = length($text);
            $self->set_cursor( $line, $col );
            return;
        }
    }

    # Skip word characters to reach the end of the word.
    while ( $col < length($text) && substr( $text, $col, 1 ) =~ /^\w$/ ) {
        $col++;
    }

    # Back up one to land on the last character of the word.
    $col--;

    $self->set_cursor( $line, $col );
}

sub word_backward {
    my ($self) = @_;
    my $line = $self->{_cur_line};
    my $col  = $self->{_cur_col};
    my $text = $self->{_lines}[$line];

    # Move back at least one position.
    $col--;
    if ( $col < 0 ) {
        if ( $line > 0 ) {
            $line--;
            $text = $self->{_lines}[$line];
            $col = length($text) - 1;
        }
        else {
            # Already at start of buffer.
            $col = 0;
            $self->set_cursor( $line, $col );
            return;
        }
    }

    # Phase 1: skip whitespace backward (may cross line boundaries).
    while ( $col >= 0 && substr( $text, $col, 1 ) =~ /\s/ ) {
        $col--;
    }

    # If we went before the start of the line, back up to the previous line.
    while ( $col < 0 ) {
        if ( $line > 0 ) {
            $line--;
            $text = $self->{_lines}[$line];
            $col = length($text) - 1;
            while ( $col >= 0 && substr( $text, $col, 1 ) =~ /\s/ ) {
                $col--;
            }
        }
        else {
            $col = 0;
            $self->set_cursor( $line, $col );
            return;
        }
    }

    if ( $col < 0 ) {
        $col = 0;
        $self->set_cursor( $line, $col );
        return;
    }

    # Phase 2: skip backward through non-whitespace characters.
    while ( $col > 0 && substr( $text, $col - 1, 1 ) !~ /\s/ ) {
        $col--;
    }

    $self->set_cursor( $line, $col );
}

# ----------------------------------------------------------------
# first_nonblank_col
# ----------------------------------------------------------------

sub first_nonblank_col {
    my ( $self, $line ) = @_;
    my $text = $self->{_lines}[$line] // '';
    if ( $text =~ /^(\s*)/ ) {
        return length($1);
    }
    return 0;
}

# ----------------------------------------------------------------
# join_lines
# ----------------------------------------------------------------

sub join_lines {
    my ( $self, $count ) = @_;
    $count //= 1;
    return if $count < 1;

    my $line = $self->{_cur_line};
    # $count = number of additional lines to join into current line
    return if $line + $count >= $self->line_count;

    my $result = $self->{_lines}[$line];
    my $join_col = length($result);

    for my $i ( 1 .. $count ) {
        my $next_text = $self->{_lines}[ $line + $i ];

        # Trim leading whitespace from the joined line
        $next_text =~ s/^\s+//;

        # Determine separator
        my $sep = ' ';
        if ( $result =~ /\s$/ || $next_text =~ /^\)/ ) {
            $sep = '';
        }
        $join_col += length($sep);
        $result .= $sep . $next_text;
    }

    $self->_save_undo;

    # Replace lines $line..($line+$count) with the joined line
    splice @{$self->{_lines}}, $line, $count + 1, $result;

    $self->{_cur_col} = $join_col < length($result) ? $join_col : length($result);
    $self->_clamp_cursor;
    $self->{_modified} = 1;
}

# ----------------------------------------------------------------
# indent_lines
# ----------------------------------------------------------------

sub indent_lines {
    my ( $self, $count, $width, $direction ) = @_;
    $count //= 1;
    $width //= 4;
    $direction //= 1;

    my $line = $self->{_cur_line};
    my $end  = $line + $count - 1;
    $end = $self->line_count - 1 if $end >= $self->line_count;

    $self->_save_undo;

    my $spaces = ' ' x $width;
    for my $ln ( $line .. $end ) {
        if ( $direction > 0 ) {
            $self->{_lines}[$ln] = $spaces . $self->{_lines}[$ln];
        }
        else {
            my $removed = 0;
            while ( $removed < $width
                && substr( $self->{_lines}[$ln], 0, 1 ) eq ' ' )
            {
                substr( $self->{_lines}[$ln], 0, 1 ) = '';
                $removed++;
            }
        }
    }

    $self->{_cur_col} = $self->first_nonblank_col($line);
    $self->{_modified} = 1;
}

# ----------------------------------------------------------------
# replace_char
# ----------------------------------------------------------------

sub replace_char {
    my ( $self, $char ) = @_;
    return unless defined $char && length($char);

    my $line = $self->{_cur_line};
    my $col  = $self->{_cur_col};
    my $text = $self->{_lines}[$line];

    # Cannot replace past end of line
    return if $col >= length($text);

    $self->_save_undo;

    substr( $text, $col, 1 ) = $char;
    $self->{_lines}[$line] = $text;
    $self->{_modified}     = 1;
}

# ----------------------------------------------------------------
# char_at
# ----------------------------------------------------------------

sub char_at {
    my ( $self, $line, $col ) = @_;
    return '' if $line < 0 || $line >= $self->line_count;
    my $text = $self->{_lines}[$line];
    return '' if $col < 0 || $col >= length($text);
    return substr( $text, $col, 1 );
}

# ----------------------------------------------------------------
# search_forward
# ----------------------------------------------------------------

sub search_forward {
    my ( $self, $pattern, $start_line, $start_col ) = @_;
    $start_line //= $self->{_cur_line};
    $start_col  //= $self->{_cur_col} + 1;

    my $re = ref($pattern) ? $pattern : eval { qr/$pattern/ };
    return undef unless $re;

    my $total = $self->line_count;

    for my $offset ( 0 .. $total - 1 ) {
        my $ln   = ( $start_line + $offset ) % $total;
        my $text = $self->{_lines}[$ln];
        my $from = ( $offset == 0 ) ? $start_col : 0;

        next if length($text) < $from;
        my $sub = substr( $text, $from );
        if ( $sub =~ /$re/ ) {
            return { line => $ln, col => $from + $-[0] };
        }
    }
    return undef;
}

# ----------------------------------------------------------------
# search_backward
# ----------------------------------------------------------------

sub search_backward {
    my ( $self, $pattern, $start_line, $start_col ) = @_;
    $start_line //= $self->{_cur_line};
    $start_col  //= $self->{_cur_col} - 1;

    my $re = ref($pattern) ? $pattern : eval { qr/$pattern/ };
    return undef unless $re;

    my $total = $self->line_count;

    for my $offset ( 0 .. $total - 1 ) {
        my $ln   = ( $start_line - $offset + $total ) % $total;
        my $text = $self->{_lines}[$ln];
        my $from;
        if ( $offset == 0 ) {
            $from = $start_col >= 0 ? $start_col : 0;
        }
        else {
            $from = length($text) - 1;
        }

        while ( $from >= 0 ) {
            my $sub = substr( $text, 0, $from + 1 );
            if ( $sub =~ /$re/ ) {
                return { line => $ln, col => $-[0] };
            }
            $from--;
        }
    }
    return undef;
}

# ----------------------------------------------------------------
# transform_range / toggle_case
# ----------------------------------------------------------------

sub transform_range {
    my ( $self, $l1, $c1, $l2, $c2, $how ) = @_;
    $how //= 'toggle';

    $self->_save_undo;

    my $text = $self->get_range( $l1, $c1, $l2, $c2 );
    if    ( $how eq 'upper' )  { $text = uc $text; }
    elsif ( $how eq 'lower' )  { $text = lc $text; }
    elsif ( $how eq 'toggle' ) { $text =~ tr/a-zA-Z/A-Za-z/; }

    $self->delete_range( $l1, $c1, $l2, $c2 );
    $self->insert_text($text);
    $self->set_cursor( $l1, $c1 );
}

sub toggle_case {
    my ( $self, $l1, $c1, $l2, $c2 ) = @_;
    $self->transform_range( $l1, $c1, $l2, $c2, 'toggle' );
}

# ----------------------------------------------------------------
# Predicate methods (duplicated from base class for reliable
# inheritance when t/lib mock Gtk3 is loaded first)
# ----------------------------------------------------------------

sub at_line_start {
    my ($self) = @_;
    return $self->cursor_col == 0;
}

sub at_line_end {
    my ($self) = @_;
    return $self->cursor_col >= $self->line_length( $self->cursor_line );
}

sub at_buffer_end {
    my ($self) = @_;
    return $self->cursor_line == $self->line_count - 1
        && $self->at_line_end;
}

# ----------------------------------------------------------------
# Selection management (stubs -- no GUI in test backend)
# ----------------------------------------------------------------

sub set_selection {
    my ($self, $anchor_line, $anchor_col) = @_;
    $self->{_sel_anchor_line} = $anchor_line;
    $self->{_sel_anchor_col}  = $anchor_col;
}

sub clear_selection {
    my ($self) = @_;
    delete $self->{_sel_anchor_line};
    delete $self->{_sel_anchor_col};
}

sub get_selection {
    my ($self) = @_;
    return undef unless exists $self->{_sel_anchor_line};
    return {
        anchor_line => $self->{_sel_anchor_line},
        anchor_col  => $self->{_sel_anchor_col},
    };
}

# ----------------------------------------------------------------
# Undo grouping (stubs -- test backend uses simple snapshots)
# ----------------------------------------------------------------

sub begin_user_action { }
sub end_user_action   { }

1;

__END__

=head1 AUTHOR

Auto-generated for the P5-Gtk3-SourceEditor project.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
