#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name        => 'Gtk3::SourceEditor',
    license            => 'artistic_2',
    dist_author        => 'nkh',
    dist_version_from  => 'lib/Gtk3/SourceEditor.pm',
    dist_abstract      => 'Configurable Vim-like editor using Gtk3::SourceView',

    requires => {
        'perl'          => '5.020',
        'Gtk3'          => '0',
        'Glib'          => '0',
        'Pango'         => '0',
        'File::Slurper' => '0',
        'Encode'        => '0',
        'Getopt::Long'  => '0',
    },

    build_requires => {
        'Test::More'      => '0',
        'Test::Exception' => '0',
    },

    script_files => [
        'script/source-editor',
        'script/source-dialog-editor',
        'script/source-editor-cursor-demo',
    ],

    meta_merge => {
        resources => {
            #repository => 'https://github.com/nkh/',
            #bugtracker => 'https://github.com/nkh//issues',
        },
    },
);

$build->create_build_script();
