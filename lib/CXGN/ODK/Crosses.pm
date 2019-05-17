package CXGN::ODK::Crosses;

=head1 NAME

CXGN::ODK::Crosses - an object to handle retrieving crossing information from ODK services

=head1 USAGE

my $odk_crosses = CXGN::ODK::Crosses->new({
    bcs_schema=>$schema,
    phenome_schema=>$phenome_schema,
    metadata_schema=>$metadata_schema,
    sp_person_id=>$sp_person_id,
    sp_person_username=>$sp_person_username,
    sp_person_role=>$sp_person_role,
    archive_path=>$archive_path,
    temp_file_dir=>$temp_file_dir,
    cross_wishlist_temp_file_path=>$cross_wishlist_temp_file_path,
    germplasm_info_temp_file_path=>$germplasm_info_temp_file_path,
    allowed_cross_properties=>$allowed_cross_properties,
    odk_crossing_data_service_url=>$odk_crossing_data_service_url,
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
use LWP::Simple;
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
use SGN::Image;
use Time::Piece;
use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddCrossInfo;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
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

has 'sp_person_username' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'sp_person_role' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'allowed_cross_properties' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'odk_crossing_data_service_url' => (
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

has 'temp_file_dir' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'odk_cross_progress_tree_file_dir' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'cross_wishlist_temp_file_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'germplasm_info_temp_file_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has '_ona_cross_wishlist_file_name' => (
    isa => 'Str',
    is => 'rw',
);

has '_ona_germplasm_info_file_name' => (
    isa => 'Str',
    is => 'rw',
);

sub save_ona_cross_info {
    print STDERR "SAVE ONA CROSS INFO START\n";
    my $self = shift;
    my $context = shift; #Needed for SGN::Image to store images to plots
    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $cross_wishlist_temp_file_path = $self->cross_wishlist_temp_file_path;
    my $germplasm_info_temp_file_path = $self->germplasm_info_temp_file_path;
    my $form_id = $self->odk_crossing_data_service_form_id;
    my $ua = LWP::UserAgent->new(
        ssl_opts => { verify_hostname => 0 }
    );
    $ua->credentials( 'api.ona.io:443', 'DJANGO', $self->odk_crossing_data_service_username, $self->odk_crossing_data_service_password );
    my $login_resp = $ua->get("https://api.ona.io/api/v1/user.json");
    my $server_endpoint = "https://api.ona.io/api/v1/data/$form_id";
    print STDERR $server_endpoint."\n";
    my $resp = $ua->get($server_endpoint);

    my $server_endpoint2 = "https://api.ona.io/api/v1/metadata?xform=".$form_id;
    my $resp2 = $ua->get($server_endpoint2);

    if ($resp2->is_success) {
        my $message2 = $resp2->decoded_content;
        my $message_hash2 = decode_json $message2;

        foreach my $t (@$message_hash2) {
            if (index($t->{data_value}, 'cross_wishlist') != -1) {
                getstore($t->{media_url}, $cross_wishlist_temp_file_path);
                $self->_ona_cross_wishlist_file_name($t->{data_value});
            }
            if (index($t->{data_value}, 'germplasm_info') != -1) {
                getstore($t->{media_url}, $germplasm_info_temp_file_path);
                $self->_ona_germplasm_info_file_name($t->{data_value});
            }
        }
    }


    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();

    print STDERR "ONA ODK CROSS SUMMARY 1\n";

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
            #print STDERR Dumper $activity_hash;

            if ( ($activity_hash->{userCategory} && $activity_hash->{userCategory} eq 'lookup') || ($activity_hash->{Action} && ($activity_hash->{Action} eq 'reprint_barcodes' || $activity_hash->{Action} eq 'lookup'))) {
                next;
            }

            my $activity_category = $activity_hash->{Category} || $activity_hash->{userCategory};
            #print STDERR Dumper $activity_category;

            my $actions = $activity_hash->{$user_categories{$activity_category}};
            if (!$actions) {
                next;
            }
            my $attachments = $activity_hash->{'_attachments'};
            my %attachment_lookup;
            foreach (@$attachments){
                my $attachment_filepath = $_->{filename};
                my @filepath_components = split '/', $attachment_filepath;
                my $attachment_filename = $filepath_components[$#filepath_components];
                my $download_url = $_->{download_url};
                my $url = $self->odk_crossing_data_service_url.$download_url;
                my $image_temp_file = $self->temp_file_dir."/$attachment_filename";
                my @filename_components = split '\.', $attachment_filename;
                #Check that image has not already been saved
                my $h = $metadata_schema->storage->dbh->prepare("SELECT image_id FROM metadata.md_image WHERE original_filename=? ORDER BY image_id DESC LIMIT 1;");
                my $r = $h->execute($filename_components[0]);
                my $image_id = $h->fetchrow_array();

                $attachment_lookup{$attachment_filename} = [$image_temp_file, $image_id, $url];
            }

            foreach my $a (@$actions){
                #print STDERR Dumper $a;

                $a->{userCategory} = $activity_hash->{userCategory};
                $a->{startTime} = $activity_hash->{startTime};
                $a->{userName} = $activity_hash->{userName};
                $a->{'meta/instanceID'} = $activity_hash->{'meta/instanceID'};
                $a->{'formhub/uuid'} = $activity_hash->{'formhub/uuid'};
                $a->{'meta/instanceName'} = $activity_hash->{'meta/instanceName'};
                $a->{'fieldgroup/gps'} = $activity_hash->{'fieldgroup/gps'} || '';

                if ($activity_category eq 'field'){
                    #MISSING
                    if ($a->{'FieldActivities/fieldActivity'} eq 'status'){
                        #print STDERR Dumper $a;

                        my $status_identifier;
                        my $attachment_identifier;
                        my $status_message_identifier = 'FieldActivities/plantstatus/plant_status';
                        my $status_note_identifier;
                        my $status_date_identifier;
                        my $status_location_identifier = '';
                        my $status_user_identifier;
                        my $status_trial_identifier;
                        my $status_accession_identifier;
                        if ($a->{'FieldActivities/plantstatus/plant_statusLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/plant_statusLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/status_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/status_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/status_Date';
                            $status_location_identifier = 'FieldActivities/plantstatus/plant_statusAccLoc';
                            $status_user_identifier = 'FieldActivities/plantstatus/status_reporter';
                            $status_trial_identifier = 'FieldActivities/plantstatus/plant_statusLocTrialName';
                            $status_accession_identifier = 'FieldActivities/plantstatus/plant_statusLocAccName';
                        } elsif ($a->{'FieldActivities/plantstatus/fallen_plant/fallen_statusLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_statusLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_date';
                            $status_user_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_reporter';
                            $status_trial_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_statusLocTrialName';
                            $status_accession_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_statusLocAccName';
                        } elsif ($a->{'FieldActivities/plantstatus/stolen_bunch/stolen_statusLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_statusLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_date';
                            $status_user_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_reporter';
                            $status_trial_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_statusLocTrialName';
                            $status_accession_identifier = 'FieldActivities/plantstatus/stolen_bunch/stolen_statusLocAccName';
                        } elsif ($a->{'FieldActivities/plantstatus/Unusual/plant_unusualLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/Unusual/plant_unusualLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/Unusual/unusual_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/Unusual/unusual_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/Unusual/unusual_Date';
                            $status_user_identifier = 'FieldActivities/plantstatus/Unusual/unusual_reporter';
                            $status_trial_identifier = 'FieldActivities/plantstatus/Unusual/plant_unusualLocTrialName';
                            $status_accession_identifier = 'FieldActivities/plantstatus/Unusual/plant_unusualLocAccName';
                        } elsif ($a->{'FieldActivities/plantstatus/Disease/plant_diseaseLocPlotName'}){
                            $status_identifier = 'FieldActivities/plantstatus/Disease/plant_diseaseLocPlotName';
                            $attachment_identifier = 'FieldActivities/plantstatus/Disease/disease_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/Disease/disease_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/Disease/plant_disease_date';
                            $status_user_identifier = 'FieldActivities/plantstatus/Disease/disease_reporter';
                            $status_trial_identifier = 'FieldActivities/plantstatus/Disease/plant_diseaseLocTrialName';
                            $status_accession_identifier = 'FieldActivities/plantstatus/Disease/plant_diseaseLocAccName';
                        } elsif ($a->{'FieldActivities/plantstatus/fallen_plant/fallen_statusID'}){
                            $status_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_statusID';
                            $attachment_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_date';
                            $status_user_identifier = 'userName';
                            $status_trial_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_statusID';
                            $status_accession_identifier = 'FieldActivities/plantstatus/fallen_plant/fallen_statusID';
                        } elsif ($a->{'FieldActivities/plantstatus/Disease/plant_diseaseID'}){
                            $status_identifier = 'FieldActivities/plantstatus/Disease/plant_diseaseID';
                            $attachment_identifier = 'FieldActivities/plantstatus/Disease/disease_image';
                            $status_note_identifier = 'FieldActivities/plantstatus/Disease/disease_comments';
                            $status_date_identifier = 'FieldActivities/plantstatus/Disease/disease_Date';
                            $status_user_identifier = 'userName';
                            $status_trial_identifier = 'FieldActivities/plantstatus/Disease/plant_diseaseID';
                            $status_accession_identifier = 'FieldActivities/plantstatus/Disease/plant_diseaseID';
                        } elsif ($a->{'FieldActivities/PlantStatus/plant_statusID'}){
                            $status_identifier = 'FieldActivities/PlantStatus/plant_statusID';
                            $attachment_identifier = 'FieldActivities/PlantStatus/plant_status_image';
                            $status_note_identifier = 'FieldActivities/PlantStatus/plant_status_notes';
                            $status_date_identifier = 'FieldActivities/PlantStatus/plant_status_date';
                            $status_user_identifier = 'userName';
                            $status_trial_identifier = 'FieldActivities/PlantStatus/plant_statusID';
                            $status_accession_identifier = 'FieldActivities/PlantStatus/plant_statusID';
                        } else {
                            print STDERR Dumper $a;
                        }
                        my $image_temp_file_info = $attachment_lookup{$a->{$attachment_identifier}};
                        my $image_temp_file = $image_temp_file_info->[0];
                        my $found_image_id = $image_temp_file_info->[1];
                        my $download_url = $image_temp_file_info->[2];
                        $plant_status_info{$a->{$status_identifier}}->{'status'} = $a;
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{attachment_download} = $image_temp_file;
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_message} = $a->{$status_message_identifier};
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_note} = $a->{$status_note_identifier};
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_date} = $a->{$status_date_identifier};
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_location} = $a->{$status_location_identifier} || '';
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_user} = $a->{$status_user_identifier};
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_trial_name} = $a->{$status_trial_identifier};
                        $plant_status_info{$a->{$status_identifier}}->{'status'}->{status_accession_name} = $a->{$status_accession_identifier};

                        my $stock = $schema->resultset("Stock::Stock")->find( { uniquename => $a->{$status_identifier}, 'me.type_id' => [$plot_cvterm_id, $plant_cvterm_id] } );
                        if ($stock && $image_temp_file){
                            my $stock_id = $stock->stock_id;
                            my $image_id;
                            my $image;
                            if ($found_image_id){
                                $image_id = $found_image_id;
                                $image = SGN::Image->new( $schema->storage->dbh, $found_image_id, $context );
                                print STDERR "Found Image $found_image_id\n";
                            } else {
                                print STDERR "GET ODK IMAGE: $download_url to $image_temp_file\n";
                                my $response = $ua->get($download_url);
                                if ($response->is_success){
                                    my $content = $response->decoded_content;
                                    open my $OUTFILE, '>', $image_temp_file or die "Error opening $image_temp_file: $!";
                                    print { $OUTFILE } $content or croak "Cannot write to $image_temp_file: $!";
                                    close $OUTFILE or croak "Cannot close $image_temp_file: $!";
                                    $image = SGN::Image->new( $schema->storage->dbh, undef, $context );
                                    $image->set_sp_person_id($self->sp_person_id);
                                    my $stock_image_id = $image->process_image($image_temp_file, 'stock', $stock_id);
                                    $image_id = $image->get_image_id;
                                } else {
                                    print STDERR $response->status_line."\n";
                                }
                            }
                            if ($image && $image_id){
                                my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
                                my $image_source_tag_thumb = $image->get_img_src_tag("thumbnail");
                                print STDERR "IMAGE FOR ".$stock_id.": ".$image_id.": ".$image_source_tag_tiny."\n";
                                $plant_status_info{$a->{$status_identifier}}->{'status'}->{attachment_display_tiny} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
                                $plant_status_info{$a->{$status_identifier}}->{'status'}->{attachment_display_thumb} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_thumb.'</a>';
                            }
                        }
                    }
                    elsif ($a->{'FieldActivities/fieldActivity'} eq 'flowering'){
                        my $plot_name = $a->{'FieldActivities/Flowering/flowersID'} || $a->{'FieldActivities/Flowering/floweringID'};
                        $plot_name = _get_plot_name_from_barcode_id($plot_name);
                        $plant_status_info{$plot_name}->{'flowering'} = $a;
                    }
                    elsif ($a->{'FieldActivities/fieldActivity'} eq 'firstPollination'){
                        push @{$cross_info{$a->{'FieldActivities/FirstPollination/print_crossBarcode/crossID'}}->{$a->{'FieldActivities/fieldActivity'}}}, $a;

                        my $female_accession_name = $a->{'FieldActivities/FirstPollination/FemaleName'};
                        my $male_accession_name = $a->{'FieldActivities/FirstPollination/selectedMaleName'};
                        my $cycle_id = $a->{'FieldActivities/FirstPollination/cycleID'} || 1;
                        $cross_parents{$female_accession_name}->{$male_accession_name}->{$cycle_id}->{$a->{'FieldActivities/FirstPollination/print_crossBarcode/crossID'}}++;
                    }
                    elsif ($a->{'FieldActivities/fieldActivity'} eq 'repeatPollination'){
                        push @{$cross_info{$a->{'FieldActivities/RepeatPollination/getCrossID'}}->{'repeatPollination'}}, $a;

                        #my $female_accession_name = $a->{'FieldActivities/RepeatPollination/getRptFemaleAccName'};
                        #my $male_accession_name = $a->{'FieldActivities/RepeatPollination/getMaleAccName'};
                        #$cross_parents{$female_accession_name}->{$male_accession_name}->{$a->{'FieldActivities/RepeatPollination/getCrossID'}}++;
                    }
                    elsif ($a->{'FieldActivities/fieldActivity'} eq 'harvesting'){
                        my $cross_id = $a->{'FieldActivities/harvesting/harvest/harvestID'} || $a->{'FieldActivities/harvesting/harvestID'};
                        push @{$cross_info{$cross_id}->{'harvesting'}}, $a;
                    }
                    elsif ($a->{'FieldActivities/fieldActivity'} eq 'seedExtraction'){
                        my $cross_id = $a->{'FieldActivities/seedExtraction/extractionID'} || $a->{'FieldActivities/seedExtraction/extraction/extractionID'};
                        push @{$cross_info{$cross_id}->{'seedExtraction'}}, $a;
                    }
                    else {
                        print STDERR "UNKNOWN ONA ODK activity in $activity_category\n";
                        print STDERR Dumper $a;
                    }
                }
                elsif ($activity_category eq 'laboratory'){
                    #MISSING
                    if ($a->{'Laboratory/labActivity'} eq 'embryoRescue'){
                        push @{$cross_info{$a->{'Laboratory/embryoRescue/embryorescueID'}}->{'embryoRescue'}}, $a;
                    }
                    elsif ($a->{'Laboratory/labActivity'} eq 'germinating_after_2wks'){
                        push @{$cross_info{$a->{'Laboratory/embryo_germinatn_after_2wks/germinating_2wksID'}}->{'germinating_after_2wks'}}, $a;
                    }
                    elsif ($a->{'Laboratory/labActivity'} eq 'germinating_after_8weeks'){
                        push @{$cross_info{$a->{'Laboratory/embryo_germinatn_after_8weeks/germinating_8weeksID'}}->{'germinating_after_8weeks'}}, $a;
                        foreach my $active_seed (@{$a->{'Laboratory/embryo_germinatn_after_8weeks/label_active_seeds'}}){
                            $cross_info{$a->{'Laboratory/embryo_germinatn_after_8weeks/germinating_8weeksID'}}->{'active_seeds'}->{$active_seed->{'Laboratory/embryo_germinatn_after_8weeks/label_active_seeds/activeID'}} = $active_seed;
                        }
                    }
                    elsif ($a->{'Laboratory/labActivity'} eq 'subculture'){
                        push @{$cross_info{$a->{'Laboratory/subculturing/cross_Sub'}}->{'subculture'}}, $a;
                        foreach my $subculture (@{$a->{'Laboratory/subculturing/subccultures'}}){
                            $cross_info{$a->{'Laboratory/subculturing/cross_Sub'}}->{'active_seeds'}->{$a->{'Laboratory/subculturing/getGerminating_8weeks_ID'}}->{'subcultures'}->{$subculture->{'Laboratory/subculturing/subccultures/multiplicationID'}} = $subculture;
                            $cross_subculture_lookup{$subculture->{'Laboratory/subculturing/subccultures/multiplicationID'}} = $a->{'Laboratory/subculturing/cross_Sub'};
                            $cross_activeseed_lookup{$subculture->{'Laboratory/subculturing/subccultures/multiplicationID'}} = $a->{'Laboratory/subculturing/getGerminating_8weeks_ID'};
                        }
                    }
                    elsif ($a->{'Laboratory/labActivity'} eq 'rooting'){
                        push @{$cross_info{$cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'rooting'}}, $a;
                        $cross_info{$cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'active_seeds'}->{$cross_activeseed_lookup{$a->{'Laboratory/rooting/getSubcultureID'}}}->{'subcultures'}->{$a->{'Laboratory/rooting/getSubcultureID'}}->{'rooting'}->{$a->{'Laboratory/rooting/rootingID'}} = $a;
                        $rooting_cross_lookup{$a->{'Laboratory/rooting/rootingID'}} = $cross_subculture_lookup{$a->{'Laboratory/rooting/getSubcultureID'}};
                        $rooting_activeseed_lookup{$a->{'Laboratory/rooting/rootingID'}} = $cross_activeseed_lookup{$a->{'Laboratory/rooting/getSubcultureID'}};
                        $rooting_subculture_lookup{$a->{'Laboratory/rooting/rootingID'}} = $a->{'Laboratory/rooting/getSubcultureID'};
                    }
                    elsif ($a->{'Laboratory/labActivity'} eq 'contamination'){
                        push @{$cross_info{$cross_subculture_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}}}->{'contamination'}}, $a;
                        $cross_info{$cross_subculture_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}}}->{'active_seeds'}->{$cross_activeseed_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}}}->{'subcultures'}->{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}}->{'contamination'}->{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}} = $a;
                        $rooting_cross_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}} = $cross_subculture_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}};
                        $rooting_activeseed_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}} = $cross_activeseed_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}};
                        $rooting_subculture_lookup{$a->{'Laboratory/embryo_contamination/lab_econtaminationID'}} = $a->{'Laboratory/embryo_contamination/lab_econtaminationID'};
                    }
                    else {
                        print STDERR "UNKNOWN ONA ODK activity in $activity_category\n";
                        print STDERR Dumper $a;
                    }
                }
                elsif ($activity_category eq 'screenhouse'){
                    #MISSING
                    if ($a->{'screenhse_activities/screenhouseActivity'} eq 'screenhouse_humiditychamber'){
                        push @{$cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'screenhouse_humiditychamber'}}, $a;
                        $cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'active_seeds'}->{$rooting_activeseed_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'subcultures'}->{$rooting_subculture_lookup{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}}->{'rooting'}->{$a->{'screenhse_activities/screenhouse/getRoot_ID'}}->{'screenhouse_humiditychamber'}->{$a->{'screenhse_activities/screenhouse/getRoot_ID'}} = $a;
                    }
                    elsif ($a->{'screenhse_activities/screenhouseActivity'} eq 'hardening'){
                        push @{$cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'hardening'}}, $a;
                        $cross_info{$rooting_cross_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'active_seeds'}->{$rooting_activeseed_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'subcultures'}->{$rooting_subculture_lookup{$a->{'screenhse_activities/hardening/hardeningID'}}}->{'rooting'}->{$a->{'screenhse_activities/hardening/hardeningID'}}->{'hardening'}->{$a->{'screenhse_activities/hardening/hardeningID'}} = $a;
                    }
                    else {
                        print STDERR "UNKNOWN ONA ODK activity in $activity_category\n";
                        print STDERR Dumper $a;
                    }
                }
                else {
                    print STDERR "UNKNOWN ONA ODK $activity_category\n";
                    print STDERR Dumper $a;
                }
            }
        }
        #print STDERR Dumper \%cross_info;
        #print STDERR Dumper \%plant_status_info;
        #print STDERR Dumper \%cross_parents;

        my %odk_cross_hash = (
            cross_info => \%cross_info,
            cross_parents => \%cross_parents,
            plant_status_info => \%plant_status_info,
            raw_message => $message_hash
        );

        #Update cross progress tree
        my $return = $self->create_odk_cross_progress_tree(\%odk_cross_hash);
        if ($return->{error}){
            return { error => $return->{error} };
        }
        return { success => 1 };

    } else {
        print STDERR Dumper $resp;
        return { error => "Could not connect to ONA" };
    }
}

sub create_odk_cross_progress_tree {
    print STDERR "CREATE ODK CROSS PROGRESS TREE START\n";
    my $self = shift;
    my $odk_submission = shift;
    my $bcs_schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema;
    my $metadata_schema = $self->metadata_schema;
    my $cross_wishlist_temp_file_path = $self->cross_wishlist_temp_file_path;
    my $wishlist_file_name = $self->_ona_cross_wishlist_file_name;
    my $germplasm_info_file_name = $self->_ona_germplasm_info_file_name;
    my $form_id = $self->odk_crossing_data_service_form_id;

    $wishlist_file_name =~ s/.csv//;
    my $wishlist_file_name_loc = $wishlist_file_name;
    $wishlist_file_name_loc =~ s/cross_wishlist_//;
    my @wishlist_file_name_loc_array = split '_', $wishlist_file_name_loc;
    $wishlist_file_name_loc = $wishlist_file_name_loc_array[0];
    print STDERR $wishlist_file_name_loc."\n";

    my %combined;

    my @wishlist_file_lines;
    my %open_tree;
    my %cross_combinations;
    my %top_level_title;
    my %all_plant_status_info;

    print STDERR "cross_wishlist $cross_wishlist_temp_file_path\n";

    open(my $fh, '<', $cross_wishlist_temp_file_path)
        or die "Could not open file '$cross_wishlist_temp_file_path' $!";
    my $header_row = <$fh>;
    chomp $header_row;
    my @header_row = split ',', $header_row;
    while ( my $row = <$fh> ){
        chomp $row;
        my @cols = split ',', $row;
        push @wishlist_file_lines, \@cols;
    }
    #print STDERR Dumper \@wishlist_file_lines;

    print STDERR "ONA ODK CROSS SUMMARY 2\n";

    my %cross_wishlist_hash;
    foreach (@wishlist_file_lines){
        my $female_accession_name = $_->[5];
        my $female_plot_name = $_->[1];
        my $wishlist_entry_created_timestamp = $_->[15];
        my $wishlist_entry_created_by = $_->[16];
        my $number_males = $_->[17];
        $wishlist_entry_created_by =~ tr/"//d;
        $wishlist_entry_created_timestamp =~ tr/"//d;
        $female_accession_name =~ tr/"//d;
        $female_plot_name =~ tr/"//d;
        $number_males =~ tr/"//d;
        my $top_level = "$wishlist_entry_created_by @ $wishlist_entry_created_timestamp";
        my $num_males_int = $number_males ? int($number_males) : 0;
        for my $n (18 .. 18+$num_males_int){
            if ($_->[$n]){
                $_->[$n] =~ tr/"//d;
                $cross_wishlist_hash{$top_level}->{$female_accession_name}->{$female_plot_name}->{$_->[$n]}++;
            }
        }
    }
    #print STDERR Dumper \%cross_wishlist_hash;

    my @all_cross_parents;
    my %all_cross_info;

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
    #print STDERR Dumper \@all_cross_parents;
    #print STDERR Dumper \%all_plant_status_info;
    #print STDERR Dumper \%all_cross_info;

    print STDERR "ONA ODK CROSS SUMMARY 3\n";

    foreach my $top_level (keys %cross_wishlist_hash){
        foreach my $female_accession_name (keys %{$cross_wishlist_hash{$top_level}}){
            my $planned_female_plot_name_hash = $cross_wishlist_hash{$top_level}->{$female_accession_name};
            foreach my $planned_female_plot_name (keys %$planned_female_plot_name_hash){
                if (exists($all_plant_status_info{$planned_female_plot_name}->{'status'})){
                    $combined{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{'planned_female_plot_name_status'} = $all_plant_status_info{$planned_female_plot_name}->{'status'};
                }
                my $male_hash = $cross_wishlist_hash{$top_level}->{$female_accession_name}->{$planned_female_plot_name};
                foreach my $male_accession_name (keys %$male_hash){
                    foreach my $cross_parents (@all_cross_parents){
                        if (exists($cross_parents->{$female_accession_name}->{$male_accession_name})){
                            my $cycles_hash = $cross_parents->{$female_accession_name}->{$male_accession_name};
                            foreach my $cycle (keys %$cycles_hash){
                                foreach my $cross_name (keys %{$cycles_hash->{$cycle}}){
                                    my $cross_info = $all_cross_info{$cross_name};
                                    $combined{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{$male_accession_name}->{$cycle}->{$cross_name} = $cross_info;
                                    if ($cross_info->{'firstPollination'}){
                                        foreach my $first_pollination (@{$cross_info->{'firstPollination'}}){
                                            my $female_plot_name = _get_plot_name_from_barcode_id($first_pollination->{'FieldActivities/FirstPollination/femID'});
                                            if ($planned_female_plot_name eq $female_plot_name){
                                                $combined{$top_level}->{'wishlist_female_plot_match'} = $female_plot_name;
                                                $cross_combinations{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{$female_plot_name}->{$male_accession_name}->{$cycle}->{$cross_name} = 1;
                                            } else {
                                                $combined{$top_level}->{'wishlist_female_plot_no_match'} = $female_plot_name;
                                            }
                                        }
                                    }
                                    $open_tree{$top_level}++;
                                }
                            }
                        } else {
                            if ($male_accession_name =~ /^\s*$/) {
                                $male_accession_name =~ s/\s+//g;
                            }
                            if ($male_accession_name){
                                $combined{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{$male_accession_name} = "No Crosses Performed";
                            }
                        }
                    }
                }
                my $male_accession_names = join ',', keys %$male_hash;
                $top_level_title{$top_level} = "Planned Female Accession: $female_accession_name. Planned Female Plot: $planned_female_plot_name. Planned Male Accession(s): $male_accession_names.";
            }
        }
    }
    #print STDERR Dumper \%combined;

    print STDERR "ONA ODK CROSS SUMMARY 4\n";

    my %seen_top_levels;
    my %top_level_contents;
    my @top_level_json;
    my %summary_info;
    while (my ($top_level, $female_accession_hash) = each %combined){
        if (exists($seen_top_levels{$top_level})){
            die "top level $top_level not unique \n";
        }
        my $node = {
            'id' => $top_level,
            'children' => JSON::true,
        };
        push @top_level_json, $node;

        my $icon_color = '';
        my $crossed_female_plot_name = '';
        if (!exists($open_tree{$top_level})){
            $node->{state}->{opened} = JSON::false;
            $node->{text} = '<span order-field="2" title="'.$top_level_title{$top_level}.'">Wishlist Entry: '.$top_level." : No Crosses</span>";
            $icon_color = 'text-danger';
            $node->{icon} = 'glyphicon glyphicon-briefcase '.$icon_color;
        }
        if (exists($female_accession_hash->{wishlist_female_plot_match})){
            #print STDERR Dumper $female_accession_hash;
            $node->{text} = '<span order-field="0" title="'.$top_level_title{$top_level}.'" class="text-success">Crossed Wishlist Entry: '.$top_level.'</span>';
            $icon_color = 'text-success';
            $node->{icon} = 'glyphicon glyphicon-briefcase '.$icon_color;
            $node->{state}->{opened} = JSON::true;
            $crossed_female_plot_name = $female_accession_hash->{wishlist_female_plot_match};
        } elsif (exists($female_accession_hash->{wishlist_female_plot_no_match})){
            $node->{text} = '<span order-field="1" title="'.$top_level_title{$top_level}.'">Possibly Crossed Wishlist Entry: '.$top_level.': Cross Performed But Not On This Wishlist Female Plot</span>';
            $icon_color = 'text-info';
            $node->{icon} = 'glyphicon glyphicon-briefcase '.$icon_color;
            $node->{state}->{opened} = JSON::false;
            $node->{children} = JSON::false;
            next;
        }

        my @top_level_content_json;
        while (my ($female_accession_name, $planned_female_plot_name_hash) = each %$female_accession_hash){
            if ($female_accession_name ne 'wishlist_female_plot_match' && $female_accession_name ne 'wishlist_female_plot_no_match'){
                my $planned_female_node = {
                    'text' => 'Wishlist Female Accession: '.$female_accession_name,
                    'icon' => 'glyphicon glyphicon-queen '.$icon_color,
                    'state' => { 'opened' => JSON::true }
                };
                push @top_level_content_json, $planned_female_node;
                while (my ($planned_female_plot_name, $male_accession_hash) = each %$planned_female_plot_name_hash){
                    my $planned_female_plot_node = {
                        'text' => 'Wishlist Female Plot: '.$planned_female_plot_name,
                        'icon' => 'glyphicon glyphicon-queen '.$icon_color
                    };
                    push @{$planned_female_node->{children}}, $planned_female_plot_node;
                    while (my ($male_accession_name, $crosses_cycle_hash) = each %$male_accession_hash){
                        if ($male_accession_name eq 'planned_female_plot_name_status'){
                            my $status = $crosses_cycle_hash;
                            #print STDERR Dumper $status;
                            $planned_female_plot_node->{text} .= ' : '.$status->{'attachment_display_tiny'}.' : STATUS = '.$status->{'status_message'};
                        }
                        else {
                            my $planned_male_node = {
                                'text' => 'Wishlist Male Accession: '.$male_accession_name
                            };
                            push @{$planned_female_plot_node->{children}}, $planned_male_node;
                            if (ref($crosses_cycle_hash) eq "HASH") {
                                $planned_male_node->{state}->{opened} = JSON::true;
                                while (my ($cycle, $crosses_hash) = each %$crosses_cycle_hash){

                                    while (my ($cross_name, $actions_hash) = each %$crosses_hash){
                                        if (exists($cross_combinations{$top_level}->{$female_accession_name}->{$planned_female_plot_name}->{$crossed_female_plot_name}->{$male_accession_name}->{$cycle}->{$cross_name})){
                                            print STDERR "YES : ".$top_level." : ".$female_accession_name." : ".$planned_female_plot_name." : ".$crossed_female_plot_name." : ".$male_accession_name." : ".$cycle." : ".$cross_name."\n";
                                            $planned_male_node->{icon} = 'glyphicon glyphicon-king '.$icon_color;
                                            $planned_female_plot_node->{state}->{opened} = JSON::true;
                                        } else {
                                            print STDERR "NO : ".$top_level." : ".$female_accession_name." : ".$planned_female_plot_name." : ".$crossed_female_plot_name." : ".$male_accession_name." : ".$cycle." : ".$cross_name."\n";
                                            $planned_male_node->{icon} = 'glyphicon glyphicon-king';
                                            $planned_male_node->{state}->{opened} = JSON::false;
                                            my $cross_node = {
                                                'text' => 'No Crosses',
                                                'icon' => 'glyphicon glyphicon-minus',
                                            };
                                            push @{$planned_male_node->{children}}, $cross_node;
                                            next;
                                        }
                                        my $cross_node = {
                                            'text' => 'Cross Name: '.$cross_name,
                                            'icon' => 'glyphicon glyphicon-random text-primary',
                                            'state' => { 'opened' => JSON::true }
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
                                                                    if ($subcultures_action_name eq 'contamination'){
                                                                        my $contaminations_hash = $subculture_action_value;
                                                                        my $contaminations_node = {
                                                                            'text' => $subcultures_action_name,
                                                                            'icon' => 'glyphicon glyphicon-eye-open text-success',
                                                                        };
                                                                        push @{$subculture_node->{children}}, $contaminations_node;
                                                                        while (my ($contamination_name, $contamination_hash) = each %$contaminations_hash){
                                                                            my $contamination_node = {
                                                                                'text' => $contamination_name,
                                                                                'icon' => 'glyphicon glyphicon-chevron-right text-success',
                                                                            };
                                                                            push @{$contaminations_node->{children}}, $contamination_node;
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

                                                    my $user_category = $action_hash->{'userCategory'};
                                                    if ($user_category eq 'field'){
                                                        my $activity_name = $action_hash->{'FieldActivities/fieldActivity'};
                                                        if ($activity_name eq 'firstPollination'){
                                                            my $activity_summary = {
                                                                femaleAccessionName => $action_hash->{'FieldActivities/FirstPollination/FemaleName'},
                                                                maleAccessionName => $action_hash->{'FieldActivities/FirstPollination/selectedMaleName'},
                                                                femalePlotName => _get_plot_name_from_barcode_id($action_hash->{'FieldActivities/FirstPollination/femID'}),
                                                                malePlotName => _get_plot_name_from_barcode_id($action_hash->{'FieldActivities/FirstPollination/malID'}),
                                                                date => $action_hash->{'FieldActivities/FirstPollination/firstpollination_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'repeatPollination'){
                                                            my $activity_summary = {
                                                                femaleAccessionName => $action_hash->{'FieldActivities/RepeatPollination/getRptFemaleAccName'},
                                                                maleAccessionName => $action_hash->{'FieldActivities/RepeatPollination/getRptMaleAccName'},
                                                                malePlotName => _get_plot_name_from_barcode_id($action_hash->{'FieldActivities/RepeatPollination/rptMalID'}),
                                                                date => $action_hash->{'FieldActivities/RepeatPollination/rptpollination_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'harvesting'){
                                                            my $activity_summary = {
                                                                taken_ripening_shed => $action_hash->{'FieldActivities/harvesting/taken_ripening_shed'},
                                                                harvesting_date => $action_hash->{'FieldActivities/harvesting/harvesting_date'},
                                                                pollinated_date => $action_hash->{'FieldActivities/harvesting/pollinated_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'seedExtraction'){
                                                            my $activity_summary = {
                                                                harvest_date => $action_hash->{'FieldActivities/seedExtraction/getHarvest_date'},
                                                                total_seeds_extracted => $action_hash->{'FieldActivities/seedExtraction/totalSeedsExtracted'},
                                                                extraction_date => $action_hash->{'FieldActivities/seedExtraction/extraction_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                    }
                                                    if ($user_category eq 'laboratory'){
                                                        my $activity_name = $action_hash->{'Laboratory/labActivity'};
                                                        if ($activity_name eq 'embryoRescue'){
                                                            my $activity_summary = {
                                                                good_seeds => $action_hash->{'Laboratory/embryoRescue/goodSeeds'},
                                                                extracted_date => $action_hash->{'Laboratory/embryoRescue/extracted_date'},
                                                                embryorescue_seeds => $action_hash->{'Laboratory/embryoRescue/embryorescue_seeds'},
                                                                bad_seeds => $action_hash->{'Laboratory/embryoRescue/badSeeds'},
                                                                total_seeds => $action_hash->{'Laboratory/embryoRescue/getTotalSeeds'},
                                                                embryorescue_date=> $action_hash->{'Laboratory/embryoRescue/embryorescue_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'subculture'){
                                                            my $activity_summary = {
                                                                subcultures_count => $action_hash->{'Laboratory/subculturing/subccultures_count'},
                                                                multiplication_number => $action_hash->{'Laboratory/subculturing/multiplicationNumber'},
                                                                subculture_date => $action_hash->{'Laboratory/subculturing/subculture_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'rooting'){
                                                            my $activity_summary = {
                                                                subculture_date => $action_hash->{'Laboratory/rooting/getSubDate'},
                                                                rooting_date => $action_hash->{'Laboratory/rooting/rooting_date'},
                                                                rooting_plantlet => $action_hash->{'Laboratory/rooting/rooting_plantlet'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'contamination'){
                                                            my $activity_summary = {
                                                                contamination_location => $action_hash->{'Laboratory/embryo_contamination/contamination_location'},
                                                                lab_contaminated => $action_hash->{'Laboratory/embryo_contamination/lab_contaminated'},
                                                                lab_contamination_date => $action_hash->{'Laboratory/embryo_contamination/lab_contamination_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'germinating_after_2wks'){
                                                            my $activity_summary = {
                                                                rescued_seeds => $action_hash->{'Laboratory/embryo_germinatn_after_2wks/rescued_seeds'},
                                                                germinating_2wks_date => $action_hash->{'Laboratory/embryo_germinatn_after_2wks/germinating_2wks_date'},
                                                                rescued_date => $action_hash->{'Laboratory/embryo_germinatn_after_2wks/rescued_date'},
                                                                actively_2wks => $action_hash->{'Laboratory/embryo_germinatn_after_2wks/actively_2wks'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'germinating_after_8weeks'){
                                                            my $activity_summary = {
                                                                active_2weeks => $action_hash->{'Laboratory/embryo_germinatn_after_8weeks/active_2wks'},
                                                                active_8weeks => $action_hash->{'Laboratory/embryo_germinatn_after_8weeks/actively_8weeks'},
                                                                germinated_2wksdate => $action_hash->{'Laboratory/embryo_germinatn_after_8weeks/germinated_2wksdate'},
                                                                germinating_8wksdate => $action_hash->{'Laboratory/embryo_germinatn_after_8weeks/germinating_8weeks_date'},
                                                                active_seeds_count => $action_hash->{'Laboratory/embryo_germinatn_after_8weeks/label_active_seeds_count'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                    }
                                                    if ($user_category eq 'screenhouse'){
                                                        my $activity_name = $action_hash->{'screenhse_activities/screenhouseActivity'};
                                                        if ($activity_name eq 'screenhouse_humiditychamber'){
                                                            my $activity_summary = {
                                                                screenhse_transfer_date => $action_hash->{'screenhse_activities/screenhouse/screenhse_transfer_date'},
                                                                rooted_date => $action_hash->{'screenhse_activities/screenhouse/rooted_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                        if ($activity_name eq 'hardening'){
                                                            my $activity_summary = {
                                                                screenhsed_date => $action_hash->{'screenhse_activities/hardening/screenhsed_date'},
                                                                hardening_date => $action_hash->{'screenhse_activities/hardening/hardening_date'},
                                                            };
                                                            push @{$summary_info{$top_level}->{$cross_name}->{$activity_name}}, $activity_summary;
                                                        }
                                                    }

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
                                }
                            } else {
                                $planned_male_node->{icon} = 'glyphicon glyphicon-king';
                                my $action_attr_node = {
                                    'text' => $crosses_cycle_hash,
                                    'icon' => 'glyphicon glyphicon-minus',
                                };
                                push @{$planned_male_node->{children}}, $action_attr_node;
                            }
                        }
                    }
                }
            }
        }
        $top_level_contents{$top_level} = \@top_level_content_json;
    }
    #print STDERR Dumper \%summary_info;

    print STDERR "WRITING ONA ODK SUMMARY FILES\n";
    my $dir = $self->odk_cross_progress_tree_file_dir;
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }

    my $filename = $dir."/ona_odk_cross_progress_top_level_json_html_".$form_id.".txt";
    print STDERR "Writing to $filename \n";
    my $OUTFILE;
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } encode_json \@top_level_json or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    $filename = $dir."/ona_odk_cross_progress_top_level_contents_html_".$form_id.".txt";
    print STDERR "Writing to $filename \n";
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } encode_json \%top_level_contents or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    $filename = $dir."/ona_odk_cross_progress_summary_info_html_".$form_id.".txt";
    print STDERR "Writing to $filename \n";
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } encode_json \%summary_info or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    $filename = $dir."/ona_odk_cross_progress_summary_plant_status_info_html_".$form_id.".txt";
    print STDERR "Writing to $filename \n";
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } encode_json \%all_plant_status_info or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    # find or create crossing trial using name of cross wishlist
    # create cross in db if not existing
    # save properties to cross
    #print STDERR Dumper \%summary_info;
    my %parsed_data;
    foreach my $cross_hash (values %summary_info){
        while ( my ($cross_name, $activities) = each %$cross_hash){
            while ( my ($activity_name, $entries) = each %$activities){
                if ($activity_name eq 'firstPollination'){
                    foreach my $e (@$entries){
                        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_name, cross_type=>'biparental');
                        my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $e->{femaleAccessionName});
                        $pedigree->set_female_parent($female_parent_individual);
                        my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $e->{maleAccessionName});
                        $pedigree->set_male_parent($male_parent_individual);
                        my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $e->{femalePlotName});
                        $pedigree->set_female_plot($female_plot_individual);
                        my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $e->{malePlotName});
                        $pedigree->set_male_plot($male_plot_individual);
                        push @{$parsed_data{crosses}}, $pedigree;
                        $parsed_data{'First Pollation Date'}->{$cross_name} = $e->{date};
                    }
                }
                if ($activity_name eq 'repeatPollination'){
                    foreach my $e (@$entries){
                        $parsed_data{'Repeat Pollation Date'}->{$cross_name} = $e->{date};
                    }
                }
                if ($activity_name eq 'harvesting'){
                    foreach my $e (@$entries){
                        $parsed_data{'Harvest Date'}->{$cross_name} = $e->{harvesting_date};
                    }
                }
                if ($activity_name eq 'harvesting'){
                    foreach my $e (@$entries){
                        $parsed_data{'Harvest Date'}->{$cross_name} = $e->{harvesting_date};
                    }
                }
                if ($activity_name eq 'seedExtraction'){
                    foreach my $e (@$entries){
                        $parsed_data{'Seed Extraction Date'}->{$cross_name} = $e->{extraction_date};
                        $parsed_data{'Number of Seeds Extracted'}->{$cross_name} = $e->{total_seeds_extracted};
                    }
                }
                if ($activity_name eq 'embryoRescue'){
                    foreach my $e (@$entries){
                        $parsed_data{'Embryo Rescue Date'}->{$cross_name} = $e->{embryorescue_date};
                        $parsed_data{'Embryo Rescue Good Seeds'}->{$cross_name} = $e->{good_seeds};
                        $parsed_data{'Embryo Rescue Bad Seeds'}->{$cross_name} = $e->{bad_seeds};
                        $parsed_data{'Embryo Rescue Total Seeds'}->{$cross_name} = $e->{total_seeds};
                    }
                }
                if ($activity_name eq 'subculture'){
                    foreach my $e (@$entries){
                        $parsed_data{'Subcultures Count'}->{$cross_name} = $e->{subcultures_count};
                        $parsed_data{'Subculture Date'}->{$cross_name} = $e->{subculture_date};
                        $parsed_data{'Subcultures Multiplication Number'}->{$cross_name} = $e->{multiplication_number};
                    }
                }
                if ($activity_name eq 'rooting'){
                    foreach my $e (@$entries){
                        $parsed_data{'Rooting Date'}->{$cross_name} = $e->{rooting_date};
                        $parsed_data{'Rooting Plantlet'}->{$cross_name} = $e->{rooting_plantlet};
                    }
                }
                if ($activity_name eq 'germinating_after_2wks'){
                    foreach my $e (@$entries){
                        $parsed_data{'Germinating After 2 Weeks Date'}->{$cross_name} = $e->{germinating_2wks_date};
                        $parsed_data{'Active Germinating After 2 Weeks'}->{$cross_name} = $e->{actively_2wks};
                    }
                }
                if ($activity_name eq 'germinating_after_8weeks'){
                    foreach my $e (@$entries){
                        $parsed_data{'Germinating After 8 Weeks Date'}->{$cross_name} = $e->{germinating_8wksdate};
                        $parsed_data{'Active Germinating After 8 Weeks'}->{$cross_name} = $e->{active_8weeks};
                    }
                }
                if ($activity_name eq 'screenhouse_humiditychamber'){
                    foreach my $e (@$entries){
                        $parsed_data{'Screenhouse Transfer Date'}->{$cross_name} = $e->{screenhse_transfer_date};
                    }
                }
                if ($activity_name eq 'hardening'){
                    foreach my $e (@$entries){
                        $parsed_data{'Hardening Date'}->{$cross_name} = $e->{hardening_date};
                    }
                }
            }
        }
    }
    #print STDERR Dumper \%parsed_data;

    my $cross_trial_id;
    my $location_id;
    my $location = $bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$wishlist_file_name_loc});
    if ($location){
        $location_id = $location->nd_geolocation_id;
    }
    my $previous_crossing_trial_rs = $bcs_schema->resultset("Project::Project")->find({name => $wishlist_file_name});
    my $iita_breeding_program_id = $bcs_schema->resultset("Project::Project")->find({name => 'IITA'})->project_id();
    my $t = Time::Piece->new();
    if ($previous_crossing_trial_rs){
        $cross_trial_id = $previous_crossing_trial_rs->project_id;
    } else {
        my $add_crossingtrial = CXGN::Pedigree::AddCrossingtrial->new({
            chado_schema => $bcs_schema,
            dbh => $bcs_schema->storage->dbh,
            breeding_program_id => $iita_breeding_program_id,
            year => $t->year,
            project_description => 'ODK ONA crosses from wishlist',
            crossingtrial_name => $wishlist_file_name,
            nd_geolocation_id => $location_id
        });
        my $store_return = $add_crossingtrial->save_crossingtrial();
        $cross_trial_id = $store_return->{trial_id};
    }

    if ($parsed_data{crosses} && scalar(@{$parsed_data{crosses}}) > 0){

        my @new_crosses;
        foreach (@{$parsed_data{crosses}}){
            my $cross_exists_rs = $bcs_schema->resultset("Stock::Stock")->find({uniquename=>$_->get_name});
            if ($cross_exists_rs){
                print STDERR "Already saved ".$cross_exists_rs->uniquename.". Skipping AddCrosses\n";
            } else {
                push @new_crosses, $_;
            }
        }

        my $cross_add = CXGN::Pedigree::AddCrosses->new({
            chado_schema => $bcs_schema,
            phenome_schema => $phenome_schema,
            metadata_schema => $metadata_schema,
            dbh => $bcs_schema->storage->dbh,
#            location => $wishlist_file_name_loc,
            crossing_trial_id => $cross_trial_id,
            crosses => \@new_crosses,
            owner_name => $self->sp_person_username
        });
        if (!$cross_add->validate_crosses()){
            return {error => 'Error validating crosses'};
        }
        if (!$cross_add->add_crosses()){
            return {error => 'Error saving crosses'};
        }
    }

    my @cross_properties = split ',', $self->allowed_cross_properties;
    foreach my $info_type (@cross_properties){
        if ($parsed_data{$info_type}) {
            my %info_hash = %{$parsed_data{$info_type}};
            foreach my $cross_name_key (keys %info_hash) {
                my $value = $info_hash{$cross_name_key};
                my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $bcs_schema, cross_name => $cross_name_key, key => $info_type, value => $value });
                $cross_add_info->add_info();
            }
        }
    }

    return {success => 1};
}

sub _get_plot_name_from_barcode_id {
    my $id_full = shift;
    $id_full =~ s/stock\ name\:\ //g;
    my @id_split = split ' plot_id: ', $id_full;
    return $id_split[0];
}

1;
