#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBindings;
use Gtk3::SourceEditor::VimBindings::Command;
use Gtk3::SourceEditor::VimBuffer::Test;

# ==========================================================================
# Ex-command parser — comprehensive tests for parse_ex_command
# ==========================================================================

subtest 'Basic command: :w' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':w');
    ok($p, 'parse returns a hashref');
    is($p->{cmd}, 'w', 'command is w');
    is_deeply($p->{args}, [], 'no args');
    is($p->{bang}, 0, 'no bang');
    is($p->{range}, undef, 'no range');
};

subtest 'Save with filename: :w file.txt' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':w file.txt');
    is($p->{cmd}, 'w', 'command is w');
    is_deeply($p->{args}, ['file.txt'], 'filename as arg');
    is($p->{bang}, 0, 'no bang');
};

subtest 'Quit: :q' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':q');
    is($p->{cmd}, 'q', 'command is q');
    is_deeply($p->{args}, []);
};

subtest 'Force quit: :q!' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':q!');
    is($p->{cmd}, 'q', 'command is q');
    is($p->{bang}, 1, 'bang flag set');
    is_deeply($p->{args}, []);
};

subtest 'Save with bang: :w!' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':w!');
    is($p->{cmd}, 'w', 'command is w');
    is($p->{bang}, 1, 'bang flag set');
    is_deeply($p->{args}, []);
};

subtest 'Bindings command: :bindings' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':bindings');
    is($p->{cmd}, 'bindings', 'command is bindings');
};

subtest 'Empty command: :' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':');
    is($p, undef, 'empty command returns undef');
};

subtest 'Whitespace stripping: :  w  file.txt  ' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':  w  file.txt  ');
    is($p->{cmd}, 'w', 'whitespace stripped');
    is_deeply($p->{args}, ['file.txt'], 'args trimmed');
};

subtest 'Range prefix: %' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':%s/old/new/g');
    is($p->{range}, '%', 'range is %');
    is($p->{cmd}, 's', 'command is s');
    is_deeply($p->{args}, ['/old/new/g'], 'substitution pattern as arg');
};

subtest 'Range prefix: line numbers' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':1,5d');
    is($p->{range}, '1,5', 'line range preserved');
    is($p->{cmd}, 'd', 'command is d');
};

subtest 'Bang at end after args: :w file.txt !' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':w file.txt !');
    is($p->{cmd}, 'w', 'command is w');
    is_deeply($p->{args}, ['file.txt'], 'filename arg preserved');
    is($p->{bang}, 1, 'bang extracted from end');
};

subtest 'No bang: :w file.txt' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':w file.txt');
    is($p->{bang}, 0, 'no bang when not present');
};

subtest 'Undefined input' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(undef);
    is($p, undef, 'undef input returns undef');
};

subtest 'Empty string input' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command('');
    is($p, undef, 'empty string returns undef');
};

subtest 'Read file: :r myfile.txt' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':r myfile.txt');
    ok($p, 'parse returns a hashref');
    is($p->{cmd}, 'r', 'command is r');
    is_deeply($p->{args}, ['myfile.txt'], 'filename as arg');
    is($p->{bang}, 0, 'no bang');
    is($p->{range}, undef, 'no range');
};

subtest 'Read file no arg: :r' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':r');
    ok($p, 'parse returns a hashref');
    is($p->{cmd}, 'r', 'command is r');
    is_deeply($p->{args}, [], 'no args');
};

# ==========================================================================
# Tests for new commands: :browse, :set cursor=
# ==========================================================================

subtest 'Browse command: :browse' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':browse');
    ok($p, 'parse returns a hashref');
    is($p->{cmd}, 'browse', 'command is browse');
    is_deeply($p->{args}, [], 'no args');
};

subtest 'Set cursor=block: :set cursor=block' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':set cursor=block');
    ok($p, 'parse returns a hashref');
    is($p->{cmd}, 'set', 'command is set');
    is_deeply($p->{args}, ['cursor=block'], 'cursor=block as arg');
};

subtest 'Set cursor=ibeam: :set cursor=ibeam' => sub {
    my $p = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(':set cursor=ibeam');
    ok($p, 'parse returns a hashref');
    is($p->{cmd}, 'set', 'command is set');
    is_deeply($p->{args}, ['cursor=ibeam'], 'cursor=ibeam as arg');
};

subtest 'set cursor mode does not pollute mode label' => sub {
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n"),
    );
    my $label = $ctx->{mode_label};

    # Simulate :set cursor=block via command mode
    $ctx->{cmd_entry}->set_text(':set cursor=block');
    Gtk3::SourceEditor::VimBindings::handle_command_entry($ctx, 'Return');

    # After the command, mode should be normal (not "cursor shape set to block")
    my $mode_text = $label->get_text;
    is($mode_text, '-- NORMAL --', 'mode label shows NORMAL after :set cursor=block');

    # Now switch to insert mode
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i');
    is($label->get_text, '-- INSERT --', 'mode label shows INSERT after i');

    # Back to normal
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Escape');
    is($label->get_text, '-- NORMAL --', 'mode label shows NORMAL after Escape');

    # Test unknown option gives error
    $ctx->{cmd_entry}->set_text(':set bogus');
    Gtk3::SourceEditor::VimBindings::handle_command_entry($ctx, 'Return');
    is($label->get_text, "Error: Unknown option 'bogus'",
       'unknown :set option shows error');

    # Mode should still work after error
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'i');
    is($label->get_text, '-- INSERT --', 'mode label works after error');
};

subtest 'browse command registered in ex_cmds' => sub {
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n"),
    );
    ok(exists $ctx->{ex_cmds}{browse}, ':browse is in ex_cmds');
    is($ctx->{ex_cmds}{browse}, 'cmd_browse', ':browse maps to cmd_browse action');
};

done_testing;
