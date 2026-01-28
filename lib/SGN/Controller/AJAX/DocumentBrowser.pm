
=head1 NAME

SGN::Controller::AJAX::DocumentBrowser - a REST controller class to provide the backend for uploading documents and searching them using the document browser tool.

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DocumentBrowser;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use CXGN::UploadFile;
use File::Basename qw | basename dirname|;
use JSON;
use CXGN::File;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_document :  Path('/ajax/tools/documents/upload') : ActionClass('REST') { }
sub upload_document_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");

    if (!$c->user){
        $c->stash->{rest} = { error => 'Must be logged in!' };
        $c->detach;
    }
    
    my $user_id = $c->user->get_object->get_sp_person_id;
    my $user_type = $c->user->get_object->get_user_type();

    my $uploads = $c->req->upload('upload_document_browser_file_input');
    my $factory_uploads = $c->req->uploads->{'upload_factory_archive_new_file[]'};

    if ($factory_uploads) {
        $uploads = $factory_uploads;
    }

    $uploads = [$uploads] unless ref($uploads) eq 'ARRAY';

    foreach my $upload (@$uploads) {
        my $upload_original_name = $upload->filename();
        my $upload_tempfile = $upload->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        my $archive_path = $c->config->{archive_path};

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => 'document_browser',
            archive_path => $archive_path,
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_type
        });
        my $archived_filename_with_path = $uploader->archive();
        if (!$archived_filename_with_path){
            $c->stash->{rest} = { error => 'Problem archiving the files!' };
            $c->detach;
        }
        $archived_filename_with_path =~ s/$archive_path//g;
        my $md5 = $uploader->get_md5("$archive_path/$archived_filename_with_path");
        if (!$md5){
            $c->stash->{rest} = { error => 'Problem retrieving file md5 checksums!' };
            $c->detach;
        }

        my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
        $md_row->insert();
        my $file_row = $metadata_schema->resultset("MdFiles")
            ->create({
                basename => basename($archived_filename_with_path),
                dirname => dirname($archived_filename_with_path),
                filetype => 'document_browser',
                md5checksum => $md5->hexdigest(),
                metadata_id => $md_row->metadata_id(),
            });
        $file_row->insert();
    }

    $c->stash->{rest} = {success => 'Successfully saved file!'};
}

sub search_document :  Path('/ajax/tools/documents/search') : ActionClass('REST') { }
sub search_document_POST : Args(0) {
    my ($self, $c) = @_;
    my $file_ids = $c->req->param("file_ids");
    my $search = $c->req->param("search");

    my $file_ids_ref;
    if ($file_ids){
        $file_ids_ref = decode_json $file_ids;
    }

    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $file_rs = $metadata_schema->resultset("MdFiles")->search({file_id => {-in => $file_ids_ref}});
    my @files;
    while(my $r = $file_rs->next()){
        my $dirname = $r->dirname();
        my $basename = $r->basename();
        my $file_path = $dirname. "/" .$basename;
        push @files, $file_path;
    }

    my @found_lines;
    my @list_elements;
    foreach my $f (@files){
        open(my $fh, '< :encoding(UTF-8)', $f)
            or die "Could not open file '$f' $!";

        while (my $row = <$fh>) {
            if (index($row, $search) != -1) {
                push @found_lines, $row;
                my @col = split "\t", $row;
                push @list_elements, $col[0];
            }
        }
    }
    $c->stash->{rest} = {success => 1, found_lines => \@found_lines, list_elements => \@list_elements};
}

sub user_archived_files : Path('/ajax/tools/documents/user_archive') : ActionClass('REST') { }
sub user_archived_files_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id = $c->req->param("user_id") || undef;

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if (!$user_id || ($user_id ne $logged_user && $role ne "curator")) {
        $c->stash->{rest} = {error => "You do not have permission to view these files.\n"} ;
        return;
    }

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema", undef, $logged_user);

    my $dbh = $c->dbc->dbh();
    my $q;
    my $data;

    if ($role eq "curator") {
        $data = CXGN::File->get_all_archived_files($bcs_schema);
    } else {
        $data = CXGN::File->get_user_archived_files($bcs_schema, $user_id);
    }

    $c->stash->{rest} = {success => 1, data => $data};
    return;
}

#########
1;
#########
