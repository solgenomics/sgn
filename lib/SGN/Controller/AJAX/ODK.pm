
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

sub schedule_get_crossing_data : Path('/ajax/odk/schedule_get_crossing_data') : ActionClass('REST') { }

sub schedule_get_crossing_data_GET {
    my ( $self, $c ) = @_;
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
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $tempfiles_dir = $c->tempfiles_subdir('ODK_ONA_cross_info');
    my ($temp_file, $uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_cross_info_downloadXXXXX');
    my $temp_file_path = $temp_file->filename;

    my $rootpath = $c->config->{rootpath};
    my $basepath = $c->config->{basepath};
    my $archive_path = $c->config->{archive_path};
    my $ODk_username = $c->config->{odk_crossing_data_service_username};
    my $ODK_password = $c->config->{odk_crossing_data_service_password};
    my $database_name = $c->config->{dbname};
    my $database_user = $c->config->{dbuser};
    my $database_pass = $c->config->{dbpass};
    my $database_host = $c->config->{dbhost};
    my $www_user = $c->config->{www_user};
    my $include_path = 'export PERL5LIB="$PERL5LIB:'.$basepath.'/lib:'.$rootpath.'/cxgn-corelibs/lib:'.$rootpath.'/Phenome/lib"';
    my $perl_command = "$include_path; perl $basepath/bin/ODK/ODK_ONA_get_crosses.pl -u $user_id -r $user_role -a $archive_path -t $temp_file_path -n $ODk_username -m $ODK_password -o $form_id -D $database_name -U $database_user -p $database_pass -H $database_host >> /home/vagrant/cron.log 2>&1";
    my $timing = '';
    if ($timing_select eq 'everyminute'){
        $timing = "0-59/1 * * * * ";
    } elsif ($timing_select eq 'everyday'){
        $timing = "1 0 * * * ";
    }
    my $crontab_line = $timing.$perl_command."\n";
    #print STDERR $crontab_line;
    my $crontab_file = $c->config->{crontab_file};
    open (my $F, ">", $crontab_file) || die "Could not open $crontab_file: $!\n";
        if ($timing){
            print $F $crontab_line;
        }
    close $F;
    # perl /home/vagrant/cxgn/sgn/bin/ODK/ODK_ONA_get_crosses.pl -u 482 -r curator -a /data/prod/archive -t /home/vagrant/test_ONA_cross_info -n seedtracker -m Seedtracking101 -o 237289 -D cassava_orig -U web_usr -p web_usr -H localhost

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
    open(my $fh, '<:encoding(UTF-8)', $crontab_file)
        or die "Could not open file '$crontab_file' $!";
 
    while (my $row = <$fh>) {
        chomp $row;
        my @c = split 'export', $row;
        push @entries, $c[0];
    }
    close $fh;

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
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");

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

sub get_crossing_data_progress : Path('/ajax/odk/get_crossing_data_progress') : ActionClass('REST') { }

sub get_crossing_data_progress_GET {
    my ( $self, $c ) = @_;
    my $file_id = $c->req->param("cross_wishlist_file_id");
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
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");

    my %combined;
    my $wishlist_md_file = $metadata_schema->resultset("MdFiles")->find({file_id=> $file_id});
    my @wishlist_file_lines;
    if ($wishlist_md_file){
        #my $wishlist_file_path = $wishlist_md_file->dirname."/".$wishlist_md_file->basename;
        my $wishlist_file_path = "/home/vagrant/Downloads/cross_wishlist_MusaBase_Arusha_KgtuGst.csv";
        print STDERR "cross_wishlist $wishlist_file_path\n";
        open(my $fh, '<', $wishlist_file_path)
            or die "Could not open file '$wishlist_file_path' $!";
        my $header_row = <$fh>;
        chomp $header_row;
        my @header_row = split ',', $header_row;
        print STDERR $header_row."\n";
        while ( my $row = <$fh> ){
            chomp $row;
            my @cols = split ',', $row;
            #print STDERR Dumper \@cols;
            if (scalar(@cols) != scalar(@header_row)){
                $c->stash->{rest} = {error=>'Cross wishlist not parsed correctly!'};
                $c->detach();
            }
            my @cleaned_cols;
            foreach (@cols){
                #$_ =~ s/\s+//g;
                push @cleaned_cols, $_;
            }
            push @wishlist_file_lines, \@cleaned_cols;
        }
        #print STDERR Dumper \@wishlist_file_lines;

        my %cross_wishlist_hash;
        foreach (@wishlist_file_lines){
            my $female_accession_name = $_->[2];
            my $number_males = $_->[9];
            for my $n (10 .. 10+$number_males){
                if ($_->[$n]){
                    $cross_wishlist_hash{$female_accession_name}->{$_->[$n]}++;
                }
            }
        }
        #print STDERR Dumper \%cross_wishlist_hash;

        my @all_cross_parents;
        my %all_cross_info;
        my %all_plant_status_info;
        my $odk_submissions = $metadata_schema->resultset("MdFiles")->search({filetype=>"ODK_ONA_cross_info_download"}, {order_by => { -asc => 'file_id' }});
        while (my $r=$odk_submissions->next){
            my $odk_submission = decode_json $r->comment;
            my $cross_parents = $odk_submission->{cross_parents};
            my $cross_info = $odk_submission->{cross_info};
            my $plant_status_info = $odk_submission->{plant_status_info};
            push @all_cross_parents, $cross_parents;
            foreach my $cross (keys %$cross_info){
                $all_cross_info{$cross} = $cross_info->{$cross};
            }
            foreach my $plant (keys %$plant_status_info){
                $all_plant_status_info{$plant} = $plant_status_info->{$plant};
            }
        }
        #print STDERR Dumper \@all_cross_parents;
        #print STDERR Dumper \%all_plant_status_info;
        #print STDERR Dumper \%all_cross_info;

        foreach my $female_accession_name (keys %cross_wishlist_hash){
            my $male_hash = $cross_wishlist_hash{$female_accession_name};
            foreach my $male_accession_name (keys %$male_hash){
                foreach my $cross_parents (@all_cross_parents){
                    if (exists($cross_parents->{$female_accession_name}->{$male_accession_name})){
                        foreach my $cross_name (keys %{$cross_parents->{$female_accession_name}->{$male_accession_name}}){
                            print STDERR Dumper $cross_name;
                            $combined{$female_accession_name}->{$male_accession_name}->{$cross_name} = $all_cross_info{$cross_name};
                        }
                    }
                }
            }
        }
        #print STDERR Dumper \%combined;
    }
    $c->stash->{rest} = { success => 1, progress=>\%combined };
    $c->detach();
}

1;
