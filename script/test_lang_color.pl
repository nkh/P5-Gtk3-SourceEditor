use strict ;
use warnings ;
use Gtk3 '-init' ;
use Gtk3::SourceView ;

my $window = Gtk3::Window->new('toplevel') ;

my $buffer   = Gtk3::SourceView::Buffer->new(undef);
my $view  = Gtk3::SourceView::View->new_with_buffer($buffer);
$view->set_show_line_numbers(1);
$view->set_highlight_current_line(1);

my $lang_manager = Gtk3::SourceView::LanguageManager->get_default;

my $perl_lang = $lang_manager->get_language('perl') ;
$buffer->set_language($perl_lang) ;
$buffer->set_highlight_syntax(1) ;

# Insert code with various syntax elements on line 0
$buffer->set_text("use strict ;") ;

$window->add($view) ;
$window->show_all() ;

Glib::Idle->add(sub { probe($buffer, $view) ; return 0 ; }) ;

Gtk3->main() ;

# ------------------------------------------------------------------------------

sub probe
{
    my ($buffer, $view) = @_ ;

    my $iter = $buffer->get_iter_at_line_offset(0, 1) ;
    my @tags = $iter->get_tags() ;

    print "=== Tags at (0,1) ===\n";
    print "Count: " . scalar(@tags) . "\n\n";

    foreach my $tag (@tags)
    {
        # 1. Class info
        print "--- Tag class ---\n";
        print "  ref:         " . ref($tag) . "\n";
        my $type_name = eval { Glib::Object::type_name($tag) } // '?';
        print "  GType name:  $type_name\n";

        # 2. Try to list all properties via Glib introspection
        eval {
            my $class = ref($tag);
            my $pspecs = $tag->list_properties;
            if ($pspecs && @$pspecs) {
                print "  Properties (" . scalar(@$pspecs) . "):\n";
                for my $pspec (@$pspecs) {
                    my $pname = $pspec->get_name;
                    my $ptype = $pspec->get_type;
                    # Only print color-related or style-related properties
                    next unless $pname =~ /color|foreground|background|style|font|weight|scale|underline|strikethrough|italic|bold|pixel/i;
                    my $val = eval { $tag->get_property($pname) };
                    my $val_str = defined $val ? (ref $val ? ref($val) : $val) : '(undef)';
                    print "    $pname ($ptype) = $val_str\n";
                }
            } else {
                print "  list_properties: (empty or unavailable)\n";
            }
        };
        if ($@) { print "  list_properties error: $@\n"; }

        # 3. Try specific property names (various naming conventions)
        print "  Specific probes:\n";
        my @probes = qw(
            foreground foreground-rgba foreground-set foreground-gdk
            background background-rgba background-set background-gdk
            paragraph-background paragraph-background-rgba
            font font-desc font-family
            weight scale size style
            underline underline-rgba underline-set
            strikethrough strikethrough-rgba strikethrough-set
            rise pixels-above-lines pixels-below-lines
            indent left-margin right-margin
            name tag-name
            invisible editable
        );
        for my $p (@probes) {
            my $v = eval { $tag->get_property($p) };
            next unless defined $v;
            my $d = ref($v) ? (eval { $v->to_string } // ref($v)) : $v;
            print "    $p = $d\n";
        }

        # 4. If it's a GtkSourceTag, try source-specific properties
        print "  GtkSourceTag probes:\n";
        for my $p (qw(
            id name style-scheme
        )) {
            my $v = eval { $tag->get_property($p) };
            next unless defined $v;
            print "    $p = $v\n";
        }
    }

    # 5. Also try: get the active style scheme and look up style names
    print "\n=== Style scheme ===\n";
    eval {
        my $scheme = $buffer->get_style_scheme;
        if ($scheme) {
            print "  Scheme name: " . $scheme->get_name . "\n";
            print "  Scheme id:   " . $scheme->get_id . "\n";
            print "  Scheme desc: " . ($scheme->get_description // '(none)') . "\n";

            # Try to get style by known GtkSourceView style names
            my @style_ids = qw(
                text selection selected
                keyword builtin type string comment preprocessor
                variable declaration function identifier
                number operator delimiter error
                def:keyword def:type def:string def:comment
                perl:keyword perl:builtin perl:type perl:string
                perl:comment perl:identifier perl:variable
            );
            for my $sid (@style_ids) {
                my $style = eval { $scheme->get_style($sid) };
                next unless $style;
                my $fg = eval { $style->get_foreground } // '(none)';
                my $bg = eval { $style->get_background } // '(none)';
                my $b  = eval { $style->get_bold };
                my $i  = eval { $style->get_italic };
                next unless defined $fg && $fg ne '(none)' || defined $bg && $bg ne '(none)';
                print "  style '$sid': fg=$fg bg=$bg bold=$b italic=$i\n";
            }
        } else {
            print "  (no scheme set)\n";
        }
    };
    if ($@) { print "  Error: $@\n"; }

    # 6. View style context with correct state flag
    print "\n=== View style context ===\n";
    eval {
        my $sc = $view->get_style_context;
        my $fg = $sc->get_color('normal');
        my $bg = $sc->get_background_color('normal');
        printf "  fg=(%.3f,%.3f,%.3f) bg=(%.3f,%.3f,%.3f)\n",
            $fg->red, $fg->green, $fg->blue,
            $bg->red, $bg->green, $bg->blue;
    };
    if ($@) { print "  Error: $@\n"; }

    Gtk3->main_quit ;
}
