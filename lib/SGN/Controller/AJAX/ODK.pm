
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
use LWP::Simple;
use LWP::UserAgent;
use JSON;
use CXGN::ODK::Crosses;
use Carp;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw(make_path);
use CXGN::List;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $dbh = $bcs_schema->storage->dbh;
    my $odk_crossing_data_service_name = $c->config->{odk_crossing_data_service_name};
    my $session_id = $c->req->param('session_id');

    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to look at ONA forms!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to look at ONA forms!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

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
    }
    $c->stash->{rest} = { success => 1, forms=>$message_hash };
}

sub get_crossing_data : Path('/ajax/odk/get_crossing_data') : ActionClass('REST') { }

sub get_crossing_data_GET {
    my ( $self, $c ) = @_;
    my $form_id = $c->req->param('form_id');
    print STDERR Dumper $form_id;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to request ODK crossing data import!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to request ODK crossing data import!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $user_id);
    my $tempfiles_dir = $c->tempfiles_subdir('ODK_ONA_cross_info');
    my ($cross_wishlist_temp_file, $cross_wishlist_uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_cross_wishlist_downloadXXXXX');
    my $cross_wishlist_temp_file_path = $cross_wishlist_temp_file->filename;
    my ($germplasm_info_temp_file, $germplasm_info_uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_germplasm_info_downloadXXXXX');
    my $germplasm_info_temp_file_path = $germplasm_info_temp_file->filename;

    my $progress_tree_dir = catdir($c->site_cluster_shared_dir, "ODK_ONA_cross_info");

    my $odk_crosses = CXGN::ODK::Crosses->new({
        bcs_schema=>$bcs_schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        sp_person_id=>$user_id,
        sp_person_username=>$user_name,
        sp_person_role=>$user_role,
        archive_path=>$c->config->{archive_path},
        temp_file_dir=>$c->config->{basepath}.$tempfiles_dir,
        cross_wishlist_temp_file_path=>$cross_wishlist_temp_file_path,
        germplasm_info_temp_file_path=>$germplasm_info_temp_file_path,
        allowed_cross_properties=>$c->config->{cross_properties},
        odk_crossing_data_service_url=>$c->config->{odk_crossing_data_service_url},
        odk_crossing_data_service_username=>$c->config->{odk_crossing_data_service_username},
        odk_crossing_data_service_password=>$c->config->{odk_crossing_data_service_password},
        odk_crossing_data_service_form_id=>$form_id,
        odk_cross_progress_tree_file_dir=>$progress_tree_dir
    });

    my $odk_crossing_data_service_name = $c->config->{odk_crossing_data_service_name};
    if ($odk_crossing_data_service_name eq 'ONA'){
        my $result = $odk_crosses->save_ona_cross_info($c);
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

sub schedule_get_crossing_data : Path('/ajax/odk/schedule_get_crossing_data') : ActionClass('REST') { }

sub schedule_get_crossing_data_GET {
    my ( $self, $c ) = @_;
    if ($c->config->{production_server}){
        $c->stash->{rest} = { error=>'Please use contact form. Currently this cannot be set through the website.' };
        $c->detach();
    }
    my $form_id = $c->req->param('form_id');
    my $timing_select = $c->req->param('timing');
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to schedule ODK crossing data import!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to schedule ODK crossing data import!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);
    my $tempfiles_dir = $c->tempfiles_subdir('ODK_ONA_cross_info');
    my ($temp_file, $uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_cross_info_downloadXXXXX');
    my $temp_file_path = $temp_file->filename;
    my ($cross_wishlist_temp_file, $cross_wishlist_uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_cross_wishlist_downloadXXXXX');
    my $cross_wishlist_temp_file_path = $cross_wishlist_temp_file->filename;
    my ($germplasm_info_temp_file, $germplasm_info_uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_germplasm_info_downloadXXXXX');
    my $germplasm_info_temp_file_path = $germplasm_info_temp_file->filename;

    my $progress_tree_dir = catdir($c->site_cluster_shared_dir, "ODK_ONA_cross_info");

    my $cross_properties = $c->config->{cross_properties};
    my $rootpath = $c->config->{rootpath};
    my $basepath = $c->config->{basepath};
    my $archive_path = $c->config->{archive_path};
    my $ODK_url = $c->config->{odk_crossing_data_service_url};
    my $ODk_username = $c->config->{odk_crossing_data_service_username};
    my $ODK_password = $c->config->{odk_crossing_data_service_password};
    my $database_name = $c->config->{dbname};
    my $database_user = $c->config->{dbuser};
    my $database_pass = $c->config->{dbpass};
    my $database_host = $c->config->{dbhost};
    my $www_user = $c->config->{www_user};
    my $crontab_log = $c->config->{crontab_log_filepath};
    my $include_path = 'export PERL5LIB="$PERL5LIB:'.$basepath.'/lib:'.$rootpath.'/cxgn-corelibs/lib:'.$rootpath.'/Phenome/lib:'.$rootpath.'/local-lib/lib/perl5"';
    my $perl_command = "$include_path; perl $basepath/bin/ODK/ODK_ONA_get_crosses.pl -u $user_id -i $user_name -r $user_role -a $archive_path -d $basepath.$tempfiles_dir -t $temp_file_path -n $ODk_username -m $ODK_password -o $form_id -q $cross_wishlist_temp_file_path -y $germplasm_info_temp_file_path -f $progress_tree_dir -l $ODK_url -c $cross_properties -D $database_name -U $database_user -p $database_pass -H $database_host >> $crontab_log 2>&1";
    my $timing = '';
    if ($timing_select eq 'everyminute'){
        $timing = "0-59/1 * * * * ";
    } elsif ($timing_select eq 'everyday'){
        $timing = "1 0 * * * ";
    } elsif ($timing_select eq 'everyhour'){
        $timing = "0 * * * * ";
    } elsif ($timing_select eq 'twicedaily'){
        $timing = "0 0,12 * * * ";
    }
    my $crontab_line = $timing.$perl_command."\n";
    #print STDERR $crontab_line;
    my $crontab_file = $c->config->{crontab_file};
    open (my $F, "> :encoding(UTF-8)", $crontab_file) || die "Could not open $crontab_file: $!\n";
        if ($timing){
            print $F $crontab_line;
        }
    close $F;

    my $enable_new_crontab = "crontab -u $www_user $crontab_file";
    system($enable_new_crontab);

    $c->stash->{rest} = { success => 1 };
    $c->detach();
}


sub get_crossing_data_cronjobs : Path('/ajax/odk/get_crossing_data_cronjobs') : ActionClass('REST') { }

sub get_crossing_data_cronjobs_GET {
    my ( $self, $c ) = @_;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to see scheduled ODK crossing data import!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to see scheduled ODK crossing data import!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my @entries;
    my $crontab_file = $c->config->{crontab_file};
    if ($crontab_file ne 'NULL') {
        open(my $fh, '< :encoding(UTF-8)', $crontab_file)
            or die "Could not open file '$crontab_file' $!";

        while (my $row = <$fh>) {
            chomp $row;
            my @c = split 'export', $row;
            push @entries, $c[0];
        }
        close $fh;
    }

    $c->stash->{rest} = { success => 1, entries=>\@entries };
    $c->detach();
}

sub get_crossing_available_wishlists : Path('/ajax/odk/get_crossing_available_wishlists') : ActionClass('REST') { }

sub get_crossing_available_wishlists_GET {
    my ( $self, $c ) = @_;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to see ODK cross wishlists!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to see ODK cross wishlists!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);

    my $wishlist_md_files = $metadata_schema->resultset("MdFiles")->search({filetype=> { '-like' => 'cross_wishlist_%',  }});
    my @wishlists;
    while (my $r=$wishlist_md_files->next){
        if (index($r->filetype, 'cross_wishlist_germplasm_info_') == -1) {
            push @wishlists, [$r->file_id, $r->filetype];
        }
    }
    #print STDERR Dumper \@wishlists;

    $c->stash->{rest} = { success => 1, wishlists => \@wishlists };
    $c->detach();
}

sub get_odk_cross_progress_cached : Path('/ajax/odk/get_odk_cross_progress_cached') : ActionClass('REST') { }

sub get_odk_cross_progress_cached_GET {
    my ( $self, $c ) = @_;
    my $ona_form_id = $c->req->param("form_id");
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to see ODK crossing data progress!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to see ODK crossing data progress!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);

    my $dir = catdir($c->site_cluster_shared_dir, "ODK_ONA_cross_info");
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/ona_odk_cross_progress_top_level_json_html_".$ona_form_id.".txt";
    print STDERR "Opening $filename \n";
    my $json;
    open(my $fh, '< ":encoding(UTF-8)', $filename) or warn "cannot open file $filename";
    {
        local $/;
        my $line = <$fh>;
        $json = $line && $line ne '{}' ? decode_json $line : {};
    }
    close($fh);

    my $top_level_id = $c->req->param('id');
    print STDERR "ODK Cross Tree Progress Node: ".$top_level_id."\n";
    if ($top_level_id eq '#'){
        $top_level_id = undef;
    }
    if ($top_level_id){
        $filename = $dir."/ona_odk_cross_progress_top_level_contents_html_".$ona_form_id.".txt";
        print STDERR "Opening $filename \n";
        my $top_level_contents;
        open(my $fh, '< :encoding(UTF-8)', $filename) or warn "cannot open file $filename";
        {
            local $/;
            my $line = <$fh>;
            $top_level_contents = $line && $line ne '{}' ? decode_json $line : {};
        }
        close($fh);
        $json = $top_level_contents->{$top_level_id};
    }

    #print STDERR Dumper $json;
    $c->stash->{rest} = $json;
}

sub get_odk_cross_summary_cached : Path('/ajax/odk/get_odk_cross_summary_cached') : ActionClass('REST') { }

sub get_odk_cross_summary_cached_GET {
    my ( $self, $c ) = @_;
    my $ona_form_id = $c->req->param("form_id");
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to see ODK crossing data progress!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to see ODK crossing data progress!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);

    my $dir = catdir($c->site_cluster_shared_dir, "ODK_ONA_cross_info");
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/ona_odk_cross_progress_summary_info_html_".$ona_form_id.".txt";
    print STDERR "Opening $filename \n";
    my $summary;
    open(my $fh, '< :encoding(UTF-8)', $filename) or warn "cannot open file $filename";
    {
        local $/;
        my $line = <$fh>;
        $summary = $line && $line ne '{}' ? decode_json $line : undef;
    }
    close($fh);
    $filename = $dir."/ona_odk_cross_progress_summary_plant_status_info_html_".$ona_form_id.".txt";
    print STDERR "Opening $filename \n";
    my $plant_status_summary;
    open($fh, '< :encoding(UTF-8)', $filename) or warn "cannot open file $filename";
    {
        local $/;
        my $line = <$fh>;
        $plant_status_summary = $line && $line ne '{}' ? decode_json $line : undef;
    }
    close($fh);

    #print STDERR Dumper $summary;
    $c->stash->{rest} = { summary => $summary, plant_status_summary => $plant_status_summary };
}

sub get_crossing_saved_ona_forms : Path('/ajax/odk/get_crossing_saved_ona_forms') : ActionClass('REST') { }

sub get_crossing_saved_ona_forms_GET {
    my ( $self, $c ) = @_;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to see your saved odk ona forms!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to see your saved odk ona forms!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);
    my $dbh = $bcs_schema->storage->dbh;
    my $production_server = $c->config->{production_server};

    my $odk_ona_forms = _get_allowed_ONA_ODK_forms_from_lists($dbh, $production_server);
    $c->stash->{rest} = {success => 1, odk_ona_forms => $odk_ona_forms};
}

sub _get_allowed_ONA_ODK_forms_from_lists {
    my $dbh = shift;
    my $production_server = shift;
    my @odk_ona_forms =();

    if ($production_server == 1) {
        my $odk_ona_lists = CXGN::List::available_public_lists($dbh, 'odk_ona_forms');
        my %odk_ona_forms_unique;
        foreach (@$odk_ona_lists) {
            my $list = CXGN::List->new({ dbh => $dbh, list_id => $_->[0] });
            my $elements = $list->elements();
            foreach (@$elements) {
                $odk_ona_forms_unique{$_}++;
            }
        }
        @odk_ona_forms = keys %odk_ona_forms_unique;
    }

    return \@odk_ona_forms;
}

1;
