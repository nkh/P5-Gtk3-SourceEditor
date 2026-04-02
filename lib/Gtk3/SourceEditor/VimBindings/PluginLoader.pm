package Gtk3::SourceEditor::VimBindings::PluginLoader;

use strict;
use warnings;

our $VERSION = '0.05';

use File::Find ();
use File::Spec ();

# ── Internal state (package-level lexical variables) ──────────────────

my %ACTION_OWNERS;   # { action_name => package_name }
my %PLUGIN_ACTIONS;  # { package_name => [action_names] }
my %PLUGIN_KEYMAPS;  # { package_name => keymap_return_value }
my %PLUGIN_META;     # { package_name => meta_hashref }
my %PLUGIN_HOOKS;    # { package_name => hooks_hashref }
my %PLUGIN_FILES;    # { package_name => absolute_path }
my %PLUGIN_CONFIGS;  # { package_name => config_hashref }
my %LOADED_PACKAGES; # { absolute_path => package_name }
my $WARNINGS = 1;

# ── Package extraction ────────────────────────────────────────────────

sub _extract_package {
    my ($file) = @_;
    open my $fh, '<', $file or return;
    my $count = 0;
    while (my $line = <$fh>) {
        last if ++$count > 20;
        if ($line =~ /^\s*package\s+([\w:]+)\s*;/) {
            close $fh;
            return $1;
        }
    }
    close $fh;
    # Derive from filename
    my ($vol, $dir, $name) = File::Spec->splitpath($file);
    $name =~ s/\.pm$//;
    return $name;
}

# ── Namespace rewriting ───────────────────────────────────────────────

sub _rewrite_namespaced {
    my ($pkg, $ACTIONS, $result, $new_action_names) = @_;

    my $meta = $result->{meta} || {};
    return unless $meta->{namespace};

    my $prefix = (defined $meta->{name} && $meta->{name} ne '')
        ? $meta->{name}
        : ($pkg =~ /::([^:]+)$/ ? $1 : $pkg);

    # Build rename map from new action names
    my %rename;
    for my $old_name (@$new_action_names) {
        my $new_name = "${prefix}::${old_name}";
        $rename{$old_name} = $new_name;
    }

    return unless %rename;

    # Rewrite action names in %ACTIONS
    for my $old (sort keys %rename) {
        my $new = $rename{$old};
        $ACTIONS->{$new} = delete $ACTIONS->{$old};
    }

    # Helper: recursively rewrite action references in a keymap hash
    my $_rewrite_keymap;
    $_rewrite_keymap = sub {
        my ($km) = @_;
        return unless ref $km eq 'HASH';
        for my $k (keys %$km) {
            my $v = $km->{$k};
            if (!ref $v && defined $v && exists $rename{$v}) {
                $km->{$k} = $rename{$v};
            } elsif (ref $v eq 'HASH') {
                $_rewrite_keymap->($v);
            }
        }
    };

    # Rewrite modes
    if ($result->{modes}) {
        for my $mode (keys %{$result->{modes}}) {
            $_rewrite_keymap->($result->{modes}{$mode});
        }
    }

    # Rewrite ex_commands
    if ($result->{ex_commands}) {
        for my $cmd (keys %{$result->{ex_commands}}) {
            my $v = $result->{ex_commands}{$cmd};
            if (!ref $v && defined $v && exists $rename{$v}) {
                $result->{ex_commands}{$cmd} = $rename{$v};
            }
        }
    }

    # Update $new_action_names in-place to reflect namespaced names
    for my $i (0 .. $#$new_action_names) {
        my $old = $new_action_names->[$i];
        $new_action_names->[$i] = $rename{$old} if exists $rename{$old};
    }

    return;
}

# ── Detect newly registered and overwritten actions ───────────────────

sub _detect_action_changes {
    my ($ACTIONS, $actions_before_snapshot) = @_;
    my (@new, @overwritten);

    for my $key (keys %$ACTIONS) {
        my $cur_addr = "$ACTIONS->{$key}";
        if (!exists $actions_before_snapshot->{$key}) {
            push @new, $key;
        } elsif ($actions_before_snapshot->{$key} ne $cur_addr) {
            push @overwritten, $key;
        }
    }

    return (\@new, \@overwritten);
}

# ── Load a single plugin (shared between load_plugins and reload_plugin)

sub _load_single {
    my ($file, $pkg, $ACTIONS, $plugin_config) = @_;

    # Snapshot %ACTIONS before register() — stringify coderefs for comparison
    my %before_snapshot;
    for my $k (keys %$ACTIONS) {
        $before_snapshot{$k} = "$ACTIONS->{$k}";
    }

    # Call register
    my $result = eval { $pkg->register($ACTIONS, $plugin_config) };
    if ($@) {
        (my $err = $@) =~ s/\s+$//;
        warn "Failed to load plugin '$file': $err\n";
        return;
    }

    $LOADED_PACKAGES{$file} = $pkg;
    $PLUGIN_FILES{$pkg}     = $file;
    $PLUGIN_CONFIGS{$pkg}   = $plugin_config;

    if ($result && ref $result eq 'HASH') {
        my $meta        = $result->{meta}        || {};
        my $modes       = $result->{modes}       || {};
        my $ex_commands = $result->{ex_commands} || {};
        my $hooks       = $result->{hooks}       || {};

        # Detect new and overwritten actions
        my ($new_actions, $overwritten_actions) =
            _detect_action_changes($ACTIONS, \%before_snapshot);

        # Warn about overwritten action collisions
        for my $action (@$overwritten_actions) {
            next unless $WARNINGS;
            if (exists $ACTION_OWNERS{$action}) {
                my $prev = $ACTION_OWNERS{$action};
                if (exists $PLUGIN_FILES{$prev}) {
                    warn "Plugin overrides plugin: normal 'gal' -> '${action}' (was from $prev)\n";
                } else {
                    warn "Plugin overrides core: normal 'gal' -> '${action}' (was '$prev')\n";
                }
            } else {
                warn "Action '$action' redefined by $pkg (was core)\n";
            }
        }

        # Namespace rewriting on newly registered actions
        _rewrite_namespaced($pkg, $ACTIONS, $result, $new_actions);

        # Re-read after potential rewriting
        $meta        = $result->{meta}        || $meta;
        $modes       = $result->{modes}       || $modes;
        $ex_commands = $result->{ex_commands} || $ex_commands;
        $hooks       = $result->{hooks}       || $hooks;

        # Record ownership for all actions this plugin touched
        my @all_actions = (@$new_actions, @$overwritten_actions);
        for my $action (@all_actions) {
            $ACTION_OWNERS{$action} = $pkg;
        }

        $PLUGIN_ACTIONS{$pkg} = \@all_actions;
        $PLUGIN_KEYMAPS{$pkg} = { modes => $modes, ex_commands => $ex_commands };
        $PLUGIN_META{$pkg}    = $meta;
        $PLUGIN_HOOKS{$pkg}   = $hooks;

        # Check meta.requires
        if ($meta->{requires}) {
            my @deps = ref $meta->{requires} eq 'ARRAY'
                ? @{$meta->{requires}}
                : ($meta->{requires});
            for my $dep (@deps) {
                unless (grep { $_ eq $dep } values %LOADED_PACKAGES) {
                    warn "Plugin '$pkg' requires '$dep' which is not loaded -- skipped\n";
                    last;
                }
            }
        }

        return {
            pkg         => $pkg,
            modes       => $modes,
            ex_commands => $ex_commands,
            meta        => $meta,
            hooks       => $hooks,
        };
    }

    # register() didn't return a hashref — track what it did to %ACTIONS
    my ($new_actions, $overwritten_actions) =
        _detect_action_changes($ACTIONS, \%before_snapshot);

    for my $action (@$overwritten_actions) {
        next unless $WARNINGS;
        if (exists $ACTION_OWNERS{$action}) {
            my $prev = $ACTION_OWNERS{$action};
            warn "Action '$action' redefined by $pkg (was $prev)\n";
        } else {
            warn "Action '$action' redefined by $pkg (was core)\n";
        }
    }

    my @all_actions = (@$new_actions, @$overwritten_actions);
    for my $action (@all_actions) {
        $ACTION_OWNERS{$action} = $pkg;
    }

    $PLUGIN_ACTIONS{$pkg} = \@all_actions;
    $PLUGIN_KEYMAPS{$pkg} = {};
    $PLUGIN_META{$pkg}    = {};
    $PLUGIN_HOOKS{$pkg}   = {};

    return {
        pkg         => $pkg,
        modes       => {},
        ex_commands => {},
        meta        => {},
        hooks       => {},
    };
}

# ── Public API ────────────────────────────────────────────────────────

sub load_plugins {
    my ($ACTIONS, %opts) = @_;

    $WARNINGS = 1;
    $WARNINGS = 0 if exists $opts{warnings} && !$opts{warnings};

    my $dirs   = $opts{dirs}   || ['./bindings/'];
    my $files  = $opts{files}  || [];
    my $config = $opts{config} || {};

    # 1. Scan directories recursively for .pm files
    my @found;
    for my $dir (@$dirs) {
        next unless -d $dir;
        File::Find::find({
            wanted => sub {
                return unless -f $_ && /\.pm$/;
                push @found, File::Spec->rel2abs($File::Find::name);
            },
            no_chdir => 1,
        }, $dir);
    }

    # Sort alphabetically
    @found = sort @found;

    # 2. Append explicit files
    push @found, map { File::Spec->rel2abs($_) } @$files;

    my @results;

    for my $file (@found) {
        next if exists $LOADED_PACKAGES{$file};

        # 3a. Extract package name
        my $pkg = _extract_package($file);
        unless ($pkg) {
            warn "Failed to determine package for '$file'\n";
            next;
        }

        # 3b. require
        eval { require $file };
        if ($@) {
            (my $err = $@) =~ s/\s+$//;
            warn "Failed to load plugin '$file': $err\n";
            next;
        }

        # 3c. Verify register sub exists
        unless ($pkg->can('register')) {
            warn "Plugin '$pkg' has no register() -- skipped\n";
            next;
        }

        # 3d. Build config
        my $plugin_config = $config->{$pkg} // {};

        # 3e. Load
        my $r = _load_single($file, $pkg, $ACTIONS, $plugin_config);
        push @results, $r if $r;
    }

    return @results;
}

sub unload_plugin {
    my ($pkg_name, $ACTIONS) = @_;

    return unless exists $PLUGIN_ACTIONS{$pkg_name};

    my $actions = $PLUGIN_ACTIONS{$pkg_name} || [];
    for my $action (@$actions) {
        if (exists $ACTION_OWNERS{$action} && $ACTION_OWNERS{$action} eq $pkg_name) {
            delete $ACTION_OWNERS{$action};
            delete $ACTIONS->{$action};
        }
    }

    my $file = delete $PLUGIN_FILES{$pkg_name};
    delete $LOADED_PACKAGES{$file} if $file;

    my $keymap = delete $PLUGIN_KEYMAPS{$pkg_name};
    delete $PLUGIN_ACTIONS{$pkg_name};
    delete $PLUGIN_META{$pkg_name};
    delete $PLUGIN_HOOKS{$pkg_name};
    delete $PLUGIN_CONFIGS{$pkg_name};

    return $keymap;
}

sub reload_plugin {
    my ($pkg_name, $ACTIONS, %opts) = @_;

    my $file = $PLUGIN_FILES{$pkg_name};
    return unless $file;

    # Preserve config before unload deletes it
    my $saved_config = $PLUGIN_CONFIGS{$pkg_name} // {};

    # Unload first
    unload_plugin($pkg_name, $ACTIONS);

    # Remove from %INC so require will re-read the file
    delete $INC{$file};

    # Re-require
    eval { require $file };
    if ($@) {
        (my $err = $@) =~ s/\s+$//;
        warn "Failed to load plugin '$file': $err\n";
        return;
    }

    # Re-extract package (should be same)
    my $pkg = _extract_package($file);

    # Merge config: opts override saved
    my $plugin_config = exists $opts{config}
        ? { %$saved_config, %{$opts{config}} }
        : $saved_config;

    # Re-load
    my $r = _load_single($file, $pkg, $ACTIONS, $plugin_config);
    return unless $r;

    return { modes => $r->{modes}, ex_commands => $r->{ex_commands} };
}

sub list_plugins {
    return sort keys %PLUGIN_ACTIONS;
}

sub get_plugin_hooks {
    return \%PLUGIN_HOOKS;
}

sub get_plugin_config {
    my ($pkg_name) = @_;
    return $PLUGIN_CONFIGS{$pkg_name};
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::PluginLoader - Plugin discovery and lifecycle management

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBindings::PluginLoader;

    my %ACTIONS;
    my @plugins = Gtk3::SourceEditor::VimBindings::PluginLoader::load_plugins(
        \%ACTIONS,
        dirs     => ['./plugins/', './vendor_plugins/'],
        config   => { 'My::Align' => { indent => 4 } },
        warnings => 1,
    );

    my $hooks  = Gtk3::SourceEditor::VimBindings::PluginLoader::get_plugin_hooks();
    my @names  = Gtk3::SourceEditor::VimBindings::PluginLoader::list_plugins();

    Gtk3::SourceEditor::VimBindings::PluginLoader::unload_plugin('My::Align', \%ACTIONS);

    Gtk3::SourceEditor::VimBindings::PluginLoader::reload_plugin('My::Align', \%ACTIONS);

=head1 DESCRIPTION

Pure Perl plugin loader with no GTK dependency. Discovers, loads, unloads,
and reloads plugin modules that follow the C<register(\%ACTIONS, $config)>
convention. Supports namespace rewriting, dependency checking, action
ownership tracking, and collision warnings.

=head1 FUNCTIONS

=head2 load_plugins(\%ACTIONS, %opts)

Scan directories for C<.pm> plugins, C<require> them, call their C<register()>
method, and return an array of plugin descriptor hashrefs.

Options:

=over 4

=item dirs - arrayref of directories to scan (default: C<['./bindings/']>)

=item files - arrayref of specific .pm files to load

=item config - hashref of C<< { package_name => config_hashref } >>

=item warnings - boolean, default 1. If 0, suppress override/collision warnings

=back

Returns: array of hashrefs, one per loaded plugin, each with:
C<< { pkg, modes, ex_commands, meta, hooks } >>

=head2 unload_plugin($pkg_name, \%ACTIONS)

Remove all actions owned by the named plugin from C<%ACTIONS> and internal
tracking. Returns the removed keymap data so the caller can rebuild dispatch.

=head2 reload_plugin($pkg_name, \%ACTIONS, %opts)

Unload, re-require, and re-register a plugin. Options:

=over 4

=item config - optional config hashref to merge with saved config

=back

Returns: new keymap data hashref with C<modes> and C<ex_commands>.

=head2 list_plugins()

Returns a sorted list of loaded package names.

=head2 get_plugin_hooks()

Returns a reference to the internal C<%PLUGIN_HOOKS> hash.

=head2 get_plugin_config($pkg_name)

Returns the config hashref for a plugin, or C<undef>.

=cut
