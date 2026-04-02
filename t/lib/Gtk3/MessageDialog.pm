package Gtk3::MessageDialog;
use strict;
use warnings;

# Stub for headless testing — the :bindings command opens a help dialog.

sub new {
    my ($class, @args) = @_;
    return bless { _help => '' }, $class;
}

sub set_title       { }
sub set_default_size { }
sub get_message_area { return bless { _children => [] }, __PACKAGE__ }
sub get_children     { return () }
sub run             { return 'ok' }
sub destroy         { }

1;
