package Gtk3::SourceEditor::VimBindings::Completion;
use strict;
use warnings;
use File::Basename ();
use Cwd qw(abs_path getcwd);

our $VERSION = '0.01';

# ==========================================================================
# Constructor
# ==========================================================================
sub new {
    my ($class, %opts) = @_;
    return bless {
        show_hidden => $opts{show_hidden} // 0,
        cwd         => $opts{cwd} // getcwd(),
    }, $class;
}

# ==========================================================================
# complete($partial_path)
#
# Given a partial path (possibly empty, possibly with directory components),
# return a hashref:
#   { prefix => $common_prefix, candidates => \@list }
#
# - $common_prefix is the longest common prefix of all matches, relative to
#   the directory being completed.
# - @list is the full list of matching entries (not the prefix).
# - If there are no matches, candidates is [] and prefix equals the input
#   basename component.
# - If there is exactly one match, candidates has one element and prefix
#   equals that element (with trailing / for directories).
# - Entries ending in '/' are directories.
# ==========================================================================
sub complete {
    my ($self, $partial_path) = @_;

    $partial_path //= '';
    $partial_path =~ s/^\s+//;
    $partial_path =~ s/\s+$//;

    # Empty or whitespace-only input: list current directory
    if (!length $partial_path) {
        $partial_path = './';
    }

    my $dir;
    my $base;

    # Handle trailing slash: user wants directory listing
    if ($partial_path =~ m{(.+)/$}) {
        # Ends with /: treat the part before / as directory,
        # list all entries (base is empty = match all)
        $dir  = length($1) ? $1 : '/';
        $base = '';
    } elsif ($partial_path =~ m{(.*)/(.+)$}) {
        # Has directory component and a basename
        $dir  = length($1) ? $1 : '/';
        $base = $2;
    } else {
        $dir  = '.';
        $base = $partial_path;
    }

    # Resolve the directory
    $dir = $self->_resolve_dir($dir);
    return { prefix => $base, candidates => [] } unless defined $dir;

    my $entries = $self->_list_dir($dir);
    return { prefix => $base, candidates => [] } unless $entries && @$entries;

    # Filter entries that start with $base
    my $show_hidden = $self->{show_hidden};
    my @matches;
    for my $e (@$entries) {
        next if !$show_hidden && $e =~ /^\./ && $base !~ /^\./;
        next unless index($e, $base) == 0;
        push @matches, $e;
    }

    return { prefix => $base, candidates => [] } unless @matches;

    # Append '/' to directories
    my $abs_dir = abs_path($dir) // $dir;
    @matches = map {
        -d "$abs_dir/$_" ? "$_/" : $_
    } @matches;

    if (@matches == 1) {
        # Single match: prefix is the whole entry
        return { prefix => $matches[0], candidates => \@matches };
    }

    # Multiple matches: find longest common prefix
    my $lcp = $self->_longest_common_prefix(@matches);
    return { prefix => $lcp, candidates => \@matches };
}

# ==========================================================================
# _resolve_dir($dir)
#
# Resolve a directory path.  Returns absolute path string, or undef if
# the directory does not exist.
# ==========================================================================
sub _resolve_dir {
    my ($self, $dir) = @_;

    if (File::Spec->file_name_is_absolute($dir)) {
        return -d $dir ? $dir : undef;
    }

    my $abs = $self->{cwd} . '/' . $dir;
    $abs =~ s{/\./}{/}g;
    $abs =~ s{/+}{/}g;
    return -d $abs ? $abs : undef;
}

# ==========================================================================
# _list_dir($dir)
#
# List directory entries.  Returns arrayref of entry names (no path prefix),
# sorted alphabetically.  Returns [] on error.
# ==========================================================================
sub _list_dir {
    my ($self, $dir) = @_;
    opendir(my $dh, $dir) or return [];
    my @entries = sort readdir($dh);
    closedir($dh);
    # Remove . and ..
    @entries = grep { $_ ne '.' && $_ ne '..' } @entries;
    return \@entries;
}

# ==========================================================================
# _longest_common_prefix(@strings)
#
# Returns the longest common prefix of the given strings.
# ==========================================================================
sub _longest_common_prefix {
    my ($self, @strings) = @_;
    return '' unless @strings;

    my $first = $strings[0];
    my $max   = length($first);
    my $prefix = '';

    for my $i (0 .. $max - 1) {
        my $ch = substr($first, $i, 1);
        my $all_match = 1;
        for my $s (@strings[1 .. $#strings]) {
            if ($i >= length($s) || substr($s, $i, 1) ne $ch) {
                $all_match = 0;
                last;
            }
        }
        last unless $all_match;
        $prefix .= $ch;
    }
    return $prefix;
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::Completion - Path completion engine

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBindings::Completion;

    my $c = Gtk3::SourceEditor::VimBindings::Completion->new();
    my $result = $c->complete('lib/Gtk');
    # { prefix => 'Gtk3/', candidates => ['Gtk3/'] }

=head1 DESCRIPTION

Pure-Perl filename completion engine with no GTK dependency.  Given a
partial file path, returns the longest common prefix and a list of
matching candidates.  Designed for use with the command entry in a
Vim-like editor, but testable in isolation.

Hidden files (dotfiles) are excluded unless the partial path starts
with a dot or C<show_hidden> is set in the constructor.

=cut
