#!/usr/bin/env perl
# Standalone test: query syntax-highlighted colors from GtkSourceView
# at various cursor positions using different API methods.

use strict;
use warnings;
use Gtk3 -init;
use Glib ('TRUE', 'FALSE');
use Gtk3::SourceView;

my $window = Gtk3::Window->new('toplevel');
$window->set_default_size(600, 400);
$window->signal_connect(delete_event => sub { Gtk3->main_quit });

# --- Create SourceView with syntax highlighting ---
my $buf   = Gtk3::SourceView::Buffer->new(undef);
my $view  = Gtk3::SourceView::View->new_with_buffer($buf);
$view->set_show_line_numbers(1);
$view->set_highlight_current_line(1);

# Set language to Perl
my $lm = Gtk3::SourceView::LanguageManager->get_default;
my $lang = $lm->get_language('perl');
$buf->set_language($lang) if $lang;
print "Language: " . ($lang ? $lang->get_name : '(none)') . "\n";

# Set a dark style scheme
my $sm = Gtk3::SourceView::StyleSchemeManager->get_default;
my $scheme = $sm->get_scheme('kate');
if (!$scheme) { $scheme = $sm->get_scheme('tango'); }
if ($scheme) {
    $buf->set_style_scheme($scheme);
    print "Scheme: " . $scheme->get_name . "\n";
}

# Sample Perl code with different syntax elements
$buf->set_text(<<'CODE');
#!/usr/bin/perl
use strict;
use warnings;

# This is a comment
my $variable = "hello world";
my $number = 42;

sub my_function {
    my ($arg) = @_;
    print "arg: $arg\n";
    if ($arg > 10) {
        return 1;
    }
    return 0;
}
CODE

$window->add($view);
$window->show_all;

# --- After show_all, query colors at various positions ---
Glib::Timeout->add(500, sub {
    print "=" x 60 . "\n";
    print "PROBING SYNTAX COLORS AFTER REALIZE\n";
    print "=" x 60 . "\n";

    my $start = $buf->get_start_iter;
    my $end   = $buf->get_end_iter;

    # Walk through each character and probe at positions
    # where we know different syntax elements exist
    my $pos = 0;
    my $iter = $buf->get_start_iter;
    my $last_probed_line = -1;

    while (!$iter->is_end && $pos < 500) {
        my $line = $iter->get_line;
        my $col  = $iter->get_line_index;
        my $char = $iter->get_char // '?';

        # Only probe at first non-whitespace of each line, or at interesting chars
        next if $line == $last_probed_line;
        $last_probed_line = $line;

        my $line_text = $buf->get_text(
            $buf->get_iter_at_line($line),
            $buf->get_iter_at_line($line + 1),
            Glib::FALSE()
        ) // '';
        chomp $line_text;
        $line_text =~ s/\s+$//;

        print "\n--- Line $line col $col: \"$line_text\" ---\n";

        # METHOD 1: get_tags
        {
            my @tags = eval { $buf->get_tags($iter) };
            print "  get_tags: " . scalar(@tags) . " tags\n";
            for my $tag (@tags) {
                my $name = eval { $tag->get_property('name') } // '?';
                my $fg   = eval { $tag->get_property('foreground') } // '(undef)';
                my $fr   = eval { $tag->get_property('foreground-rgba') } // '(undef)';
                print "    tag '$name': foreground=$fg foreground-rgba=$fr\n";
            }
        }

        # METHOD 2: tag table foreach + active()
        {
            my $s = $iter->copy;
            my $e = $iter->copy;
            $e->forward_char;
            my @active;
            eval {
                my $table = $buf->get_tag_table;
                $table->foreach(sub {
                    my ($tag) = @_;
                    my $a = eval { $tag->active($s, $e) };
                    if ($a) {
                        my $name = eval { $tag->get_property('name') } // '?';
                        my $fg   = eval { $tag->get_property('foreground') } // '(undef)';
                        my $fr   = eval { $tag->get_property('foreground-rgba') } // '(undef)';
                        push @active, "$name fg=$fg fr=$fr";
                    }
                });
            };
            print "  tag_table active: " . scalar(@active) . "\n";
            for my $a (@active) {
                print "    $a\n";
            }
        }

        # METHOD 3: GtkSourceBuffer::get_style_at_iter
        {
            eval {
                my $style = $buf->get_style_at_iter($iter);
                if ($style) {
                    my $fg      = $style->get_foreground;
                    my $bg      = $style->get_background;
                    my $bold    = $style->get_bold;
                    my $italic  = $style->get_italic;
                    my $strikethrough = $style->get_strikethrough;
                    my $underline    = $style->get_underline;
                    print "  get_style_at_iter: fg=$fg bg=$bg bold=$bold italic=$italic";
                    print " strikethrough=$strikethrough underline=$underline\n";
                } else {
                    print "  get_style_at_iter: (undef)\n";
                }
            };
            if ($@) {
                print "  get_style_at_iter ERROR: $@\n";
            }
        }

        # METHOD 4: get_source_tag_at_iter (GtkSourceBuffer 3.x?)
        {
            eval {
                my $tag = $buf->get_source_tag_at_iter($iter);
                if ($tag) {
                    my $name = $tag->get_name // '?';
                    my $fg   = eval { $tag->get_property('foreground') } // '(undef)';
                    print "  get_source_tag_at_iter: name=$name foreground=$fg\n";
                } else {
                    print "  get_source_tag_at_iter: (undef)\n";
                }
            };
            if ($@) {
                print "  get_source_tag_at_iter ERROR: $@\n";
            }
        }

        # METHOD 5: Style context on the view
        {
            eval {
                my $sc = $view->get_style_context;
                my $fg = $sc->get_color(0);
                my $bg = $sc->get_background_color(0);
                printf "  view style_context: fg=(%.3f,%.3f,%.3f) bg=(%.3f,%.3f,%.3f)\n",
                    $fg->red, $fg->green, $fg->blue,
                    $bg->red, $bg->green, $bg->blue;
            };
            if ($@) {
                print "  view style_context ERROR: $@\n";
            }
        }

        $iter->forward_line;
        $pos++;
    }

    print "\n" . "=" x 60 . "\n";
    print "DONE. Quitting.\n";
    Gtk3->main_quit;
    return Glib::FALSE();  # don't repeat timeout
});

Gtk3->main;
