#!/usr/bin/env perl
# t/vim_completion.t - Tests for the Completion engine (pure Perl, no GTK)
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(getcwd);

use_ok('Gtk3::SourceEditor::VimBindings::Completion');

# ==========================================================================
# Setup: create a temp directory structure for testing
# ==========================================================================
my $tmpdir = tempdir(CLEANUP => 1);
my $cwd = getcwd();

# Create test directory tree:
#   $tmpdir/docs/
#   $tmpdir/docs/notes.txt
#   $tmpdir/docs/readme.md
#   $tmpdir/lib/
#   $tmpdir/lib/Foo.pm
#   $tmpdir/lib/Bar.pm
#   $tmpdir/lib/Baz/
#   $tmpdir/lib/Baz/Qux.pm
#   $tmpdir/.hidden
#   $tmpdir/.config/
#   $tmpdir/.config/settings.rc

make_path("$tmpdir/docs");
make_path("$tmpdir/lib/Baz");
make_path("$tmpdir/.config");

for my $f (
    "$tmpdir/docs/notes.txt",
    "$tmpdir/docs/readme.md",
    "$tmpdir/lib/Foo.pm",
    "$tmpdir/lib/Bar.pm",
    "$tmpdir/lib/Baz/Qux.pm",
    "$tmpdir/.hidden",
    "$tmpdir/.config/settings.rc",
) {
    open my $fh, '>', $f or die "Cannot create $f: $!";
    print $fh "test\n";
    close $fh;
}

my $c = Gtk3::SourceEditor::VimBindings::Completion->new(cwd => $tmpdir);

# ==========================================================================
# Test: empty input
# ==========================================================================
subtest 'empty input lists cwd' => sub {
    my $r = $c->complete('');
    ok(scalar @{$r->{candidates}} > 0, 'has candidates from cwd');
    is($r->{prefix}, '', 'prefix is empty (all entries match)');
};

subtest 'undef input' => sub {
    my $r = $c->complete(undef);
    ok(scalar @{$r->{candidates}} > 0, 'undef treated like empty, lists cwd');
};

# ==========================================================================
# Test: single directory match
# ==========================================================================
subtest 'single directory match' => sub {
    my $r = $c->complete('doc');
    is($r->{prefix}, 'docs/', 'prefix includes trailing slash');
    is_deeply($r->{candidates}, ['docs/'], 'one candidate');
};

# ==========================================================================
# Test: multiple matches in a directory
# ==========================================================================
subtest 'multiple matches - docs/' => sub {
    my $r = $c->complete('docs/');
    is($r->{prefix}, '', 'no common prefix beyond empty');
    is(scalar @{$r->{candidates}}, 2, 'two candidates');
    is($r->{candidates}[0], 'notes.txt', 'first candidate');
    is($r->{candidates}[1], 'readme.md', 'second candidate');
};

# ==========================================================================
# Test: partial match with common prefix
# ==========================================================================
subtest 'partial match - single result completes fully' => sub {
    my $r = $c->complete('docs/r');
    is($r->{prefix}, 'readme.md', 'single match completes fully');
    is_deeply($r->{candidates}, ['readme.md'], 'only readme matches');
};

# ==========================================================================
# Test: no matches
# ==========================================================================
subtest 'no matches' => sub {
    my $r = $c->complete('xyz');
    is($r->{prefix}, 'xyz', 'prefix is the input');
    is_deeply($r->{candidates}, [], 'no candidates');
};

# ==========================================================================
# Test: lib/ with partial
# ==========================================================================
subtest 'lib/ partial match' => sub {
    my $r = $c->complete('lib/B');
    is($r->{prefix}, 'Ba', 'common prefix is Ba');
    is(scalar @{$r->{candidates}}, 2, 'two candidates: Bar.pm and Baz/');
    is($r->{candidates}[0], 'Bar.pm', 'Bar.pm');
    is($r->{candidates}[1], 'Baz/', 'Baz/');
};

# ==========================================================================
# Test: nested directory
# ==========================================================================
subtest 'nested directory' => sub {
    my $r = $c->complete('lib/Baz/');
    is($r->{prefix}, 'Qux.pm', 'completes to Qux.pm');
    is_deeply($r->{candidates}, ['Qux.pm'], 'single file');
};

# ==========================================================================
# Test: hidden files excluded by default
# ==========================================================================
subtest 'hidden files excluded by default' => sub {
    my $r = $c->complete('');
    # .hidden and .config should not appear
    my @names = @{$r->{candidates}};
    ok(!grep { $_ eq '.hidden' } @names, '.hidden not in candidates');
    ok(!grep { $_ eq '.config/' } @names, '.config/ not in candidates');
    ok(grep { $_ eq 'docs/' } @names, 'docs/ is in candidates');
    ok(grep { $_ eq 'lib/' } @names, 'lib/ is in candidates');
};

# ==========================================================================
# Test: hidden files shown when partial starts with dot
# ==========================================================================
subtest 'hidden files shown when leading dot' => sub {
    my $r = $c->complete('.');
    my @names = @{$r->{candidates}};
    ok(scalar @names > 0, 'has candidates');
    ok(grep { $_ eq '.hidden' } @names, '.hidden visible with dot prefix');
    ok(grep { $_ eq '.config/' } @names, '.config/ visible with dot prefix');
};

# ==========================================================================
# Test: show_hidden option
# ==========================================================================
subtest 'show_hidden option' => sub {
    my $c2 = Gtk3::SourceEditor::VimBindings::Completion->new(
        cwd => $tmpdir,
        show_hidden => 1,
    );
    my $r = $c2->complete('');
    my @names = @{$r->{candidates}};
    ok(grep { $_ eq '.hidden' } @names, '.hidden visible with show_hidden');
    ok(grep { $_ eq '.config/' } @names, '.config/ visible with show_hidden');
};

# ==========================================================================
# Test: absolute path
# ==========================================================================
subtest 'absolute path' => sub {
    my $r = $c->complete("$tmpdir/lib/");
    is(scalar @{$r->{candidates}}, 3, 'three entries in lib/');
    # Baz should have trailing /
    ok(grep { $_ eq 'Baz/' } @{$r->{candidates}}, 'Baz/ has trailing slash');
    ok(grep { $_ eq 'Foo.pm' } @{$r->{candidates}}, 'Foo.pm present');
};

# ==========================================================================
# Test: non-existent directory
# ==========================================================================
subtest 'non-existent directory' => sub {
    my $r = $c->complete('nonexistent/foo');
    is($r->{prefix}, 'foo', 'prefix is the basename');
    is_deeply($r->{candidates}, [], 'no candidates');
};

# ==========================================================================
# Test: directory with trailing slash (list contents)
# ==========================================================================
subtest 'directory with trailing slash' => sub {
    my $r = $c->complete('docs/');
    ok(scalar @{$r->{candidates}} >= 2, 'lists directory contents');
};

# ==========================================================================
# Test: longest_common_prefix helper
# ==========================================================================
subtest 'longest_common_prefix' => sub {
    is($c->_longest_common_prefix('abc', 'abd'), 'ab');
    is($c->_longest_common_prefix('hello', 'hello'), 'hello');
    is($c->_longest_common_prefix('foo', 'bar'), '');
    is($c->_longest_common_prefix('test'), 'test');
    is($c->_longest_common_prefix('a', 'ab', 'ac'), 'a');
    is($c->_longest_common_prefix(), '');
};

# ==========================================================================
# Test: whitespace handling
# ==========================================================================
subtest 'whitespace handling' => sub {
    my $r = $c->complete('  docs/  ');
    # Should strip whitespace
    is(scalar @{$r->{candidates}}, 2, 'whitespace stripped, two candidates');
};

done_testing;
