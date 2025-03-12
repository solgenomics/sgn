=head1 NAME

SGN::Controller::AJAX::Cross::CrossingExperiment - a REST controller class to provide
functions related to crossing experiment

=head1 DESCRIPTION


=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut

package SGN::Controller::AJAX::Cross::CrossingExperiment;
use Moose;
use Try::Tiny;
use DateTime;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use Data::Dumper;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use List::MoreUtils qw /any /;
use List::MoreUtils 'none';
use CXGN::UploadFile;
use CXGN::Pedigree::ParseUpload;
use CXGN::Pedigree::TargetNumbers;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use JSON;
use Tie::UrlEncoder; our(%urlencode);
use LWP::UserAgent;
use URI::Encode qw(uri_encode uri_decode);
BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub upload_target_numbers : Path('/ajax/crossing_experiment/upload_target_numbers') : ActionClass('REST'){ }

sub upload_target_numbers_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $dbh = $c->dbc->dbh;
    my $target_numbers_experiment_id = $c->req->param('target_numbers_experiment_id');
    my $upload = $c->req->upload('target_numbers_file');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "target_numbers_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
    my $session_id = $c->req->param("sgn_session_id");
    my @error_messages;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload target numbers!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload intercross data!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    #if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
    if (my $message = $c->stash->{access}->denied( $user_id, "write", "crosses" )) { 
        $c->stash->{rest} = { error => 'You do not have the privileges to upload target numbers of seed/progenies' };
        $c->detach();
    }

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

        ## Store uploaded temporary file in arhive
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TargetNumbersExcel');
    $parsed_data = $parser->parse();
    #print STDERR "PARSED DATA =". Dumper($parsed_data)."\n";
    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    if ($parsed_data){

        my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
        $md_row->insert();
        my $upload_file = CXGN::UploadFile->new();
        my $md5 = $upload_file->get_md5($archived_filename_with_path);
        my $md5checksum = $md5->hexdigest();
        my $file_row = $metadata_schema->resultset("MdFiles")->create({
            basename => basename($archived_filename_with_path),
            dirname => dirname($archived_filename_with_path),
            filetype => 'target_numbers_upload',
            md5checksum => $md5checksum,
            metadata_id => $md_row->metadata_id(),
        });
        my $file_id = $file_row->file_id();
        my %target_numbers = %{$parsed_data};

#        print STDERR "UPLOAD TARGET NUMBERS=".Dumper(\%target_numbers)."\n";
        my $targets = CXGN::Pedigree::TargetNumbers->new({ chado_schema => $schema, crossing_experiment_id => $target_numbers_experiment_id, target_numbers => \%target_numbers });
    	$targets->store();
    }


    $c->stash->{rest} = {success => "1",};
}


sub record_target_numbers_using_lists : Path('/ajax/crossing_experiment/record_target_numbers') : ActionClass('REST') { }

sub record_target_numbers_using_lists_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $crossing_experiment_id = $c->req->param('crossing_experiment_id');
    my $number_of_seeds = decode_json $c->req->param('number_of_seeds');
    my $number_of_progenies = decode_json $c->req->param('number_of_progenies');

    my %target_numbers_hash;
    foreach my $seed_info_hash (@$number_of_seeds) {
        my $number_of_seeds = $seed_info_hash->{'number_of_seeds'};
        if ($number_of_seeds) {
            $target_numbers_hash{$seed_info_hash->{'female_name'}}{$seed_info_hash->{'male_name'}}{'target_number_of_seeds'} = $number_of_seeds;
        }
    }

    foreach my $progeny_info_hash (@$number_of_progenies) {
        my $number_of_progenies = $progeny_info_hash->{'number_of_progenies'};
        if ($number_of_progenies) {
            $target_numbers_hash{$progeny_info_hash->{'female_name'}}{$progeny_info_hash->{'male_name'}}{'target_number_of_progenies'} = $number_of_progenies;
        }
    }

#    print STDERR "TARGET NUMBERS HASH =".Dumper(\%target_numbers_hash)."\n";
    my $targets = CXGN::Pedigree::TargetNumbers->new({ chado_schema => $schema, crossing_experiment_id => $crossing_experiment_id, target_numbers => \%target_numbers_hash });
    $targets->store();

    $c->stash->{rest} = {success => "1",};

}

sub get_target_numbers_and_progress :Path('/ajax/crossing_experiment/target_numbers_and_progress') Args(1) {
    my $self = shift;
    my $c = shift;
    my $crossing_experiment_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $target_numbers = CXGN::Pedigree::TargetNumbers->new({ chado_schema => $schema, crossing_experiment_id => $crossing_experiment_id});
    my $target_info = $target_numbers->get_target_numbers_and_progress();
#    print STDERR "AJAX TARGET NUMBERS =".Dumper($target_info)."\n";


    $c->stash->{rest} = { data => $target_info };

}


1;
