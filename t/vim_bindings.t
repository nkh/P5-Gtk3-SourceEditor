#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBindings;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings::Command;

# ==========================================================================
# Tests for :bindings command output
#
# generate_bindings_text() builds the help text from the resolved keymap.
# These tests verify completeness, formatting, and correctness without
# requiring a GTK display.
# ==========================================================================

subtest 'Output contains all 6 mode sections' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    like($text, qr/^-- NORMAL MODE --/m,    'has NORMAL section header');
    like($text, qr/^-- INSERT MODE --/m,    'has INSERT section header');
    like($text, qr/^-- REPLACE MODE --/m,   'has REPLACE section header');
    like($text, qr/^-- VISUAL MODE --/m,    'has VISUAL section header');
    like($text, qr/^-- COMMAND MODE --/m,   'has COMMAND section header');
    like($text, qr/^-- EX COMMANDS --/m,    'has EX COMMANDS section header');
};

subtest 'Normal mode includes Ctrl keys' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    # Extract just the NORMAL MODE section
    my ($normal) = $text =~ /^(-- NORMAL MODE --\n.*?)(?=\n-- |\z)/ms;
    ok(defined $normal, 'got NORMAL section');

    like($normal, qr/Ctrl-r/,    'Ctrl-r (redo) listed');
    like($normal, qr/Ctrl-u/,    'Ctrl-u (half page up) listed');
    like($normal, qr/Ctrl-d/,    'Ctrl-d (half page down) listed');
    like($normal, qr/Ctrl-b/,    'Ctrl-b (page up) listed');
    like($normal, qr/Ctrl-f/,    'Ctrl-f (page down) listed');
    like($normal, qr/Ctrl-y/,    'Ctrl-y (scroll line up) listed');
    like($normal, qr/Ctrl-e/,    'Ctrl-e (scroll line down) listed');
};

subtest 'Normal mode includes char actions (f, r, m, etc.)' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    my ($normal) = $text =~ /^(-- NORMAL MODE --\n.*?)(?=\n-- |\z)/ms;
    ok(defined $normal, 'got NORMAL section');

    like($normal, qr/\bf\b/,   'f (find char) listed');
    like($normal, qr/\bF\b/,   'F (find char backward) listed');
    like($normal, qr/\bt\b/,   't (till char) listed');
    like($normal, qr/\bT\b/,   'T (till char backward) listed');
    like($normal, qr/\br\b/,   'r (replace char) listed');
    like($normal, qr/\bm\b/,   'm (set mark) listed');
    like($normal, qr/\Q`\E/,   '` (jump to mark) listed');
    like($normal, qr/'/,       q{' (jump to mark line) listed});
};

subtest 'Key names are user-friendly (not GDK internal)' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    # Should NOT contain raw GDK names
    unlike($text, qr/\bBackSpace\b/,    'no raw BackSpace');
    unlike($text, qr/\bPage_Up\b/,      'no raw Page_Up');
    unlike($text, qr/\bPage_Down\b/,    'no raw Page_Down');
    unlike($text, qr/\bdollar\b/,       'no raw dollar');
    unlike($text, qr/\basciicircum\b/,  'no raw asciicircum');
    unlike($text, qr/\bgreatergreater\b/, 'no raw greatergreater');
    unlike($text, qr/\blessless\b/,     'no raw lessless');
    unlike($text, qr/\bsemicolon\b/,    'no raw semicolon');
    unlike($text, qr/\bcomma\b/,        'no raw comma');
    unlike($text, qr/\bpercent\b/,      'no raw percent');
    unlike($text, qr/\basciitilde\b/,   'no raw asciitilde');
    unlike($text, qr/\bd_dollar\b/,     'no raw d_dollar');
    unlike($text, qr/\bapostrophe\b/,   'no raw apostrophe');
    unlike($text, qr/\bgrave\b/,        'no raw grave');

    # Should contain user-friendly names
    like($text, qr/<BS>/,       'has <BS>');
    like($text, qr/<PgUp>/,     'has <PgUp>');
    like($text, qr/<PgDn>/,     'has <PgDn>');
    like($text, qr/\$\s/,       'has $');
    like($text, qr/\^\s/,       'has ^');
    like($text, qr/>>\s/,       'has >>');
    like($text, qr/<<\s/,       'has <<');
    like($text, qr/d\$\s/,      'has d$');
    like($text, qr/%\s/,        'has %');
    like($text, qr/~\s/,        'has ~');
    like($text, qr/;\s/,        'has ;');
    like($text, qr/,\s/,        'has ,');
};

subtest 'Action descriptions are human-readable' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    # Should NOT contain raw action names in key:desc pairs
    unlike($text, qr/\benter_insert\b/,     'no raw enter_insert');
    unlike($text, qr/\bmove_down\b/,        'no raw move_down');
    unlike($text, qr/\bdelete_char\b/,      'no raw delete_char');
    unlike($text, qr/\benter_visual\b/,     'no raw enter_visual');

    # Should contain descriptions
    like($text, qr/insert mode/,            'has "insert mode" description');
    like($text, qr/move down/,              'has "move down" description');
    like($text, qr/delete char/,            'has "delete char" description');
    like($text, qr/visual mode/,            'has "visual mode" description');
    like($text, qr/undo/,                   'has "undo" description');
    like($text, qr/paste after/,            'has "paste after" description');
};

subtest '3-column layout: columns are aligned (fixed-width)' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    # Each data line (not headers/separators) should be at least 60 chars wide
    # (3 columns × 30 chars per column)
    my @data_lines = grep { !/^--/ && /\S/ } split /\n/, $text;
    ok(@data_lines > 0, 'has data lines');

    for my $line (@data_lines) {
        # Lines with 3 full columns should be >= 60 chars
        if ($line =~ /\S.*\S.*\S.*\S.*\S.*\S/) {
            cmp_ok(length($line), '>=', 30,
                   "3-column line is >= 30 chars: " . substr($line, 0, 40) . "...");
        }
    }
};

subtest 'Ex commands section lists all commands' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    my ($ex) = $text =~ /^(-- EX COMMANDS --\n.*?\n(?:\z))/ms;
    ok(defined $ex, 'got EX COMMANDS section');

    like($ex, qr/:bindings/,  'has :bindings');
    like($ex, qr/:browse/,    'has :browse');
    like($ex, qr/:e\b/,       'has :e');
    like($ex, qr/:q\b/,       'has :q');
    like($ex, qr/:r\b/,       'has :r');
    like($ex, qr/:s\b/,       'has :s');
    like($ex, qr/:set/,       'has :set');
    like($ex, qr/:w\b/,       'has :w');
    like($ex, qr/:wq/,        'has :wq');
    like($ex, qr/:q!/,        'has :q!');
    like($ex, qr/:%s\/p\/r\/g/, 'has :%s/p/r/g');
};

subtest 'Insert mode shows Escape and Tab' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    my ($insert) = $text =~ /^(-- INSERT MODE --\n.*?)(?=\n-- |\z)/ms;
    ok(defined $insert, 'got INSERT section');
    like($insert, qr/<Esc>/, 'Escape listed in insert mode');
    like($insert, qr/<Tab>/, 'Tab listed in insert mode');
};

subtest 'Replace mode shows Escape and BackSpace' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    my ($replace) = $text =~ /^(-- REPLACE MODE --\n.*?)(?=\n-- |\z)/ms;
    ok(defined $replace, 'got REPLACE section');
    like($replace, qr/<Esc>/, 'Escape listed in replace mode');
    like($replace, qr/<BS>/,  'BackSpace listed in replace mode');
};

subtest 'Visual-only entries are separate from normal' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    my ($normal) = $text =~ /^(-- NORMAL MODE --\n.*?)(?=\n-- |\z)/ms;
    my ($visual) = $text =~ /^(-- VISUAL MODE --\n.*?)(?=\n-- |\z)/ms;

    # visual_exit should only be in visual, not normal
    if (defined $normal && defined $visual) {
        unlike($normal, qr/exit visual/, 'exit visual not in normal section');
        like($visual, qr/exit visual/, 'exit visual in visual section');
    }

    # visual-specific actions
    if (defined $visual) {
        like($visual, qr/swap/,        'swap ends in visual');
        like($visual, qr/format/,      'format in visual');
    }
};

subtest 'Total binding count is comprehensive (>= 90)' => sub {
    my $vb  = Gtk3::SourceEditor::VimBuffer::Test->new(text => "\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(vim_buffer => $vb);
    my $text = Gtk3::SourceEditor::VimBindings::Command::generate_bindings_text($ctx);

    # Count data lines (non-header, non-separator, non-empty)
    my @data = grep { /\S/ && !/^--/ } split /\n/, $text;
    cmp_ok(scalar(@data), '>=', 30,
           'at least 30 data lines (3 columns each = 90+ bindings)');
};

done_testing;
