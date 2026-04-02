#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib 'lib', 't/lib';
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Spec;

# ==========================================================================
# Temporary directory for all test plugins
# ==========================================================================
my $tmp_base = tempdir(CLEANUP => 0, TEMPLATE => 'vim_plugin_test_XXXX');

# Helper: write a .pm plugin file into a directory, return absolute path
sub write_plugin_file {
    my ($dir, $filename, $content) = @_;
    make_path($dir);
    my $filepath = File::Spec->catfile($dir, $filename);
    open my $fh, '>', $filepath or die "Cannot write $filepath: $!";
    print $fh $content;
    close $fh;
    return $filepath;
}

# Helper: substitute __PKG__ placeholder in a plugin template
sub fill_pkg { my ($tmpl, $pkg) = @_; my $c = $tmpl; $c =~ s/__PKG__/$pkg/g; return $c; }

# ==========================================================================
# Plugin templates
# ==========================================================================

# Main plugin: registers my_test_action (inserts "TESTOK"), bound to ZZ
# in normal mode, plus ex-command testcmd that inserts "TESTOK".
my $main_plugin_tmpl = <<'END_PLUGIN';
package __PKG__;

use strict;
use warnings;

sub register {
    my ($class, $ACTIONS, $config) = @_;

    $ACTIONS->{my_test_action} = sub {
        my ($ctx, $count) = @_;
        $ctx->{vb}->insert_text("TESTOK");
    };

    return {
        meta => {
            name        => 'TestPlugin',
            version     => '1.0',
            description => 'Test plugin for vim_plugin.t',
        },
        modes => {
            normal => {
                _prefixes => ['Z'],
                ZZ        => 'my_test_action',
            },
        },
        ex_commands => {
            testcmd => 'my_test_action',
        },
        hooks => {},
    };
}

1;
END_PLUGIN

# Ex-command-only plugin: testcmd sets mode_label to "TESTCMD_OK"
my $excmd_plugin_tmpl = <<'END_PLUGIN';
package __PKG__;

use strict;
use warnings;

sub register {
    my ($class, $ACTIONS, $config) = @_;

    $ACTIONS->{my_testcmd_action} = sub {
        my ($ctx, $count) = @_;
        $ctx->{mode_label}->set_text("TESTCMD_OK");
    };

    return {
        meta => {
            name        => 'ExCmdPlugin',
            version     => '1.0',
            description => 'Test plugin with ex-command',
        },
        modes => {},
        ex_commands => {
            testcmd => 'my_testcmd_action',
        },
        hooks => {},
    };
}

1;
END_PLUGIN

# Config plugin: stores $config->{my_option} in a package var,
# inserts "CFG:<value>" at cursor.
my $config_plugin_tmpl = <<'END_PLUGIN';
package __PKG__;

use strict;
use warnings;

our $CONFIG_VALUE;

sub register {
    my ($class, $ACTIONS, $config) = @_;

    $CONFIG_VALUE = $config->{my_option} // 'DEFAULT';

    $ACTIONS->{config_test_action} = sub {
        my ($ctx, $count) = @_;
        $ctx->{vb}->insert_text("CFG:" . $CONFIG_VALUE);
    };

    return {
        meta => {
            name        => 'ConfigPlugin',
            version     => '1.0',
            description => 'Test plugin that reads config',
        },
        modes => {
            normal => {
                _prefixes => ['Z'],
                ZZ        => 'config_test_action',
            },
        },
        ex_commands => {},
        hooks => {},
    };
}

1;
END_PLUGIN

# No-register plugin: has a package but no register() sub
my $no_register_tmpl = <<'END_PLUGIN';
package __PKG__;

use strict;
use warnings;

# Intentionally no register() sub -- should be skipped with a warning

1;
END_PLUGIN

# Dying register plugin: register() throws an exception
my $dying_register_tmpl = <<'END_PLUGIN';
package __PKG__;

use strict;
use warnings;

sub register {
    die "This plugin is intentionally broken";
}

1;
END_PLUGIN

# Override plugin: binds key 'j' to a custom action
my $override_plugin_tmpl = <<'END_PLUGIN';
package __PKG__;

use strict;
use warnings;

sub register {
    my ($class, $ACTIONS, $config) = @_;

    $ACTIONS->{override_j_action} = sub {
        my ($ctx, $count) = @_;
        $ctx->{mode_label}->set_text("OVERRIDDEN_J");
    };

    return {
        meta => {
            name        => 'OverridePlugin',
            version     => '1.0',
            description => 'Test plugin that overrides core j binding',
        },
        modes => {
            normal => { j => 'override_j_action' },
        },
        ex_commands => {},
        hooks => {},
    };
}

1;
END_PLUGIN

# ==========================================================================
# Test 4: No plugin_dirs = no loading
# (Runs first to verify clean state before any plugins are loaded)
# ==========================================================================
subtest 'No plugin_dirs = no loading' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer => $vb,
    );

    is(${$ctx->{vim_mode}}, 'normal',
        'context created and starts in normal mode without plugins');

    # Basic movement should work normally
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'l', 'l');
    is($vb->cursor_col, 2, 'l moves cursor right by 2');

    # ZZ is not a core binding -- it should not crash or do anything
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Z', 'Z');
    is(${$ctx->{vim_mode}}, 'normal',
        'ZZ does not change mode (no plugin loaded)');
    is($vb->text, "hello\n",
        'buffer unchanged after unrecognized ZZ sequence');
};

# ==========================================================================
# Test 1: Plugin loading from directory
# ==========================================================================
subtest 'Plugin loading from directory' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test1_dir');
    write_plugin_file($dir, 'TestPluginDir.pm',
        fill_pkg($main_plugin_tmpl, 'TestPluginDir'));

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer  => $vb,
        plugin_dirs => [$dir],
    );

    is(${$ctx->{vim_mode}}, 'normal', 'starts in normal mode');
    is($vb->text, "hello\n", 'buffer unchanged before plugin action');

    # ZZ should trigger the plugin's my_test_action
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Z', 'Z');

    is(${$ctx->{vim_mode}}, 'normal', 'still in normal mode after ZZ');
    like($vb->text, qr/TESTOK/,
        'ZZ triggered plugin action and inserted TESTOK at cursor');
    is($vb->cursor_col, length("TESTOK"),
        'cursor advanced past inserted text');
};

# ==========================================================================
# Test 2: Plugin loading from single file (plugin_files)
# ==========================================================================
subtest 'Plugin loading from single file' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test2_dir');
    my $file = write_plugin_file($dir, 'TestPluginFile.pm',
        fill_pkg($main_plugin_tmpl, 'TestPluginFile'));

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer   => $vb,
        plugin_files => [$file],
    );

    is(${$ctx->{vim_mode}}, 'normal', 'starts in normal mode');
    is($vb->text, "abc\n", 'buffer unchanged before plugin action');

    # ZZ should trigger the file-loaded plugin's my_test_action
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Z', 'Z');

    is(${$ctx->{vim_mode}}, 'normal', 'still in normal mode after ZZ');
    like($vb->text, qr/TESTOK/,
        'ZZ from file-loaded plugin inserted TESTOK at cursor');
};

# ==========================================================================
# Test 3: Plugin ex-commands
# ==========================================================================
subtest 'Plugin ex-commands' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test3_dir');
    write_plugin_file($dir, 'TestPluginExCmd.pm',
        fill_pkg($excmd_plugin_tmpl, 'TestPluginExCmd'));

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer  => $vb,
        plugin_dirs => [$dir],
    );

    is(${$ctx->{vim_mode}}, 'normal', 'starts in normal mode');

    # Enter command mode via colon
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'colon');
    is(${$ctx->{vim_mode}}, 'command', 'colon enters command mode');

    # Type the ex-command name
    Gtk3::SourceEditor::VimBindings::simulate_keys(
        $ctx, 't', 'e', 's', 't', 'c', 'm', 'd');
    is($ctx->{cmd_entry}->get_text, ':testcmd',
        'command entry shows :testcmd');

    # Execute with Return
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Return');

    is(${$ctx->{vim_mode}}, 'normal', 'returned to normal mode');
    is($ctx->{mode_label}->get_text, 'TESTCMD_OK',
        'plugin ex-command set mode_label to TESTCMD_OK');

    # Buffer should not have been modified (excmd plugin only sets label)
    is($vb->text, "hello\n", 'buffer unchanged by ex-command plugin');
};

# ==========================================================================
# Test 5: Plugin with config
# ==========================================================================
subtest 'Plugin with config' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test5_dir');
    write_plugin_file($dir, 'TestPluginConfig.pm',
        fill_pkg($config_plugin_tmpl, 'TestPluginConfig'));

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer    => $vb,
        plugin_dirs   => [$dir],
        plugin_config => {
            'TestPluginConfig' => { my_option => 42 },
        },
    );

    is(${$ctx->{vim_mode}}, 'normal', 'starts in normal mode');

    # ZZ triggers config_test_action which inserts "CFG:42"
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'Z', 'Z');

    is(${$ctx->{vim_mode}}, 'normal', 'still in normal mode');
    is($TestPluginConfig::CONFIG_VALUE, 42,
        'plugin received config value my_option = 42');
    like($vb->text, qr/CFG:42/,
        'plugin action used config value in buffer output');
};

# ==========================================================================
# Test 6: Missing register() is skipped with a warning
# ==========================================================================
subtest 'Missing register() is skipped with warning' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test6_dir');
    write_plugin_file($dir, 'TestPluginNoReg.pm',
        fill_pkg($no_register_tmpl, 'TestPluginNoReg'));

    # Capture warnings from the plugin loader
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer  => $vb,
        plugin_dirs => [$dir],
    );

    # Context should still be created successfully
    is(${$ctx->{vim_mode}}, 'normal',
        'context created despite plugin with no register()');

    # A warning should have been emitted about the missing register
    my $got_warning = 0;
    for my $w (@warnings) {
        if ($w =~ /no register\(\)\s*--\s*skipped/i) {
            $got_warning = 1;
            last;
        }
    }
    ok($got_warning,
        'plugin loader warned about missing register() and skipped');

    # Normal editing should still work
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "ello\n", 'x still deletes a character (core works)');
};

# ==========================================================================
# Test 7: Dying register() is skipped
# ==========================================================================
subtest 'Dying register() is skipped' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test7_dir');
    write_plugin_file($dir, 'TestPluginDie.pm',
        fill_pkg($dying_register_tmpl, 'TestPluginDie'));

    # Capture warnings from the plugin loader
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer  => $vb,
        plugin_dirs => [$dir],
    );

    # Context should still be created successfully
    is(${$ctx->{vim_mode}}, 'normal',
        'context created despite plugin whose register() dies');

    # A warning should have been emitted about the failure
    my $got_warning = 0;
    for my $w (@warnings) {
        if ($w =~ /Failed to load plugin.*intentionally broken/i) {
            $got_warning = 1;
            last;
        }
    }
    ok($got_warning,
        'plugin loader warned about failing register() and skipped');

    # Normal editing should still work
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'x');
    is($vb->text, "ello\n", 'x still deletes a character (core works)');
};

# ==========================================================================
# Test 8: Plugin overrides core binding (j)
# ==========================================================================
subtest 'Plugin overrides core binding' => sub {
    my $dir = File::Spec->catdir($tmp_base, 'test8_dir');
    write_plugin_file($dir, 'TestPluginOverride.pm',
        fill_pkg($override_plugin_tmpl, 'TestPluginOverride'));

    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(
        text => "line1\nline2\nline3\n");
    my $ctx = Gtk3::SourceEditor::VimBindings::create_test_context(
        vim_buffer  => $vb,
        plugin_dirs => [$dir],
    );

    is(${$ctx->{vim_mode}}, 'normal', 'starts in normal mode');
    is($vb->cursor_line, 0, 'cursor starts on line 0');

    # Press j -- core would move down, but plugin overrides to set label
    Gtk3::SourceEditor::VimBindings::simulate_keys($ctx, 'j');

    is($vb->cursor_line, 0,
        'j did NOT move cursor down (plugin overrode core binding)');
    is($ctx->{mode_label}->get_text, 'OVERRIDDEN_J',
        'j triggered plugin action instead of core cursor_down');
};

# ==========================================================================
# Cleanup: remove the temporary plugin directory tree
# ==========================================================================
END {
    if (-d $tmp_base) {
        remove_tree($tmp_base);
    }
}

done_testing;
