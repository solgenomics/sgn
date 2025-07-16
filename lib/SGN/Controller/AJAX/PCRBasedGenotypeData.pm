
=head1 NAME

SGN::Controller::AJAX::PCRBasedGenotypeData

=head1 DESCRIPTION


=head1 AUTHOR


=cut

package SGN::Controller::AJAX::PCRBasedGenotypeData;

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
use CXGN::Genotype::StorePCRMarkerInfo;
use File::Basename qw | basename dirname|;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

sub upload_ssr_protocol : Path('/ajax/genotype/upload_ssr_protocol') : ActionClass('REST'){ }

sub upload_ssr_protocol_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('xls_ssr_protocol_file');
    my $upload_type = 'SSRProtocolExcel';
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "ssr_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my %upload_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload SSR marker info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload progenies!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
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

    my $protocol_name = $c->req->param('upload_ssr_protocol_name');
    my $protocol_description = $c->req->param('upload_ssr_protocol_description_input');
    my $species_name = $c->req->param('upload_ssr_species_name_input');
#    my $sample_type = $c->req->param('upload_ssr_sample_type_select');
    my $sample_type = 'tissue_sample_or_accession';

    my $organism_check = "SELECT organism_id FROM organism WHERE species = ?";
    my @found_organisms;
    my $h = $chado_schema->storage->dbh()->prepare($organism_check);
    $h->execute($species_name);
    while (my ($organism_id) = $h->fetchrow_array()){
        push @found_organisms, $organism_id;
    }
    if (scalar(@found_organisms) == 0){
        $c->stash->{rest} = { error => 'The organism species you provided is not in the database! Please contact us.' };
        $c->detach();
    }
    if (scalar(@found_organisms) > 1){
        $c->stash->{rest} = { error => 'The organism species you provided is not unique in the database! Please contact us.' };
        $c->detach();
    }
    my $organism_id = $found_organisms[0];

 #   print STDERR "PROTOCOL NAME =".Dumper($protocol_name)."\n";
#    print STDERR "PROTOCOL DESCRIPTION =".Dumper($protocol_description)."\n";
#    print STDERR "SPECIES NAME =".Dumper($species_name)."\n";

    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="ssr upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Genotype::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, observation_unit_type_name => $sample_type);
    $parser->load_plugin($upload_type);
    $parsed_data = $parser->parse();
#    print STDERR "PARSED DATA =". Dumper($parsed_data)."\n";

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

    my $pcr_markers = CXGN::Genotype::StorePCRMarkerInfo->new({
        bcs_schema => $chado_schema,
        protocol_name => $protocol_name,
        protocol_description => $protocol_description,
        species_name => $species_name,
        sample_observation_unit_type_name => $sample_type,
        marker_type => 'SSR',
        marker_details => $parsed_data
    });

    my $protocol_id = $pcr_markers->store_pcr_marker_info();
#    print STDERR "PROTOCOL ID =".Dumper($protocol_id)."\n";

    if (!$protocol_id) {
        $c->stash->{rest} = {error_string => "Error saving PCR marker info",};
        return;
    }

    $c->stash->{rest} = {success => "1", protocol_id => $protocol_id};

}


###
1;#
###
