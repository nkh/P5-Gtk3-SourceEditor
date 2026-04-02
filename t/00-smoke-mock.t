#!/usr/bin/perl
# t/00-smoke-mock.t - Smoke test for SourceEditor using STRICT mocks.
#
# This test creates a mock environment where each GTK class only accepts
# method calls that are known to exist in the real GtkSourceView 3.x API.
# Unknown method calls cause the test to FAIL.
#
# Run with:  perl -Ilib -It/lib t/00-smoke-mock.t
#
# This catches "Can't locate object method" errors that would otherwise
# only surface on a system with real GTK libraries installed.

use strict;
use warnings;
use Test::More;

# ==========================================================================
# IMPORTANT: Add mock_strict BEFORE lib in @INC so strict mocks shadow
# the real Gtk3::SourceView when it's not installed, and shadow the
# permissive t/lib mocks.
# ==========================================================================
use lib "/home/z/my-project/src/lib";          # The actual library modules
use lib "/home/z/my-project/src/t/mock_strict"; # Strict Gtk3::SourceView mock
use lib "/home/z/my-project/src/t/lib";         # Gtk3.pm, Glib.pm mocks

# ==========================================================================
# Now load the actual modules under test
# ==========================================================================

use_ok('Gtk3::SourceEditor::ThemeManager');
use_ok('Gtk3::SourceEditor::Config', 'parse_editor_config');
use_ok('Gtk3::SourceEditor::VimBuffer');
use_ok('Gtk3::SourceEditor::VimBuffer::Test');

# ==========================================================================
# Test 1: ThemeManager::load
# ==========================================================================
my $theme_dir = "/home/z/my-project/src/themes";
SKIP: {
    skip "themes directory not found", 3 unless -d $theme_dir;
    my $theme_file;
    for my $f (qw(theme_dark.xml default.xml theme_light.xml theme_solarized.xml)) {
        if (-f "$theme_dir/$f") { $theme_file = "$theme_dir/$f"; last; }
    }
    skip "No theme files found", 3 unless $theme_file;

    my $data = Gtk3::SourceEditor::ThemeManager::load(file => $theme_file);
    ok(defined $data, 'ThemeManager::load returns data');
    is(ref($data), 'HASH', 'ThemeManager::load returns hashref');
    like($data->{fg}, qr/^#[0-9a-fA-F]{6}$/, 'fg is hex color');
    like($data->{bg}, qr/^#[0-9a-fA-F]{6}$/, 'bg is hex color');
}

# ==========================================================================
# Test 2: VimBuffer::Test basic operations
# ==========================================================================
my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
ok(defined $vb, 'VimBuffer::Test->new works');
is($vb->text, "hello world\n", 'VimBuffer::Test text access works');
is($vb->line_count, 2, 'line_count is 2');
is($vb->cursor_line, 0, 'cursor starts at line 0');
is($vb->cursor_col, 0, 'cursor starts at col 0');

$vb->set_cursor(0, 5);
is($vb->cursor_col, 5, 'set_cursor works');

is($vb->line_text(0), "hello world", 'line_text works');
is($vb->line_length(0), 11, 'line_length works');

# ==========================================================================
# Test 3: VimBuffer::Test editing operations
# ==========================================================================
$vb->insert_text("INSERTED");
is($vb->line_text(0), "helloINSERTED world", 'insert_text works');

$vb->set_cursor(0, 5);
$vb->delete_range(0, 5, 0, 13);
is($vb->line_text(0), "hello world", 'delete_range works');

# ==========================================================================
# Test 4: Config parsing
# ==========================================================================
my $tmp_conf = "/tmp/test_editor_$$\.conf";
END { unlink $tmp_conf if -f $tmp_conf }

open my $fh, '>', $tmp_conf or die "Cannot write $tmp_conf: $!";
print $fh "[editor]\ntheme = dark\nfont_size = 14\nwrap = 0\n";
close $fh;

my $cfg = parse_editor_config($tmp_conf);
ok(defined $cfg, 'parse_editor_config returns data');
is($cfg->{theme}, 'dark', 'config theme parsed');
is($cfg->{font_size}, 14, 'config font_size parsed');
is($cfg->{wrap}, 0, 'config wrap parsed');

# ==========================================================================
# Report any unknown method calls that were caught by strict mocks
# ==========================================================================
# The strict mock in Gtk3/SourceView.pm tracks unknown calls in
# $Gtk3::SourceView::unknown_calls
my $failures = 0;
{
    no strict 'refs';
    my $unknown = \%Gtk3::SourceView::unknown_calls;
    for my $class (sort keys %$unknown) {
        for my $method (sort keys %{$unknown->{$class}}) {
            diag("STRICT MOCK: unknown method '$method' called on $class");
            $failures++;
        }
    }
}

ok($failures == 0, "No unknown method calls on strict mocks") or
    diag("$failures unknown method call(s) detected - these may crash on real GTK");

done_testing;
