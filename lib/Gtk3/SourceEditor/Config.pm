package Gtk3::SourceEditor::Config;
use strict;
use warnings;
use Exporter 'import';

our $VERSION = '0.04';
our @EXPORT_OK = qw(parse_editor_config parse_editor_config_string);

# =============================================================================
# parse_editor_config_string($string)
#
# Parse a configuration string and return a hashref of key => value pairs.
#
#   - Lines starting with '#' are treated as comments and skipped.
#   - Blank lines are skipped.
#   - Format:  key = value
#   - Leading/trailing whitespace around the key and value is trimmed.
#   - Values enclosed in double quotes are unquoted (outer quotes stripped,
#     inner content preserved verbatim, including embedded spaces).
#   - Boolean-ish values (true/false/yes/no/1/0, case-insensitive) are
#     converted to Perl booleans (1 or 0).
#   - Values that look like integers are converted to numbers.
#   - All keys are lowercased.
#   - Unknown keys are accepted silently (no warnings).
#
# Returns: hashref
# =============================================================================
sub parse_editor_config_string {
    my ($string) = @_;
    return {} unless defined $string && length $string;

    my %config;
    for my $line (split /\n/, $string) {

        # Strip trailing whitespace / carriage-return
        $line =~ s/\s+$//;

        # Skip blank lines and comments
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*#/;

        # Extract key = value  (first '=' is the separator)
        if ($line =~ /^\s*([^=]+?)\s*=\s*(.*)$/) {
            my $key   = lc($1);
            my $value = $2;

            # Trim trailing comment (only if not inside quotes)
            unless ($value =~ /^"/ && $value =~ /[^\\]"$/) {
                $value =~ s/\s+#.*$//;
            }

            # Trim leading/trailing whitespace
            $value =~ s/^\s+//;
            $value =~ s/\s+$//;

            # Handle double-quoted values
            if ($value =~ /^"(.*)"$/s) {
                $value = $1;
            }

            # Convert booleans
            if ($value =~ /^(true|yes|1)$/i) {
                $value = 1;
            }
            elsif ($value =~ /^(false|no|0)$/i) {
                $value = 0;
            }

            # Convert plain integers to numbers (leave floats / other strings alone)
            if ($value =~ /^-?\d+$/) {
                $value = int($value);
            }

            $config{$key} = $value;
        }
        # Lines without '=' are silently ignored
    }

    return \%config;
}

# =============================================================================
# parse_editor_config($file_path)
#
# Read a configuration file from disk and parse it.  Dies if the file cannot
# be opened for reading.
#
#   $file_path  — absolute or relative path to the config file
#
# Returns: hashref (same format as parse_editor_config_string)
# =============================================================================
sub parse_editor_config {
    my ($file_path) = @_;
    die "Gtk3::SourceEditor::Config: file path is required\n"
        unless defined $file_path && length $file_path;

    open my $fh, '<', $file_path
        or die "Gtk3::SourceEditor::Config: cannot open '$file_path': $!\n";

    my $content = do { local $/; <$fh> };
    close $fh;

    return parse_editor_config_string($content);
}

1;

__END__

=encoding UTF-8

=head1 NAME

Gtk3::SourceEditor::Config - Parse editor configuration files

=head1 SYNOPSIS

    use Gtk3::SourceEditor::Config qw(parse_editor_config parse_editor_config_string);

    # From a file
    my $cfg = parse_editor_config('editor.conf');

    # From a string
    my $cfg = parse_editor_config_string(<<'CONF');
        theme = dark
        font_size = 14
        vim_mode = true
    CONF

    print $cfg->{theme};        # "dark"
    print $cfg->{font_size};    # 14  (numeric)
    print $cfg->{vim_mode};     # 1   (Perl boolean)

=head1 DESCRIPTION

Parses simple C<key = value> configuration files with C<#> comments, blank
lines, quoted values, automatic boolean conversion, and automatic integer
conversion.  All keys are lowercased.  Unknown keys are silently accepted.

=head1 EXPORTED FUNCTIONS

=head2 parse_editor_config($file_path)

Reads a configuration file from disk and returns a hashref.  Dies if the
file cannot be opened.

=head2 parse_editor_config_string($string)

Parses a configuration string and returns a hashref.  Returns an empty
hashref for C<undef> or empty strings.

=head1 CONFIG FORMAT

    # This is a comment
    key = value
    quoted = "value with spaces"
    flag  = true
    number = 42

Boolean values (C<true/false>, C<yes/no>, C<1/0>) are case-insensitive and
converted to Perl booleans.  Integer values are converted to numbers.

=head1 AUTHOR

See L<Gtk3::SourceEditor>.

=head1 LICENSE

Artistic License 2.0.

=cut
