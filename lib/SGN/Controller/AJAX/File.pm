package SGN::Controller::AJAX::File;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::File;
use Try::Tiny;

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

has 'schema' => (
        is       => 'rw',
        isa      => 'DBIx::Class::Schema',
        lazy_build => 1,
    );

sub file : Chained('/') PathPart('ajax/file/') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $file_id = shift;

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $user_id);

    my $archive_path = $c->config->{archive_path};

    my $file = CXGN::File->new({
        metadata_schema => $metadata_schema,
        file_id => $file_id,
        archive_path => $archive_path
    });

    $c->stash->{archived_file} = $file;
    $c->stash->{metadata_schema} = $metadata_schema;
    $c->stash->{file_id} = $file_id;

    if (!$c->stash->{archived_file}) {
        $c->stash->{rest} = {error => "The file with ID $file_id does not exist."};
        return;
    }
}

sub set_file_type : Chained('file') PathPart('set_file_type') Args(1) {
    my $self = shift;
    my $c = shift;
    my $file_type = shift;
    my $file = $c->stash->{archived_file};
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    if (!($c->user()->check_roles('curator') || $user_id == $file->user_directory())) {
        $c->stash->{rest} = {error => "You do not have permission to modify this file entry. You must either be the uploader or a curator."};
        return;
    }

    try {
        $file->set_file_type($file_type);
    } catch {
        $c->stash->{rest} = {error => "Could not save file type: $_"};
        return;
    };
    
    $c->stash->{rest} = {success => 1};
}

1;