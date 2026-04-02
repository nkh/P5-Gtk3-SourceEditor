#!/usr/bin/env perl
# extract-typelib-api.pl -- Extract Perl package::method mappings from a .typelib file
#
# Usage: perl extract-typelib-api.pl <typelib_path> <C_namespace> <Perl_prefix>
#   typelib_path:  Path to the .typelib binary file
#   C_namespace:   C namespace prefix (e.g., "GtkSource", "Gtk", "Pango")
#   Perl_prefix:   Perl package prefix (e.g., "Gtk3::SourceView", "Gtk3", "Pango")
#
# Output: JSON object mapping Perl class names to arrays of method names.
#
# Example:
#   perl extract-typelib-api.pl GtkSource-3.0.typelib GtkSource Gtk3::SourceView

use strict;
use warnings;

if (@ARGV < 3) {
    die "Usage: $0 <typelib_path> <C_namespace> <Perl_prefix>\n";
}

my ($typelib_path, $c_ns, $perl_prefix) = @ARGV;

# Read typelib binary
open my $fh, '<:raw', $typelib_path
    or die "Cannot read '$typelib_path': $!\n";
local $/;
my $data = <$fh>;
close $fh;

# Extract all printable ASCII strings >= 4 chars
my @strings;
while ($data =~ /([\x20-\x7e]{4,})/g) {
    push @strings, $1;
}

# Find class names (CamelCase strings matching the C namespace prefix)
my %classes;
for my $s (@strings) {
    if ($s =~ /^\Q$c_ns\E([A-Z][A-Za-z0-9]+)$/) {
        $classes{$1} = 1;
    }
}

# Convert CamelCase to snake_case for C function prefix matching
sub camel_to_snake {
    my $name = shift;
    $name =~ s/([a-z0-9])([A-Z])/$1_$2/g;
    return lc($name);
}

# For each class, find all methods in the typelib
my %api;
for my $class (sort keys %classes) {
    my $c_prefix = lc($c_ns) . '_' . camel_to_snake($class) . '_';
    my $perl_class = $perl_prefix . '::' . $class;
    my %methods;

    for my $s (@strings) {
        if ($s =~ /^\Q$c_prefix\E([a-z]\w*)$/) {
            my $method = $1;
            next if $method eq 'get_type';  # universal, skip noise
            $methods{$method} = 1;
        }
    }

    $api{$perl_class} = [sort keys %methods] if %methods;
}

# Output JSON
use JSON::PP;
print encode_json(\%api), "\n";
