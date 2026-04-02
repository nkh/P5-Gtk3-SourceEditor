package Gtk3::SourceEditor::VimBindings::CompletionUI;
use strict;
use warnings;

our $VERSION = '0.01';

# ==========================================================================
# Constructor
# ==========================================================================
# $ctx      - the VimBindings context hash (needs mode_label, cmd_entry)
# $completer - a Completion engine object
#
# The UI object manages its own state (active/inactive, selection index)
# and reads/writes the command entry and mode label through the context.
# No other part of VimBindings needs to know about completion state.
# ==========================================================================
sub new {
    my ($class, $ctx, $completer) = @_;
    return bless {
        ctx       => $ctx,
        completer => $completer,
        active    => 0,
        candidates   => [],
        selected_idx => 0,
        cmd_prefix   => '',    # e.g. ':e ' or ':r '
        partial_base => '',    # directory prefix before the completed part
    }, $class;
}

# ==========================================================================
# active() - returns true if completion UI is active
# ==========================================================================
sub active { $_[0]->{active} }

# ==========================================================================
# handle_key($k)
#
# Called from handle_command_entry when Tab, Left, Right, Return, Escape
# arrive and completion is active (or Tab arrives to start it).
#
# Returns:
#   undef   - key not handled (let caller deal with it)
#   1       - key consumed (return TRUE to GTK)
#   'accept' - accepted completion, caller should execute the command
#   'cancel' - cancelled, caller should exit command mode
# ==========================================================================
sub handle_key {
    my ($self, $k) = @_;

    # Tab: toggle completion on, or re-complete with current text
    if ($k eq 'Tab') {
        if ($self->{active}) {
            # Already active: re-complete with current entry text
            $self->_recomplete();
        } else {
            # Start completion
            my $started = $self->_start();
            return undef unless $started;
        }
        return 1;
    }

    # If not active, not our concern
    return undef unless $self->{active};

    # Left: select previous candidate
    if ($k eq 'Left') {
        $self->_select_prev();
        return 1;
    }

    # Right: select next candidate
    if ($k eq 'Right') {
        $self->_select_next();
        return 1;
    }

    # Return: accept selected candidate (file -> 'accept', directory -> 1)
    if ($k eq 'Return') {
        return $self->_accept();
    }

    # Escape: cancel completion, exit command mode
    if ($k eq 'Escape') {
        $self->deactivate();
        return 'cancel';
    }

    # BackSpace: delete last char, re-complete
    if ($k eq 'BackSpace') {
        my $ce = $self->{ctx}{cmd_entry};
        my $text = $ce->get_text();
        my $prefix_len = length($self->{cmd_prefix});
        if (length($text) > $prefix_len) {
            chop $text;
            $ce->set_text($text);
            $ce->set_position(-1);
            $self->_recomplete();
        } else {
                # Backspaced past the command prefix (e.g. ':e ' -> ':e')
                $self->deactivate();
        }
        return 1;
    }

    # Any other printable key: append to entry, keep completion active and
    # re-complete.  This allows refining the search by typing more characters
    # and then pressing Tab to narrow candidates, without losing the popup.
    if (length($k) == 1) {
        my $ce = $self->{ctx}{cmd_entry};
        $ce->set_text($ce->get_text() . $k);
        $ce->set_position(-1);
        $self->_recomplete();
        return 1;
    }
    $self->deactivate();
    return undef;
}

# ==========================================================================
# deactivate() - clear completion state and restore label
# ==========================================================================
sub deactivate {
    my ($self) = @_;
    $self->{active}      = 0;
    $self->{candidates}  = [];
    $self->{selected_idx} = 0;
    # Restore mode label to current mode text (completion candidates
    # may have overwritten it with Pango markup)
    my $ctx = $self->{ctx};
    if ($ctx->{mode_label} && $ctx->{vim_mode}) {
        my $mode = ${$ctx->{vim_mode}};
        if ($mode ne 'command') {
            my %mode_labels = (
                normal       => "-- NORMAL --",
                insert       => "-- INSERT --",
                replace      => "-- REPLACE --",
                visual       => "-- VISUAL --",
                visual_line  => "-- VISUAL LINE --",
                visual_block => "-- VISUAL BLOCK --",
            );
            eval { $ctx->{mode_label}->set_text($mode_labels{$mode} // "-- NORMAL --"); };
        }
    }
}

# ==========================================================================
# _dir_prefix() - extract the directory portion from partial_base
#
# If partial_base ends with '/' (e.g. "lib/"), the whole thing is the
# directory.  Otherwise extract everything up to the last '/'
# (e.g. "lib/Gtk3" -> "lib/").  Returns '' for bare filenames.
# ==========================================================================
sub _dir_prefix {
    my ($self) = @_;
    my $partial = $self->{partial_base} // '';
    if ($partial =~ m{/$}) {
        return $partial;                       # "lib/" -> "lib/"
    }
    (my $base = $partial) =~ s{/+$}{};
    if ($base =~ m{(.+)/}) {
        return $1 . '/';                       # "lib/Gtk3" -> "lib/"
    }
    return '';                                # "Gtk3" -> ""
}

# ==========================================================================
# _start() - begin completion from current entry text
#
# Returns 1 if completion started, 0 if not applicable (wrong command
# or no matches).
# ==========================================================================
sub _start {
    my ($self) = @_;
    my $ce = $self->{ctx}{cmd_entry};
    my $text = $ce->get_text();

    # Only complete for :e and :r commands
    # Match ":e partial" or ":r partial" (with at least one space)
    if ($text =~ /^(:e\s+|:r\s+)(.*)/) {
        $self->{cmd_prefix} = $1;
        my $partial = $2;

        my $result = $self->{completer}->complete($partial);
        return 0 unless @{$result->{candidates}};

        $self->{candidates}   = $result->{candidates};
        $self->{selected_idx} = 0;
        $self->{partial_base} = $partial;   # store for _update_entry()

        # Update entry: preserve the directory part of the partial path
        # so that "lib/Gtk" -> ":e lib/Gtk3/" (not ":e Gtk3/").
        my $dp = $self->_dir_prefix();
        $ce->set_text($self->{cmd_prefix} . $dp . $result->{prefix});
        $ce->set_position(-1);

        $self->{active} = 1;
        $self->_render();
        return 1;
    }

    return 0;
}

# ==========================================================================
# _recomplete() - re-complete using current entry text
# ==========================================================================
sub _recomplete {
    my ($self) = @_;
    my $ce = $self->{ctx}{cmd_entry};
    my $text = $ce->get_text();

    if ($text =~ /^(:e\s+|:r\s+)(.*)/) {
        $self->{cmd_prefix} = $1;
        my $partial = $2;

        my $result = $self->{completer}->complete($partial);
        if (!@{$result->{candidates}}) {
            # No matches: deactivate
            $self->deactivate();
            return;
        }

        $self->{candidates}   = $result->{candidates};
        $self->{selected_idx} = 0;
        $self->{partial_base} = $partial;   # store for _update_entry()

        # Preserve the directory part of the partial path so that
        # navigating into a subdirectory works (e.g. "lib/" ->
        # ":e lib/Gtk3/" not ":e Gtk3/").
        my $dp = $self->_dir_prefix();
        $ce->set_text($self->{cmd_prefix} . $dp . $result->{prefix});
        $ce->set_position(-1);

        $self->{active} = 1;
        $self->_render();
    } else {
        $self->deactivate();
    }
}

# ==========================================================================
# _accept() - accept the currently selected candidate
#
# For files: sets the entry text to the full completed path, deactivates,
# and returns 'accept' so the caller executes the ex-command.
# For directories: navigates into the subdirectory (re-completes) and
# returns a truthy non-'accept' value so the caller treats it as consumed.
# Returns 0 if no candidate is available.
# ==========================================================================
sub _accept {
    my ($self) = @_;
    return 0 unless $self->{active} && @{$self->{candidates}};

    my $selected = $self->{candidates}[$self->{selected_idx}];
    return 0 unless defined $selected;

    # If the selected candidate is a directory, navigate into it instead
    # of trying to execute :e on a directory path.
    if ($selected =~ m{/$}) {
        my $ce = $self->{ctx}{cmd_entry};
        my $dp = $self->_dir_prefix();
        my $new_base = $dp . $selected;
        $self->{partial_base} = $new_base;
        $ce->set_text($self->{cmd_prefix} . $new_base);
        $ce->set_position(-1);
        # Re-complete to show the contents of the subdirectory
        $self->_recomplete();
        return 1;   # consumed (not 'accept')
    }

    # For files: update the entry with the full path and accept
    my $ce = $self->{ctx}{cmd_entry};
    $self->_update_entry();
    $self->deactivate();
    return 'accept';
}

# ==========================================================================
# _select_prev() - move selection to the previous candidate (wrap)
# ==========================================================================
sub _select_prev {
    my ($self) = @_;
    return unless $self->{active} && @{$self->{candidates}};
    my $n = scalar @{$self->{candidates}};
    $self->{selected_idx} = ($self->{selected_idx} - 1 + $n) % $n;
    $self->_update_entry();
    $self->_render();
}

# ==========================================================================
# _select_next() - move selection to the next candidate (wrap)
# ==========================================================================
sub _select_next {
    my ($self) = @_;
    return unless $self->{active} && @{$self->{candidates}};
    my $n = scalar @{$self->{candidates}};
    $self->{selected_idx} = ($self->{selected_idx} + 1) % $n;
    $self->_update_entry();
    $self->_render();
}

# ==========================================================================
# _update_entry() - set the entry text to the currently selected candidate
#
# We need to reconstruct the full path.  The completer's prefix already
# advanced in the entry, so we replace the path portion with the selected
# candidate, preserving the command prefix.
# ==========================================================================
sub _update_entry {
    my ($self) = @_;
    return unless $self->{active};

    my $ce = $self->{ctx}{cmd_entry};
    my $selected = $self->{candidates}[$self->{selected_idx}];
    return unless defined $selected;

    # Reconstruct the full path: directory prefix from partial_base +
    # the selected candidate basename.  _dir_prefix() handles both
    # cases: partial_base="lib/Gtk3" -> dir="lib/" and
    # partial_base="lib/" -> dir="lib/".
    my $dp = $self->_dir_prefix();
    $ce->set_text($self->{cmd_prefix} . $dp . $selected);
    $ce->set_position(-1);
}

# ==========================================================================
# _render() - update the mode label with candidates, highlighting selection
#
# Uses Pango markup to highlight the selected entry with a different
# background.  If there are too many candidates, truncates the list.
# ==========================================================================
sub _render {
    my ($self) = @_;
    return unless $self->{active};

    my $label = $self->{ctx}{mode_label};
    my @c     = @{$self->{candidates}};
    my $sel   = $self->{selected_idx};
    my $n     = scalar @c;

    # Truncate display if too many candidates
    my $max_display = 10;
    my $truncated = 0;
    if ($n > $max_display) {
        $truncated = $n - $max_display;
        @c = @c[0 .. $max_display - 1];
    }

    my $markup = '';
    for my $i (0 .. $#c) {
        $markup .= '  ' if length $markup;
        if ($i == $sel) {
            # Highlight with background color
            $markup .= "<span background='#4a6ea9' foreground='white'>"
                     . _escape_xml($c[$i]) . "</span>";
        } else {
            $markup .= _escape_xml($c[$i]);
        }
    }

    if ($truncated) {
        $markup .= "  ...and " . $truncated . " more";
    }

    eval { $label->set_markup($markup); };
    # If set_markup is not available (e.g., MockLabel), fall back
    if ($@) {
        $label->set_text(join("  ", @{$self->{candidates}}));
    }
}

# ==========================================================================
# _escape_xml($str) - minimal XML entity escaping for Pango markup
# ==========================================================================
sub _escape_xml {
    my ($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::CompletionUI - Completion display and
interaction handler

=head1 SYNOPSIS

    my $c = Gtk3::SourceEditor::VimBindings::Completion->new();
    my $ui = Gtk3::SourceEditor::VimBindings::CompletionUI->new($ctx, $c);

    # In handle_command_entry:
    my $result = $ui->handle_key($k);
    if (!defined $result) {
        # Not handled, proceed normally
    } elsif ($result eq 'accept') {
        # Execute the command with the completed path
    } elsif ($result eq 'cancel') {
        # Exit command mode
    } else {
        # Consumed (return TRUE to GTK)
    }

=head1 DESCRIPTION

Manages the completion interaction state machine.  Keeps all completion-
related state (active/inactive, candidate list, selection index) internal,
exposing only C<handle_key()> and C<active()> to the rest of the system.

Key bindings while active:

    Tab     - re-complete with current entry text
    Left    - select previous candidate (wraps)
    Right   - select next candidate (wraps)
    Return  - accept selected candidate
    Escape  - cancel completion, exit command mode
    Other   - deactivate, let GTK handle normally

=cut
