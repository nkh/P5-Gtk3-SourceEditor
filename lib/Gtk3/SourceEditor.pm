package Gtk3::SourceEditor;
use strict;
use warnings;
use Gtk3;
use Glib ('TRUE', 'FALSE');
use Gtk3::SourceView;
use Pango;
use File::Slurper 'read_text';

use Gtk3::SourceEditor::VimBindings;
use Gtk3::SourceEditor::ThemeManager;
use Gtk3::SourceEditor::Config qw(parse_editor_config);
use Gtk3::SourceEditor::VimBuffer::Gtk3;

our $VERSION = '0.04';

sub new {
    my ($class, %opts) = @_;
    my $self = bless {}, $class;

    # --- Load config file (if specified) and merge into %opts ---
    # Config file values act as defaults; explicit constructor options win.
    if ($opts{config_file} && -f $opts{config_file}) {
        my $cfg = eval { parse_editor_config($opts{config_file}) };
        if ($@) { warn "Gtk3::SourceEditor: $@" }
        if ($cfg && ref $cfg eq 'HASH') {
            # Map config keys to constructor option names.
            # Only set values that weren't explicitly passed.
            my %map = (
                theme           => 'theme',
                theme_file      => 'theme_file',
                font_family     => 'font_family',
                font_size       => 'font_size',
                wrap            => 'wrap',
                read_only       => 'read_only',
                vim_mode        => 'vim_mode',
                show_line_numbers        => 'show_line_numbers',
                highlight_current_line  => 'highlight_current_line',
                auto_indent              => 'auto_indent',
                tab_width                => 'tab_width',
                indent_width             => 'indent_width',
                insert_spaces_instead_of_tabs => 'insert_spaces_instead_of_tabs',
                smart_home_end           => 'smart_home_end',
                show_right_margin        => 'show_right_margin',
                right_margin_position   => 'right_margin_position',
                highlight_matching_brackets => 'highlight_matching_brackets',
                show_line_marks          => 'show_line_marks',
                block_cursor             => 'block_cursor',
                force_language           => 'force_language',
                use_clipboard            => 'use_clipboard',
                tab_string               => 'tab_string',
                scrolloff                => 'scrolloff',
                scroll_mode              => 'scroll_mode',
            );
            for my $ck (keys %$cfg) {
                my $opt_key = $map{$ck};
                next unless defined $opt_key;
                next if defined $opts{$opt_key};  # explicit option wins
                $opts{$opt_key} = $cfg->{$ck};
            }
            # theme_name → theme_file: if 'theme' is a known name, build the path
            if (exists $cfg->{theme} && !defined $opts{theme_file}) {
                my $tn = $cfg->{theme};
                if ($tn ne 'default' && $tn !~ m{[/\\.]}) {
                    $opts{theme_file} = "themes/theme_$tn.xml";
                } elsif ($tn eq 'default') {
                    $opts{theme_file} = 'themes/default.xml';
                }
            }
            # theme_file from config takes precedence over theme name
            if (exists $cfg->{theme_file} && length $cfg->{theme_file}) {
                $opts{theme_file} = $cfg->{theme_file};
            }
        }
    }

    $self->{filename}      = $opts{file};
    $self->{font_size}     = $opts{font_size} // 0;
    $self->{font_family}   = $opts{font_family} // 'Monospace';
    $self->{wrap}          = defined $opts{wrap} ? $opts{wrap} : 1;
    $self->{read_only}     = $opts{read_only} // 0;
    $self->{on_close}      = $opts{on_close};
    $self->{window}        = $opts{window};
    $self->{keymap}        = $opts{keymap};
    $self->{vim_mode}      = defined $opts{vim_mode} ? $opts{vim_mode} : 1;
    $self->{force_language} = $opts{force_language};
    $self->{tab_string}    = defined $opts{tab_string} ? $opts{tab_string} : "\t";
    $self->{block_cursor}      = defined $opts{block_cursor} ? $opts{block_cursor} : 0;
    $self->{highlight_current_line} = defined $opts{highlight_current_line} ? $opts{highlight_current_line} : 1;
    $self->{use_clipboard}     = $opts{use_clipboard} // 0;
    $self->{show_line_numbers} = defined $opts{show_line_numbers} ? $opts{show_line_numbers} : 1;

    $self->_build_ui(%opts);
    return $self;
}

# ==========================================================================
# _build_ui( %opts )
#
# All GTK method calls go through the $_call helper which checks
# $obj->can($method) before dispatching.  This prevents crashes when
# running against older GtkSourceView 3.x releases that lack certain
# methods (e.g. set_indent_width was added in 3.16,
# set_show_line_marks in 2.2, etc.).
# ==========================================================================

sub _build_ui {
    my ($self, %opts) = @_;

    # --- Safe-call helper: die never, warn once per missing method ---
    my %_missing_warned;
    my $_call = sub {
        my ($obj, $method, @args) = @_;
        return unless $obj && $method;
        if ($obj->can($method)) {
            return $obj->$method(@args);
        }
        unless ($_missing_warned{$method}) {
            warn "Gtk3::SourceEditor: method '$method' not available on "
               . ref($obj) . " (feature skipped)\n";
            $_missing_warned{$method} = 1;
        }
        return;
    };

    # Load Theme
    my $theme_data = Gtk3::SourceEditor::ThemeManager::load(file => $opts{theme_file});
    my $fg = $theme_data->{fg};
    my $bg = $theme_data->{bg};

    # Helper to convert "#RRGGBB" to a GdkRGBA object safely across all GTK3 versions
    my $parse_hex = sub {
        my $h = shift;
        $h =~ s/^#//;
        my $r = hex(substr($h, 0, 2)) / 255.0;
        my $g = hex(substr($h, 2, 2)) / 255.0;
        my $b = hex(substr($h, 4, 2)) / 255.0;

        my $rgba = Gtk3::Gdk::RGBA->new();
        $rgba->red($r);
        $rgba->green($g);
        $rgba->blue($b);
        $rgba->alpha(1.0);

        return $rgba;
    };

    my $fg_rgba = $parse_hex->($fg);
    my $bg_rgba = $parse_hex->($bg);

    # Main Container
    $self->{widget} = Gtk3::Box->new('vertical', 0);

    # Text Buffer & View
    my $lm = Gtk3::SourceView::LanguageManager->get_default();
    my $lang;
    if ($self->{force_language}) {
        # Explicitly set language -- useful for files without extensions
        # or files with misleading extensions.  Accepts language IDs known
        # to GtkSourceView (e.g. 'perl', 'python', 'c', 'javascript',
        # 'xml', 'json', 'sql', 'sh', 'markdown', etc.).
        $lang = $lm->get_language($self->{force_language});
        unless ($lang) {
            warn "Gtk3::SourceEditor: unknown language '$self->{force_language}', "
               . "falling back to auto-detection\n";
            $lang = $lm->guess_language($self->{filename}, undef)
                 || $lm->get_language('perl');
        }
    } else {
        # Auto-detect from filename extension and MIME type
        $lang = $lm->guess_language($self->{filename}, undef)
             || $lm->get_language('perl');
    }
    $self->{buffer} = Gtk3::SourceView::Buffer->new_with_language($lang);
    $_call->($self->{buffer}, 'set_highlight_syntax', TRUE);

    if ($self->{filename} && -e $self->{filename}) {
        eval { $self->{buffer}->set_text(read_text($self->{filename})); };
        warn "Failed to read $self->{filename}: $@" if $@;
    }
    $_call->($self->{buffer}, 'place_cursor', $self->{buffer}->get_start_iter());
    $_call->($self->{buffer}, 'set_modified', FALSE);
    $_call->($self->{buffer}, 'set_style_scheme', $theme_data->{scheme});

    $self->{textview} = Gtk3::SourceView::View->new();
    $_call->($self->{textview}, 'set_buffer', $self->{buffer});
    $_call->($self->{textview}, 'set_show_line_numbers',
             $self->{show_line_numbers} ? TRUE : FALSE);
    $_call->($self->{textview}, 'set_highlight_current_line',
             $self->{highlight_current_line} ? TRUE : FALSE);
    if (defined $self->{auto_indent}) {
        $_call->($self->{textview}, 'set_auto_indent',
                 $self->{auto_indent} ? TRUE : FALSE);
    }
    $_call->($self->{textview}, 'set_wrap_mode', $self->{wrap} ? 'word' : 'none');

    # Tab behaviour
    my $isp = defined $self->{insert_spaces_instead_of_tabs}
            ? $self->{insert_spaces_instead_of_tabs} : 0;
    $_call->($self->{textview}, 'set_insert_spaces_instead_of_tabs',
             $isp ? TRUE : FALSE);

    # Tab width
    if (defined $opts{tab_width} && $opts{tab_width} > 0) {
        $_call->($self->{textview}, 'set_tab_width', $opts{tab_width});
    }

    # Indent width (available since GtkSourceView 3.16)
    if (defined $opts{indent_width} && $opts{indent_width} > 0) {
        $_call->($self->{textview}, 'set_indent_width', $opts{indent_width});
    }

    # Right margin
    if (defined $opts{show_right_margin}) {
        $_call->($self->{textview}, 'set_show_right_margin',
                 $opts{show_right_margin} ? TRUE : FALSE);
    }
    if (defined $opts{right_margin_position} && $opts{right_margin_position} > 0) {
        $_call->($self->{textview}, 'set_right_margin_position',
                 $opts{right_margin_position});
    }

    # Smart Home/End (available since GtkSourceView 3.0)
    if (defined $opts{smart_home_end}) {
        $_call->($self->{textview}, 'set_smart_home_end',
                 $opts{smart_home_end} ? 'after-line-start' : 'disabled');
    }

    # Highlight matching brackets (Buffer method, NOT View)
    if (defined $opts{highlight_matching_brackets}) {
        $_call->($self->{buffer}, 'set_highlight_matching_brackets',
                 $opts{highlight_matching_brackets} ? TRUE : FALSE);
    } else {
        $_call->($self->{buffer}, 'set_highlight_matching_brackets', TRUE);
    }

    # Show line marks (available since GtkSourceView 2.2)
    if (defined $opts{show_line_marks}) {
        $_call->($self->{textview}, 'set_show_line_marks',
                 $opts{show_line_marks} ? TRUE : FALSE);
    }

    # Cursor: always start with a visible native i-beam cursor.
    # Block cursor (Cairo-drawn) can be activated at runtime via
    # :set cursor=block  through the VimBindings layer.
    $_call->($self->{textview}, 'set_cursor_visible', TRUE);

    # Font
    my $pango_font = $self->{font_family} // 'Monospace';
    $pango_font .= " $self->{font_size}" if $self->{font_size} > 0;
    $_call->($self->{textview}, 'modify_font',
             Pango::FontDescription->from_string($pango_font));

    # Scrolled Window
    my $scroll = Gtk3::ScrolledWindow->new();
    $_call->($scroll, 'set_policy', 'automatic', 'automatic');
    $_call->($scroll, 'add', $self->{textview});
    $_call->($self->{widget}, 'pack_start', $scroll, TRUE, TRUE, 0);

    # Bottom Bar (Command Entry + Status Label + Position Label)
    my $bottom_box = Gtk3::Box->new('vertical', 0);

    $self->{cmd_entry} = Gtk3::Entry->new();
    $_call->($self->{cmd_entry}, 'set_no_show_all', TRUE);
    $_call->($self->{cmd_entry}, 'hide');

    $_call->($self->{cmd_entry}, 'override_color', 'normal', $fg_rgba);
    $_call->($self->{cmd_entry}, 'override_background_color', 'normal', $bg_rgba);

    # Status bar: horizontal box with mode label (left) and position (right)
    my $status_box = Gtk3::EventBox->new();
    $_call->($status_box, 'override_background_color', 'normal', $bg_rgba);
    my $status_inner = Gtk3::Box->new('horizontal', 0);

    $self->{mode_label} = Gtk3::Label->new('-- NORMAL --');
    $_call->($self->{mode_label}, 'override_color', 'normal', $fg_rgba);
    $_call->($self->{mode_label}, 'set_xalign', 0.0);

    $self->{pos_label} = Gtk3::Label->new('1:0');
    $_call->($self->{pos_label}, 'override_color', 'normal', $fg_rgba);
    $_call->($self->{pos_label}, 'set_xalign', 1.0);
    $_call->($self->{pos_label}, 'set_margin_end', 6);

    $_call->($status_inner, 'pack_start', $self->{mode_label}, TRUE, TRUE, 4);
    $_call->($status_inner, 'pack_end', $self->{pos_label}, FALSE, FALSE, 0);
    $_call->($status_box, 'add', $status_inner);

    $_call->($bottom_box, 'pack_end', $status_box, FALSE, FALSE, 0);
    $_call->($bottom_box, 'pack_end', $self->{cmd_entry}, FALSE, FALSE, 0);
    $_call->($self->{widget}, 'pack_end', $bottom_box, FALSE, FALSE, 0);

    # Connect a pre-vim key handler if provided (runs before vim bindings
    # so it can intercept specific keys like Alt+Arrow).  Must return TRUE
    # to consume the event, FALSE to pass it to vim bindings.
    if ($opts{key_handler}) {
        $_call->($self->{textview}, 'signal_connect',
                 'key-press-event' => $opts{key_handler});
    }

    # Track cursor position via mark-set signal (not the draw handler).
    # This is more efficient and avoids any interaction with the draw cycle
    # that could interfere with mode label updates.
    if ($self->{pos_label}) {
        $_call->($self->{buffer}, 'signal_connect', 'mark-set' => sub {
            my ($buf, $iter, $mark) = @_;
            return unless defined $mark->get_name && $mark->get_name eq 'insert';
            $self->{pos_label}->set_text(
                sprintf("%d:%d", $iter->get_line + 1, $iter->get_line_offset)
            );
        });
    }

    # Create VimBuffer adapter and attach bindings (if vim mode enabled)
    if ($self->{vim_mode}) {
        my $vb = Gtk3::SourceEditor::VimBuffer::Gtk3->new(
            buffer => $self->{buffer},
            view   => $self->{textview},
        );
        Gtk3::SourceEditor::VimBindings::add_vim_bindings(
            $self->{textview},
            $self->{mode_label},
            $self->{cmd_entry},
            \$self->{filename},
            $self->{read_only},
            ( defined $self->{keymap} ? ( keymap => $self->{keymap} ) : () ),
            vim_buffer    => $vb,
            tab_string    => $self->{tab_string},
            use_clipboard => $self->{use_clipboard},
            pos_label     => $self->{pos_label},
            scrolloff     => $self->{scrolloff},
            scroll_mode   => $opts{scroll_mode},
            on_ready      => $opts{on_ready},
            theme         => { fg => $fg, bg => $bg },
        );
    } else {
        # Native Gtk3::SourceView mode -- no vim bindings, use standard GTK keybindings
        # (Ctrl+C/V/X/Z/A, arrow keys, Tab indent, etc.)
        $_call->($self->{cmd_entry}, 'hide');
        $_call->($self->{mode_label}, 'set_text', '');
    }

    # Hook into window close event to trigger callback
    if ($self->{window} && $self->{on_close}) {
        $_call->($self->{window}, 'signal_connect', 'destroy' => sub {
            $self->{on_close}->($self->get_text);
        });
    }
}

sub get_widget {
    my ($self) = @_;
    return $self->{widget};
}

sub get_text {
    my ($self) = @_;
    return $self->{buffer}->get_text(
        $self->{buffer}->get_start_iter,
        $self->{buffer}->get_end_iter, TRUE
    );
}

sub get_buffer {
    my ($self) = @_;
    return $self->{buffer};
}

1;

__END__

=encoding UTF-8

=head1 NAME

Gtk3::SourceEditor - Embeddable Vim-like text editor widget for Gtk3 applications

=head1 SYNOPSIS

    use Gtk3::SourceEditor;

    my $editor = Gtk3::SourceEditor->new(
        file       => 'my_script.pl',
        theme_file => 'themes/theme_dark.xml',
        font_size  => 12,
        wrap       => 1,
        read_only  => 0,
        window     => $main_window,
        on_close   => sub { my $text = shift; ... },
        keymap     => \%custom_keymap,
    );

    # Force syntax highlighting for a file without an extension:
    my $editor = Gtk3::SourceEditor->new(
        file           => 'Makefile',
        force_language => 'makefile',
    );

    # Without vim bindings (native Gtk3::SourceView keybindings):
    my $editor = Gtk3::SourceEditor->new(
        file     => 'my_script.pl',
        vim_mode => 0,
    );

    my $widget = $editor->get_widget();
    $vbox->pack_start($widget, TRUE, TRUE, 0);

=head1 DESCRIPTION

Gtk3::SourceEditor provides a complete, modular, embeddable text editor widget
for any Gtk3 application. It is built on top of Gtk3::SourceView and
includes syntax highlighting, Vim-like modal keybindings, theme support,
and a command mode for saving and quitting.

When C<vim_mode> is set to C<0> (default is C<1>), the Vim keybindings are not
loaded and the native Gtk3::SourceView keybindings are preserved. This gives
the user standard GTK text editing: Ctrl+C/V/X (copy/paste/cut), Ctrl+Z
(undo), Ctrl+A (select all), arrow keys, Tab indentation, etc. The mode label
and command entry are hidden in this mode.

All GtkSourceView method calls are dispatched through an internal safe-call
helper that checks C<< $obj->can($method) >> before calling.  This means
the widget degrades gracefully on older GtkSourceView 3.x releases that lack
certain methods (e.g. C<set_indent_width> was added in 3.16,
C<set_show_line_marks> in 2.2, etc.).  A one-time warning is emitted for any
method that is not available, and the corresponding feature is silently skipped.

=head1 CONSTRUCTOR

=head2 new( %opts )

Creates and returns a new editor widget instance. Accepts the following options:

=head3 file => $filename (optional)

Path to the file to load into the editor. If the file exists, its contents are
read and displayed. The filename is also used by C<guess_language()> to
determine syntax highlighting when C<force_language> is not set. This value
is stored as a reference so that ex-commands like C<:w> and C<:e> can update
it. If omitted or C<undef>, the editor starts with an empty buffer.

=head3 theme_file => $path (optional, default: 'themes/default.xml')

Path to a GtkSourceView XML theme file. The file is parsed by
L<ThemeManager> which extracts foreground/background colors and injects a
cursor style if missing, then installs the scheme via the
C<StyleSchemeManager>. The theme is also used to style the mode label and
command entry via dynamically generated CSS. Four built-in themes are shipped
in the C<themes/> directory: C<default.xml>, C<theme_dark.xml>,
C<theme_light.xml>, and C<theme_solarized.xml>.

=head3 font_size => $integer (optional, default: 0)

Font point size for the editor text. When set to 0 (the default), the system
default monospace font size is used. When set to a positive integer (e.g. 12),
the font is set to C<"Monospace $size"> via Pango. The font is applied to the
Gtk3::SourceView widget via C<modify_font()>.

=head3 wrap => $boolean (optional, default: 1)

Controls line wrapping in the text view. When true (the default), lines that
exceed the widget width wrap at word boundaries (C<'word'> wrap mode). When
false, long lines scroll horizontally without wrapping (C<'none'> wrap mode).

=head3 read_only => $boolean (optional, default: 0)

When set to a true value, the buffer is opened in read-only mode. Attempting
to enter insert or replace mode displays C<"-- READ ONLY --"> in the mode
label and blocks the mode transition. The modified flag is not set, and all
editing actions that modify the buffer are effectively prevented. The user can
still navigate, search, and use ex-commands like C<:q>.

=head3 window => $gtk_window (optional)

A C<Gtk3::Window> (or C<Gtk3::Dialog>) to which the editor belongs. When
provided together with C<on_close>, the window's C<destroy> signal is
connected to the C<on_close> callback, which receives the full buffer text as
its only argument. This allows the embedding application to capture the editor
contents when the window is closed.

=head3 on_close => $coderef (optional)

A callback invoked when the window (specified by C<window>) is destroyed.
Receives the complete buffer text as a single string argument. This is useful
for saving editor contents, updating application state, or cleaning up resources
when the editor is closed. Has no effect unless C<window> is also specified.

=head3 keymap => \%custom_keymap (optional)

A hashref for customizing Vim keybindings. The hash is structured by mode
(normal, insert, visual, etc.), with each mode containing key-to-action-name
mappings. Keys prefixed with underscore (C<_immediate>, C<_prefixes>,
C<_char_actions>, C<_ctrl>) have special meaning for the dispatch engine.
Set a key's value to C<undef> to remove it from the default keymap. See
L<Gtk3::SourceEditor::VimBindings> for the full keymap format.

=head3 vim_mode => $boolean (optional, default: 1)

Controls whether Vim-like modal keybindings are loaded. When set to 1 (the
default), the full Vim emulation layer is attached: Normal, Insert, Replace,
Visual (char/line/block), and Command modes are all available with their
complete keybinding sets. When set to 0, no Vim bindings are attached; the
Gtk3::SourceView widget uses its native GTK keybindings (Ctrl+C/V/X/Z for
copy/paste/cut/undo, Ctrl+A for select all, arrow keys, Tab for indentation,
etc.). The mode label is hidden and the command entry is hidden in this mode.

=head3 force_language => $language_id (optional)

Overrides automatic language detection for syntax highlighting. Accepts any
language ID recognized by the system's GtkSourceView C<LanguageManager>
(e.g. C<'perl'>, C<'python'>, C<'c'>, C<'javascript'>, C<'xml'>, C<'json'>,
C<'sql'>, C<'sh'>, C<'markdown'>, C<'makefile'>, C<'html'>, C<'css'>, etc.).

By default, GtkSourceView guesses the language from the filename extension and
MIME type via C<guess_language()>. This works well for files with standard
extensions (C<.pl>, C<.py>, C<.c>), but fails for extensionless files like
C<Makefile>, C<Dockerfile>, C<Vagrantfile>, or files with ambiguous extensions.
Setting C<force_language> bypasses the guess and directly sets the highlighting
language.

If the specified language ID is not found, a warning is emitted and the editor
falls back to automatic detection. The language can also be set to C<undef> or
omitted to use the default auto-detection behavior.

=head3 show_line_numbers => $boolean (optional, default: 1)

Controls whether line numbers are displayed in the left gutter. When true
(the default), line numbers are shown and the gutter width adjusts
automatically as the document grows. When false, no line numbers are shown
and the full widget width is available for text. This also affects the
coordinate system used by the block cursor (C<:set cursor=block>), since
the gutter offset is removed when line numbers are disabled.

=head3 key_handler => $coderef (optional)

A coderef connected to the textview's C<key-press-event> signal I<before>
vim bindings. Receives C<($widget, $event)> and must return TRUE to
consume the key or FALSE to pass it through to the vim bindings layer.
Use this to intercept specific key combinations that vim bindings would
otherwise consume (e.g. Alt+Arrow for dialog movement, F-keys for UI
toggles).

=head3 on_ready => $coderef (optional)

A coderef invoked once after all initialisation is complete. Receives the
vim bindings context hashref (C<$ctx>) which provides access to
C<gtk_view>, C<mode_label>, C<pos_label>, C<set_cursor_mode>, and other
internals. Use it to attach custom signal handlers for debugging or
extended functionality (e.g. a Cairo draw hook). Only called when vim mode
is enabled.

=head3 scroll_mode => $mode (optional, default: 'edge')

Controls how the viewport follows the cursor during vertical navigation in
normal mode. Accepts two static values that can be set at construction time
or via the configuration file:

=over 4

=item C<'edge'> (default)

The cursor moves freely within the viewport. Scrolling only starts when the
cursor reaches the top or bottom edge of the visible area. This matches
standard GTK text widget behavior and is comfortable for most editing tasks.

=item C<'center'>

The cursor is kept vertically centered in the viewport during navigation.
Near the beginning or end of the buffer, GTK automatically relaxes centering
so the cursor can still reach the first and last lines. This mode is useful
for reading code or following long functions.

=back

A third mode, C<scroll_lock>, is available only as a runtime toggle via the
C<zx> key binding. When activated, the cursor is frozen at its current screen
position and j/k (or arrow keys) scroll the buffer underneath instead of moving
the cursor. Pressing C<zx> again deactivates scroll lock and restores the
previous mode (edge or center). The scroll mode can also be changed at runtime
via the ex-command C<:set scroll_mode=edge> or C<:set scroll_mode=center>,
and the current mode can be queried with C<:set scroll_mode>.

When the C<scrolloff> option is set to a positive integer, it takes precedence
over C<scroll_mode> by enforcing a minimum context margin around the cursor.
Set C<scrolloff> to 0 or leave it undefined to use C<scroll_mode>.

=head1 DEPENDENCIES

Gtk3, Gtk3::SourceView, Glib, Pango, File::Slurper.

=head1 ACCESSOR METHODS

=head2 get_widget()

    my $gtk_box = $editor->get_widget();

Returns the root C<Gtk3::Box> widget containing the scrolled text view, command
entry, and mode label. This widget should be packed into the parent container
(e.g., C<$vbox-E<gt>pack_start($editor-E<gt>get_widget, TRUE, TRUE, 0)>).

=head2 get_text()

    my $content = $editor->get_text();

Returns the entire buffer contents as a single string, including all line
breaks. This is typically used in the C<on_close> callback or when saving
programmatically.

=head2 get_buffer()

    my $source_buffer = $editor->get_buffer();

Returns the underlying C<Gtk3::SourceView::Buffer> object, giving direct access
to the GTK text buffer for advanced operations (signals, marks, tags, etc.).
Note that operating on the buffer directly bypasses the Vim undo/redo stack
and may interfere with the Vim bindings layer.

=head1 AUTHOR

Original by nkh. See L<Gtk3::SourceEditor::VimBindings> for binding architecture.

=head1 LICENSE

Artistic License 2.0.

=cut
