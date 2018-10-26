
=head1 NAME

SGN::Controller::AJAX::GenotypingQC - a REST controller class to provide the
backend for running genotype QC from an allele matrix upload

=head1 DESCRIPTION

Running Genotype QC from an allele matrix file (Intertek format)

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::GenotypingQC;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::UploadFile;
use CXGN::Genotype::ParseUpload;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Genotype::Protocol;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_genotype_qc_verify :  Path('/ajax/genotype_qc/upload') : ActionClass('REST') { }
sub upload_genotype_qc_verify_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my @error_status;
    my @success_status;

    #print STDERR Dumper $c->req->params();
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'submitter' && $user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to upload VCF genotypes! Please contact us.' };
        $c->detach();
    }

    #archive uploaded file
    my $upload_file = $c->req->upload('upload_genotype_qc_file_input');

    if (!defined($upload_file)) {
        $c->stash->{rest} = { error => 'Please provide a genotype qc file.' };
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $include_lab_numbers = 1;
    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $subdirectory = "genotype_qc_upload";
    my $parser_plugin = 'IntertekCSV';

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        return (\@success_status, \@error_status);
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $parser = CXGN::Genotype::ParseUpload->new({
        chado_schema => $schema,
        filename => $archived_filename_with_path,
        observation_unit_type_name => 'accession',
    });
    $parser->load_plugin($parser_plugin);
    my $parsed_data = $parser->parse();
    my $parse_errors;
    if (!$parsed_data) {
        my $return_error = '';
        if (!$parser->has_parse_errors() ){
            $return_error = "Could not get parsing errors";
            $c->stash->{rest} = {error_string => $return_error,};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
        $c->detach();
    }
    #print STDERR Dumper $parsed_data;
    my $observation_unit_uniquenames = $parsed_data->{observation_unit_uniquenames};
    my $genotype_info = $parsed_data->{genotypes_info};
    my $protocol_info = $parsed_data->{protocol_info};

    #print STDERR Dumper $genotype_info;
    #print STDERR Dumper $protocol_info;
    #print STDERR Dumper $observation_unit_uniquenames;

    $c->stash->{rest} = {success => 1};
}

1;
