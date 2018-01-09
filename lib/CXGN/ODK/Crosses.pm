package CXGN::ODK::Crosses;

=head1 NAME

CXGN::ODK::Crosses - an object to handle retrieving crossing information from ODK services

=head1 USAGE

my $odk_crosses = CXGN::ODK::Crosses->new({
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    sp_person_id=>$sp_person_id,
    sp_person_role=>$sp_person_role,
    archive_path=>$archive_path,
    temp_file_path=>$temp_file_path,
    cross_wishlist_md_file_id=>$cross_wishlist_md_file_id,
    odk_crossing_data_service_username=>$odk_crossing_data_service_username,
    odk_crossing_data_service_password=>$odk_crossing_data_service_password,
    odk_crossing_data_service_form_id=>$odk_crossing_data_service_form_id,
    odk_cross_progress_tree_file_dir=>$odk_cross_progress_tree_file_dir
});
my $result = $odk_crosses->save_ona_cross_info();

=head1 DESCRIPTION


=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use LWP::UserAgent;
use JSON;
use CXGN::UploadFile;
use DateTime;
use File::Basename qw | basename dirname|;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
);

has 'sp_person_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'cross_wishlist_md_file_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'sp_person_role' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'odk_crossing_data_service_username' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'odk_crossing_data_service_password' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'odk_crossing_data_service_form_id' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'archive_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'temp_file_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'odk_cross_progress_tree_file_dir' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

sub save_ona_cross_info {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $form_id = $self->odk_crossing_data_service_form_id;
    my $ua = LWP::UserAgent->new;
    $ua->credentials( 'api.ona.io:443', 'DJANGO', $self->odk_crossing_data_service_username, $self->odk_crossing_data_service_password );
    my $login_resp = $ua->get("https://api.ona.io/api/v1/user.json");
    my $server_endpoint = "https://api.ona.io/api/v1/data/$form_id";
    print STDERR $server_endpoint."\n";
    my $resp = $ua->get($server_endpoint);

    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $message_hash = decode_json $message;
        #print STDERR Dumper $message_hash;

        my %user_categories = (
            'field' => 'FieldActivities',
            'laboratory' => 'Laboratory',
            'screenhouse' => 'screenhse_activities'
        );
        my %cross_info;
        my %cross_parents;
        my %plant_status_info;
        my %cross_subculture_lookup;
        my %cross_activeseed_lookup;
        my %rooting_cross_lookup;
        my %rooting_subculture_lookup;
        my %rooting_activeseed_lookup;
        foreach my $activity_hash (@$message_hash){
            my $activity_category = $activity_hash->{userCategory};
            my $actions = $activity_hash->{$user_categories{$activity_category}};
            my $attachments = $activity_hash->{'_attachments'};
            my %attachment_lookup;
            foreach (@$attachments){
                my $attachment_filepath = $_->{filename};
                my @filepath_components = split '/', $attachment_filepath;
                my $attachment_filename = $filepath_components[$#filepath_components];
                $attachment_lookup{$attachment_filename} = $_->{download_url};
            }

            foreach my $a (@$actions){
                $a->{userCategory} = $activity_hash->{userCategory};
                $a->{startTime} = $activity_hash->{startTime};
                $a->{userName} = $activity_hash->{userName};
                $a->{'meta/instanceID'} = $activity_hash->{'meta/instanceID'};
                $a->{'formhub/uuid'} = $activity_hash->{'formhub/uuid'};
                $a->{'meta/instanceName'} = $activity_hash->{'meta/instanceName'};
                $a->{'fieldgroup/gps'} = $activity_hash->{'fieldgroup/gps'} || '';

                if ($activity_category eq 'field'){
                    #MISSING 'flowering'
                    if ($a->{'FieldActivities/fieldActivity'} eq 'status'){
                        my $status_identifier;
                        my $attachment_identifier;
                        if ($a->{'FieldActivities/plantstatus/plant_statusLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/plant_statusLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/status_image';
                        } elsif ($a->{'FieldActivities/plantstatus/stolen_bunch/stolen_statusLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_statusLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_image';
                        }
                        $plant_status_info{$a->{$status_identifier}}->{'status'} = $a;
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{attachment_download} = $attachment_lookup{$a->{$attachment_identifier}};
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'firstPollination'){
                        push @{$cross_info{$a->{'FieldActivities/FirstPollination/print_crossBarcode/crossID'}}->{$a->{'FieldActivities/fieldActivity'}}}, $a;

                        my $female_accession_name = $a->{'FieldActivities/FirstPollination/firstFemaleName'};
                        my $male_accession_name = $a->{'FieldActivities/FirstPollination/selectedMaleName'};
                        $cross_parents{$female_accession_name}->{$male_accession_name}->{$a->{'FieldActivities/FirstPollination/print_crossBarcode/crossID'}}++;
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'repeatPollination'){
                        push @{$cross_info{$a->{'FieldActivities/RepeatPollination/getCrossID'}}->{'repeatPollination'}}, $a;

                        my $female_accession_name = $a->{'FieldActivities/RepeatPollination/getRptFemaleAccName'};
                        my $male_accession_name = $a->{'FieldActivities/RepeatPollination/getMaleAccName'};
                        $cross_parents{$female_accession_name}->{$male_accession_name}->{$a->{'FieldActivities/RepeatPollination/getCrossID'}}++;
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'harvesting'){
                        push @{$cross_info{$a->{'FieldActivities/harvesting/harvestID'}}->{'harvesting'}}, $a;
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'seedExtraction'){
                        push @{$cross_info{$a->{'FieldActivities/seedExtraction/extractionID'}}->{'seedExtraction'}}, $a;
                    }
                }
                if ($activity_category eq 'laboratory'){
                    #MISSING
                    if ($a->{'Laboratory/labActivity'} eq 'embryoRescue'){
                        push @{$cross_info{$a->{'Laboratory/embryoRescue/embryorescueID'}}->{'embryoRescue'}}, $a;
                    }
                    if ($a->{'Laboratory/labActivity'} eq 'germinating_after_2wks'){
                        push @{$cross_info{$a->{'Laboratory/embryo_germinatn_after_2wks/germinating_2wksID'}}->{'germinating_after_2wks'}}, $a;
                    }
                    if ($a->{'Laboratory/labActivity'} eq 'germinating_after_8weeks'){
                        push @{$cross_info{$a->{'Laboratory/embryo_germinatn_after_8weeks/germinating_8weeksID'}}->{'germinating_after_8weeks'}}, $a;
                        foreach my $active_seed (@{$a->{'Laboratory/embryo_germinatn_after_8weeks/label_active_seeds'}}){
                            $cross_info{$a->{'Laboratory/embryo_germinatn_after_8weeks/germinating_8weeksID'}}->{'active_seeds'}->{$active_seed->{'Laboratory/embryo_germinatn_after_8weeks/label_active_seeds/activeID'}} = $active_seed;
                        }
                    }
                    if ($a->{'Laboratory/labActivity'} eq 'subculture'){
                        push @{$cross_info{$a->{'Laboratory/subculturing/cross_Sub'}}->{'subculture'}}, $a;
                        foreach my $subculture (@{$a->{'Laboratory/subculturing/subccultures'}}){
                            $cross_info{$a->{'Laboratory/subculturing/cross_Sub'}}->{'active_seeds'}->{$a->{'Laboratory/subculturing/getGerminating_8weeks_ID'}}->{'subcultures'}->{$subculture->{'Laboratory/subculturing/subccultures/multiplicationID'}} = $subculture;
                            $cross_subculture_lookup{$subculture->{'Laboratory/subculturing/subccultures/multiplicationID'}} = $a->{'Laboratory/subculturing/cross_Sub'};
                            $cross_activeseed_lookup{$subculture->{'Laboratory/subculturing/subccultures/multiplicationID'}} = $a->{'Laboratory/subculturing/getGerminating_8weeks_ID'};
                        }
                    }
                    if ($a->{'Laboratory/labActivity'} eq 'rooting'){
                        push @{$cross_info{$cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'rooting'}}, $a;
                        $cross_info{$cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'active_seeds'}->{$cross_activeseed_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'subcultures'}->{$a->{'Laboratory/rooting/getSubcultureID'}}->{'rooting'}->{$a->{'Laboratory/rooting/rootingID'}} = $a;
                        $rooting_cross_lookup{$a->{'Laboratory/rooting/rootingID'}} = $cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}};
                        $rooting_activeseed_lookup{$a->{'Laboratory/rooting/rootingID'}} = $cross_activeseed_lookup{$a->{'Laboratory/rooting/getSubcultureID'}};
                        $rooting_subculture_lookup{$a->{'Laboratory/rooting/rootingID'}} = $a->{'Laboratory/rooting/getSubcultureID'};
                    }
                }
                if ($activity_category eq 'screenhouse'){
                    #MISSING
                    if ($a->{'screenhse_activities/screenhouseActivity'} eq 'screenhouse_humiditychamber'){
                        push @{$cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'screenhouse_humiditychamber'}}, $a;
                        $cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'active_seeds'}->{$rooting_activeseed_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'subcultures'}->{$rooting_subculture_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'rooting'}->{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}->{'screenhouse_humiditychamber'}->{$a->{'screenhse_activities/screenhouse/getRoot_ID'}} = $a;
                    }
                    if ($a->{'screenhse_activities/screenhouseActivity'} eq 'hardening'){
                        push @{$cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'hardening'}}, $a;
                        $cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'active_seeds'}->{$rooting_activeseed_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'subcultures'}->{$rooting_subculture_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'rooting'}->{$a->{'screenhse_activities/hardening/hardeningID'}}->{'hardening'}->{$a->{'screenhse_activities/hardening/hardeningID'}} = $a;
                    }
                }
            }
        }
        print STDERR Dumper \%cross_info;
        #print STDERR Dumper \%plant_status_info;
        my %odk_cross_hash = (
            cross_info => \%cross_info,
            cross_parents => \%cross_parents,
            plant_status_info => \%plant_status_info,
            raw_message => $message_hash
        );

        #Store recieved info into file and use UploadFile to archive
        #Store recieved info into metadata for display on ODK dashboard
        my $temp_file_path = $self->temp_file_path;
        my $encoded_odk_cross_hash = encode_json \%odk_cross_hash;
        open(my $F1, ">", $temp_file_path) || die "Can't open file ".$temp_file_path;
            print $F1 $encoded_odk_cross_hash;
        close($F1);

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        my $file_type = "ODK_ONA_cross_info_download";
        my $uploader = CXGN::UploadFile->new({
            tempfile => $temp_file_path,
            subdirectory => "ODK_ONA_cross_info",
            archive_path => $self->archive_path,
            archive_filename => $file_type,
            timestamp => $timestamp,
            user_id => $self->sp_person_id,
            user_role => $self->sp_person_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            return { error => "Could not save file ODK_ONA_cross_info_download in archive" };
        }

        #Metadata schema not working for some reason in cron job (can't find md_metadata table?), so use sql instead
        #my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $self->sp_person_id});
        #my $file_row = $metadata_schema->resultset("MdFiles")
        #    ->create({
        #        basename => basename($archived_filename_with_path),
        #        dirname => dirname($archived_filename_with_path),
        #        filetype => $file_type,
        #        md5checksum => $md5->hexdigest(),
        #        metadata_id => $md_row->metadata_id(),
        #        comment => $encoded_odk_cross_hash
        #    });

        my $h = $metadata_schema->storage->dbh->prepare("INSERT INTO metadata.md_metadata (create_person_id) VALUES (?) RETURNING metadata_id");
        my $r = $h->execute($self->sp_person_id);
        my $metadata_id = $h->fetchrow_array();
        my $h2 = $metadata_schema->storage->dbh->prepare("INSERT INTO metadata.md_files (basename, dirname, filetype, md5checksum, metadata_id, comment) VALUES (?,?,?,?,?,?) RETURNING metadata_id");
        my $r2 = $h2->execute(basename($archived_filename_with_path), dirname($archived_filename_with_path), $file_type, $md5->hexdigest(), $metadata_id, $encoded_odk_cross_hash);

        #Update cross progress tree
        $self->create_odk_cross_progress_tree();

        #Create or get crossing trial based on name of form

        foreach (keys %cross_info){
            #Add cross to database and link to crossing trial
            #Add cross_metadata_json stockprop
        }

        return { success => 1 };

    } else {
        print STDERR Dumper $resp;
        return { error => "Could not connect to ONA" };
    }
}

sub create_odk_cross_progress_tree {
    my $self = shift;
    my $wishlist_file_id = $self->cross_wishlist_md_file_id;
    my $metadata_schema = $self->metadata_schema;

    my %combined;

    #Metadata schema not working for some reason in cron job (can't find md_metadata table?), so use sql instead
    #my $wishlist_md_file = $metadata_schema->resultset("MdFiles")->find({file_id=> $wishlist_file_id});

    my $h = $metadata_schema->storage->dbh->prepare("SELECT dirname, basename FROM metadata.md_files WHERE file_id=?");
    $h->execute($wishlist_file_id);
    my @wishlist_file_elements = $h->fetchrow_array;

    my @wishlist_file_lines;
    my %open_tree;
    if (@wishlist_file_elements){

        #Metadata schema not working for some reason in cron job (can't find md_metadata table?), so use sql instead
        #my $wishlist_file_path = $wishlist_md_file->dirname."/".$wishlist_md_file->basename;

        #my $wishlist_file_path = $wishlist_file_elements[0]."/".$wishlist_file_elements[1];

        my $wishlist_file_path = "/home/vagrant/Downloads/cross_wishlist_MusaBase_Arusha_KgtuGst.csv";
        print STDERR "cross_wishlist $wishlist_file_path\n";
        open(my $fh, '<', $wishlist_file_path)
            or die "Could not open file '$wishlist_file_path' $!";
        my $header_row = <$fh>;
        chomp $header_row;
        my @header_row = split ',', $header_row;
        #print STDERR $header_row."\n";
        while ( my $row = <$fh> ){
            chomp $row;
            my @cols = split ',', $row;
            #print STDERR Dumper \@cols;
            if (scalar(@cols) != scalar(@header_row)){
                return {error=>'Cross wishlist not parsed correctly!'};
            }
            push @wishlist_file_lines, \@cols;
        }
        #print STDERR Dumper \@wishlist_file_lines;

        my %cross_wishlist_hash;
        foreach (@wishlist_file_lines){
            my $female_accession_name = $_->[2];
            my $female_plot_name = $_->[1];
            my $wishlist_entry_created_timestamp = $_->[7];
            my $wishlist_entry_created_by = $_->[8];
            my $number_males = $_->[9];
            my $top_level = "$wishlist_entry_created_by @ $wishlist_entry_created_timestamp";
            for my $n (10 .. 10+$number_males){
                if ($_->[$n]){
                    $cross_wishlist_hash{$top_level}->{$female_accession_name}->{$female_plot_name}->{$_->[$n]}++;
                }
            }
        }
        #print STDERR Dumper \%cross_wishlist_hash;

        my @all_cross_parents;
        my %all_cross_info;
        my %all_plant_status_info;

        #Metadata schema not working for some reason in cron job (can't find md_metadata table?), so use sql instead
        #my $odk_submissions = $metadata_schema->resultset("MdFiles")->search({filetype=>"ODK_ONA_cross_info_download"}, {order_by => { -asc => 'file_id' }});
        #while (my $r=$odk_submissions->next){
        #    my $odk_submission = decode_json $r->comment;

        $h = $metadata_schema->storage->dbh->prepare("SELECT comment FROM metadata.md_files WHERE filetype='ODK_ONA_cross_info_download' ORDER BY file_id ASC");
        $h->execute();
        my $odk_cross_submission_count = 0;
        while (my $r = $h->fetchrow_array) {
            $odk_cross_submission_count++;
            my $odk_submission = decode_json $r;
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
        print STDERR "Number ODK Cross Submissions: ".$odk_cross_submission_count."\n";
        #print STDERR Dumper \@all_cross_parents;
        #print STDERR Dumper \%all_plant_status_info;
        #print STDERR Dumper \%all_cross_info;

        foreach my $top_level (keys %cross_wishlist_hash){
            foreach my $female_accession_name (keys %{$cross_wishlist_hash{$top_level}}){
                my $planned_female_plot_name_hash = $cross_wishlist_hash{$top_level}->{$female_accession_name};
                foreach my $planned_female_plot_name (keys %$planned_female_plot_name_hash){
                    my $male_hash = $cross_wishlist_hash{$top_level}->{$female_accession_name}->{$planned_female_plot_name};
                    foreach my $male_accession_name (keys %$male_hash){
                        foreach my $cross_parents (@all_cross_parents){
                            if (exists($cross_parents->{$female_accession_name}->{$male_accession_name})){
                                foreach my $cross_name (keys %{$cross_parents->{$female_accession_name}->{$male_accession_name}}){
                                    #print STDERR Dumper $cross_name;
                                    $combined{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{$male_accession_name}->{$cross_name} = $all_cross_info{$cross_name};
                                    $open_tree{$top_level}++;
                                }
                            } else {
                                $male_accession_name =~ s/\s+//g;
                                if ($male_accession_name){
                                    $combined{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{$male_accession_name} = "No Crosses Performed";
                                }
                            }
                        }
                    }
                }
            }
        }
        #print STDERR Dumper \%combined;
    }

    my %seen_top_levels;
    my %top_level_contents;
    my @top_level_json;
    while (my ($top_level, $female_accession_hash) = each %combined){
        if (exists($seen_top_levels{$top_level})){
            die "top level $top_level not unique \n";
        }
        my $node = {
            'id' => $top_level,
            'children' => JSON::true,
        };
        if (exists($open_tree{$top_level})){
            $node->{state}->{opened} = JSON::true;
            $node->{text} = 'Wishlist Entry: '.$top_level;
            $node->{icon} = 'glyphicon glyphicon-briefcase text-info';
        } else {
            $node->{state}->{opened} = JSON::false;
            $node->{text} = 'Wishlist Entry: '.$top_level." : No Crosses";
            $node->{icon} = 'glyphicon glyphicon-briefcase text-danger';
        }
        push @top_level_json, $node;

        my @top_level_content_json;
        while (my ($female_accession_name, $planned_female_plot_name_hash) = each %$female_accession_hash){
            my $planned_female_node = {
                'text' => 'Wishlist Female Accession: '.$female_accession_name,
                'icon' => 'glyphicon glyphicon-queen text-info',
            };
            push @top_level_content_json, $planned_female_node;
            while (my ($planned_female_plot_name, $male_accession_hash) = each %$planned_female_plot_name_hash){
                my $planned_female_plot_node = {
                    'text' => 'Wishlist Female Plot: '.$planned_female_plot_name,
                    'icon' => 'glyphicon glyphicon-queen text-info',
                };
                push @{$planned_female_node->{children}}, $planned_female_plot_node;
                while (my ($male_accession_name, $crosses_hash) = each %$male_accession_hash){
                    my $planned_male_node = {
                        'text' => 'Wishlist Male Accession: '.$male_accession_name,
                        'icon' => 'glyphicon glyphicon-king text-info',
                    };
                    push @{$planned_female_plot_node->{children}}, $planned_male_node;
                    if (ref($crosses_hash) eq "HASH") {
                        while (my ($cross_name, $actions_hash) = each %$crosses_hash){
                            my $cross_node = {
                                'text' => 'Cross Name: '.$cross_name,
                                'icon' => 'glyphicon glyphicon-random text-primary',
                            };
                            push @{$planned_male_node->{children}}, $cross_node;
                            while (my ($action_name, $actions_array) = each %$actions_hash){
                                if ($action_name eq 'active_seeds'){
                                    my $active_seeds_hash = $actions_array;
                                    my $active_seeds_node = {
                                        'text' => $action_name,
                                        'icon' => 'glyphicon glyphicon-eye-open text-success',
                                    };
                                    push @{$cross_node->{children}}, $active_seeds_node;
                                    while (my ($active_seed_name, $active_seed_hash) = each %$active_seeds_hash){
                                        my $active_seed_node = {
                                            'text' => $active_seed_name,
                                            'icon' => 'glyphicon glyphicon-chevron-right text-success',
                                        };
                                        push @{$active_seeds_node->{children}}, $active_seed_node;
                                        while (my ($active_seed_action, $active_seed_action_value) = each %$active_seed_hash){
                                            if ($active_seed_action eq 'subcultures'){
                                                my $subcultures_hash = $active_seed_action_value;
                                                my $subcultures_node = {
                                                    'text' => $active_seed_action,
                                                    'icon' => 'glyphicon glyphicon-eye-open text-success',
                                                };
                                                push @{$active_seed_node->{children}}, $subcultures_node;
                                                while (my ($subculture_name, $subcultures_hash) = each %$subcultures_hash){
                                                    my $subculture_node = {
                                                        'text' => $subculture_name,
                                                        'icon' => 'glyphicon glyphicon-chevron-right text-success',
                                                    };
                                                    push @{$subcultures_node->{children}}, $subculture_node;
                                                    while (my ($subcultures_action_name, $subculture_action_value) = each %$subcultures_hash){
                                                        if ($subcultures_action_name eq 'rooting'){
                                                            my $rooting_hash = $subculture_action_value;
                                                            my $rootings_node = {
                                                                'text' => $subcultures_action_name,
                                                                'icon' => 'glyphicon glyphicon-eye-open text-success',
                                                            };
                                                            push @{$subculture_node->{children}}, $rootings_node;
                                                            while (my ($rooting_name, $rooting_hash) = each %$rooting_hash){
                                                                my $rooting_node = {
                                                                    'text' => $rooting_name,
                                                                    'icon' => 'glyphicon glyphicon-chevron-right text-success',
                                                                };
                                                                push @{$rootings_node->{children}}, $rooting_node;
                                                                while (my ($rooting_action, $rooting_action_value) = each %$rooting_hash){
                                                                    if ($rooting_action eq 'hardening'){
                                                                        my $hardening_hash = $rooting_action_value;
                                                                        my $hardenings_node = {
                                                                            'text' => $rooting_action,
                                                                            'icon' => 'glyphicon glyphicon-eye-open text-success',
                                                                        };
                                                                        push @{$rooting_node->{children}}, $hardenings_node;
                                                                        while (my ($hardening_name, $hardening) = each %$hardening_hash){
                                                                            my $hardening_node = {
                                                                                'text' => $hardening_name,
                                                                                'icon' => 'glyphicon glyphicon-chevron-right text-success',
                                                                            };
                                                                            push @{$hardenings_node->{children}}, $hardening_node;
                                                                        }
                                                                    }
                                                                    if ($rooting_action eq 'screenhouse_humiditychamber'){
                                                                        my $humidity_hash = $rooting_action_value;
                                                                        my $humiditys_node = {
                                                                            'text' => $rooting_action,
                                                                            'icon' => 'glyphicon glyphicon-eye-open text-success',
                                                                        };
                                                                        push @{$rooting_node->{children}}, $humiditys_node;
                                                                        while (my ($humidity_name, $humidity) = each %$humidity_hash){
                                                                            my $humidity_node = {
                                                                                'text' => $humidity_name,
                                                                                'icon' => 'glyphicon glyphicon-chevron-right text-success',
                                                                            };
                                                                            push @{$humiditys_node->{children}}, $humidity_node;
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    my $action_name_node = {
                                        'text' => $action_name,
                                        'icon' => 'glyphicon glyphicon-fast-forward text-info',
                                    };
                                    push @{$cross_node->{children}}, $action_name_node;
                                    foreach my $action_hash (@$actions_array){
                                        my $action_start = $action_hash->{userName}." @ ".$action_hash->{startTime};
                                        my $action_time_node = {
                                            'text' => $action_start,
                                            'icon' => 'glyphicon glyphicon-time',
                                        };
                                        push @{$action_name_node->{children}}, $action_time_node;
                                        while (my ($action_attr_name, $val) = each %$action_hash){
                                            if (ref($val) eq 'HASH' || ref($val) eq 'ARRAY'){
                                                $val = encode_json $val;
                                            }
                                            $val =~ s/<br>//g;
                                            my $action_attr_node = {
                                                'text' => $action_attr_name.':'.$val,
                                                'icon' => 'glyphicon glyphicon-minus',
                                            };
                                            push @{$action_time_node->{children}}, $action_attr_node;
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        my $action_attr_node = {
                            'text' => $crosses_hash,
                            'icon' => 'glyphicon glyphicon-minus',
                        };
                        push @{$planned_male_node->{children}}, $action_attr_node;
                    }
                }
            }
        }
        $top_level_contents{$top_level} = \@top_level_content_json;
    }

    my %save_content = (
        top_level_json => \@top_level_json,
        top_level_contents => \%top_level_contents
    );

    my $dir = $self->odk_cross_progress_tree_file_dir;
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/entire_odk_cross_progress_html_".$wishlist_file_id.".txt";
    print STDERR "Writing to $filename \n";

    my $OUTFILE;
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } encode_json \%save_content or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

}

1;
