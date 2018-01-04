package CXGN::ODK::Crosses;

=head1 NAME

CXGN::ODK::Crosses - an object to handle retrieving crossing information from ODK services

=head1 USAGE

my $odk_crosses = CXGN::ODK::Crosses->new({
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    sp_person_id=>$sp_person_id,
    odk_crossing_data_service_username=>$odk_crossing_data_service_username,
    odk_crossing_data_service_password=>$odk_crossing_data_service_password,
    odk_crossing_data_service_form_id=>$odk_crossing_data_service_form_id
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
        print STDERR Dumper $message_hash;

        my %user_categories = (
            'field' => 'FieldActivities',
            'laboratory' => 'Laboratory',
            'screenhouse' => 'screenhse_activities'
        );
        my %cross_info;
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
            if ($activity_category eq 'field'){
                #MISSING 'flowering'
                foreach my $a (@$actions){
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
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'repeatPollination'){
                        push @{$cross_info{$a->{'FieldActivities/RepeatPollination/getCrossID'}}->{'repeatPollination'}}, $a;
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'harvesting'){
                        push @{$cross_info{$a->{'FieldActivities/harvesting/harvestID'}}->{'harvesting'}}, $a;
                    }
                    if ($a->{'FieldActivities/fieldActivity'} eq 'seedExtraction'){
                        push @{$cross_info{$a->{'FieldActivities/seedExtraction/extractionID'}}->{'seedExtraction'}}, $a;
                    }
                }
            }
            if ($activity_category eq 'laboratory'){
                #MISSING
                foreach my $a (@$actions){
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
                        $cross_info{$cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'active_seeds'}->{$cross_activeseed_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'subcultures'}->{$a->{'Laboratory/rooting/getSubcultureID'}}->{'rooting'} = $a;
                        $rooting_cross_lookup{$a->{'Laboratory/rooting/rootingID'}} = $cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}};
                        $rooting_activeseed_lookup{$a->{'Laboratory/rooting/rootingID'}} = $cross_activeseed_lookup{$a->{'Laboratory/rooting/getSubcultureID'}};
                        $rooting_subculture_lookup{$a->{'Laboratory/rooting/rootingID'}} = $a->{'Laboratory/rooting/getSubcultureID'};
                    }
                }
            }
            if ($activity_category eq 'screenhouse'){
                #MISSING
                foreach my $a (@$actions){
                    if ($a->{'screenhse_activities/screenhouseActivity'} eq 'screenhouse_humiditychamber'){
                        push @{$cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'screenhouse_humiditychamber'}}, $a;
                        $cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'active_seeds'}->{$rooting_activeseed_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'subcultures'}->{$rooting_subculture_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'rooting'}->{$a->{'screenhse_activities/screenhouse/getRoot_ID'}} = $a;
                    }
                    if ($a->{'screenhse_activities/screenhouseActivity'} eq 'hardening'){
                        push @{$cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'hardening'}}, $a;
                        $cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'active_seeds'}->{$rooting_activeseed_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'subcultures'}->{$rooting_subculture_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'rooting'}->{$a->{'screenhse_activities/hardening/hardeningID'}}->{'hardening'} = $a;
                    }
                }
            }
        }
        print STDERR Dumper \%cross_info;
        print STDERR Dumper \%plant_status_info;

        #Create or get crossing trial based on name of form

        foreach (keys %cross_info){
            #Add cross to database and link to crossing trial
            #Add cross_metadata_json stockprop
        }

    } else {
        print STDERR Dumper $resp;
    }
}

1;
