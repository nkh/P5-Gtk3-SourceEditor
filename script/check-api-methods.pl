#!/usr/bin/env perl
# check-api-methods.pl -- Static analysis: verify GTK method calls against the API registry
#
# Usage:  perl script/check-api-methods.pl
# Exit 0 = all methods valid, Exit 1 = issues found

use strict;
use warnings;
use File::Find;
use File::Basename qw(dirname basename);
use JSON::PP;

# ==========================================================================
# Paths
# ==========================================================================
my $BASE_DIR   = dirname(dirname($0));       # -> src/
my $LIB_DIR    = $BASE_DIR . '/lib';

# Look for API registry: prefer local copy, fall back to cpan-sources
my $API_FILE   = $BASE_DIR . '/api-registry/full_api.json';
$API_FILE      = $BASE_DIR . '/../cpan-sources/full_api.json'
    unless -f $API_FILE;

# ==========================================================================
# 1. Load the API registry
# ==========================================================================
sub load_api {
    open my $fh, '<', $API_FILE
        or die "Cannot open API registry '$API_FILE': $!\n";
    local $/;
    my $data = decode_json(<$fh>);
    close $fh;

    # Flatten: build a hash  class => { method => 1, ... }
    my %api;
    for my $class (keys %$data) {
        $api{$class} = { map { $_ => 1 } @{$data->{$class}} };
    }
    return \%api;
}

# ==========================================================================
# 2. Inheritance map (known GTK class hierarchy)
#    Each class maps to its ordered list of parent classes.
# ==========================================================================
my %INHERITANCE = (
    # GtkSourceView 3.x classes
    'Gtk3::SourceView::View'          => [qw(Gtk3::TextView Gtk3::Container Gtk3::Widget)],
    'Gtk3::SourceView::Buffer'        => [qw(Gtk3::TextBuffer)],
    'Gtk3::SourceView::Gutter'        => [qw(Gtk3::Widget)],
    'Gtk3::SourceView::Completion'    => [qw(Gtk3::Widget)],
    'Gtk3::SourceView::LanguageManager' => [],
    'Gtk3::SourceView::StyleSchemeManager' => [],
    # GTK widget hierarchy
    'Gtk3::TextView'    => [qw(Gtk3::Container Gtk3::Widget)],
    'Gtk3::Container'   => [qw(Gtk3::Widget)],
    'Gtk3::Bin'         => [qw(Gtk3::Container Gtk3::Widget)],
    'Gtk3::Window'      => [qw(Gtk3::Bin Gtk3::Container Gtk3::Widget)],
    'Gtk3::Dialog'      => [qw(Gtk3::Window Gtk3::Bin Gtk3::Container Gtk3::Widget)],
    'Gtk3::ScrolledWindow' => [qw(Gtk3::Container Gtk3::Widget)],
    'Gtk3::Box'         => [qw(Gtk3::Container Gtk3::Widget)],
    'Gtk3::Entry'       => [qw(Gtk3::Widget)],
    'Gtk3::Label'       => [qw(Gtk3::Widget)],
    'Gtk3::EventBox'    => [qw(Gtk3::Bin Gtk3::Container Gtk3::Widget)],
    'Gtk3::Adjustment'  => [],
    'Gtk3::CssProvider' => [],
    'Gtk3::StyleContext'=> [],
    'Gtk3::TextBuffer'  => [],
    'Gtk3::Widget'      => [],
    # TreeView hierarchy
    'Gtk3::TreeStore'   => [],
    'Gtk3::TreeView'    => [qw(Gtk3::Container Gtk3::Widget)],
    'Gtk3::TreeViewColumn' => [qw(Gtk3::CellLayout Gtk3::Widget)],
    'Gtk3::CellRendererText' => [qw(Gtk3::CellRenderer)],
    'Gtk3::CellLayout' => [],
    'Gtk3::CellRenderer'=> [],
    'Gtk3::FileChooserDialog' => [qw(Gtk3::Dialog Gtk3::Window Gtk3::Bin Gtk3::Container Gtk3::Widget)],
    'Gtk3::FileChooser' => [],
    'Gtk3::Clipboard'   => [],
);

# Known methods that exist in GTK but are not in our extracted API.
# These are universally available via Glib::Object::Introspection and
# should not be reported as missing.
my %KNOWN_GOOD = map { $_ => 1 } (
    # GObject universal
    qw(signal_connect signal_connect_after set_property get_property),
    # GtkWidget
    qw(create_pango_layout modify_font override_font override_color
       override_background_color set_size_request queue_draw show show_all
       hide grab_focus set_name get_name set_no_show_all),
    # GtkContainer
    qw(pack_start pack_end add remove),
    # GtkMisc / GtkWidget sizing
    qw(set_xalign set_margin_end set_margin_start set_margin_top set_margin_bottom),
    # GtkTextView
    qw(set_editable set_cursor_visible buffer_to_window_coords get_iter_location
       set_show_text),
    # GtkLabel / GtkEditable
    qw(set_text get_text),
    # GtkEntry
    qw(set_position),
    # GtkWindow
    qw(set_title get_title set_default_size),
    # GtkTreeSortable interface
    qw(set_sort_column_id get_sort_column_id),
    # GtkFileChooser
    qw(set_current_folder get_current_folder),
    # GtkListStore / GtkTreeModel
    qw(set append),
    # GtkTextIter (not in our API registry)
    qw(forward_chars forward_search backward_search get_line get_line_offset
       get_char forward_to_line_end copy is_end starts_line ends_line),
    # GtkTextBuffer / GtkTextMark
    qw(get_insert get_selection_bound select_range get_iter_at_line
       get_iter_at_line_offset get_iter_at_mark place_cursor get_start_iter
       get_end_iter get_line_count set_modified get_modified get_chars_in_line),
    # Pango
    qw(from_string get_font_description set_font_description get_metrics
       get_ascent get_descent get_pixel_extents),
    # Glib
    qw(keyval_name),
    # GtkSourceView::LanguageManager
    qw(get_language),
    # Cairo context
    qw(save restore set_source_rgb rectangle fill new_path move_to get_pango_context),
    # VimBuffer abstract interface methods (not GTK - project internal)
    qw(set_cursor insert_text delete_range get_range line_text line_count
       line_length cursor_line cursor_col word_forward word_backward word_end
       first_nonblank_col join_lines indent_lines replace_char char_at
       search_forward search_backward at_line_end at_line_start at_buffer_end
       text set_text modified set_modified transform_range toggle_case can
       begin_user_action end_user_action set_selection clear_selection
       gtk_buffer gtk_view register),
);

# ==========================================================================
# 3. Variable-name → type conventions
# ==========================================================================
my %VAR_TYPE = (
    # SourceView objects
    view        => 'Gtk3::SourceView::View',
    textview    => 'Gtk3::SourceView::View',
    buffer      => 'Gtk3::SourceView::Buffer',
    gbuf        => 'Gtk3::SourceView::Buffer',
    lang        => 'Gtk3::SourceView::Language',
    lm          => 'Gtk3::SourceView::LanguageManager',
    language    => 'Gtk3::SourceView::Language',
    scheme      => 'Gtk3::SourceView::StyleScheme',
    manager     => 'Gtk3::SourceView::StyleSchemeManager',
    gutter      => 'Gtk3::SourceView::Gutter',
    completion  => 'Gtk3::SourceView::Completion',
    scroll      => 'Gtk3::ScrolledWindow',
    scrollee    => 'Gtk3::ScrolledWindow',
    # Generic GTK widgets
    widget      => 'Gtk3::Widget',
    box         => 'Gtk3::Box',
    label       => 'Gtk3::Label',
    ml          => 'Gtk3::Label',
    mode_label  => 'Gtk3::Label',
    pos_label   => 'Gtk3::Label',
    search_label=> 'Gtk3::Label',
    entry       => 'Gtk3::Entry',
    ce          => 'Gtk3::Entry',
    cmd_entry   => 'Gtk3::Entry',
    search_entry=> 'Gtk3::Entry',
    window      => 'Gtk3::Window',
    chooser     => 'Gtk3::FileChooserDialog',
    dialog      => 'Gtk3::Dialog',
    adj         => 'Gtk3::Adjustment',
    vadj        => 'Gtk3::Adjustment',
    hadj        => 'Gtk3::Adjustment',
    clipboard   => 'Gtk3::Clipboard',
    provider    => 'Gtk3::CssProvider',
    fg_rgba     => 'Gtk3::Gdk::RGBA',
    bg_rgba     => 'Gtk3::Gdk::RGBA',
    rgba        => 'Gtk3::Gdk::RGBA',
    style_ctx   => 'Gtk3::StyleContext',
    sc          => 'Gtk3::StyleContext',
    status_box  => 'Gtk3::EventBox',
    event_box   => 'Gtk3::EventBox',
    bottom_box  => 'Gtk3::Box',
    status_inner=> 'Gtk3::Box',
    search_box  => 'Gtk3::Box',
    vbox        => 'Gtk3::Box',
    # Tree-related widgets
    treeview   => 'Gtk3::TreeView',
    store       => 'Gtk3::TreeStore',
    col_key     => 'Gtk3::TreeViewColumn',
    col_action  => 'Gtk3::TreeViewColumn',
    renderer_mode => 'Gtk3::CellRendererText',
    renderer_key=> 'Gtk3::CellRendererText',
    btn         => 'Gtk3::Button',
    r           => 'Gtk3::CellRendererText',
    # Pango
    pango_font  => 'Pango::FontDescription',
    font_desc   => 'Pango::FontDescription',
    fd          => 'Pango::FontDescription',
    layout      => 'Pango::Layout',
    pctx        => 'Pango::Context',
    # Cairo
    cr          => 'Cairo::Context',
    # TextIter
    iter        => 'Gtk3::TextIter',
    start       => 'Gtk3::TextIter',
    end         => 'Gtk3::TextIter',
    end_char    => 'Gtk3::TextIter',
    end_of_cur  => 'Gtk3::TextIter',
    found       => 'Gtk3::TextIter',
    match_start => 'Gtk3::TextIter',
    cursor_iter => 'Gtk3::TextIter',
    anchor_iter=> 'Gtk3::TextIter',
    top_iter    => 'Gtk3::TextIter',
    bot_iter    => 'Gtk3::TextIter',
    mark        => 'Gtk3::TextMark',
    first       => 'Gtk3::TextIter',
    # VimBuffer interface (project-internal, will be skipped)
    vb          => 'Gtk3::SourceEditor::VimBuffer',
    obj         => 'Gtk3::SourceEditor::VimBuffer',
    pkg         => '__skip__',
    check       => '__skip__',
    del_end     => '__skip__',
);

# ==========================================================================
# 4. File-context hash-key → type maps
#    These override VAR_TYPE for specific files when a known key is used
#    in a $self->{key} or $ctx->{key} accessor pattern.
# ==========================================================================
my %FILE_KEY_TYPE = (
    'SourceEditor.pm' => {
        textview   => 'Gtk3::SourceView::View',
        buffer     => 'Gtk3::SourceView::Buffer',
        widget     => 'Gtk3::Box',
        scroll     => 'Gtk3::ScrolledWindow',
        cmd_entry  => 'Gtk3::Entry',
        mode_label => 'Gtk3::Label',
        pos_label  => 'Gtk3::Label',
        window     => 'Gtk3::Window',
    },
    'VimBindings.pm' => {
        gtk_view   => 'Gtk3::SourceView::View',
        mode_label => 'Gtk3::Label',
        cmd_entry  => 'Gtk3::Entry',
        pos_label  => 'Gtk3::Label',
    },
    'ThemeManager.pm' => {
        manager    => 'Gtk3::SourceView::StyleSchemeManager',
        ui_css_provider => 'Gtk3::CssProvider',
        css_provider    => 'Gtk3::CssProvider',
    },
);

# ==========================================================================
# 5. Resolve a (class, method) pair against the API registry with inheritance
# ==========================================================================
sub method_valid {
    my ($api, $class, $method) = @_;

    # Known-good exclusions (methods not in extracted API but known to exist)
    return 1 if $KNOWN_GOOD{$method};

    # Direct lookup
    return 1 if $api->{$class} && $api->{$class}{$method};

    # Walk inheritance chain (BFS up to 3 levels deep)
    my @queue = @{$INHERITANCE{$class} // []};
    my %seen = ($class => 1);
    for my $parent (@queue) {
        next if $seen{$parent}++;
        return 1 if $api->{$parent} && $api->{$parent}{$method};
        push @queue, @{$INHERITANCE{$parent} // []};
    }

    return 0;
}

# ==========================================================================
# 6. Find all .pm files under lib/
# ==========================================================================
my @PM_FILES;
find({
    wanted => sub { push @PM_FILES, $File::Find::name if /\.pm$/ },
    no_chdir => 1,
}, $LIB_DIR);

# ==========================================================================
# 7. Parse a file and extract method calls with inferred types
# ==========================================================================
sub parse_file {
    my ($filepath, $api) = @_;

    open my $fh, '<', $filepath or do { warn "Cannot read $filepath: $!\n"; return () };
    my @lines = <$fh>;
    close $fh;

    my $basename = basename($filepath);
    my $file_key_map = $FILE_KEY_TYPE{$basename} // {};

    # --- Pass 1: collect constructor assignments ---
    # e.g.  $self->{buffer} = Gtk3::SourceView::Buffer->new_with_language(...)
    #       my $view = Gtk3::SourceView::View->new();
    #       my $lm = Gtk3::SourceView::LanguageManager->get_default();
    my %local_type;   # varname => type  (for my $var = Class->method)
    my %key_type;     # hashkey => type  (for $self->{key} = Class->method)

    for my $line (@lines) {
        # $var = Class::Name->method(...)
        if ($line =~ /\$(\w+)\s*=\s*([\w:]+)->(\w+)/) {
            my ($var, $class, $method) = ($1, $2, $3);
            $local_type{$var} = $class;
        }
        # $self->{key} = Class::Name->method(...)
        if ($line =~ /\$self\{['"]?(\w+)['"]?\}\s*=\s*([\w:]+)->(\w+)/) {
            my ($key, $class, $method) = ($1, $2, $3);
            $key_type{$key} = $class;
        }
        # $ctx->{key} = Class::Name->method(...)
        if ($line =~ /\$ctx\{['"]?(\w+)['"]?\}\s*=\s*([\w:]+)->(\w+)/) {
            my ($key, $class, $method) = ($1, $2, $3);
            $key_type{$key} = $class;
        }
    }

    # --- Pass 2: extract method calls and resolve types ---
    my @calls;

    for my $lineno (1 .. @lines) {
        my $line = $lines[$lineno - 1];
        chomp $line;

        # Pattern A:  $var->method_name(...)
        while ($line =~ /\$(\w+)->(\w+)\s*\(/g) {
            my ($var, $method) = ($1, $2);
            # Skip internal/project calls (Gtk3::SourceEditor::* classes)
            next if $var eq 'self';
            next if $var eq 'class';
            my $type = resolve_type($var, $api, \%local_type, \%key_type, $file_key_map);
            push @calls, {
                line => $lineno,
                var  => "\$$var",
                method => $method,
                type => $type,
                raw  => "\$$var->$method()",
                file => $basename,
            };
        }

        # Pattern B:  $self->{key}->method_name(...)
        while ($line =~ /\$self\{['"]?(\w+)['"]?\}->(\w+)\s*\(/g) {
            my ($key, $method) = ($1, $2);
            my $type = resolve_key_type($key, \%key_type, $file_key_map, \%local_type);
            push @calls, {
                line => $lineno,
                var  => "\$self->{$key}",
                method => $method,
                type => $type,
                raw  => "\$self->{$key}->$method()",
                file => $basename,
            };
        }

        # Pattern C:  $ctx->{key}->method_name(...)
        while ($line =~ /\$ctx\{['"]?(\w+)['"]?\}->(\w+)\s*\(/g) {
            my ($key, $method) = ($1, $2);
            my $type = resolve_key_type($key, \%key_type, $file_key_map, \%local_type);
            push @calls, {
                line => $lineno,
                var  => "\$ctx->{$key}",
                method => $method,
                type => $type,
                raw  => "\$ctx->{$key}->$method()",
                file => $basename,
            };
        }

        # Pattern D:  $_call->($obj, 'method_name')
        while ($line =~ /\$_call\s*->\s*\(\s*\$(\w+)\s*,\s*['"](\w+)['"]/g) {
            my ($var, $method) = ($1, $2);
            my $type = resolve_type($var, $api, \%local_type, \%key_type, $file_key_map);
            push @calls, {
                line => $lineno,
                var  => "\$$var",
                method => $method,
                type => $type,
                raw  => "\$_call->(\$$var, '$method')",
                file => $basename,
            };
        }
        # Also: $_call->($self->{key}, 'method_name')
        while ($line =~ /\$_call\s*->\s*\(\s*\$self\{['"]?(\w+)['"]?\}\s*,\s*['"](\w+)['"]/g) {
            my ($key, $method) = ($1, $2);
            my $type = resolve_key_type($key, \%key_type, $file_key_map, \%local_type);
            push @calls, {
                line => $lineno,
                var  => "\$self->{$key}",
                method => $method,
                type => $type,
                raw  => "\$_call->(\$self->{$key}, '$method')",
                file => $basename,
            };
        }

        # Pattern E:  $obj->signal_connect(...)  -- capture signal_connect on known vars
        # (already handled by Pattern A, but let's also capture $ce-> and $ml-> etc.)

        # Pattern F:  $ce->method_name(...)  where $ce is a shorthand from context
        # This is handled by the local_type detection in Pass 1.
    }

    return @calls;
}

sub resolve_type {
    my ($var, $api, $local_type, $key_type, $file_key_map) = @_;

    # 1. From constructor assignment in same file
    return $local_type->{$var} if $local_type->{$var};

    # 2. From variable-name convention
    my $conv = $VAR_TYPE{$var};
    return undef if !defined $conv;
    return undef if $conv eq '__skip__';
    return $conv;
}

sub resolve_key_type {
    my ($key, $key_type, $file_key_map, $local_type) = @_;

    # 1. From constructor assignment in same file
    return $key_type->{$key} if $key_type->{$key};

    # 2. From file-specific context map
    return $file_key_map->{$key} if $file_key_map->{$key};

    # 3. From variable-name convention (e.g., 'buffer', 'view', 'label')
    my $conv = $VAR_TYPE{$key};
    return undef if !defined $conv;
    return undef if $conv eq '__skip__';
    return $conv;
}

# ==========================================================================
# MAIN
# ==========================================================================
my $api = load_api();

print "=" x 72, "\n";
print "  GTK API Method Checker\n";
print "=" x 72, "\n\n";
printf "  API registry:  %s (%d classes)\n", $API_FILE, scalar(keys %$api);
printf "  Scanning:      %s\n\n", $LIB_DIR;

my @all_calls;
my $total_files = 0;

for my $pm (sort @PM_FILES) {
    $total_files++;
    my @calls = parse_file($pm, $api);
    push @all_calls, @calls;
}

printf "  Files scanned: %d\n", $total_files;
printf "  Method calls found: %d\n\n", scalar(@all_calls);

# --- Classify calls ---
my @wrong_object;   # method exists but on a different class
my @not_found;      # method not found in any class
my @unknown_type;   # could not determine the object type
my @valid_calls;

for my $call (@all_calls) {
    my $type   = $call->{type};
    my $method = $call->{method};

    if (!defined $type) {
        push @unknown_type, $call;
        next;
    }

    # Skip non-GTK types (project-internal, Pango::Cairo, etc.)
    if ($type =~ /^Gtk3::SourceEditor/ || $type =~ /^Pango::Cairo/) {
        next;
    }

    # Check if the type even exists in the API
    if (!$api->{$type}) {
        # Might be a type not in our registry (like Pango::*, Cairo::*, Gtk3::Gdk::*,
        # or base classes like Gtk3::Object)
        if ($type =~ /^Gtk3::(Gdk|Style|Pango)/ || $type =~ /^(Pango|Cairo|Glib)::/) {
            next;  # Skip -- not in our API registry
        }
        # Check if method is known-good regardless of type
        if ($KNOWN_GOOD{$method}) {
            next;
        }
        # Class not in registry and method not known-good
        push @not_found, $call;
        next;
    }

    # Type exists in registry -- check method
    if (method_valid($api, $type, $method)) {
        push @valid_calls, $call;
    } else {
        # Check if the method exists on ANY class in the registry
        my $found_on_other = 0;
        my @found_classes;
        for my $cls (sort keys %$api) {
            if ($api->{$cls}{$method}) {
                $found_on_other = 1;
                push @found_classes, $cls;
            }
        }
        if ($found_on_other) {
            # Method exists but maybe not on this class (considering inheritance)
            push @wrong_object, { %$call, found_on => \@found_classes };
        } else {
            push @not_found, $call;
        }
    }
}

# --- Print report ---
my $issue_count = 0;

if (@wrong_object) {
    $issue_count += scalar(@wrong_object);
    print "-" x 72, "\n";
    printf "  WRONG OBJECT: Methods called on potentially wrong class (%d)\n", scalar(@wrong_object);
    print "-" x 72, "\n";
    for my $c (@wrong_object) {
        printf "    %-45s %-30s line %4d\n", $c->{file}, $c->{raw}, $c->{line};
        printf "      %-45s -> %-30s\n", "(inferred: " . ($c->{type} // "?") . ")", "";
        my @candidates = @{$c->{found_on}};
        my @shown;
        for my $i (0 .. $#candidates) {
            last if $i >= 5;
            next unless defined $candidates[$i];
            next if $candidates[$i] =~ /Flags$|Type$|Mode$/;
            push @shown, $candidates[$i];
        }
        printf "      Found on: %s\n", join(", ", grep { defined } @shown);
        print "\n";
    }
}

if (@not_found) {
    $issue_count += scalar(@not_found);
    print "-" x 72, "\n";
    printf "  NOT FOUND: Methods not found in any API class (%d)\n", scalar(@not_found);
    print "-" x 72, "\n";
    for my $c (@not_found) {
        printf "    %-45s %-30s line %4d\n", $c->{file}, $c->{raw}, $c->{line};
        printf "      Inferred type: %s\n", ($c->{type} // "(unknown)");
        print "\n";
    }
}

if (@unknown_type) {
    print "-" x 72, "\n";
    printf "  UNKNOWN TYPE: Could not infer object type (%d)\n", scalar(@unknown_type);
    print "-" x 72, "\n";
    for my $c (@unknown_type) {
        printf "    %-45s %-30s line %4d\n", $c->{file}, $c->{raw}, $c->{line};
    }
    print "\n";
}

# --- Summary ---
print "=" x 72, "\n";
print "  SUMMARY\n";
print "=" x 72, "\n";
printf "  Total method calls analyzed: %d\n", scalar(@all_calls);
printf "  Valid / skipped:             %d\n", scalar(@valid_calls);
printf "  Unknown type (skipped):      %d\n", scalar(@unknown_type);
printf "  Wrong object:                %d\n", scalar(@wrong_object);
printf "  Not found:                   %d\n", scalar(@not_found);
printf "  Issues:                      %d\n", $issue_count;
print "=" x 72, "\n";

if ($issue_count > 0) {
    print "\n  RESULT: ISSUES FOUND (exit 1)\n\n";
    exit 1;
} else {
    print "\n  RESULT: ALL CHECKS PASSED (exit 0)\n\n";
    exit 0;
}
