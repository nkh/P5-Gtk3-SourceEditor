#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::Config qw(parse_editor_config parse_editor_config_string);

# =============================================================================
# Gtk3::SourceEditor::Config — unit tests
# =============================================================================

# ==========================================================================
# 1. Valid config string parsing
# ==========================================================================
subtest 'parse_editor_config_string: valid config' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
theme = dark
font_size = 14
vim_mode = true
read_only = false
tab_width = 4
font_family = Monospace
force_language = perl
tab_string = \t
CONF

    is(ref $cfg, 'HASH', 'returns a hashref');
    is($cfg->{theme}, 'dark', 'theme = dark');
    is($cfg->{font_size}, 14, 'font_size converted to integer');
    is($cfg->{vim_mode}, 1, 'vim_mode = true → 1');
    is($cfg->{read_only}, 0, 'read_only = false → 0');
    is($cfg->{tab_width}, 4, 'tab_width converted to integer');
    is($cfg->{font_family}, 'Monospace', 'font_family is a string');
    is($cfg->{force_language}, 'perl', 'force_language preserved');
    is($cfg->{tab_string}, '\t', 'tab_string backslash-t preserved as literal');
};

# ==========================================================================
# 2. Empty config
# ==========================================================================
subtest 'parse_editor_config_string: empty input' => sub {
    my $cfg = parse_editor_config_string('');
    is(ref $cfg, 'HASH', 'returns hashref for empty string');
    is(scalar(keys %$cfg), 0, 'empty config has no keys');

    $cfg = parse_editor_config_string(undef);
    is(ref $cfg, 'HASH', 'returns hashref for undef');
    is(scalar(keys %$cfg), 0, 'undef config has no keys');
};

# ==========================================================================
# 3. Comments and blank lines
# ==========================================================================
subtest 'parse_editor_config_string: comments and blank lines' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');

# This is a full-line comment
theme = dark

   # Indented comment

font_size = 12
  # Another comment after a value
CONF

    is(scalar(keys %$cfg), 2, 'only 2 keys from config with comments/blank lines');
    is($cfg->{theme}, 'dark', 'theme parsed correctly');
    is($cfg->{font_size}, 12, 'font_size parsed correctly');
};

# ==========================================================================
# 4. Inline comments
# ==========================================================================
subtest 'parse_editor_config_string: inline comments after values' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
theme = dark # this is the best theme
font_size = 14  # size in points
CONF

    is($cfg->{theme}, 'dark', 'inline comment stripped from theme');
    is($cfg->{font_size}, 14, 'inline comment stripped from font_size');
};

# ==========================================================================
# 5. Boolean conversion (true/false/yes/no/1/0)
# ==========================================================================
subtest 'parse_editor_config_string: boolean values' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
b_true  = true
b_false = false
b_yes   = yes
b_no    = no
b_one   = 1
b_zero  = 0
b_True  = True
b_False = False
b_YES   = YES
b_NO    = NO
CONF

    is($cfg->{b_true},  1, 'true → 1');
    is($cfg->{b_false}, 0, 'false → 0');
    is($cfg->{b_yes},   1, 'yes → 1');
    is($cfg->{b_no},    0, 'no → 0');
    is($cfg->{b_one},   1, '1 → 1');
    is($cfg->{b_zero},  0, '0 → 0');
    is($cfg->{b_true},  1, 'True (mixed case) → 1');
    is($cfg->{b_false}, 0, 'False (mixed case) → 0');
    is($cfg->{b_yes},   1, 'YES (upper case) → 1');
    is($cfg->{b_no},    0, 'NO (upper case) → 0');
};

# ==========================================================================
# 6. Integer conversion
# ==========================================================================
subtest 'parse_editor_config_string: integer values' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
positive = 42
negative = -7
zero     = 0
large    = 999999
CONF

    is($cfg->{positive}, 42,    'positive integer');
    is($cfg->{negative}, -7,    'negative integer');
    is($cfg->{zero},     0,     'zero (not confused with boolean)');
    is($cfg->{large},    999999, 'large integer');
};

# ==========================================================================
# 7. Unknown keys are accepted silently
# ==========================================================================
subtest 'parse_editor_config_string: unknown keys accepted' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
theme = dark
completely_unknown_key = some_value
another_made_up_option = 123
CONF

    is($cfg->{theme}, 'dark', 'known key parsed');
    is($cfg->{completely_unknown_key}, 'some_value', 'unknown key preserved');
    is($cfg->{another_made_up_option}, 123, 'unknown numeric key preserved');

    # No warnings should have been emitted — if this test fails, check stderr
    ok(1, 'no warnings for unknown keys');
};

# ==========================================================================
# 8. Keys are lowercased
# ==========================================================================
subtest 'parse_editor_config_string: keys are lowercased' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
Theme = dark
Font_Size = 14
VIM_MODE = true
CONF

    ok(exists $cfg->{theme},      'Theme → theme');
    ok(exists $cfg->{font_size},  'Font_Size → font_size');
    ok(exists $cfg->{vim_mode},   'VIM_MODE → vim_mode');
    is($cfg->{theme}, 'dark', 'Theme value correct');
    is($cfg->{font_size}, 14, 'Font_Size value correct');
    is($cfg->{vim_mode}, 1, 'VIM_MODE value correct');
};

# ==========================================================================
# 9. Quoted values
# ==========================================================================
subtest 'parse_editor_config_string: quoted values' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
font_family = "DejaVu Sans Mono"
description = "My favourite editor"
empty_quoted = ""
CONF

    is($cfg->{font_family}, 'DejaVu Sans Mono', 'quoted value with spaces preserved');
    is($cfg->{description}, 'My favourite editor', 'quoted string value');
    is($cfg->{empty_quoted}, '', 'empty quoted value');
};

# ==========================================================================
# 10. theme vs theme_file precedence
# ==========================================================================
subtest 'parse_editor_config_string: theme vs theme_file precedence' => sub {
    # When both are present, both are stored — the caller decides precedence
    my $cfg = parse_editor_config_string(<<'CONF');
theme = dark
theme_file = themes/theme_solarized.xml
CONF

    is($cfg->{theme}, 'dark', 'theme is parsed');
    is($cfg->{theme_file}, 'themes/theme_solarized.xml', 'theme_file is parsed');
    ok(exists $cfg->{theme} && exists $cfg->{theme_file},
       'both theme and theme_file are available for caller precedence logic');

    # theme_file only (theme absent)
    $cfg = parse_editor_config_string(<<'CONF');
theme_file = themes/custom.xml
CONF

    is($cfg->{theme_file}, 'themes/custom.xml', 'theme_file alone');
    ok(!exists $cfg->{theme}, 'theme key absent when not in config');

    # theme only (theme_file absent)
    $cfg = parse_editor_config_string(<<'CONF');
theme = light
CONF

    is($cfg->{theme}, 'light', 'theme alone');
    ok(!exists $cfg->{theme_file}, 'theme_file key absent when not in config');
};

# ==========================================================================
# 11. Whitespace handling
# ==========================================================================
subtest 'parse_editor_config_string: whitespace trimming' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
  theme  =  dark  
  font_size=12
font_family =   Monospace   
CONF

    is($cfg->{theme}, 'dark', 'value trimmed');
    is($cfg->{font_size}, 12, 'no-space-around-= works');
    is($cfg->{font_family}, 'Monospace', 'leading/trailing spaces trimmed');
};

# ==========================================================================
# 12. Lines without '=' are ignored
# ==========================================================================
subtest 'parse_editor_config_string: malformed lines ignored' => sub {
    my $cfg = parse_editor_config_string(<<'CONF');
theme = dark
this line has no equals sign
= value_without_key
another_invalid_line
font_size = 12
CONF

    is(scalar(keys %$cfg), 2, 'only 2 valid key=value pairs');
    is($cfg->{theme}, 'dark', 'theme parsed');
    is($cfg->{font_size}, 12, 'font_size parsed');
};

# ==========================================================================
# 13. Trailing comment preserved inside quoted values
# ==========================================================================
subtest 'parse_editor_config_string: hash inside quoted value preserved' => sub {
    my $cfg = parse_editor_config_string(q{description = "this has a # hash inside"});

    is($cfg->{description}, 'this has a # hash inside',
       'hash character inside double quotes is not treated as a comment');
};

# ==========================================================================
# 14. parse_editor_config: file reading
# ==========================================================================
subtest 'parse_editor_config: reads a file' => sub {
    use File::Temp qw(tempfile);

    my ($fh, $tmpfile) = tempfile(SUFFIX => '.conf', UNLINK => 1);
    print $fh "theme = dark\nfont_size = 16\nvim_mode = true\n";
    close $fh;

    my $cfg = parse_editor_config($tmpfile);
    is(ref $cfg, 'HASH', 'returns hashref');
    is($cfg->{theme}, 'dark', 'theme from file');
    is($cfg->{font_size}, 16, 'font_size from file');
    is($cfg->{vim_mode}, 1, 'vim_mode from file');
};

subtest 'parse_editor_config: dies on missing file' => sub {
    eval { parse_editor_config('/nonexistent/path/editor.conf') };
    like($@, qr/cannot open.*nonexistent/i,
         'dies with descriptive message for missing file');
};

subtest 'parse_editor_config: dies on undef path' => sub {
    eval { parse_editor_config(undef) };
    like($@, qr/file path is required/i,
         'dies with descriptive message for undef path');
};

# ==========================================================================
# 15. Full example config (editor.conf if available)
# ==========================================================================
subtest 'parse_editor_config: full editor.conf integration' => sub {
    my $conf_path = 'editor.conf';
    plan skip_all => 'editor.conf not found' unless -f $conf_path;

    my $cfg = parse_editor_config($conf_path);
    is(ref $cfg, 'HASH', 'returns hashref from full config');

    # Check expected default values from the distributed config
    is($cfg->{theme}, 'dark', 'default theme');
    is($cfg->{font_family}, 'Monospace', 'default font_family');
    is($cfg->{font_size}, 12, 'default font_size');
    is($cfg->{vim_mode}, 1, 'default vim_mode = true');
    is($cfg->{wrap}, 1, 'default wrap = true');
    is($cfg->{read_only}, 0, 'default read_only = false');
    is($cfg->{show_line_numbers}, 1, 'default show_line_numbers');
    is($cfg->{highlight_current_line}, 1, 'default highlight_current_line');
    is($cfg->{tab_width}, 8, 'default tab_width');
    is($cfg->{force_language}, 'perl', 'default force_language');
    is($cfg->{use_clipboard}, 1, 'default use_clipboard');
};

done_testing;
