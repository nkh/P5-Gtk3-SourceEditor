package Gtk3::SourceEditor::VimBuffer;

use strict;
use warnings;

our $VERSION = '0.04';

=head1 NAME

Gtk3::SourceEditor::VimBuffer - Abstract interface for a Vim-like text buffer

=head1 SYNOPSIS

    # This is an abstract base class; use one of the concrete subclasses.
    #
    # For testing:
    my $buf = Gtk3::SourceEditor::VimBuffer::Test->new( text => "hello\nworld" );
    #
    # For GTK3 integration:
    my $buf = Gtk3::SourceEditor::VimBuffer::Gtk3->new(
        buffer => $gtk_source_buffer,
        view   => $gtk_source_view,
    );

=head1 DESCRIPTION

C<Gtk3::SourceEditor::VimBuffer> defines the abstract interface that all
buffer backends must implement.  Every method in the L</ABSTRACT METHODS>
section throws an exception when called on the base class; subclasses B<must>
override them.

The class also provides default L</PREDICATE METHODS> built on top of the
abstract cursor and line accessors, so subclasses only need to implement the
primitives.

=head1 ABSTRACT METHODS

The following methods die with "Unimplemented in ..." when invoked on the
base class.  Every subclass must provide its own implementation.

=head2 cursor_line()

    my $line = $buf->cursor_line;

Return the 0-based line number where the cursor currently resides.

=head2 cursor_col()

    my $col = $buf->cursor_col;

Return the 0-based column (character offset) within the cursor line.

=head2 set_cursor( $line, $col )

    $buf->set_cursor( $line, $col );

Move the cursor to the given position.  Implementations should clamp the
values to valid ranges.

=head2 line_count()

    my $n = $buf->line_count;

Return the total number of lines in the buffer.

=head2 line_text( $line )

    my $text = $buf->line_text( $line );

Return the text of line C<$line> (0-based) B<without> a trailing newline.

=head2 line_length( $line )

    my $len = $buf->line_length( $line );

Return the number of characters in line C<$line>.

=head2 text()

    my $whole = $buf->text;

Return the entire buffer contents as a single string.

=head2 set_text( $text )

    $buf->set_text( $text );

Replace the entire buffer contents with C<$text>.  The cursor is moved
to the start of the buffer.  The modified flag is not automatically changed;
callers should use C<set_modified()> if needed.

=head2 get_range( $l1, $c1, $l2, $c2 )

    my $chunk = $buf->get_range( $l1, $c1, $l2, $c2 );

Return the text between two positions.  The range is inclusive at the start
and exclusive at the end (like Perl C<substr>).

=head2 delete_range( $l1, $c1, $l2, $c2 )

    $buf->delete_range( $l1, $c1, $l2, $c2 );

Delete the text between two positions and move the cursor to C<($l1, $c1)>.
The range is inclusive at the start and exclusive at the end.

=head2 insert_text( $text )

    $buf->insert_text( $text );

Insert C<$text> at the current cursor position and advance the cursor past
the inserted text.

=head2 undo()

    $buf->undo;

Undo the last editing operation (insert or delete).

=head2 redo()

    $buf->redo;

Redo the last undone editing operation.

=head2 modified()

    my $bool = $buf->modified;

Return true if the buffer has been modified since the last save/checkpoint.

=head2 set_modified( $bool )

    $buf->set_modified( 0 );   # mark as clean
    $buf->set_modified( 1 );   # mark as dirty

Set the modified flag.

=head2 word_forward()

    $buf->word_forward;

Move the cursor forward to the start of the next word.  Skips the rest of
the current word (non-whitespace) and any trailing whitespace.  Wraps to the
beginning of the next line when necessary.

=head2 word_end()

    $buf->word_end;

Move the cursor to the last character of the current or next word.
Advances at least one position, skips whitespace, then skips non-whitespace,
and backs up one character to land on the final character of the word.

=head2 word_backward()

    $buf->word_backward;

Move the cursor backward to the start of the previous (or current) word.
Moves back one position first, then skips whitespace backwards (crossing
line boundaries), then skips backward through non-whitespace characters.

=head2 first_nonblank_col( $line )

    my $col = $buf->first_nonblank_col( $line );

Return the column of the first non-whitespace character on line C<$line>.
Returns 0 if the line is empty or entirely whitespace.

=head2 join_lines( $count )

    $buf->join_lines( $count );

Join the current line with the next C<$count - 1> lines (like Vim's C<J>).
A single space is inserted between lines unless the current line already
ends with whitespace or the next line starts with C<)>.  Leading whitespace
on the joined line is removed.  The cursor is placed at the join point.

=head2 indent_lines( $count, $width, $direction )

    $buf->indent_lines( $count, 4, 1 );   # indent right
    $buf->indent_lines( $count, 4, -1 );  # indent left

Add (C<$direction E<gt> 0>) or remove (C<$direction E<lt> 0>) C<$width> spaces
at the beginning of C<$count> lines starting from the current line.
Cursor is moved to the first non-blank column of the current line.

=head2 replace_char( $char )

    $buf->replace_char( 'x' );

Replace the character under the cursor with C<$char>.  The cursor stays
at its current position.

=head2 char_at( $line, $col )

    my $ch = $buf->char_at( $line, $col );

Return the character at the given position, or the empty string if out
of bounds.

=head2 search_forward( $pattern, $start_line, $start_col )

    my $match = $buf->search_forward( qr/\d+/, $line, $col );

Search forward for C<$pattern> (a C<qr//> or plain string) starting from
C<($start_line, $start_col)>.  Wraps around the buffer.  Returns a
hashref C<{ line =E<gt> $l, col =E<gt> $c }> on success, or C<undef>.

=head2 search_backward( $pattern, $start_line, $start_col )

    my $match = $buf->search_backward( qr/\d+/, $line, $col );

Search backward for C<$pattern> starting from C<($start_line, $start_col)>,
moving left on the same line then to previous lines (wrapping).  Returns
a hashref C<{ line =E<gt> $l, col =E<gt> $c }> on success, or C<undef>.

=head1 PREDICATE METHODS

These methods are implemented in the base class and call the abstract
C<cursor_line>, C<cursor_col>, and C<line_length> methods.  Subclasses
generally do B<not> need to override them.

=head2 at_line_start()

    if ( $buf->at_line_start ) { ... }

True when the cursor column is 0.

=head2 at_line_end()

    if ( $buf->at_line_end ) { ... }

True when the cursor column is at or past the last character of the current
line.

=head2 at_buffer_end()

    if ( $buf->at_buffer_end ) { ... }

True when the cursor is on the last line B<and> at the end of that line.

=cut

# ----------------------------------------------------------------
# Abstract methods - every one dies when called on the base class.
# ----------------------------------------------------------------

sub cursor_line  { die "Unimplemented in " . __PACKAGE__ }
sub cursor_col   { die "Unimplemented in " . __PACKAGE__ }
sub set_cursor   { die "Unimplemented in " . __PACKAGE__ }
sub move_cursor  { die "Unimplemented in " . __PACKAGE__ }
sub line_count   { die "Unimplemented in " . __PACKAGE__ }
sub line_text    { die "Unimplemented in " . __PACKAGE__ }
sub line_length  { die "Unimplemented in " . __PACKAGE__ }
sub text         { die "Unimplemented in " . __PACKAGE__ }
sub set_text     { die "Unimplemented in " . __PACKAGE__ }
sub get_range    { die "Unimplemented in " . __PACKAGE__ }
sub delete_range { die "Unimplemented in " . __PACKAGE__ }
sub insert_text  { die "Unimplemented in " . __PACKAGE__ }
sub undo         { die "Unimplemented in " . __PACKAGE__ }
sub redo         { die "Unimplemented in " . __PACKAGE__ }
sub modified     { die "Unimplemented in " . __PACKAGE__ }
sub set_modified { die "Unimplemented in " . __PACKAGE__ }
sub word_forward { die "Unimplemented in " . __PACKAGE__ }
sub word_end     { die "Unimplemented in " . __PACKAGE__ }
sub word_backward{ die "Unimplemented in " . __PACKAGE__ }

sub first_nonblank_col { die "Unimplemented in " . __PACKAGE__ }
sub join_lines    { die "Unimplemented in " . __PACKAGE__ }
sub indent_lines  { die "Unimplemented in " . __PACKAGE__ }
sub replace_char  { die "Unimplemented in " . __PACKAGE__ }
sub char_at       { die "Unimplemented in " . __PACKAGE__ }
sub search_forward  { die "Unimplemented in " . __PACKAGE__ }
sub search_backward { die "Unimplemented in " . __PACKAGE__ }
sub toggle_case     { die "Unimplemented in " . __PACKAGE__ }
sub transform_range { die "Unimplemented in " . __PACKAGE__ }

# ----------------------------------------------------------------
# Predicate helpers - built on top of the abstract accessors.
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

1;

__END__

=head1 AUTHOR

Auto-generated for the P5-Gtk3-SourceEditor project.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
