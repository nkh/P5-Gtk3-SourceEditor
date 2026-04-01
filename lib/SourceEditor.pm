package SourceEditor;
use strict;
use warnings;
use Gtk3;
use Glib ('TRUE', 'FALSE');
use Gtk3::SourceView;
use Pango;
use File::Slurper 'read_text';

require VimBindings;
require ThemeManager;

sub new {
    my ($class, %opts) = @_;
    my $self = bless {}, $class;

    $self->{filename}   = $opts{file};
    $self->{font_size}  = $opts{font_size} // 0;
    $self->{wrap}       = defined $opts{wrap} ? $opts{wrap} : 1;
    $self->{read_only}  = $opts{read_only} // 0;
    $self->{on_close}   = $opts{on_close};
    $self->{window}     = $opts{window};

    $self->_build_ui(%opts);
    return $self;
}

sub _build_ui {
    my ($self, %opts) = @_;
    
    # Load Theme
    my $theme_data = ThemeManager::load(file => $opts{theme_file});
    my $fg = $theme_data->{fg};
    my $bg = $theme_data->{bg};

    # Helper to convert "#RRGGBB" to a GdkRGBA object safely across all GTK3 versions
    my $parse_hex = sub {
        my $h = shift;
        $h =~ s/^#//;
        my $r = hex(substr($h, 0, 2)) / 255.0;
        my $g = hex(substr($h, 2, 2)) / 255.0;
        my $b = hex(substr($h, 4, 2)) / 255.0;
        
        # Create a blank GdkRGBA and set properties (most compatible method)
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
    my $lang = $lm->guess_language($self->{filename}, undef) || $lm->get_language('perl');
    $self->{buffer} = Gtk3::SourceView::Buffer->new_with_language($lang);
    $self->{buffer}->set_highlight_syntax(TRUE);

    if ($self->{filename} && -e $self->{filename}) {
        eval { $self->{buffer}->set_text(read_text($self->{filename})); };
        warn "Failed to read $self->{filename}: $@" if $@;
    }
    $self->{buffer}->place_cursor($self->{buffer}->get_start_iter());
    $self->{buffer}->set_modified(FALSE);
    $self->{buffer}->set_style_scheme($theme_data->{scheme});

    $self->{textview} = Gtk3::SourceView::View->new();
    $self->{textview}->set_buffer($self->{buffer});
    $self->{textview}->set_show_line_numbers(TRUE);
    $self->{textview}->set_highlight_current_line(TRUE);
    $self->{textview}->set_auto_indent(TRUE);
    $self->{textview}->set_wrap_mode($self->{wrap} ? 'word' : 'none');

    # Font
    my $pango_font = "Monospace";
    $pango_font .= " $self->{font_size}" if $self->{font_size} > 0;
    $self->{textview}->modify_font(Pango::FontDescription->from_string($pango_font));

    # Scrolled Window
    my $scroll = Gtk3::ScrolledWindow->new();
    $scroll->set_policy('automatic', 'automatic');
    $scroll->add($self->{textview});
    $self->{widget}->pack_start($scroll, TRUE, TRUE, 0);

    # Bottom Bar (Command Entry + Status Label)
    my $bottom_box = Gtk3::Box->new('vertical', 0);

    $self->{cmd_entry} = Gtk3::Entry->new();
    $self->{cmd_entry}->set_no_show_all(TRUE);
    $self->{cmd_entry}->hide();
    
    $self->{cmd_entry}->override_color('normal', $fg_rgba);
    $self->{cmd_entry}->override_background_color('normal', $bg_rgba);

    # GtkLabel doesn't draw backgrounds. We MUST wrap it in an EventBox.
    my $label_box = Gtk3::EventBox->new();
    $label_box->override_background_color('normal', $bg_rgba);
    
    $self->{mode_label} = Gtk3::Label->new('-- NORMAL --');
    $self->{mode_label}->override_color('normal', $fg_rgba);
    
    $label_box->add($self->{mode_label});

    $bottom_box->pack_end($label_box, FALSE, FALSE, 0);
    $bottom_box->pack_end($self->{cmd_entry}, FALSE, FALSE, 0);
    $self->{widget}->pack_end($bottom_box, FALSE, FALSE, 0);

    # Bindings
    VimBindings::add_vim_bindings(
        $self->{textview}, 
        $self->{mode_label}, 
        $self->{cmd_entry}, 
        \$self->{filename}, 
        $self->{read_only}
    );

    # Hook into window close event to trigger callback
    if ($self->{window} && $self->{on_close}) {
        $self->{window}->signal_connect('destroy' => sub {
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
    return $self->{buffer}->get_text($self->{buffer}->get_start_iter, $self->{buffer}->get_end_iter, TRUE);
}

sub get_buffer {
    my ($self) = @_;
    return $self->{buffer};
}

1;
