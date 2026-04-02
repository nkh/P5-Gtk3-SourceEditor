package Gtk3;
use strict;
use warnings;

# Stub for headless testing -- provides Gtk3 namespace without a real GTK
# display.  Only the symbols actually called by VimBindings and friends
# are defined here.

sub import { }  # Accepts 'use Gtk3 -init' etc. silently

sub main_quit { }
sub main      { }

# Stubs for widget construction (return blessed refs that accept method calls)
sub new {
    my ($class, $type, @args) = @_;
    return bless { _type => $type, @args }, $class;
}

# --- Common widget methods ---
sub signal_connect      { }
sub signal_connect_after { }
sub signal_stop_emission_by_name { }
sub show                { }
sub hide                { }
sub show_all            { }
sub set_text            { $_[0]->{_text} = $_[1] }
sub get_text            { return $_[0]->{_text} // '' }
sub set_editable        { }
sub set_visible         { }
sub grab_focus          { }
sub set_position        { }
sub get_visible_rect    { return { height => 400, width => 800, x => 0, y => 0 } }
sub get_toplevel        { return bless {}, __PACKAGE__ }
sub queue_draw          { }
sub set_default_size    { }
sub set_decorated       { }
sub get_decorated       { return 1 }
sub set_title           { }
sub run                 { return 'ok' }
sub destroy             { }
sub get_message_area    { return bless { _children => [] }, __PACKAGE__ }
sub get_children        { return () }
sub set_xalign          { }
sub set_margin_end      { }
sub add                 { }
sub resize              { }
sub move                { }
sub set_policy          { }
sub set_no_show_all     { }
sub override_color      { }
sub override_background_color { }
sub set_modified        { }
sub get_modified        { return 0 }
sub set_show_line_numbers { }
sub set_highlight_current_line { }
sub set_auto_indent     { }
sub set_wrap_mode       { }
sub set_highlight_syntax { }
sub set_style_scheme    { }
sub set_cursor_visible  { }
sub place_cursor        { }
sub modify_font         { }
sub insert              { }
sub set_buffer          { }
sub set_show_right_margin { }
sub set_right_margin_position { }
sub set_insert_spaces_instead_of_tabs { }
sub set_tab_width       { }
sub set_indent_width    { }
sub set_smart_home_end  { }
sub set_highlight_matching_brackets { }
sub set_show_line_marks { }
sub get_buffer          { return bless {}, __PACKAGE__ }
sub get_insert          { return bless { _iter => 1 }, __PACKAGE__ }
sub get_start_iter      { return bless {}, __PACKAGE__ }
sub get_end_iter        { return bless {}, __PACKAGE__ }
sub get_iter_at_line_offset { return bless {}, __PACKAGE__ }
sub get_iter_at_line    { return bless {}, __PACKAGE__ }
sub get_iter_at_mark    { return bless {}, __PACKAGE__ }
sub get_iter_at_location { return bless {}, __PACKAGE__ }
sub select_range        { }
sub scroll_to_mark      { }
sub scroll_to_iter      { }
sub get_pango_context   { return bless {}, __PACKAGE__ }
sub create_pango_layout { return bless {}, __PACKAGE__ }
sub get_iter_location   { return { x => 0, y => 0, width => 8, height => 16 } }
sub buffer_to_window_coords { return (0, 0) }
sub get_line_count      { return 1 }
sub get_line_offset     { return 0 }
sub get_chars_in_line   { return 1 }
sub get_style_context   { return bless {}, __PACKAGE__ }
sub get_size            { return (800, 600) }
sub get_position        { return (0, 0) }
sub set_default_response { }
sub get_content_area    { return bless {}, __PACKAGE__ }
sub get_action_area     { return bless {}, __PACKAGE__ }
sub get_response        { return 'ok' }
sub add_button          { }
sub set_sensitive       { }

# Box/Container stubs
sub pack_start          { }
sub pack_end            { }

# SourceView / SourceBuffer stubs
sub new_with_language   { return bless {}, shift }
sub new_with_buffer     { return bless {}, shift }
sub set_language        { }
sub get_tag_table       { return bless {}, __PACKAGE__ }
sub foreach             { }
sub get_style_scheme    { return undef }

# LanguageManager
sub get_default         { return bless {}, __PACKAGE__ }
sub guess_language      { return undef }
sub get_language        { return undef }

# StyleSchemeManager
sub prepend_search_path { }
sub get_scheme          { return bless {}, __PACKAGE__ }
sub get_name            { return 'mock-scheme' }
sub get_id              { return 'mock-scheme' }
sub get_description     { return '' }
sub get_style           { return undef }

# CssProvider
sub load_from_data      { }

# ==========================================================================
# Sub-packages that real Gtk3 sets up via Glib::Object::Introspection.
# In the real GTK, 'use Gtk3' registers ALL Gtk3:: sub-packages so
# calling Gtk3::CssProvider->new() works without an explicit 'use'.
# We mimic that here by defining minimal stubs.
# ==========================================================================

package Gtk3::CssProvider;
sub new            { return bless {}, shift }
sub load_from_data { }

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

package Gtk3::Window;
sub new             { return bless {}, shift }
sub add             { }
sub show_all        { }
sub destroy         { }

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

package Gtk3::Dialog;
sub new                { return bless {}, shift }
sub add_button         { }
sub set_default_response { }
sub set_default_size   { }
sub set_decorated      { }
sub get_decorated      { return 1 }
sub get_content_area   { return bless {}, shift }
sub get_action_area    { return bless {}, shift }
sub signal_connect     { }
sub show_all           { }
sub destroy            { }

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

package Gtk3::Box;
sub new        { return bless {}, shift }
sub pack_start { }
sub pack_end   { }

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

package Gtk3::ScrolledWindow;
sub new        { return bless {}, shift }
sub set_policy { }
sub add        { }

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

package Gtk3::Entry;
sub new                     { return bless {}, shift }
sub set_no_show_all         { }
sub hide                    { }
sub show                    { }
sub set_text                { $_[0]->{_text} = $_[1] }
sub get_text                { return $_[0]->{_text} // '' }
sub override_color          { }
sub override_background_color { }
sub grab_focus              { }
sub set_position            { }
sub signal_connect          { }

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

package Gtk3::Label;
sub new          { return bless {}, shift }
sub set_text     { $_[0]->{_text} = $_[1] }
sub set_markup   { }
sub set_xalign   { }
sub override_color { }
sub set_margin_end { }
sub signal_connect { }

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

package Gtk3::EventBox;
sub new                    { return bless {}, shift }
sub override_background_color { }
sub add                    { }
sub signal_connect          { }

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

package Gtk3::CellRendererText;
sub new { return bless {}, shift }

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

package Gtk3::Clipboard;
sub new { return bless {}, shift }

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

package Gtk3::FileChooserDialog;
sub new { return bless {}, shift }

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

package Gtk3::TreeStore;
sub new { return bless {}, shift }

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

package Gtk3::TreeView;
sub new { return bless {}, shift }
sub signal_connect { }
sub get_selection { return bless {}, shift }
sub get_model { return bless {}, shift }

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

package Gtk3::TreeViewColumn;
sub new { return bless {}, shift }

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

package Gtk3::Gdk::RGBA;
sub new   { return bless { red => 0, green => 0, blue => 0, alpha => 1 }, shift }
sub red   { $_[0]->{red} }
sub green { $_[0]->{green} }
sub blue  { $_[0]->{blue} }
sub alpha { $_[0]->{alpha} }

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

package Gtk3::MessageDialog;
sub new             { return bless { _help => '' }, shift }
sub set_title       { }
sub set_default_size { }
sub get_message_area { return bless { _children => [] }, shift }
sub get_children     { return () }
sub run             { return 'ok' }
sub destroy         { }

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

# ==========================================================================
# Back to the main Gtk3 package for additional stubs
# ==========================================================================
package Gtk3;

# Pango context/layout stubs (when accessed via Gtk3 widgets)
sub get_font_description { return bless {}, __PACKAGE__ }
sub get_metrics          { return bless {}, __PACKAGE__ }
sub set_font_description { }
sub get_pixel_extents    { return (undef, { width => 8, height => 16 }) }

# Style context
sub get_color              { return bless { red => 0, green => 0, blue => 0 }, __PACKAGE__ }
sub get_background_color   { return bless { red => 1, green => 1, blue => 1 }, __PACKAGE__ }

# EventBox
sub set_above_child { }

# Window
sub set_resizable   { }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
# instead of dying with "Can't locate object method". This is the catch-all
# for the main Gtk3 package -- all sub-packages have their own AUTOLOAD above.
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

1;
