package Gtk3::SourceEditor::VimBindings::Command;
use strict;
use warnings;
use Glib qw(TRUE FALSE);

our $VERSION = '0.04';

sub register {
    my ($ACTIONS) = @_;

    # --- Show bindings help ---
    $ACTIONS->{cmd_show_bindings} = sub {
        my ($ctx) = @_;
        eval { _show_bindings_dialog($ctx) };
        warn "bindings help error: $@" if $@;
    };

    # --- Browse (GTK file picker) ---
    $ACTIONS->{cmd_browse} = sub {
        my ($ctx, $count, $parsed) = @_;
        my $tv = $ctx->{gtk_view} or return;
        my $parent = eval { $tv->get_toplevel } or return;

        my $chooser = Gtk3::FileChooserDialog->new(
            'Open File', $parent, 'open',
            'Cancel' => 'cancel',
            'Open'   => 'ok',
        );
        # Default to current file's directory
        my $cur_file = ${$ctx->{filename_ref}};
        if (defined $cur_file && -f $cur_file) {
            eval {
                use File::Basename;
                $chooser->set_current_folder(dirname($cur_file));
            };
        }
        my $resp = $chooser->run;
        if ($resp eq 'ok') {
            my $file = $chooser->get_filename;
            $chooser->destroy;
            return unless defined $file && length $file;
            # Open the selected file (same as :e)
            $ACTIONS->{cmd_edit}->($ctx, 1, { args => [$file] });
        } else {
            $chooser->destroy;
        }
    };

    # --- Quit ---
    $ACTIONS->{cmd_quit} = sub {
        my ($ctx, $count, $parsed) = @_;
        if ($parsed->{bang}) { eval { Gtk3->main_quit() }; return; }
        if ($ctx->{vb}->modified) {
            $ctx->{show_status}->("Error: No write since last change (use :q!)") if $ctx->{show_status};
            return;
        }
        eval { Gtk3->main_quit() };
    };

    $ACTIONS->{cmd_force_quit} = sub { eval { Gtk3->main_quit() } };

    # --- Save ---
    $ACTIONS->{cmd_save} = sub {
        my ($ctx, $count, $parsed) = @_;
        _cmd_save($ctx, $parsed->{args}[0]);
    };

    # --- Save and quit ---
    $ACTIONS->{cmd_save_quit} = sub {
        my ($ctx, $count, $parsed) = @_;
        _cmd_save($ctx, undef);
        eval { Gtk3->main_quit() };
    };

    # --- Edit (open file) ---
    $ACTIONS->{cmd_edit} = sub {
        my ($ctx, $count, $parsed) = @_;
        my $file = $parsed->{args}[0];
        unless (defined $file && length $file) {
            $ctx->{show_status}->("Error: No filename") if $ctx->{show_status};
            return;
        }
        $file =~ s/^\s+|\s+$//g;
        unless (-e $file) {
            $ctx->{show_status}->("Error: File '$file' not found") if $ctx->{show_status};
            return;
        }
        eval {
            open my $fh, '<', $file or die $!;
            my $content = do { local $/; <$fh> };
            close $fh;
            chomp $content;  # Remove trailing newline to match buffer convention
            my $vb = $ctx->{vb};
            $vb->set_text($content);
            $vb->set_modified(0);
            ${$ctx->{filename_ref}} = $file;
            # Scroll to top of file
            if ($ctx->{gtk_view} && $vb->can('gtk_buffer')) {
                my $buf = $vb->gtk_buffer;
                $buf->place_cursor($buf->get_start_iter);
                $ctx->{gtk_view}->scroll_to_mark($buf->get_insert(), 0.0, 1, 0, 0.0);
            }
            $ctx->{show_status}->("Opened: $file") if $ctx->{show_status};
        };
        if ($@) { chomp $@; $ctx->{show_status}->("Error: $@") if $ctx->{show_status}; }
    };

    # --- Read (insert file) ---
    $ACTIONS->{cmd_read} = sub {
        my ($ctx, $count, $parsed) = @_;
        my $file = $parsed->{args}[0];
        unless (defined $file && length $file) {
            $ctx->{show_status}->("Error: No filename") if $ctx->{show_status};
            return;
        }
        $file =~ s/^\s+|\s+$//g;
        eval {
            open my $fh, '<', $file or die $!;
            my $content = do { local $/; <$fh> };
            close $fh;
            my $vb = $ctx->{vb};
            $vb->set_cursor($vb->cursor_line, $vb->line_length($vb->cursor_line));
            $vb->insert_text("\n" . $content);
            $ctx->{show_status}->("Read: $file") if $ctx->{show_status};
        };
        if ($@) { chomp $@; $ctx->{show_status}->("Error: $@") if $ctx->{show_status}; }
    };

    # --- Substitute ---
    $ACTIONS->{cmd_substitute} = sub {
        my ($ctx, $count, $parsed) = @_;
        my $arg = $parsed->{args}[0] // '';
        my $sub = _parse_substitute($arg);
        unless ($sub) {
            $ctx->{show_status}->("Error: Invalid substitute syntax (use /pattern/replacement/flags)") if $ctx->{show_status};
            return;
        }

        my $vb = $ctx->{vb};
        my $re = eval { qr/$sub->{pattern}/ };
        unless ($re) {
            $ctx->{show_status}->("Error: Invalid regex: $sub->{pattern}") if $ctx->{show_status};
            return;
        }

        my $range = $parsed->{range};
        my ($start, $end);
        if (defined $range && $range eq '%') {
            $start = 0;
            $end = $vb->line_count - 1;
        } elsif (defined $range && $range =~ /^(\d+),(\d+)$/) {
            $start = $1 - 1;
            $end   = $2 - 1;
            $start = 0 if $start < 0;
            $end = $vb->line_count - 1 if $end >= $vb->line_count;
        } else {
            $start = $vb->cursor_line;
            $end   = $start;
        }

        # Collect modified lines
        my @new_lines;
        for my $ln ($start .. $end) {
            my $text = $vb->line_text($ln);
            if ($sub->{global}) {
                $text =~ s/$re/$sub->{replacement}/g;
            } else {
                $text =~ s/$re/$sub->{replacement}/;
            }
            push @new_lines, $text;
        }

        # Replace the range in the buffer
        my $del_end_line = $end;
        my $del_end_col  = $vb->line_length($end);
        if ($end < $vb->line_count - 1) {
            $del_end_line = $end + 1;
            $del_end_col  = 0;
        }
        $vb->delete_range($start, 0, $del_end_line, $del_end_col);
        $vb->set_cursor($start, 0);
        $vb->insert_text(join("\n", @new_lines));
        $vb->set_cursor($start, 0);

        my $count_matches = @new_lines;
        $ctx->{show_status}->("$count_matches line(s) substituted") if $ctx->{show_status};
    };

    # --- Goto line number ---
    $ACTIONS->{cmd_goto_line} = sub {
        my ($ctx, $count, $parsed) = @_;
        my $vb = $ctx->{vb};
        my $target = $parsed->{line_number};
        if (!defined $target) {
            # Default: go to last line (like bare G)
            $target = $vb->line_count;
        }
        $target = $target - 1;  # Convert 1-based to 0-based
        $target = 0 if $target < 0;
        $target = $vb->line_count - 1 if $target >= $vb->line_count;
        $vb->set_cursor($target, 0);
        $ctx->{after_move}->($ctx) if $ctx->{after_move};
    };

    # --- Set option ---
    $ACTIONS->{cmd_set} = sub {
        my ($ctx, $count, $parsed) = @_;
        my $arg = $parsed->{args}[0] // '';
        $arg =~ s/^\s+|\s+$//g;
        return unless length $arg;

        if ($arg eq 'cursor=block' || $arg eq 'cursor=ibeam') {
            my $mode = ($arg eq 'cursor=block') ? 'block' : 'ibeam';
            if ($ctx->{set_cursor_mode}) {
                $ctx->{set_cursor_mode}->($mode);
            } else {
                my $view = $ctx->{gtk_view};
                if ($view) {
                    eval { $view->set_property('cursor-shape',
                              $mode eq 'block' ? 0 : 1) };
                    if ($@) {
                        $ctx->{show_status}->("Error: cursor-shape not supported") if $ctx->{show_status};
                    }
                }
            }
        } elsif ($arg =~ /^scrolloff\s*=\s*(.+)$/i) {
            my $val = $1;
            $val =~ s/^\s+|\s+$//g;
            if ($val =~ /^(?:center)$/i) {
                $ctx->{scrolloff} = lc($val);
                $ctx->{show_status}->("scrolloff=center") if $ctx->{show_status};
            } elsif ($val =~ /^(\d+)$/) {
                $ctx->{scrolloff} = 0 + $1;
                $ctx->{show_status}->("scrolloff=$ctx->{scrolloff}") if $ctx->{show_status};
            } else {
                $ctx->{show_status}->("Error: invalid scrolloff value '$val'") if $ctx->{show_status};
            }
        } elsif ($arg =~ /^scrolloff$/i) {
            # Show current value
            my $val = defined $ctx->{scrolloff} ? $ctx->{scrolloff} : 'natural (default)';
            $ctx->{show_status}->("scrolloff=$val") if $ctx->{show_status};
        } elsif ($arg =~ /^scroll_mode\s*=\s*(.+)$/i) {
            my $val = $1;
            $val =~ s/^\s+|\s+$//g;
            if ($val =~ /^(edge|center)$/i) {
                $ctx->{_scroll_mode} = lc($val);
                $ctx->{_scroll_lock_active} = 0;
                $ctx->{_scroll_lock_prev} = undef;
                $ctx->{show_status}->("scroll_mode=$ctx->{_scroll_mode}") if $ctx->{show_status};
            } else {
                $ctx->{show_status}->("Error: invalid scroll_mode '$val' (edge|center)") if $ctx->{show_status};
            }
        } elsif ($arg =~ /^scroll_mode$/i) {
            # Show current value
            my $val = $ctx->{_scroll_lock_active} ? 'scroll_lock'
                    : ($ctx->{_scroll_mode} // 'edge');
            $ctx->{show_status}->("scroll_mode=$val") if $ctx->{show_status};
        } else {
            $ctx->{show_status}->("Error: Unknown option '$arg'") if $ctx->{show_status};
        }
    };

    return {
        bindings => 'cmd_show_bindings',
        browse   => 'cmd_browse',
        q        => 'cmd_quit',
        w        => 'cmd_save',
        wq       => 'cmd_save_quit',
        e        => 'cmd_edit',
        r        => 'cmd_read',
        s        => 'cmd_substitute',
        set      => 'cmd_set',
    };
}

# --- Ex-command parser ---
sub parse_ex_command {
    my ($raw) = @_;
    $raw //= '';
    $raw =~ s/^[:\/?]\s*//;  # Strip leading :, /, or ?
    $raw =~ s/\s+$//;
    return undef unless length $raw;

    my %p = (cmd => undef, args => [], bang => 0, range => undef, line_number => undef);

    # Check for bare line number (e.g., :42)
    if ($raw =~ /^(\d+)$/) {
        return { cmd => 'goto_line', line_number => 0 + $1, args => [], bang => 0, range => undef };
    }

    # Range prefix
    if ($raw =~ s/^([%\d,]+)\s*//) { $p{range} = $1; }

    # Bang
    if ($raw =~ s/!\s*$//) { $p{bang} = 1; }

    # Command name
    if ($raw =~ s/^(\w+)//) { $p{cmd} = $1; }

    $raw =~ s/^\s+//; $raw =~ s/\s+$//;
    if (length $raw) {
        $p{args} = $raw =~ m{^/} ? [$raw] : [split /\s+/, $raw];
    }

    return \%p;
}

# --- Internal helpers ---
sub _parse_substitute {
    my ($arg) = @_;
    return undef unless defined $arg;
    # Support /pattern/replacement/flags or other delimiters
    if ($arg =~ m{^/(.+)/([^/]*)/(g?)$}) {
        return { pattern => $1, replacement => $2, global => ($3 eq 'g') };
    }
    return undef;
}

sub _show_bindings_dialog {
    my ($ctx) = @_;
    my $tv = $ctx->{gtk_view} or return;
    my $parent = eval { $tv->get_toplevel } // undef;

    my $window = Gtk3::Window->new('toplevel');
    $window->set_title('Key Bindings');
    $window->set_transient_for($parent) if $parent;
    $window->set_default_size(700, 500);
    $window->set_modal(TRUE);
    $window->set_decorated(FALSE);
    $window->set_name('bindings_window');

    # TreeStore: Mode | Key | Action
    my $store = Gtk3::TreeStore->new('Glib::String', 'Glib::String', 'Glib::String');

    my $all_sections = generate_bindings_list($ctx);
    my $filter_text = '';

    # Populate / re-populate the store.  Instead of a TreeModelFilter
    # (whose set_visible_func callback breaks on Perl 5.36 GI), we
    # rebuild the store on every keystroke.  With ~100 bindings this
    # is instantaneous and avoids all callback-marshalling issues.
    my $populate_store = sub {
        $store->clear;
        my $ft = $filter_text;
        for my $section (@$all_sections) {
            my @matching = grep {
                !length($ft)
                || lc($_->{key})    =~ /\Q$ft\E/
                || lc($_->{action}) =~ /\Q$ft\E/
            } @{$section->{bindings}};
            next unless @matching;
            my $mode_iter = $store->append(undef);
            $store->set($mode_iter, 0, $section->{mode}, 1, '', 2, '');
            for my $b (@matching) {
                my $child_iter = $store->append($mode_iter);
                $store->set($child_iter, 0, '', 1, $b->{key}, 2, $b->{action});
            }
        }
    };

    $populate_store->();

    my $treeview = Gtk3::TreeView->new_with_model($store);
    $treeview->set_name('bindings_tree');
    $treeview->set_headers_visible(TRUE);
    $treeview->set_enable_search(TRUE);
    $treeview->expand_all;

    # Column 0: Mode (tree expander, bold)
    my $renderer_mode = Gtk3::CellRendererText->new();
    $renderer_mode->set('weight', 700);
    my $col_mode = Gtk3::TreeViewColumn->new_with_attributes(
        'Mode', $renderer_mode, text => 0
    );

    # Column 1: Key (monospace, sortable)
    my $renderer_key = Gtk3::CellRendererText->new();
    eval {
        my $font_desc = Pango::FontDescription->from_string('Monospace 10');
        $renderer_key->set('font-desc', $font_desc);
    };
    my $col_key = Gtk3::TreeViewColumn->new_with_attributes(
        'Key', $renderer_key, text => 1
    );
    $col_key->set_sort_column_id(1);
    $col_key->set_resizable(TRUE);
    $col_key->set_min_width(120);

    # Column 2: Action (proportional, sortable, expand to fill)
    my $renderer_action = Gtk3::CellRendererText->new();
    my $col_action = Gtk3::TreeViewColumn->new_with_attributes(
        'Action', $renderer_action, text => 2
    );
    $col_action->set_sort_column_id(2);
    $col_action->set_resizable(TRUE);
    $col_action->set_expand(TRUE);

    # --- Apply theme to cell renderers (foreground) and column header buttons ---
    # NOTE: Do NOT use set_cell_data_func — it overrides the text => N
    # attribute mapping and requires manually re-setting text per row.
    # Instead, set foreground properties directly on each renderer.
    if (my $theme = $ctx->{theme}) {
        my $fg = $theme->{fg};
        my $bg = $theme->{bg};

        for my $r ($renderer_mode, $renderer_key, $renderer_action) {
            # Method 1: string foreground (works in many GTK3 Perl GI setups)
            eval { $r->set('foreground', $fg) };
            eval { $r->set('foreground-set', 1) };

            # Method 2: GdkRGBA foreground (works when string doesn't)
            eval {
                my $rgba = Gtk3::Gdk::RGBA->new();
                $rgba->parse($fg);
                $r->set('foreground-rgba', $rgba);
                $r->set('foreground-rgba-set', 1);
            };
        }

        # Apply theme to column header buttons directly via their style contexts
        my $header_css = Gtk3::CssProvider->new();
        $header_css->load_from_data(
            "* { background-color: $bg; color: $fg; border-color: $fg; }"
        );
        for my $col ($col_mode, $col_key, $col_action) {
            my $btn = eval { $col->get_widget };
            next unless $btn;
            $btn->set_name('bindings_header_btn');
            $btn->get_style_context->add_provider($header_css, 600);
        }
    }

    $treeview->append_column($col_mode);
    $treeview->append_column($col_key);
    $treeview->append_column($col_action);

    # --- Search bar (Gtk3::Entry — available everywhere) ---
    my $search_entry = Gtk3::Entry->new();
    $search_entry->set_name('bindings_search');
    $search_entry->set_placeholder_text('Type to filter bindings\u2026');
    my $search_label = Gtk3::Label->new('Filter:');
    $search_label->set_name('bindings_label');
    my $search_box = Gtk3::Box->new('horizontal', 6);
    $search_box->set_margin_start(8);
    $search_box->set_margin_end(8);
    $search_box->set_margin_top(6);
    $search_box->set_margin_bottom(2);
    $search_box->pack_start($search_label, FALSE, FALSE, 0);
    $search_box->pack_start($search_entry, TRUE, TRUE, 0);

    # Rebuild store and expand on every keystroke
    $search_entry->signal_connect(changed => sub {
        $filter_text = lc($search_entry->get_text // '');
        $populate_store->();
        $treeview->expand_all;
    });

    # Focus search entry when the dialog is shown
    $window->signal_connect(show => sub {
        eval { $search_entry->grab_focus };
    });

    # --- Escape handling: clear filter first, close on second press ---
    $window->signal_connect(key_press_event => sub {
        my ($w, $event) = @_;
        if ($event->keyval == Gtk3::Gdk::keyval_from_name('Escape')) {
            if (length $search_entry->get_text) {
                $search_entry->set_text('');
                $filter_text = '';
                $populate_store->();
                $treeview->expand_all;
                return TRUE;
            }
            $w->destroy;
            return TRUE;
        }
        return FALSE;
    });

    # --- Layout ---
    my $vbox = Gtk3::Box->new('vertical', 0);
    $vbox->set_name('bindings_vbox');
    $vbox->pack_start($search_box, FALSE, FALSE, 0);

    my $scroll = Gtk3::ScrolledWindow->new();
    $scroll->set_policy('automatic', 'automatic');
    $scroll->set_shadow_type('none');
    $scroll->add($treeview);
    $vbox->pack_start($scroll, TRUE, TRUE, 0);

    $window->add($vbox);

    # --- Theme: per-widget CSS providers (more reliable than cascading
    #     from the window, which fails to reach TreeView internals on
    #     some GTK3 / Perl GI versions) ---
    if (my $theme = $ctx->{theme}) {
        my $fg = $theme->{fg};
        my $bg = $theme->{bg};

        # Window background
        eval {
            my $css = Gtk3::CssProvider->new();
            $css->load_from_data("#bindings_window { background-color: $bg; color: $fg; }");
            $window->get_style_context->add_provider($css, 600);
        };

        # Vbox border (wraps both search and treeview)
        eval {
            my $css = Gtk3::CssProvider->new();
            $css->load_from_data("#bindings_vbox { border: 1px solid $fg; }");
            $vbox->get_style_context->add_provider($css, 600);
        };

        # Filter label
        eval {
            my $css = Gtk3::CssProvider->new();
            $css->load_from_data("#bindings_label { color: $fg; background-color: transparent; }");
            $search_label->get_style_context->add_provider($css, 600);
        };

        # Search entry
        eval {
            my $css = Gtk3::CssProvider->new();
            $css->load_from_data(
                "#bindings_search { color: $fg; background-color: $bg; border: 1px solid $fg; }"
            );
            $search_entry->get_style_context->add_provider($css, 600);
        };

        # Treeview: body + selected rows + expanders + scrollbar
        eval {
            my $css = Gtk3::CssProvider->new();
            $css->load_from_data(qq{
                #bindings_tree { background-color: $bg; color: $fg; }
                #bindings_tree:selected { background-color: $fg; color: $bg; }
                #bindings_tree expander { color: $fg; }
                #bindings_tree scrollbar trough { background-color: $bg; }
                #bindings_tree scrollbar slider { background-color: $fg; min-width: 8px; min-height: 8px; }
                #bindings_tree scrollbar button { background-color: $bg; color: $fg; border-color: $fg; }
            });
            $treeview->get_style_context->add_provider($css, 600);
        };
    }

    $window->show_all;
}

# ----------------------------------------------------------------
# Shared data maps for key/display translation
# ----------------------------------------------------------------

sub _build_key_name_map {
    return {
        dollar         => '$',   caret         => '^',
        colon          => ':',   slash         => '/',
        question       => '?',   greatergreater=> '>>',
        lessless       => '<<',  asciicircum   => '^',
        asciitilde     => '~',   percent       => '%',
        semicolon      => ';',   comma         => ',',
        d_dollar       => 'd$',  grave         => '`',
        apostrophe     => "'",   BackSpace     => '<BS>',
        Delete         => '<Del>',Page_Up      => '<PgUp>',
        Page_Down      => '<PgDn>',Escape      => '<Esc>',
        Tab            => '<Tab>',Home         => '<Home>',
        End            => '<End>',Return       => '<CR>',
    };
}

sub _build_desc_map {
    return {
        move_left         => 'move left',            move_right    => 'move right',
        move_up           => 'move up',              move_down     => 'move down',
        word_forward      => 'next word start',      word_backward => 'prev word start',
        word_end          => 'next word end',
        line_start        => 'start of line',        line_end      => 'end of line',
        first_nonblank    => 'first non-blank',
        file_start        => 'first line',           file_end      => 'last line',
        page_up           => 'page up',              page_down     => 'page down',
        scroll_half_up    => 'half page up',         scroll_half_down => 'half page down',
        scroll_line_up    => 'scroll line up',       scroll_line_down => 'scroll line down',
        delete_char       => 'delete char',          backspace     => 'backspace',
        delete_line       => 'delete line (dd)',     delete_word   => 'delete word (dw)',
        delete_to_eol     => 'delete to EOL (d$)',
        change_line       => 'change line (cc)',     change_word   => 'change word (cw)',
        change_to_eol     => 'change to EOL (C)',
        replace_char      => 'replace char (r{c})',
        join_lines        => 'join lines',
        enter_insert      => 'insert mode',          enter_insert_after => 'insert after cursor',
        enter_insert_eol  => 'insert at EOL (A)',    enter_insert_bol   => 'insert at BOL (I)',
        open_below        => 'open line below (o)',  open_above      => 'open line above (O)',
        enter_replace_mode=> 'replace mode (R)',     do_replace_char => 'replace single char',
        replace_backspace => 'replace backspace',
        insert_tab        => 'insert tab',
        exit_to_normal    => 'back to normal',       exit_replace_to_normal => 'back to normal',
        yank_line         => 'yank line (yy)',       yank_word     => 'yank word (yw)',
        yank_inner_word   => 'yank inner word (yiw)',
        paste             => 'paste after (p)',      paste_before  => 'paste before (P)',
        undo              => 'undo',                 redo          => 'redo',
        line_undo         => 'undo line (U)',
        indent_right      => 'indent right (>>)',    indent_left   => 'indent left (<<)',
        search_next       => 'next search match',    search_prev   => 'prev search match',
        enter_search      => 'search forward',       enter_search_backward => 'search backward',
        set_mark          => 'set mark (m{a-z})',
        jump_mark         => 'jump to mark (`{a-z})',
        jump_mark_line    => 'jump to mark line',
        find_char_forward => 'find char forward (f{c})',
        find_char_backward=> 'find char backward (F{c})',
        till_char_forward => 'till char forward (t{c})',
        till_char_backward=> 'till char backward (T{c})',
        find_repeat       => 'repeat find (;)',      find_repeat_reverse => 'repeat find rev (,)',
        percent_motion    => 'match bracket (%)',
        enter_visual      => 'visual mode',          enter_visual_line => 'visual line (V)',
        reselect_visual   => 'reselect visual (gv)',
        enter_command     => 'command mode',
        visual_exit       => 'exit visual',          visual_delete => 'delete selection',
        visual_yank       => 'yank selection',       visual_change => 'change selection',
        visual_toggle_case=> 'swap case (~)',        visual_uppercase => 'uppercase selection (U)',
        visual_lowercase  => 'lowercase selection (u)',
        visual_join       => 'join selected lines',
        visual_swap_ends  => 'swap cursor/anchor (o)',
        visual_format     => 'format selection (gq)',
        visual_indent_right => 'indent right (>>)',  visual_indent_left  => 'indent left (<<)',
        visual_block_insert_start => 'block insert start (I)',
        visual_block_insert_end   => 'block insert end (A)',
        cmd_quit          => 'quit',                 cmd_force_quit=> 'force quit',
        cmd_save          => 'save file',            cmd_save_quit => 'save and quit',
        cmd_edit          => 'open file',            cmd_read      => 'insert file',
        cmd_substitute    => 'substitute',           cmd_set       => 'set option',
        cmd_show_bindings => 'show key bindings',    cmd_browse    => 'file browser',
        goto_line         => 'goto line N',
        toggle_scroll_lock=> 'toggle scroll lock (zx)',
    };
}

# ----------------------------------------------------------------
# Shared helper builders for collecting bindings from a keymap
# ----------------------------------------------------------------

sub _build_from_keys {
    my ($km, $display_key, $get_desc) = @_;
    my @out; my %seen;
    for my $key (sort grep { !/^_/ } keys %$km) {
        my $action = $km->{$key};
        next unless defined $action;
        my $dk = $display_key->($key);
        next if $seen{$dk}++;
        push @out, { key => $dk, action => $get_desc->($action) };
    }
    return @out;
}

sub _build_ctrl {
    my ($km, $get_desc) = @_;
    my @out;
    return @out unless $km->{_ctrl};
    for my $key (sort keys %{$km->{_ctrl}}) {
        my $action = $km->{_ctrl}{$key};
        next unless defined $action;
        push @out, { key => "Ctrl-$key", action => $get_desc->($action) };
    }
    return @out;
}

sub _build_char_actions {
    my ($km, $display_key, $get_desc) = @_;
    my @out;
    return @out unless $km->{_char_actions};
    for my $key (sort grep { !/^_/ } keys %{$km->{_char_actions}}) {
        my $action = $km->{_char_actions}{$key};
        next unless defined $action;
        push @out, { key => $display_key->($key), action => $get_desc->($action) };
    }
    return @out;
}

# ----------------------------------------------------------------
# Collect all bindings sections from context (shared by both
# generate_bindings_text and generate_bindings_list)
# ----------------------------------------------------------------

sub _collect_bindings_sections {
    my ($ctx) = @_;
    my $key_name = _build_key_name_map();
    my $desc     = _build_desc_map();
    my $display_key = sub { $key_name->{$_[0]} // $_[0] };
    my $get_desc    = sub { $desc->{$_[0]} // $_[0] };

    my $rk = $ctx->{resolved_keymap};

    my @normal = (_build_from_keys($rk->{normal}, $display_key, $get_desc));
    push @normal, _build_ctrl($rk->{normal}, $get_desc);
    push @normal, _build_char_actions($rk->{normal}, $display_key, $get_desc);

    my @insert  = _build_from_keys($rk->{insert}, $display_key, $get_desc);
    my @replace = _build_from_keys($rk->{replace}, $display_key, $get_desc);

    my @visual_raw = (_build_from_keys($rk->{visual}, $display_key, $get_desc));
    push @visual_raw, _build_ctrl($rk->{visual}, $get_desc);
    push @visual_raw, _build_char_actions($rk->{visual}, $display_key, $get_desc);
    my %normal_keys;
    $normal_keys{$_->{key}} = 1 for @normal;
    my @visual = grep { !$normal_keys{$_->{key}} } @visual_raw;

    my @command = _build_from_keys($rk->{command}, $display_key, $get_desc);

    my @ex_cmds;
    my $ec = $ctx->{ex_cmds};
    for my $cmd (sort keys %$ec) {
        my $action = $ec->{$cmd};
        push @ex_cmds, { key => ":$cmd", action => $get_desc->($action) };
    }
    push @ex_cmds, { key => ':q!',       action => 'force quit' };
    push @ex_cmds, { key => ':N',        action => 'goto line N' };
    push @ex_cmds, { key => ':%s/p/r/g', action => 'substitute all' };

    return (
        { mode => 'NORMAL MODE',  bindings => \@normal },
        { mode => 'INSERT MODE',  bindings => \@insert },
        { mode => 'REPLACE MODE', bindings => \@replace },
        { mode => 'VISUAL MODE',  bindings => \@visual },
        { mode => 'COMMAND MODE', bindings => \@command },
        { mode => 'EX COMMANDS',  bindings => \@ex_cmds },
    );
}

# ----------------------------------------------------------------
# Generate bindings as structured list (for TreeView)
# ----------------------------------------------------------------

sub generate_bindings_list {
    my ($ctx) = @_;
    return [ _collect_bindings_sections($ctx) ];
}

# ----------------------------------------------------------------
# Generate bindings help text (testable without GTK display)
# ----------------------------------------------------------------

sub generate_bindings_text {
    my ($ctx) = @_;

    my @sections = _collect_bindings_sections($ctx);

    # --- Format into 3-column layout ---
    my $key_w  = 10;
    my $desc_w = 20;
    my $cols   = 3;
    my @lines;

    for my $section (@sections) {
        my $heading = "-- $section->{mode} --";
        my $entries = $section->{bindings};
        next unless @$entries;
        push @lines, $heading;
        push @lines, '-' x length($heading);
        for (my $i = 0; $i < @$entries; $i += $cols) {
            my $row = '';
            for my $c (0 .. $cols - 1) {
                last if $i + $c >= @$entries;
                my $b = $entries->[$i + $c];
                $row .= sprintf("%-${key_w}s %-${desc_w}s", $b->{key}, $b->{action});
            }
            push @lines, $row;
        }
        push @lines, '';
    }

    return join("\n", @lines);
}

sub _cmd_save {
    my ($ctx, $save_arg) = @_;
    my $vb = $ctx->{vb};
    my $ml = $ctx->{mode_label};
    my $fn = $ctx->{filename_ref};
    my $sf = $save_arg;
    $sf =~ s/^\s+|\s+$//g if defined $sf;
    $sf = $$fn if !$sf;
    if ($sf) {
        eval {
            open my $fh, '>', $sf or die $!;
            print $fh $vb->text;
            close $fh;
            $vb->set_modified(0);
            $$fn = $sf;
            $ctx->{show_status}->("Saved: $sf") if $ctx->{show_status};
        };
        if ($@) { chomp $@; $ctx->{show_status}->("Error: $@") if $ctx->{show_status}; }
    } else {
        $ctx->{show_status}->("Error: No file name") if $ctx->{show_status};
    }
}

1;

__END__

=head1 NAME

Gtk3::SourceEditor::VimBindings::Command - Ex-command actions and parser

=head1 SYNOPSIS

    use Gtk3::SourceEditor::VimBindings::Command;

    my %ACTIONS;
    my $cmd_map = Gtk3::SourceEditor::VimBindings::Command->register(\%ACTIONS);

    my $parsed = Gtk3::SourceEditor::VimBindings::Command::parse_ex_command(":%s/foo/bar/g");

=head1 DESCRIPTION

Provides ex-command action handlers (quit, save, edit, substitute, etc.)
and the ex-command parser for L<Gtk3::SourceEditor::VimBindings>.

=head1 METHODS

=head2 register(\%ACTIONS)

Populates C<%ACTIONS> with command handler subs and returns a hash mapping
ex-command names to action keys.

=head2 parse_ex_command($raw)

Parses a raw ex-command string into a hash with keys: C<cmd>, C<args>,
C<bang>, C<range>, C<line_number>.

=head1 AUTHOR

Auto-generated.

=cut
