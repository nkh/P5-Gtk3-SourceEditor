#!/usr/bin/perl
# t/00-api-check.t - Verify all GTK method calls we make actually exist
# on the real Gtk3::SourceView::View and ::Buffer classes.
#
# This test requires Gtk3 and Gtk3::SourceView to be installed.
# When they are not available (e.g. CI without GTK libs), it skips.
#
# The purpose is to catch "Can't locate object method" errors BEFORE
# they reach the user.  Any method we call on a GTK object must pass
# this test.

use strict;
use warnings;
use Test::More;

# --- Try to load the REAL GTK modules ---
# This test verifies methods against the actual Gtk3 installation.
# It MUST skip when running with mock Gtk3 modules (headless testing).
eval { require Gtk3; Gtk3->import; };
if ($@ || !defined $Gtk3::Object::Introspection::VERSION || $Gtk3::VERSION eq '') {
    plan skip_all => "Real Gtk3 not installed - cannot verify GTK API (mocks detected)";
    exit;
}

eval { require Gtk3::SourceView; Gtk3::SourceView->import; };
if ($@ || $Gtk3::SourceView::VERSION eq '') {
    plan skip_all => "Real Gtk3::SourceView not installed - cannot verify GTK API";
    exit;
}

plan tests => 42;

# ==========================================================================
# Methods called on Gtk3::SourceView::View in SourceEditor.pm
# ==========================================================================
my @view_methods = (
    # Core (always present)
    'new',
    'set_buffer',
    'set_show_line_numbers',
    'set_highlight_current_line',
    'set_auto_indent',
    'set_wrap_mode',
    'set_cursor_visible',
    'modify_font',
    'set_tab_width',
    'set_insert_spaces_instead_of_tabs',
    'signal_connect',

    # Added in various 3.x releases
    'set_indent_width',               # 3.16
    'set_show_right_margin',          # 2.x
    'set_right_margin_position',      # 2.x
    'set_smart_home_end',             # 3.0
    'set_highlight_matching_brackets', # 2.0
    'set_show_line_marks',            # 2.2
);

for my $m (@view_methods) {
    ok(Gtk3::SourceView::View->can($m),
       "Gtk3::SourceView::View->can('$m')");
}

# ==========================================================================
# Methods called on Gtk3::SourceView::Buffer in SourceEditor.pm
# ==========================================================================
my @buffer_methods = (
    'new_with_language',
    'set_highlight_syntax',
    'set_text',
    'place_cursor',
    'set_modified',
    'set_style_scheme',
    'get_start_iter',
    'get_end_iter',
    'signal_connect',
);

for my $m (@buffer_methods) {
    ok(Gtk3::SourceView::Buffer->can($m),
       "Gtk3::SourceView::Buffer->can('$m')");
}

# ==========================================================================
# Methods called on Gtk3::SourceView::LanguageManager
# ==========================================================================
my @lang_methods = (
    'get_default',
    'get_language',
    'guess_language',
);

for my $m (@lang_methods) {
    ok(Gtk3::SourceView::LanguageManager->can($m),
       "Gtk3::SourceView::LanguageManager->can('$m')");
}

# ==========================================================================
# Methods called on Gtk3::SourceView::StyleSchemeManager
# ==========================================================================
my @scheme_methods = (
    'get_default',
    'prepend_search_path',
    'get_scheme',
);

for my $m (@scheme_methods) {
    ok(Gtk3::SourceView::StyleSchemeManager->can($m),
       "Gtk3::SourceView::StyleSchemeManager->can('$m')");
}
