package File::Slurper;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(read_text read_binary write_text);

sub read_text {
    my ($file) = @_;
    return '' unless defined $file && -f $file;
    open my $fh, '<:encoding(UTF-8)', $file or return '';
    local $/;
    my $text = <$fh>;
    close $fh;
    return $text // '';
}

sub read_binary {
    my ($file) = @_;
    return '' unless defined $file && -f $file;
    open my $fh, '<:raw', $file or return '';
    local $/;
    my $data = <$fh>;
    close $fh;
    return $data // '';
}

sub write_text {
    my ($file, $text) = @_;
    return unless defined $file;
    open my $fh, '>:encoding(UTF-8)', $file or return;
    print $fh $text;
    close $fh;
}

1;
