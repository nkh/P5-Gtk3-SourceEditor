package Gtk3::Gdk;
use strict;
use warnings;

# Stub for headless testing — provides Gdk namespace used by VimBindings.

sub keyval_name {
    my ($keyval) = @_;
    return '' unless defined $keyval;
    # Map common GDK keyvals to names for testing
    my %map = (
        65361 => 'Left',     # GDK_KEY_Left
        65363 => 'Right',    # GDK_KEY_Right
        65362 => 'Up',       # GDK_KEY_Up
        65364 => 'Down',     # GDK_KEY_Down
        65365 => 'Page_Up',  # GDK_KEY_Page_Up
        65366 => 'Page_Down',# GDK_KEY_Page_Down
        65307 => 'Escape',   # GDK_KEY_Escape
        65293 => 'Return',   # GDK_KEY_Return
        36    => 'Return',   # GDK_KEY_KP_Enter / some mappings
        65288 => 'BackSpace',# GDK_KEY_BackSpace
        36    => 'dollar',   # GDK_KEY_dollar
    );
    # If the caller passes a string directly (as in test stubs), return it
    return $keyval if $keyval !~ /^\d+$/;
    return $map{$keyval} // '';
}

sub RGBA {
    return bless {}, shift;
}

1;
