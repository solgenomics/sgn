
=head1 NAME

SGN::Controller::AJAX::ODK - a REST controller class to provide the
backend for ODK services

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::ODK;

use Moose;
use List::MoreUtils qw /any /;
use Data::Dumper;
use Try::Tiny;
use CXGN::Phenome::Schema;
use Bio::Chado::Schema;
use DateTime;
use SGN::Model::Cvterm;
use LWP::UserAgent;
use JSON;
use CXGN::ODK::Crosses;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub get_phenotyping_data : Path('/ajax/odk/get_phenotyping_data') : ActionClass('REST') { }

sub get_phenotyping_data_GET {
    my ( $self, $c ) = @_;
    my $odk_phenotyping_data_service_name = $c->config->{odk_phenotyping_data_service_name};
    my $odk_phenotyping_data_service_username = $c->config->{odk_phenotyping_data_service_username};
    my $odk_phenotyping_data_service_password = $c->config->{odk_phenotyping_data_service_password};
    if ($odk_phenotyping_data_service_name eq 'SMAP'){
        my $ua = LWP::UserAgent->new;
        my $server_endpoint = "https://".$odk_phenotyping_data_service_username.":".$odk_phenotyping_data_service_password."\@bio.smap.com.au/api/v1/data";
        print STDERR $server_endpoint."\n";

        my $resp = $ua->get($server_endpoint);
        if ($resp->is_success) {
            my $message = $resp->decoded_content;
            my $message_hash = decode_json $message;
            print STDERR Dumper $message_hash;
        } else {
            print STDERR Dumper $resp;
        }

    } else {
        $c->stash->{rest} = { error => 'Error: We only support SMAP as an ODK phenotyping service for now.' };
        $c->detach();
    }
    $c->stash->{rest} = { success => 1 };
}

sub get_crossing_available_forms : Path('/ajax/odk/get_crossing_available_forms') : ActionClass('REST') { }

sub get_crossing_available_forms_GET {
    my ( $self, $c ) = @_;
    my $odk_crossing_data_service_name = $c->config->{odk_crossing_data_service_name};
    my $message_hash;
    if ($odk_crossing_data_service_name eq 'ONA'){
        my $ua = LWP::UserAgent->new;
        $ua->credentials( 'api.ona.io:443', 'DJANGO', $c->config->{odk_crossing_data_service_username}, $c->config->{odk_crossing_data_service_password} );
        my $login_resp = $ua->get("https://api.ona.io/api/v1/user.json");
        my $server_endpoint = "https://api.ona.io/api/v1/data";
        my $resp = $ua->get($server_endpoint);

        if ($resp->is_success) {
            my $message = $resp->decoded_content;
            $message_hash = decode_json $message;
        }
    } else {
        $c->stash->{rest} = { error => 'Error: We only support ONA as an ODK crossing service for now.' };
        $c->detach();
    }
    $c->stash->{rest} = { success => 1, forms=>$message_hash };
}

sub get_crossing_data : Path('/ajax/odk/get_crossing_data') : ActionClass('REST') { }

sub get_crossing_data_GET {
    my ( $self, $c ) = @_;
    my $form_id = $c->req->param('form_id');
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
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
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $tempfiles_dir = $c->tempfiles_subdir('ODK_ONA_cross_info');
    my ($temp_file, $uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_cross_info_downloadXXXXX');
    my $temp_file_path = $temp_file->filename;
    my $odk_crosses = CXGN::ODK::Crosses->new({
        bcs_schema=>$bcs_schema,
        metadata_schema=>$metadata_schema,
        sp_person_id=>$user_id,
        sp_person_role=>$user_role,
        archive_path=>$c->config->{archive_path},
        temp_file_path=>$temp_file_path,
        odk_crossing_data_service_username=>$c->config->{odk_crossing_data_service_username},
        odk_crossing_data_service_password=>$c->config->{odk_crossing_data_service_password},
        odk_crossing_data_service_form_id=>$form_id
    });

    my $odk_crossing_data_service_name = $c->config->{odk_crossing_data_service_name};
    if ($odk_crossing_data_service_name eq 'ONA'){
        my $result = $odk_crosses->save_ona_cross_info();
        if ($result->{error}){
            $c->stash->{rest} = { error => $result->{error} };
            $c->detach();
        } elsif ($result->{success}){
            $c->stash->{rest} = { success => 1 };
            $c->detach();
        }
    } else {
        $c->stash->{rest} = { error => 'Error: We only support ONA as an ODK crossing service for now.' };
        $c->detach();
    }
}


1;
