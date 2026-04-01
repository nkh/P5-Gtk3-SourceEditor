package VimBindings;
use strict;
use warnings;
use Glib ('TRUE', 'FALSE');

sub add_vim_bindings {
    my ($textview, $mode_label, $cmd_entry, $filename_ref, $is_readonly) = @_;
    
    $is_readonly //= 0;
    $$filename_ref //= '';
    my $vim_mode = 'normal';
    my $command_buffer = '';
    my $yank_buffer = '';
    my $buffer = $textview->get_buffer();
    $textview->set_editable(0) if $is_readonly;

    my $set_mode = sub {
        my ($mode) = @_;
        if ($is_readonly && $mode eq 'insert') { $mode_label->set_text("-- READ ONLY --"); return; }
        $vim_mode = $mode;
        $textview->set_editable($mode eq 'insert') unless $is_readonly;
        if ($mode eq 'command' && $cmd_entry) {
            $mode_label->set_text('');
            $cmd_entry->set_text(':');
            $cmd_entry->show();
            $cmd_entry->grab_focus();
            $cmd_entry->set_position(-1);
        } else {
            $cmd_entry->hide() if $cmd_entry;
            $mode_label->set_text($is_readonly ? "-- READ ONLY --" : "-- " . uc($mode) . " --");
            $textview->grab_focus();
        }
    };

    my $get_cursor = sub { return $buffer->get_iter_at_mark($buffer->get_insert()); };
    
    my $move_vert = sub {
        my ($dir) = @_;
        my $c = $get_cursor->(); my $col = $c->get_line_offset(); my $n = $c->copy();
        $dir > 0 ? $n->forward_line() : $n->backward_line();
        my $e = $n->copy(); $e->forward_to_line_end();
        $col <= $e->get_line_offset() ? $n->set_line_offset($col) : $n->forward_to_line_end();
        $buffer->place_cursor($n);
        $textview->scroll_to_mark($buffer->get_insert(), 0.1, TRUE, 0, 0.5);
    };

    my $move_page = sub {
        my ($dir) = @_;
        my $vr = $textview->get_visible_rect(); my $c = $get_cursor->();
        my ($cx, $cy) = $textview->buffer_to_window_coords('widget', $c->get_x(), $c->get_y());
        my $ty = $cy + ($dir * $vr->{height});
        $ty = 10 if $ty < 10; $ty = $vr->{height} - 10 if $ty > $vr->{height} - 10;
        my $ti = $textview->get_iter_at_location($cx, $ty);
        if ($ti) { $buffer->place_cursor($ti); $textview->scroll_to_mark($buffer->get_insert(), 0.0, TRUE, 0.0, ($dir > 0 ? 1.0 : 0.0)); }
    };

    my $delete_line = sub {
        my $c = $get_cursor->();
        my $s = $c->copy(); $s->set_line_offset(0);
        my $e = $c->copy(); $e->forward_to_line_end();
        $yank_buffer = $buffer->get_text($s, $e, TRUE);
        $yank_buffer .= "\n" unless $e->is_end();
        $buffer->delete($s, $e);
        unless ($e->is_end()) { my $nc = $get_cursor->(); $buffer->delete($nc, $nc->copy()->forward_char()); }
    };

    $textview->signal_connect('key-press-event' => sub {
        my ($w, $e) = @_; my $k = Gtk3::Gdk::keyval_name($e->keyval) // ''; my $s = $e->state;
        return FALSE if $s & ['control-mask'];
        if ($vim_mode eq 'normal') {
            if ($k eq 'Up')        { $move_vert->(-1); $command_buffer=''; return TRUE; }
            if ($k eq 'Down')      { $move_vert->(1);  $command_buffer=''; return TRUE; }
            if ($k eq 'Page_Up')   { $move_page->(-1); $command_buffer=''; return TRUE; }
            if ($k eq 'Page_Down') { $move_page->(1);  $command_buffer=''; return TRUE; }
            $command_buffer .= $k;
            if    ($command_buffer eq 'i') { $set_mode->('insert'); }
            elsif ($command_buffer eq 'a') { my $c=$get_cursor->(); $c->forward_char() unless $c->ends_line(); $buffer->place_cursor($c); $set_mode->('insert'); }
            elsif ($command_buffer eq 'A') { my $c=$get_cursor->(); $c->forward_to_line_end(); $buffer->place_cursor($c); $set_mode->('insert'); }
            elsif ($command_buffer eq 'o') { my $c=$get_cursor->(); $c->forward_to_line_end(); $buffer->insert($c, "\n", -1); $set_mode->('insert'); }
            elsif ($command_buffer eq 'O') { my $c=$get_cursor->(); $c->set_line_offset(0); $buffer->insert($c, "\n", -1); $c->backward_char(); $buffer->place_cursor($c); $set_mode->('insert'); }
            elsif ($command_buffer eq 'h') { my $c=$get_cursor->(); $c->backward_char() unless $c->starts_line(); $buffer->place_cursor($c); }
            elsif ($command_buffer eq 'l') { my $c=$get_cursor->(); $c->forward_char() unless $c->ends_line(); $buffer->place_cursor($c); }
            elsif ($command_buffer eq 'j') { $move_vert->(1); }
            elsif ($command_buffer eq 'k') { $move_vert->(-1); }
            elsif ($command_buffer eq 'w') { my $c=$get_cursor->(); $c->forward_word_end(); if (!$c->is_end() && !$c->ends_line()) { $c->forward_char(); } $buffer->place_cursor($c); $textview->scroll_to_mark($buffer->get_insert(),0.1,TRUE,0,0.5); }
            elsif ($command_buffer eq 'b') { my $c=$get_cursor->(); $c->backward_word_start(); $buffer->place_cursor($c); $textview->scroll_to_mark($buffer->get_insert(),0.1,TRUE,0,0.5); }
            elsif ($command_buffer eq 'e') { my $c=$get_cursor->(); $c->forward_word_end(); if (!$c->is_end() && !$c->ends_line()) { $c->backward_char(); } $buffer->place_cursor($c); }
            elsif ($command_buffer eq '0') { my $c=$get_cursor->(); $c->set_line_offset(0); $buffer->place_cursor($c); }
            elsif ($command_buffer eq 'dollar') { my $c=$get_cursor->(); $c->forward_to_line_end(); $buffer->place_cursor($c); }
            elsif ($command_buffer eq 'G') { my $e=$buffer->get_end_iter(); $e->backward_line(); $buffer->place_cursor($e); $textview->scroll_to_mark($buffer->get_insert(),0.1,TRUE,0,0.5); }
            elsif ($command_buffer eq 'g') { return TRUE; }
            elsif ($command_buffer eq 'gg') { $buffer->place_cursor($buffer->get_start_iter()); $textview->scroll_to_mark($buffer->get_insert(),0.1,TRUE,0,0.5); }
            elsif ($command_buffer eq 'x') { my $c=$get_cursor->(); unless($c->ends_line()) { my $e=$c->copy(); $e->forward_char(); $yank_buffer=$buffer->get_text($c,$e,TRUE); $buffer->delete($c,$e); } }
            elsif ($command_buffer eq 'p') { if(length $yank_buffer) { my $c=$get_cursor->(); $buffer->insert($c, $yank_buffer, -1); } }
            elsif ($command_buffer eq 'u') { $buffer->undo(); }
            elsif ($command_buffer eq 'dd') { $delete_line->(); }
            elsif ($command_buffer eq 'yy') { my $c=$get_cursor->(); my $s=$c->copy(); $s->set_line_offset(0); $c->forward_to_line_end(); $yank_buffer=$buffer->get_text($s,$c,TRUE)."\n"; }
            elsif ($command_buffer eq 'dw') { my $c=$get_cursor->(); my $e=$c->copy(); $e->forward_word_end(); $yank_buffer=$buffer->get_text($c,$e,TRUE); $buffer->delete($c,$e); }
            elsif ($command_buffer eq 'colon') { $set_mode->('command'); }
            else { $command_buffer = ''; return TRUE; }
            $command_buffer = ''; return TRUE;
        } elsif ($vim_mode eq 'insert') {
            if ($k eq 'Escape') { $set_mode->('normal'); my $c = $get_cursor->(); $c->backward_char() unless $c->starts_line(); $buffer->place_cursor($c); return TRUE; }
            return FALSE;
        }
        return FALSE;
    });

    if ($cmd_entry) {
        $cmd_entry->signal_connect('key-press-event' => sub {
            my ($w, $e) = @_; my $k = Gtk3::Gdk::keyval_name($e->keyval) // '';
            if ($k eq 'Escape') { $set_mode->('normal'); return TRUE; }
            elsif ($k eq 'Return') {
                my $cmd = $cmd_entry->get_text(); $cmd =~ s/^:\s*//; $cmd =~ s/\s+$//;
                if ($cmd eq 'bindings') {
                    my $h = "NORMAL MODE:\n  i,a,A,o,O - Insert\n  h,j,k,l - Move\n  w,b,e - Words\n  0,\$ - Line start/end\n  gg,G - File start/end\n  PgUp/PgDn - Scroll\n  dd - Del line\n  yy - Yank line\n  x - Del char\n  p - Paste\n  u - Undo\nCMD MODE:\n  :w [file] - Save\n  :q - Quit\n  :q! - Force quit";
                    my $d = Gtk3::MessageDialog->new($textview->get_toplevel, 'destroy-with-parent', 'info', 'ok', $h);
                    $d->set_title("Bindings"); $d->set_default_size(400, 300);
                    my ($l) = $d->get_message_area()->get_children(); $l->set_xalign(0) if $l;
                    $d->run(); $d->destroy(); $set_mode->('normal');
                } elsif ($cmd eq 'q') {
                    if ($buffer->get_modified()) { $mode_label->set_text("Error: No write since last change (use :q!)"); return TRUE; }
                    Gtk3->main_quit();
                } elsif ($cmd eq 'q!') { Gtk3->main_quit(); }
                elsif ($cmd =~ /^w\s*(.*)?$/) {
                    my $sf = $1; $sf =~ s/^\s+|\s+$//g; $sf = $$filename_ref if !$sf;
                    if ($sf) { eval { open my $fh, '>', $sf or die $!; print $fh $buffer->get_text($buffer->get_start_iter, $buffer->get_end_iter, TRUE); close $fh; $buffer->set_modified(FALSE); $$filename_ref = $sf; $mode_label->set_text("Saved: $sf"); }; if ($@) { chomp $@; $mode_label->set_text("Error: $@"); } }
                    else { $mode_label->set_text("Error: No file name"); }
                    $set_mode->('normal');
                } else { $mode_label->set_text("Error: Unknown command"); $set_mode->('normal'); }
                return TRUE;
            }
            return FALSE;
        });
    }
    $set_mode->('normal');
    return 1;
}
1;
