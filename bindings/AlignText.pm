# ==========================================================================
# Example Plugin: AlignText
#
# This is an example plugin for P5-Gtk3-SourceEditor demonstrating the
# plugin system.  It provides two alignment operations:
#
#   gal  - Remove leading whitespace from the current line and next N-1 lines
#   gar  - Right-align text in the current line and next N-1 lines
#
# ACTIVATION
#
#   Pass plugin_dirs to the editor constructor (or script CLI):
#
#     Gtk3::SourceEditor->new(
#         file        => 'example.pl',
#         plugin_dirs => ['./bindings/'],
#     );
#
#   Or from the command line:
#
#     perl script/source-editor --bindings ./bindings/ myfile.pl
#
# HOW IT WORKS
#
#   The plugin system looks for .pm files in each plugin_dirs directory.
#   Each file must provide a register(\%ACTIONS, $config) function that:
#
#     1. Registers action coderefs in %ACTIONS
#     2. Returns a hashref with keys:
#        meta        - plugin metadata (name, version, description, requires,
#                      namespace)
#        modes       - per-mode keymap additions (_prefixes, key mappings)
#        ex_commands - ex-command name-to-action mappings
#        hooks       - event hook registrations (optional)
#
#   $config is a hashref of user-supplied configuration values.  Plugins
#   should document which config keys they honour and provide sensible
#   defaults.
#
#   The namespace meta field controls whether action names are namespaced.
#   When namespace is true, all actions and key mappings are prefixed with
#   "plugin_name:" to avoid collisions with built-in actions.  When false
#   (the default), actions use plain names.  Set this to true if your
#   plugin might conflict with built-in or other plugin actions.
#
# TESTS
#
#   Plugin tests go in the t/ directory of the project.  Use the
#   VimBuffer::Test backend and create_test_context() helper for
#   headless testing.  Example:
#
#     t/plugin_aligntext.t
#
#   Run tests with:
#
#     perl -Ilib -It/lib t/plugin_aligntext.t
#
# ==========================================================================

package My::Editor::Plugin::AlignText;

use strict;
use warnings;

our $VERSION = '0.01';

# ------------------------------------------------------------------
# register(\%ACTIONS, $config)
#
# Populate %ACTIONS with action coderefs and return plugin metadata
# plus keymap/ex-command bindings.
# ------------------------------------------------------------------
sub register {
    my ($class, $ACTIONS, $config) = @_;

    my $indent_width = $config->{indent_width} // 4;
    my $align_width  = $config->{align_width}  // 80;

    # ================================================================
    #  align_lines -- remove leading whitespace from N lines
    # ================================================================

    $ACTIONS->{align_lines} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $start_line = $vb->cursor_line;

        for my $ln ($start_line .. $start_line + $count - 1) {
            last if $ln >= $vb->line_count;
            my $text = $vb->line_text($ln);
            my $col = 0;
            while ($col < length($text) && substr($text, $col, 1) =~ /^\s$/) {
                $col++;
            }
            next if $col == 0;    # nothing to strip
            $vb->set_cursor($ln, 0);
            $vb->delete_range($ln, 0, $ln, $col);
        }

        # Position cursor at first non-blank of the starting line
        $vb->set_cursor($start_line, $vb->first_nonblank_col($start_line));
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ================================================================
    #  align_right -- right-align text in N lines to a given width
    # ================================================================

    $ACTIONS->{align_right} = sub {
        my ($ctx, $count) = @_;
        $count ||= 1;
        my $vb = $ctx->{vb};
        my $start_line = $vb->cursor_line;

        for my $ln ($start_line .. $start_line + $count - 1) {
            last if $ln >= $vb->line_count;
            my $text = $vb->line_text($ln);
            my $len  = length($text);

            # Delete existing content first
            $vb->set_cursor($ln, 0);
            $vb->delete_range($ln, 0, $ln, $len);

            # Re-insert right-aligned (padded with leading spaces)
            if ($len > 0) {
                my $pad = $align_width - $len;
                $pad = 0 if $pad < 0;
                $vb->insert_text((' ' x $pad) . $text);
            }
        }

        # Position cursor at start of the starting line
        $vb->set_cursor($start_line, 0);
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # ================================================================
    #  Return plugin descriptor
    # ================================================================

    return {
        meta => {
            name        => 'AlignText',
            version     => '0.01',
            description => 'Whitespace alignment operations for text blocks',
            requires    => [],
            namespace   => 0,     # demonstrating that namespace is available but off by default
        },
        modes => {
            normal => {
                _prefixes  => ['ga'],
                gal        => 'align_lines',
                gar        => 'align_right',
            },
        },
        ex_commands => {
            align   => 'align_lines',
            alignr  => 'align_right',
        },
        hooks => {
            # No hooks in this example, but showing the key is valid
        },
    };
}

1;

__END__

=head1 NAME

My::Editor::Plugin::AlignText - Example plugin: whitespace alignment for text blocks

=head1 SYNOPSIS

    # In your editor startup:
    Gtk3::SourceEditor->new(
        file        => 'example.pl',
        plugin_dirs => ['./bindings/'],
    );

    # In normal mode:
    #   gal        Remove leading whitespace from current line
    #   3gal       Remove leading whitespace from 3 lines
    #   gar        Right-align current line to 80 columns
    #   :align     Same as gal
    #   :alignr    Same as gar

    # With custom configuration:
    # (passed via config option when loading plugins)
    #   indent_width => 2     # reference width (not used by align_lines)
    #   align_width  => 100   # target width for align_right

=head1 DESCRIPTION

This is an example plugin demonstrating the P5-Gtk3-SourceEditor plugin
system.  It provides two simple alignment operations that operate on
the current line and subsequent lines (controlled by the numeric prefix).

B<align_lines> (gal, :align) strips all leading whitespace from the
current line and the next N-1 lines, where N defaults to 1.  After
the operation, the cursor is positioned at the first non-blank
character of the starting line.

B<align_right> (gar, :alignr) right-aligns each line by padding with
leading spaces so the line content ends at column C<align_width>
(default 80).  Lines longer than the target width are left unchanged.
After the operation, the cursor is positioned at column 0 of the
starting line.

=head1 AUTHOR

Example plugin for the P5-Gtk3-SourceEditor project.

=head1 LICENSE

Artistic License 2.0.

=cut
