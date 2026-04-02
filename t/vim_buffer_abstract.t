#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use lib ('t/lib', 'lib');
use Gtk3::SourceEditor::VimBuffer;
use Gtk3::SourceEditor::VimBuffer::Test;
use Gtk3::SourceEditor::VimBindings;

# ==========================================================================
# VimBuffer abstract interface — verify abstract methods die,
# predicate methods work, Test backend implements everything
# ==========================================================================

# --- Abstract methods die on base class ---
subtest 'Abstract: cursor_line dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->cursor_line };
    like($@, qr/Unimplemented/i, 'cursor_line dies on base class');
};

subtest 'Abstract: cursor_col dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->cursor_col };
    like($@, qr/Unimplemented/i, 'cursor_col dies on base class');
};

subtest 'Abstract: set_cursor dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->set_cursor(0, 0) };
    like($@, qr/Unimplemented/i, 'set_cursor dies on base class');
};

subtest 'Abstract: line_count dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->line_count };
    like($@, qr/Unimplemented/i, 'line_count dies on base class');
};

subtest 'Abstract: line_text dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->line_text(0) };
    like($@, qr/Unimplemented/i, 'line_text dies on base class');
};

subtest 'Abstract: line_length dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->line_length(0) };
    like($@, qr/Unimplemented/i, 'line_length dies on base class');
};

subtest 'Abstract: text dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->text };
    like($@, qr/Unimplemented/i, 'text dies on base class');
};

subtest 'Abstract: get_range dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->get_range(0, 0, 0, 1) };
    like($@, qr/Unimplemented/i, 'get_range dies on base class');
};

subtest 'Abstract: delete_range dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->delete_range(0, 0, 0, 1) };
    like($@, qr/Unimplemented/i, 'delete_range dies on base class');
};

subtest 'Abstract: insert_text dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->insert_text("x") };
    like($@, qr/Unimplemented/i, 'insert_text dies on base class');
};

subtest 'Abstract: undo dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->undo };
    like($@, qr/Unimplemented/i, 'undo dies on base class');
};

subtest 'Abstract: modified dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->modified };
    like($@, qr/Unimplemented/i, 'modified dies on base class');
};

subtest 'Abstract: set_modified dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->set_modified(1) };
    like($@, qr/Unimplemented/i, 'set_modified dies on base class');
};

subtest 'Abstract: word_forward dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->word_forward };
    like($@, qr/Unimplemented/i, 'word_forward dies on base class');
};

subtest 'Abstract: join_lines dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->join_lines(1) };
    like($@, qr/Unimplemented/i, 'join_lines dies on base class');
};

subtest 'Abstract: search_forward dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->search_forward("x") };
    like($@, qr/Unimplemented/i, 'search_forward dies on base class');
};

subtest 'Abstract: transform_range dies' => sub {
    my $buf = bless {}, 'Gtk3::SourceEditor::VimBuffer';
    eval { $buf->transform_range(0, 0, 0, 1, 'upper') };
    like($@, qr/Unimplemented/i, 'transform_range dies on base class');
};

# --- Predicate methods on Test backend ---
subtest 'Predicate: at_line_start' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 0);
    ok($vb->at_line_start, 'col 0 is line start');
    $vb->set_cursor(0, 3);
    ok(!$vb->at_line_start, 'col 3 is not line start');
};

subtest 'Predicate: at_line_end' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 5);
    ok($vb->at_line_end, 'col 5 (len) is line end');
    $vb->set_cursor(0, 2);
    ok(!$vb->at_line_end, 'col 2 is not line end');
};

# "hello\n" splits into ["hello", ""] — 2 lines.
# Buffer end = last line (1) at end of line (col 0, since line 1 is empty).
subtest 'Predicate: at_buffer_end' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    $vb->set_cursor(0, 5);
    ok(!$vb->at_buffer_end, 'line 0 end is not buffer end (2 lines total)');
    $vb->set_cursor(1, 0);
    ok($vb->at_buffer_end, 'last line, last col = buffer end');
    $vb->set_cursor(0, 0);
    ok(!$vb->at_buffer_end, 'col 0 is not buffer end');
};

# "hello\nworld\n" splits into ["hello", "world", ""] — 3 lines.
subtest 'Predicate: at_buffer_end multi-line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\nworld\n");
    $vb->set_cursor(0, 5);
    ok(!$vb->at_buffer_end, 'line 0 end is not buffer end');
    $vb->set_cursor(1, 5);
    ok(!$vb->at_buffer_end, 'line 1 end is not buffer end');
    $vb->set_cursor(2, 0);
    ok($vb->at_buffer_end, 'line 2 col 0 = buffer end');
};

# --- Test backend: basic operations work ---
subtest 'Test backend: construction with text' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "line1\nline2\n");
    is($vb->line_count, 3, '2 lines + trailing newline = 3 lines');
    is($vb->line_text(0), 'line1', 'first line text');
    is($vb->line_text(1), 'line2', 'second line text');
    is($vb->text, "line1\nline2\n", 'full buffer text');
};

subtest 'Test backend: construction without text' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new;
    is($vb->line_count, 1, 'empty buffer has 1 line');
    is($vb->line_text(0), '', 'single empty line');
};

# Insert "BB\n" at (0, 2) on "aa\ncc\n":
# Buffer is ["aa", "cc", ""], cursor at col 2 (end of "aa").
# insert_text("BB\n") splits "aa" into "aaBB" + new empty line.
# Result: ["aaBB", "", "cc", ""] → text = "aaBB\n\ncc\n"
subtest 'Test backend: insert_text multi-line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "aa\ncc\n");
    $vb->set_cursor(0, 2);
    $vb->insert_text("BB\n");
    is($vb->text, "aaBB\n\ncc\n", 'multi-line insert splits line correctly');
};

# delete_range(0, 2, 2, 2) on "abcd\nefgh\nijkl\n":
# Buffer is ["abcd", "efgh", "ijkl", ""].
# new_line = substr("abcd", 0, 2) + substr("ijkl", 2) = "ab" + "kl" = "abkl"
# splice removes lines 0-2, inserts "abkl". Result: ["abkl", ""]
subtest 'Test backend: delete_range cross-line' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abcd\nefgh\nijkl\n");
    $vb->delete_range(0, 2, 2, 2);
    is($vb->text, "abkl\n", 'cross-line delete: keeps first part + tail of last line');
};

subtest 'Test backend: set_modified / modified' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello\n");
    ok(!$vb->modified, 'new buffer is unmodified');
    $vb->set_modified(1);
    ok($vb->modified, 'set_modified(1) works');
    $vb->set_modified(0);
    ok(!$vb->modified, 'set_modified(0) works');
};

subtest 'Test backend: char_at' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "abc\n");
    is($vb->char_at(0, 0), 'a', 'char at (0,0)');
    is($vb->char_at(0, 2), 'c', 'char at (0,2)');
    is($vb->char_at(0, 3), '', 'char past end of line is empty');
    is($vb->char_at(5, 0), '', 'char on non-existent line is empty');
};

subtest 'Test backend: transform_range upper' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "hello world\n");
    $vb->transform_range(0, 0, 0, 5, 'upper');
    is($vb->text, "HELLO world\n", 'transform_range upper works');
};

subtest 'Test backend: transform_range lower' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "HELLO world\n");
    $vb->transform_range(0, 6, 0, 11, 'lower');
    is($vb->text, "HELLO world\n", 'transform_range lower works');
};

subtest 'Test backend: cursor clamping' => sub {
    my $vb = Gtk3::SourceEditor::VimBuffer::Test->new(text => "ab\ncd\n");
    $vb->set_cursor(0, 10);  # past end of line
    is($vb->cursor_col, 2, 'col clamped to line length');
    $vb->set_cursor(99, 0);   # past end of buffer
    is($vb->cursor_line, 2, 'line clamped to last line');
    $vb->set_cursor(-1, 0);   # negative line
    is($vb->cursor_line, 0, 'negative line clamped to 0');
};

done_testing;
