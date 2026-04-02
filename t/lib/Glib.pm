package Glib;
use strict;
use warnings;

# Stub for headless testing -- provides constants and sub-packages used
# by VimBuffer::Gtk3 and other modules that depend on the real Glib at runtime.

sub TRUE  { 1 }
sub FALSE { 0 }

sub import {
    my $class = shift;
    my $caller = caller;
    no strict 'refs';
    for my $sym (@_) {
        if ($sym eq 'TRUE' || $sym eq 'FALSE') {
            *{"${caller}::$sym"} = \&{$sym};
        }
    }
}

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
# instead of dying with "Can't locate object method". Handles timeout_add,
# idle_add, source_remove, and any other Glib functions called at runtime.
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
    # timeout_add / idle_add return a fake source ID
    return 0 if $method =~ /^(timeout_add|idle_add)$/;
    # source_remove and other void calls return empty
    return;
}
sub can { return 1 }

# Sub-packages used by the codebase
package Glib::Timeout;
use strict;
use warnings;

sub add { return 0 }

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

package Glib::Idle;
use strict;
use warnings;

sub add { return 0 }

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

package Glib::Source;
use strict;
use warnings;

sub remove { }

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
