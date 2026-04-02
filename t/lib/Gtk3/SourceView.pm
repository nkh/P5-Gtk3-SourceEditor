package Gtk3::SourceView;
use strict;
use warnings;

# Stub for headless testing -- provides Gtk3::SourceView namespace.
# The actual class hierarchy (Buffer, View, LanguageManager, etc.) is
# provided as sub-packages.

sub new { return bless {}, shift }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
# at runtime instead of dying with "Can't locate object method".
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    # Chaining methods (set_*, constructors, signal handlers) return self
    return $self if $method =~ /^(set_|new|signal_connect)/;
    # Getter methods return undef
    return undef if $method =~ /^get_/;
    # Everything else returns empty list
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Buffer;
use strict;
use warnings;

sub new              { return bless {}, shift }
sub new_with_language { return bless {}, shift }
sub set_text         { $_[0]->{_text} = $_[1] }
sub get_text         { return $_[0]->{_text} // '' }
sub set_language     { }
sub set_highlight_syntax { }
sub set_style_scheme { }
sub get_style_scheme { return undef }
sub place_cursor     { }
sub set_modified     { }
sub get_modified     { return 0 }
sub get_start_iter   { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_end_iter     { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_iter_at_line_offset { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_iter_at_line { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_iter_at_mark { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_insert       { return bless { _name => 'insert' }, 'Gtk3::SourceView::Buffer::Mark' }
sub get_tag_table    { return bless {}, 'Gtk3::SourceView::Buffer::TagTable' }
sub select_range     { }
sub get_tags         { return () }
sub begin_user_action { }
sub end_user_action   { }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Buffer::Iter;
use strict;
use warnings;

sub copy          { return bless {}, __PACKAGE__ }
sub get_line      { return 0 }
sub get_line_index { return 0 }
sub get_line_offset { return 0 }
sub get_char       { return '' }
sub is_end        { return 0 }
sub forward_char   { }
sub forward_line   { }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Buffer::Mark;
use strict;
use warnings;

sub get_name { return $_[0]->{_name} // '' }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Buffer::TagTable;
use strict;
use warnings;

sub foreach { }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::View;
use strict;
use warnings;

sub new              { return bless {}, shift }
sub new_with_buffer  { return bless {}, shift }
sub set_buffer       { }
sub set_show_line_numbers { }
sub set_highlight_current_line { }
sub get_visible_rect { return { height => 400, width => 800, x => 0, y => 0 } }
sub get_buffer       { return bless {}, 'Gtk3::SourceView::Buffer' }
sub get_insert       { return bless { _name => 'insert' }, 'Gtk3::SourceView::Buffer::Mark' }
sub get_iter_at_mark { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_iter_at_location { return bless {}, 'Gtk3::SourceView::Buffer::Iter' }
sub get_iter_location { return { x => 0, y => 0, width => 8, height => 16 } }
sub scroll_to_mark   { }
sub scroll_to_iter   { }
sub signal_connect   { }
sub signal_connect_after { }
sub get_pango_context { return bless {}, __PACKAGE__ }
sub create_pango_layout { return bless {}, __PACKAGE__ }
sub buffer_to_window_coords { return (0, 0) }
sub get_style_context { return bless {}, __PACKAGE__ }
sub modify_font      { }
sub queue_draw       { }
sub set_editable     { }
sub set_cursor_visible { }
sub get_style_scheme { return undef }
sub set_show_right_margin { }
sub set_right_margin_position { }
sub set_insert_spaces_instead_of_tabs { }
sub set_tab_width    { }
sub set_indent_width { }
sub set_smart_home_end { }
sub set_highlight_matching_brackets { }
sub set_show_line_marks { }
sub get_name         { return 'mock-view' }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::LanguageManager;
use strict;
use warnings;

sub get_default   { return bless {}, __PACKAGE__ }
sub guess_language { return undef }
sub get_language  { return undef }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::StyleSchemeManager;
use strict;
use warnings;

sub get_default         { return bless {}, __PACKAGE__ }
sub prepend_search_path { }
sub get_scheme          { return bless {}, 'Gtk3::SourceView::StyleScheme' }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::StyleScheme;
use strict;
use warnings;

sub get_name        { return 'mock-scheme' }
sub get_id          { return 'mock-scheme' }
sub get_description { return '' }
sub get_style       { return undef }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Language;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Completion;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::CompletionWords;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::UndoManager;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::SearchContext;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::SearchSettings;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Gutter;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::MarkAttributes;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::SpaceDrawer;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Region;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::File;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::FileLoader;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::FileSaver;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::Encoding;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::CompletionInfo;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::CompletionContext;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::CompletionItem;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::CompletionProvider;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

# -------------------------------------------------------------------
package Gtk3::SourceView::CompletionProposal;
use strict;
use warnings;

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    return $self if $method =~ /^(set_|new|signal_connect)/;
    return undef if $method =~ /^get_/;
    return;
}
sub can { return 1 }

1;
