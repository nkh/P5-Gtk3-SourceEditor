# Strict mock for Gtk3::SourceView - only accepts known methods.
# Used by t/00-smoke-mock.t to catch calls to non-existent GTK methods.

package Gtk3::SourceView;
use strict;
use warnings;

sub new { return bless {}, shift }

# ==========================================================================
# Strict base class: AUTOLOAD dies on unknown methods
# ==========================================================================
{
    my %unknown_calls;
    my %allowed;

    %allowed = (
        'Gtk3::SourceView' => { new => 1 },
    );

    sub _allow {
        my ($class, %methods) = @_;
        for my $m (keys %methods) {
            $allowed{$class}{$m} = $methods{$m};
            no strict 'refs';
            *{"${class}::$m"} = $methods{$m};
        }
        *{"${class}::DESTROY"} = sub { } unless defined &{"${class}::DESTROY"};
    }

    sub _get_unknown { return \%unknown_calls }

    sub _reset_unknown { %unknown_calls = () }
}

# --- Gtk3::SourceView::Buffer ---
package Gtk3::SourceView::Buffer;
use strict;
use warnings;

Gtk3::SourceView::_allow(__PACKAGE__,
    new              => sub { return bless {}, shift },
    new_with_language => sub { return bless {}, shift },
    set_highlight_syntax => sub { },
    set_text          => sub { $_[0]->{_text} = $_[1] },
    get_text          => sub { return $_[0]->{_text} // '' },
    place_cursor      => sub { },
    set_modified      => sub { },
    get_modified      => sub { return 0 },
    set_style_scheme  => sub { },
    get_style_scheme  => sub { return undef },
    get_start_iter    => sub { return bless {}, 'Gtk3::SourceView::Buffer::Iter' },
    get_end_iter      => sub { return bless {}, 'Gtk3::SourceView::Buffer::Iter' },
    get_insert        => sub { return bless { _name => 'insert' }, 'Gtk3::SourceView::Buffer::Mark' },
    get_iter_at_mark  => sub { return bless {}, 'Gtk3::SourceView::Buffer::Iter' },
    get_line_count    => sub { return 1 },
    signal_connect    => sub { },
    select_range      => sub { },
    get_tag_table     => sub { return bless {}, 'Gtk3::SourceView::Buffer::TagTable' },
    begin_user_action => sub { },
    end_user_action   => sub { },
    get_tags          => sub { return () },
    delete            => sub { },
    insert            => sub { },
);

sub DESTROY { }

sub AUTOLOAD {
    my $method = our $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    return if Gtk3::SourceView::_allow('Gtk3::SourceView::Buffer', $method);
    $Gtk3::SourceView::unknown_calls{'Gtk3::SourceView::Buffer'}{$method} = 1;
    return bless {}, __PACKAGE__;
}

sub can {
    my ($obj, $method) = @_;
    my %allowed = %{Gtk3::SourceView::_allow('Gtk3::SourceView::Buffer')};
    # Check if method is in the allowed hash
    no strict 'refs';
    return defined &{"Gtk3::SourceView::Buffer::$method"};
}

# --- Gtk3::SourceView::Buffer::Iter ---
package Gtk3::SourceView::Buffer::Iter;
use strict;
use warnings;

sub new   { return bless {}, shift }
sub copy  { return bless {}, shift }
sub get_line        { return 0 }
sub get_line_offset { return 0 }
sub get_char        { return '' }
sub is_end          { return 0 }
sub get_text        { return '' }
sub get_name        { return '' }
sub ends_line       { return 0 }
sub starts_line     { return 0 }
sub forward_char    { }
sub forward_line    { }
sub forward_to_line_end { }
sub backward_char   { }
sub forward_word_end { }
sub backward_word_start { }
sub forward_search  { return (0, undef, undef) }
sub backward_search { return (0, undef, undef) }
sub forward_chars   { }
sub get_line_index  { return 0 }
sub get_chars_in_line { return 0 }
sub DESTROY { }

# --- Gtk3::SourceView::Buffer::Mark ---
package Gtk3::SourceView::Buffer::Mark;
use strict;
use warnings;

sub new      { return bless {}, shift }
sub get_name { return $_[0]->{_name} // '' }
sub DESTROY  { }

# --- Gtk3::SourceView::Buffer::TagTable ---
package Gtk3::SourceView::Buffer::TagTable;
use strict;
use warnings;

sub new     { return bless {}, shift }
sub foreach { }
sub DESTROY { }

# --- Gtk3::SourceView::View ---
package Gtk3::SourceView::View;
use strict;
use warnings;

Gtk3::SourceView::_allow(__PACKAGE__,
    new                             => sub { return bless {}, shift },
    new_with_buffer                 => sub { return bless {}, shift },
    set_buffer                      => sub { },
    set_show_line_numbers           => sub { },
    set_highlight_current_line      => sub { },
    set_auto_indent                 => sub { },
    set_wrap_mode                   => sub { },
    set_cursor_visible              => sub { },
    modify_font                     => sub { },
    set_tab_width                   => sub { },
    set_insert_spaces_instead_of_tabs => sub { },
    signal_connect                  => sub { },
    signal_connect_after            => sub { },
    set_indent_width                => sub { },
    set_show_right_margin           => sub { },
    set_right_margin_position       => sub { },
    set_smart_home_end              => sub { },
    set_highlight_matching_brackets => sub { },
    set_show_line_marks             => sub { },
    set_editable                    => sub { },
    get_buffer                      => sub { return bless {}, 'Gtk3::SourceView::Buffer' },
    get_insert                      => sub { return bless {}, 'Gtk3::SourceView::Buffer::Mark' },
    get_visible_rect                => sub { return { height => 400, width => 800, x => 0, y => 0 } },
    scroll_to_mark                  => sub { },
    scroll_to_iter                  => sub { },
    get_iter_location               => sub { return { x => 0, y => 0, width => 8, height => 16 } },
    get_iter_at_location            => sub { return bless {}, 'Gtk3::SourceView::Buffer::Iter' },
    buffer_to_window_coords         => sub { return (0, 0) },
    get_pango_context               => sub { return bless {}, 'Gtk3::SourceView::View::PangoCtx' },
    create_pango_layout             => sub { return bless {}, 'Gtk3::SourceView::View::Layout' },
    get_style_context               => sub { return bless {}, 'Gtk3::SourceView::View::StyleCtx' },
    queue_draw                      => sub { },
    grab_focus                      => sub { },
    get_name                        => sub { return 'mock-view' },
);

sub DESTROY { }

sub AUTOLOAD {
    my $method = our $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    no strict 'refs';
    return if defined &{"Gtk3::SourceView::View::$method"};
    $Gtk3::SourceView::unknown_calls{'Gtk3::SourceView::View'}{$method} = 1;
    return bless {}, __PACKAGE__;
}

sub can {
    my ($obj, $method) = @_;
    no strict 'refs';
    return 1 if defined &{"Gtk3::SourceView::View::$method"};
    return 0;
}

# --- Pango context/layout stubs ---
package Gtk3::SourceView::View::PangoCtx;
sub get_font_description { return bless {}, 'Gtk3::SourceView::View::FontDesc' }
sub get_metrics { return bless {}, 'Gtk3::SourceView::View::Metrics' }
sub DESTROY { }

package Gtk3::SourceView::View::Metrics;
sub get_ascent  { return 1024 * 16 }
sub get_descent { return 1024 * 4 }
sub DESTROY { }

package Gtk3::SourceView::View::FontDesc;
sub to_string { return 'Monospace 12' }
sub DESTROY { }

package Gtk3::SourceView::View::Layout;
sub set_font_description { }
sub get_pixel_extents    { return (undef, { width => 8, height => 16 }) }
sub DESTROY { }

package Gtk3::SourceView::View::StyleCtx;
sub get_color              { return bless { red => 0, green => 0, blue => 0 }, 'Gtk3::Gdk::RGBA' }
sub get_background_color   { return bless { red => 1, green => 1, blue => 1 }, 'Gtk3::Gdk::RGBA' }
sub DESTROY { }

# --- Gtk3::SourceView::LanguageManager ---
package Gtk3::SourceView::LanguageManager;
use strict;
use warnings;

sub get_default   { return bless {}, shift }
sub get_language  { return undef }
sub guess_language { return undef }
sub DESTROY { }

# --- Gtk3::SourceView::StyleSchemeManager ---
package Gtk3::SourceView::StyleSchemeManager;
use strict;
use warnings;

sub get_default         { return bless {}, shift }
sub prepend_search_path { }
sub get_scheme          { return bless {}, 'Gtk3::SourceView::StyleScheme' }
sub DESTROY { }

# --- Gtk3::SourceView::StyleScheme ---
package Gtk3::SourceView::StyleScheme;
use strict;
use warnings;

sub get_name        { return 'mock-scheme' }
sub get_id          { return 'mock-scheme' }
sub get_description { return '' }
sub get_style       { return undef }
sub DESTROY { }

1;
