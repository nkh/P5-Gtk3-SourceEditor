package Pango;
use strict;
use warnings;

# Stub for headless testing -- provides Pango namespace.

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

package Pango::FontDescription;
use strict;
use warnings;

sub new          { return bless {}, shift }
sub from_string  { return bless {}, shift }
sub set_family   { }
sub set_size     { }
sub to_string    { return 'Monospace 12' }

# AUTOLOAD fallback: defense-in-depth so mock objects accept ANY method call
# instead of dying with "Can't locate object method".
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

package Pango::Cairo;
use strict;
use warnings;

sub show_layout { }

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
