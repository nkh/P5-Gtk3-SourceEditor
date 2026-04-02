package Gtk3::SourceEditor::VimBuffer::Gtk3;

use strict;
use warnings;

use parent 'Gtk3::SourceEditor::VimBuffer';
use Glib qw(TRUE FALSE);

our $VERSION = '0.04';

=head1 NAME

Gtk3::SourceEditor::VimBuffer::Gtk3 - Gtk3::SourceView buffer backend

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBuffer::Gtk3;

    my $buf = Gtk3::SourceEditor::VimBuffer::Gtk3->new(
        buffer => $gtk_source_buffer,   # Gtk3::SourceBuffer
        view   => $gtk_source_view,     # Gtk3::SourceView
    );

    $buf->insert_text("hello");
    my $line = $buf->cursor_line;

=head1 DESCRIPTION

This backend wraps a L<Gtk3::SourceBuffer> / L<Gtk3::SourceView> pair and
delegates all buffer operations to the GTK text-widget infrastructure.  It
is intended for use inside a real GTK application.

=head1 CONSTRUCTOR

=head2 new( %opts )

    my $buf = Gtk3::SourceEditor::VimBuffer::Gtk3->new(
        buffer => $gtk_source_buffer,   # required
        view   => $gtk_source_view,     # required
    );

Both C<buffer> and C<view> are required.

=cut

sub new {
    my ( $class, %opts ) = @_;

    die "buffer option is required" unless defined $opts{buffer};
    die "view option is required"   unless defined $opts{view};

    my $self = bless {
        _buffer => $opts{buffer},
        _view   => $opts{view},
    }, $class;

    return $self;
}

# ----------------------------------------------------------------
# Accessors for the underlying GTK objects
# ----------------------------------------------------------------

=head1 ACCESSORS

=head2 gtk_buffer()

    my $src_buf = $buf->gtk_buffer;

Return the underlying C<Gtk3::SourceBuffer>.

=head2 gtk_view()

    my $src_view = $buf->gtk_view;

Return the underlying C<Gtk3::SourceView>.

=cut

sub gtk_buffer { $_[0]->{_buffer} }
sub gtk_view   { $_[0]->{_view}   }

# ----------------------------------------------------------------
# Internal helper
# ----------------------------------------------------------------

sub _iter {
    my ($self) = @_;
    # Return an iterator at the insert mark (cursor position).
    return $self->{_buffer}->get_iter_at_mark( $self->{_buffer}->get_insert );
}

# ----------------------------------------------------------------
# Cursor
# ----------------------------------------------------------------

sub cursor_line {
    my ($self) = @_;
    return $self->_iter->get_line;
}

sub cursor_col {
    my ($self) = @_;
    return $self->_iter->get_line_offset;
}

sub set_cursor {
    my ( $self, $line, $col ) = @_;
    my $buf = $self->{_buffer};

    # Clamp line to valid range
    my $max_line = $buf->get_line_count - 1;
    $line = 0        if $line < 0;
    $line = $max_line if $line > $max_line;

    # Clamp column to valid range
    my $max_col = $self->line_length($line);
    $col = 0        if $col < 0;
    $col = $max_col if $col > $max_col;

    my $iter = $buf->get_iter_at_line_offset( $line, $col );
    $buf->place_cursor($iter);
}

sub move_cursor {
    my ( $self, $line, $col ) = @_;
    my $buf = $self->{_buffer};

    # Clamp line to valid range
    my $max_line = $buf->get_line_count - 1;
    $line = 0        if $line < 0;
    $line = $max_line if $line > $max_line;

    # Clamp column to valid range
    my $max_col = $self->line_length($line);
    $col = 0        if $col < 0;
    $col = $max_col if $col > $max_col;

    my $iter = $buf->get_iter_at_line_offset( $line, $col );
    # Move the insert mark WITHOUT moving selection_bound.
    # This preserves the GTK selection while repositioning the cursor.
    $buf->move_mark_by_name( 'insert', $iter );
}

# ----------------------------------------------------------------
# Line access
# ----------------------------------------------------------------

sub line_count {
    my ($self) = @_;
    return $self->{_buffer}->get_line_count;
}

sub line_text {
    my ( $self, $line ) = @_;
    my $buf = $self->{_buffer};
    my $start = $buf->get_iter_at_line($line);
    my $end   = $start->copy;
    $end->forward_to_line_end;
    return $start->get_text($end);
}

sub line_length {
    my ( $self, $line ) = @_;
    my $buf = $self->{_buffer};
    my $iter = $buf->get_iter_at_line($line);
    my $chars = $iter->get_chars_in_line;
    # The last line may not have a trailing newline, so don't subtract.
    # For all other lines, get_chars_in_line includes the '\n'.
    if ( $line >= $buf->get_line_count - 1 ) {
        return $chars;
    }
    return $chars > 0 ? $chars - 1 : 0;
}

# ----------------------------------------------------------------
# Whole-buffer text
# ----------------------------------------------------------------

sub text {
    my ($self) = @_;
    my $buf = $self->{_buffer};
    my $start = $buf->get_start_iter;
    my $end   = $buf->get_end_iter;
    return $start->get_text($end);
}

sub set_text {
    my ($self, $text) = @_;
    my $buf = $self->{_buffer};
    $buf->set_text($text);
    $buf->place_cursor($buf->get_start_iter);
}

# ----------------------------------------------------------------
# Range operations
# ----------------------------------------------------------------

sub get_range {
    my ( $self, $l1, $c1, $l2, $c2 ) = @_;
    my $buf = $self->{_buffer};
    my $start = $buf->get_iter_at_line_offset( $l1, $c1 );
    my $end   = $buf->get_iter_at_line_offset( $l2, $c2 );
    return $start->get_text($end);
}

sub delete_range {
    my ( $self, $l1, $c1, $l2, $c2 ) = @_;
    my $buf = $self->{_buffer};
    my $start = $buf->get_iter_at_line_offset( $l1, $c1 );
    my $end   = $buf->get_iter_at_line_offset( $l2, $c2 );
    $buf->delete( $start, $end );
    $self->set_cursor( $l1, $c1 );
}

sub insert_text {
    my ( $self, $text ) = @_;
    my $buf = $self->{_buffer};
    my $iter = $self->_iter;
    $buf->insert( $iter, $text );
}

# ----------------------------------------------------------------
# Undo
# ----------------------------------------------------------------

sub undo {
    my ($self) = @_;
    $self->{_buffer}->undo;
}

sub redo {
    my ($self) = @_;
    $self->{_buffer}->redo;
}

# ----------------------------------------------------------------
# Modified flag
# ----------------------------------------------------------------

sub modified {
    my ($self) = @_;
    return $self->{_buffer}->get_modified ? TRUE : FALSE;
}

sub set_modified {
    my ( $self, $bool ) = @_;
    $self->{_buffer}->set_modified( $bool ? TRUE : FALSE );
}

# ----------------------------------------------------------------
# Word motions
# ----------------------------------------------------------------

sub word_forward {
    my ($self) = @_;
    my $buf  = $self->{_buffer};
    my $iter = $self->_iter;

    $iter->forward_word_end;

    # If not at the very end of the buffer and not already at the start of
    # a line, move one more character forward so we land at the beginning
    # of the *next* word (past any inter-word whitespace).
    if ( $iter->get_char ne chr(0) && !$iter->starts_line ) {
        $iter->forward_char;
    }

    # Use move_mark_by_name instead of place_cursor to preserve the
    # selection_bound mark (important for visual mode selections).
    $buf->move_mark_by_name( 'insert', $iter );
}

sub word_end {
    my ($self) = @_;
    my $buf  = $self->{_buffer};
    my $iter = $self->_iter;

    # Move forward at least one character so repeated 'e' presses always
    # make progress, even when already at the end of a word.
    $iter->forward_char;

    # Skip non-word characters (whitespace, punctuation, symbols).
    # These act as word separators, so 'e' jumps past them to the next
    # word.  This naturally crosses line boundaries because forward_char
    # advances past the newline to the next line.
    while ($iter->get_char ne chr(0) && $iter->get_char !~ /^\w$/) {
        $iter->forward_char;
    }

    # If we reached the end of the buffer there is no next word;
    # back up to the last character and stay there.
    if ($iter->get_char eq chr(0)) {
        $iter->backward_char;
        $buf->move_mark_by_name('insert', $iter);
        return;
    }

    # Skip word characters to reach the end of the word.
    while ($iter->get_char ne chr(0) && $iter->get_char =~ /^\w$/) {
        $iter->forward_char;
    }

    # Back up one to land on the last character of the word.
    $iter->backward_char;

    # Use move_mark_by_name instead of place_cursor to preserve the
    # selection_bound mark (important for visual mode selections).
    $buf->move_mark_by_name('insert', $iter);
}

sub word_backward {
    my ($self) = @_;
    my $buf  = $self->{_buffer};
    my $iter = $self->_iter;

    $iter->backward_word_start;

    # Use move_mark_by_name instead of place_cursor to preserve the
    # selection_bound mark (important for visual mode selections).
    $buf->move_mark_by_name( 'insert', $iter );
}

# ----------------------------------------------------------------
# first_nonblank_col
# ----------------------------------------------------------------

sub first_nonblank_col {
    my ( $self, $line ) = @_;
    my $buf  = $self->{_buffer};
    my $iter = $buf->get_iter_at_line($line);
    while ( !$iter->ends_line && ( $iter->get_char =~ /^\s$/ ) ) {
        $iter->forward_char;
    }
    return $iter->get_line_offset;
}

# ----------------------------------------------------------------
# join_lines
# ----------------------------------------------------------------

sub join_lines {
    my ( $self, $count ) = @_;
    $count //= 1;
    return if $count < 1;

    my $buf  = $self->{_buffer};
    my $line = $self->_iter->get_line;
    my $col  = $self->_iter->get_line_offset;

    for ( 1 .. $count ) {
        my $next = $line + 1;
        last if $next >= $buf->get_line_count;

        my $end_iter = $buf->get_iter_at_line($next);
        $end_iter->forward_to_line_end;
        my $next_text = $buf->get_iter_at_line($next)->get_text($end_iter);
        $next_text =~ s/^\s+//;

        my $cur_text = $self->line_text($line);
        my $sep = ' ';
        if ( $cur_text =~ /\s$/ || $next_text =~ /^\)/ ) {
            $sep = '';
        }

        my $join_col = length($cur_text) + length($sep);
        my $end_of_cur = $buf->get_iter_at_line($line);
        $end_of_cur->forward_to_line_end;
        my $start_of_next = $buf->get_iter_at_line( $line + 1 );

        $buf->delete( $end_of_cur, $start_of_next );
        my $at_eol = $buf->get_iter_at_line($line);
        $at_eol->forward_to_line_end;
        $buf->insert( $at_eol, $sep . $next_text );

        $buf->place_cursor(
            $buf->get_iter_at_line_offset( $line, $join_col ) );
    }
}

# ----------------------------------------------------------------
# indent_lines
# ----------------------------------------------------------------

sub indent_lines {
    my ( $self, $count, $width, $direction ) = @_;
    $count     //= 1;
    $width     //= 4;
    $direction //= 1;

    my $buf  = $self->{_buffer};
    my $line = $self->_iter->get_line;
    my $end  = $line + $count - 1;
    $end = $buf->get_line_count - 1 if $end >= $buf->get_line_count;

    my $spaces = ' ' x $width;

    # Work from bottom to top so line numbers stay valid
    for my $ln ( reverse $line .. $end ) {
        my $start = $buf->get_iter_at_line($ln);
        my $first = $start->copy;
        $first->forward_chars($width);

        if ( $direction > 0 ) {
            $buf->insert( $start, $spaces );
        }
        else {
            my $end_char = $start->copy;
            $end_char->forward_chars($width);
            # Only delete if there are enough leading spaces
            my $check = $start->copy;
            $check->forward_char;
            while ( $check <= $end_char
                && $start->get_char =~ /^ $/ )
            {
                my $del_end = $start->copy;
                $del_end->forward_char;
                $buf->delete( $start, $del_end );
            }
        }
    }

    my $fnc = $self->first_nonblank_col($line);
    $buf->place_cursor( $buf->get_iter_at_line_offset( $line, $fnc ) );
}

# ----------------------------------------------------------------
# replace_char
# ----------------------------------------------------------------

sub replace_char {
    my ( $self, $char ) = @_;
    return unless defined $char && length($char);

    my $buf  = $self->{_buffer};
    my $iter = $self->_iter;
    my $end  = $iter->copy;
    $end->forward_char;
    $buf->delete( $iter, $end );
    # Get a fresh iterator -- delete() invalidates all existing iters.
    $buf->insert( $self->_iter, $char );
}

# ----------------------------------------------------------------
# char_at
# ----------------------------------------------------------------

sub char_at {
    my ( $self, $line, $col ) = @_;
    my $buf = $self->{_buffer};
    return '' if $line < 0 || $line >= $buf->get_line_count;
    my $iter = $buf->get_iter_at_line_offset( $line, $col );
    return '' if $iter->is_end;
    return $iter->get_char;
}

# ----------------------------------------------------------------
# search_forward
# ----------------------------------------------------------------

sub search_forward {
    my ( $self, $pattern, $start_line, $start_col ) = @_;
    $start_line //= $self->_iter->get_line;
    $start_col  //= $self->_iter->get_line_offset + 1;

    my $str = ref($pattern) ? "$pattern" : $pattern;
    return undef unless defined $str && length $str;

    my $buf   = $self->{_buffer};
    my $found = $buf->get_iter_at_line_offset( $start_line, $start_col );

    # Gtk3::TextIter::forward_search returns (success, match_start, match_end)
    # where success is a boolean.  We must capture all three return values.
    my ($success, $match_start) = $found->forward_search( $str, 'visible-only' );

    if ( !$success ) {
        # Wrap: try from start of buffer
        $found = $buf->get_start_iter;
        ($success, $match_start) = $found->forward_search( $str, 'visible-only' );
        return undef unless $success;
    }

    return { line => $match_start->get_line, col => $match_start->get_line_offset };
}

# ----------------------------------------------------------------
# search_backward
# ----------------------------------------------------------------

sub search_backward {
    my ( $self, $pattern, $start_line, $start_col ) = @_;
    $start_line //= $self->_iter->get_line;
    $start_col  //= $self->_iter->get_line_offset - 1;

    my $str = ref($pattern) ? "$pattern" : $pattern;
    return undef unless defined $str && length $str;

    my $buf = $self->{_buffer};
    my $found =
      $buf->get_iter_at_line_offset( $start_line, $start_col < 0 ? 0 : $start_col );

    # Gtk3::TextIter::backward_search returns (success, match_start, match_end).
    my ($success, $match_start) = $found->backward_search( $str, 'visible-only' );

    if ( !$success ) {
        $found = $buf->get_end_iter;
        ($success, $match_start) = $found->backward_search( $str, 'visible-only' );
        return undef unless $success;
    }

    return { line => $match_start->get_line, col => $match_start->get_line_offset };
}

# ----------------------------------------------------------------
# transform_range / toggle_case
# ----------------------------------------------------------------

sub transform_range {
    my ( $self, $l1, $c1, $l2, $c2, $how ) = @_;
    $how //= 'toggle';
    my $buf = $self->{_buffer};

    my $start = $buf->get_iter_at_line_offset( $l1, $c1 );
    my $end   = $buf->get_iter_at_line_offset( $l2, $c2 );
    my $text  = $start->get_text($end);

    if    ( $how eq 'upper' )  { $text = uc $text; }
    elsif ( $how eq 'lower' )  { $text = lc $text; }
    elsif ( $how eq 'toggle' ) { $text =~ tr/a-zA-Z/A-Za-z/; }

    $buf->delete( $start, $end );
    my $ins = $buf->get_iter_at_line_offset( $l1, $c1 );
    $buf->insert( $ins, $text );
    $self->set_cursor( $l1, $c1 );
}

sub toggle_case {
    my ( $self, $l1, $c1, $l2, $c2 ) = @_;
    $self->transform_range( $l1, $c1, $l2, $c2, 'toggle' );
}

# ----------------------------------------------------------------
# Predicate methods -- duplicated from base class for reliable
# inheritance when loaded via blib or in complex @INC setups.
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
# Selection management (for visual mode highlighting)
# ----------------------------------------------------------------

sub set_selection {
    my ( $self, $anchor_line, $anchor_col ) = @_;
    my $buf = $self->{_buffer};
    my $anchor_iter = $buf->get_iter_at_line_offset( $anchor_line, $anchor_col );
    my $cursor_iter = $self->_iter;
    $buf->select_range( $cursor_iter, $anchor_iter );
}

sub clear_selection {
    my ($self) = @_;
    my $buf = $self->{_buffer};
    my $iter = $self->_iter;
    $buf->select_range( $iter, $iter );
}

# ----------------------------------------------------------------
# Undo grouping
# ----------------------------------------------------------------

sub begin_user_action {
    my ($self) = @_;
    $self->{_buffer}->begin_user_action;
}

sub end_user_action {
    my ($self) = @_;
    $self->{_buffer}->end_user_action;
}

1;

__END__

=head1 AUTHOR

Auto-generated for the P5-Gtk3-SourceEditor project.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
