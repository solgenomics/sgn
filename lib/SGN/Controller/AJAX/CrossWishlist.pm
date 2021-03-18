
=head1 NAME

SGN::Controller::AJAX::CrossWishlist - a REST controller class to provide the
functions for managing cross wishlist

=head1 DESCRIPTION



=head1 AUTHOR

=cut

package SGN::Controller::AJAX::CrossWishlist;

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
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::UploadFile;
use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddProgeny;
use CXGN::Pedigree::AddCrossInfo;
use CXGN::Pedigree::AddPopulations;
use CXGN::Pedigree::ParseUpload;
use CXGN::Trial::Folder;
use CXGN::Trial::TrialLayout;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use CXGN::Cross;
use JSON;
use Spreadsheet::ParseExcel;
use Tie::UrlEncoder; our(%urlencode);
use LWP::UserAgent;
use LWP::Simple;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub create_cross_wishlist : Path('/ajax/cross/create_cross_wishlist') : ActionClass('REST') { }

sub create_cross_wishlist_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    #print STDERR Dumper $c->req->params();
    my $data = decode_json $c->req->param('crosses');
    my $female_trial_id = $c->req->param('female_trial_id');
    my $male_trial_id = $c->req->param('male_trial_id');
#    print STDERR "CROSSES =".Dumper($data)."\n";

    my $female_trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $female_trial_id });
    my $location = $female_trial->get_location();
    my $location_name = $location->[1];
    #if ($location_name ne 'Arusha'){
    #    $c->stash->{rest} = { error => "Cross wishlist currently limited to trials in the location(s): Arusha. This is because currently there is only the ODK form for Arusha. In the future there will be others." };
    #    $c->detach();
    #}

    my %selected_cross_hash;
    my %selected_females;
    my %selected_males;
    foreach (@$data){
        push @{$selected_cross_hash{$_->{female_id}}->{$_->{priority}}}, $_->{male_id};
        $selected_females{$_->{female_id}}++;
        $selected_males{$_->{male_id}}++;
    }
#    print STDERR "CROSS HASH =".Dumper(\%selected_cross_hash)."\n";

    my %ordered_data;
    foreach my $female_id (keys %selected_cross_hash){
        foreach my $priority (sort keys %{$selected_cross_hash{$female_id}}){
            my $males = $selected_cross_hash{$female_id}->{$priority};
            foreach my $male_id (@$males){
                push @{$ordered_data{$female_id}}, $male_id;
            }
        }
    }
#    print STDERR "ORDERED DATA =".Dumper(\%ordered_data)."\n";

    my $female_trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $female_trial_id, experiment_type=>'field_layout' });
    my $design_layout = $female_trial_layout->get_design();
    print STDERR Dumper $design_layout;

    my %block_plot_hash;
    print STDERR "NUM PLOTS:".scalar(keys %$design_layout);
    while ( my ($key,$value) = each %$design_layout){
        $block_plot_hash{$value->{block_number}}->{$value->{plot_number}} = $value;
    }
#    print STDERR "BLOCK PLOT HASH =".Dumper(\%block_plot_hash)."\n";

    my $cross_wishlist_plot_select_html = '<h1>Select Female <!--and Male -->Plots For Each Desired Cross Below:</h1>';

    foreach my $female_accession_name (sort keys %ordered_data){
        my $decoded_female_accession_name = uri_decode($female_accession_name);
        my $num_seen = 0;
        my $current_males = $ordered_data{$female_accession_name};
        my $current_males_string = join ',', @$current_males;
        my $encoded_males_string = uri_encode($current_males_string);
        $cross_wishlist_plot_select_html .= '<div class="well" id="cross_wishlist_plot_'.$female_accession_name.'_tab" ><h2>Female: '.$decoded_female_accession_name.' Males: '.$current_males_string.'</h2><h3><!--Select All Male Plots <input type="checkbox" name="cross_wishlist_plot_select_all_male" id="cross_wishlist_plot_select_all_male_'.$female_accession_name.'" data-female_accession_name="'.$female_accession_name.'" />   -->Select All Female Plots <input type="checkbox" id="cross_wishlist_plot_select_all_female_'.$female_accession_name.'" name="cross_wishlist_plot_select_all_female" data-female_accession_name="'.$female_accession_name.'" /></h3><table class="table table-bordered table-hover"><thead>';

        $cross_wishlist_plot_select_html .= "</thead><tbody>";
        my %current_males = map{$_=>1} @$current_males;
        foreach my $block_number (sort { $a <=> $b } keys %block_plot_hash){
            $cross_wishlist_plot_select_html .= "<tr><td><b>Block $block_number</b></td>";
            my $plot_number_obj = $block_plot_hash{$block_number};
            my @plot_numbers = sort { $a <=> $b } keys %$plot_number_obj;
            for (0 .. scalar(@plot_numbers)-1){
                my $plot_number = $plot_numbers[$_];
                my $value = $plot_number_obj->{$plot_number};
                my $accession_name = $value->{accession_name};
                #if ($female_accession_name eq $accession_name && exists($current_males{$accession_name})){
                #    $cross_wishlist_plot_select_html .= '<td><span class="bg-primary" title="Female. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.' Males to Cross:';
                #    my $count = 1;
                #    foreach (@{$ordered_data{$value->{accession_name}}}){
                #        $cross_wishlist_plot_select_html .= ' Male'.$count.': '.$_;
                #        $count ++;
                #    }
                #    $cross_wishlist_plot_select_html .= '">'.$accession_name.'</span><input type="checkbox" data-female_accession_name="'.$female_accession_name.'" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_female_input" /><br/><span class="bg-success" title="Male. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'</span><input type="checkbox" data-female_accession_name="'.$female_accession_name.'" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_male_input" /></td>';
                #    $num_seen++;
                #}
                if ($decoded_female_accession_name eq $accession_name){
                    $cross_wishlist_plot_select_html .= '<td class="bg-primary" title="Female. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.' Males to Cross: '.$current_males_string;
                    #my $count = 1;
                    #foreach (@{$ordered_data{$value->{accession_name}}}){
                    #    $cross_wishlist_plot_select_html .= ' Male'.$count.': '.$_;
                    #    $count ++;
                    #}
                    $cross_wishlist_plot_select_html .= '">'.$accession_name.'<input type="checkbox" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_female_input" data-female_accession_name="'.$female_accession_name.'" data-male_genotypes_string="'.$encoded_males_string.'" /></td>';
                    $num_seen++;
                }
                #elsif (exists($current_males{$accession_name})){
                #    $cross_wishlist_plot_select_html .= '<td class="bg-success" title="Male. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'<input type="checkbox" value="'.$value->{plot_id}.'" name="cross_wishlist_plot_select_male_input" data-female_accession_name="'.$female_accession_name.'" /></td>';
                #    $num_seen++;
                #}
                else {
                    $cross_wishlist_plot_select_html .= '<td title="Not Chosen. Plot Name: '.$value->{plot_name}.' Plot Number: '.$value->{plot_number}.'">'.$accession_name.'</td>';
                    $num_seen++;
                }
            }
            $cross_wishlist_plot_select_html .= '</tr>'
        }
        $cross_wishlist_plot_select_html .= '</tbody></table></div>';

        #$cross_wishlist_plot_select_html .= '<script>jQuery(document).on("change", "#cross_wishlist_plot_select_all_male_'.$female_accession_name.'", function(){if(jQuery(this).is(":checked")){var female_accession = jQuery(this).data("female_accession_name");jQuery(\'input[name="cross_wishlist_plot_select_male_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}});jQuery(document).on("change", "#cross_wishlist_plot_select_all_female_'.$female_accession_name.'", function(){if(jQuery(this).is(":checked")){var female_accession = jQuery(this).data("female_accession_name");jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}});</script>';
        $cross_wishlist_plot_select_html .= '<script>jQuery(document).on("change", "input[name=\"cross_wishlist_plot_select_all_female\"]", function(){var female_accession = jQuery(this).data("female_accession_name");if(jQuery(this).is(":checked")){jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", true);}});}else{jQuery(\'input[name="cross_wishlist_plot_select_female_input"]\').each(function(){if(jQuery(this).data("female_accession_name")==female_accession){jQuery(this).prop("checked", false);}});}});</script>';

#        print STDERR "NUM PLOTS SEEN: $num_seen\n";
    }

    $c->stash->{rest}->{data} = $cross_wishlist_plot_select_html;
}

sub create_cross_wishlist_submit : Path('/ajax/cross/create_cross_wishlist_submit') : ActionClass('REST') { }

sub create_cross_wishlist_submit_POST : Args(0) {
    my ($self, $c) = @_;

    if (!$c->user){
        $c->stash->{rest}->{error} = "You must be logged in to actually create a cross wishlist.";
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $site_name = $c->config->{project_name};

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    #print STDERR Dumper $c->req->params();
    my $data = decode_json $c->req->param('crosses');
    my $female_trial_id = $c->req->param('female_trial_id');
    my $male_trial_id = $c->req->param('male_trial_id');
    my $ona_form_id = $c->req->param('form_id') || '0';
    my $ona_form_name = $c->req->param('form_name') || '';
    my $selected_plot_ids = decode_json $c->req->param('selected_plot_ids');
    my $test_ona_form_name = $c->config->{odk_crossing_data_test_form_name};
    my $separate_crosswishlist_by_location = $c->config->{odk_crossing_data_separate_wishlist_by_location};

#    print STDERR "CROSSES =".Dumper($data)."\n";
#    print STDERR "SELECT PLOT IDS =".Dumper($selected_plot_ids)."\n";

    #For test ona forms, the cross wishlists are combined irrespective of location. On non-test forms, the cross wishlists can be separated by location
    my $is_test_form;
    if ($ona_form_name eq $test_ona_form_name){
        $is_test_form = 1;
    }
    #print STDERR Dumper $data;
    #print STDERR Dumper $selected_plot_ids;

    my %individual_cross_plot_ids;
    foreach (@$selected_plot_ids){
        if (exists($_->{female_plot_id})){
            push @{$individual_cross_plot_ids{$_->{cross_female_accession_name}}->{female_plot_ids}}, $_->{female_plot_id};
        }
        if (exists($_->{male_plot_id})){
            push @{$individual_cross_plot_ids{$_->{cross_female_accession_name}}->{male_plot_ids}}, $_->{male_plot_id};
        }
        if (exists($_->{male_genotypes_string})){
            my $male_genotypes_string = $_->{male_genotypes_string};
            my @male_genotypes = split ',', $male_genotypes_string;
            foreach my $g (@male_genotypes){
                $individual_cross_plot_ids{$_->{cross_female_accession_name}}->{male_genotypes}->{uri_decode($g)}++;
            }
        }
    }
    #print STDERR Dumper \%individual_cross_plot_ids;

    my %selected_cross_hash;
    my %selected_females;
    my %selected_males;
    foreach (@$data){
        push @{$selected_cross_hash{$_->{female_id}}->{$_->{priority}}}, $_->{male_id};
    }
    #print STDERR Dumper \%selected_cross_hash;

    my %ordered_data;
    foreach my $female_id (keys %selected_cross_hash){
        foreach my $priority (sort keys %{$selected_cross_hash{$female_id}}){
            my $males = $selected_cross_hash{$female_id}->{$priority};
            foreach my $male_id (@$males){
                push @{$ordered_data{$female_id}}, $male_id;
            }
        }
    }
    #print STDERR Dumper \%ordered_data;

    my $female_trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $female_trial_id });
    my $female_location = $female_trial->get_location();
    my $female_location_name = $female_location->[1];
    my $female_location_id = $female_location->[0];
    my $female_trial_name = $female_trial->get_name();
    my $female_planting_date = $female_trial->get_planting_date() || " ";
    my $female_trial_year = $female_trial->get_year();
    my $male_trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $male_trial_id });
    my $male_location = $male_trial->get_location();
    my $male_location_name = $male_location->[1];
    my $male_location_id = $male_location->[0];
    my $male_trial_name = $male_trial->get_name();
    my $male_planting_date = $male_trial->get_planting_date() || " ";
    my $male_trial_year = $male_trial->get_year();

    my $female_trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $female_trial_id, experiment_type=>'field_layout' });
    my $female_design_layout = $female_trial_layout->get_design();
    my $male_trial_layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $male_trial_id, experiment_type=>'field_layout' });
    my $male_design_layout = $male_trial_layout->get_design();

    my ($cross_wishlist_temp_file, $cross_wishlist_uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_cross_wishlist_downloadXXXXX');
    my $cross_wishlist_temp_file_path = $cross_wishlist_temp_file->filename;
    my ($germplasm_info_temp_file, $germplasm_info_uri1) = $c->tempfile( TEMPLATE => 'ODK_ONA_cross_info/ODK_ONA_germplasm_info_downloadXXXXX');
    my $germplasm_info_temp_file_path = $germplasm_info_temp_file->filename;
    my $cross_wihlist_ona_id;
    my $germplasm_info_ona_id;

    my $ua = LWP::UserAgent->new(
        ssl_opts => { verify_hostname => 0 }
    );
    $ua->credentials( 'api.ona.io:443', 'DJANGO', $c->config->{odk_crossing_data_service_username}, $c->config->{odk_crossing_data_service_password} );
    my $login_resp = $ua->get("https://api.ona.io/api/v1/user.json");
    my $server_endpoint = "https://api.ona.io/api/v1/data/$ona_form_id";
    print STDERR $server_endpoint."\n";
    my $resp = $ua->get($server_endpoint);

    my $server_endpoint2 = "https://api.ona.io/api/v1/metadata?xform=".$ona_form_id;
    my $resp2 = $ua->get($server_endpoint2);
    if ($resp2->is_success) {
        my $message2 = $resp2->decoded_content;
        my $message_hash2 = decode_json $message2;
        foreach my $t (@$message_hash2) {
            if (index($t->{data_value}, 'cross_wishlist') != -1) {
                my $cross_wishlist_file_name = $t->{data_value};

                $cross_wishlist_file_name =~ s/.csv//;
                my $wishlist_file_name_loc = $cross_wishlist_file_name;
                $wishlist_file_name_loc =~ s/cross_wishlist_//;
                print STDERR Dumper $wishlist_file_name_loc;

                if ($separate_crosswishlist_by_location){
                    if ($female_location_name eq $wishlist_file_name_loc) {
                        getstore($t->{media_url}, $cross_wishlist_temp_file_path);
                        $cross_wihlist_ona_id = $t->{id};
                    }
                } else {
                    getstore($t->{media_url}, $cross_wishlist_temp_file_path);
                    $cross_wihlist_ona_id = $t->{id};
                }
            }
            if (index($t->{data_value}, 'germplasm_info') != -1) {
                my $germplasm_info_file_name = $t->{data_value};

                $germplasm_info_file_name =~ s/.csv//;
                my $germplasm_info_file_name_loc = $germplasm_info_file_name;
                $germplasm_info_file_name_loc =~ s/germplasm_info_//;
                print STDERR Dumper $germplasm_info_file_name_loc;

                if ($separate_crosswishlist_by_location){
                    if ($female_location_name eq $germplasm_info_file_name_loc) {
                        getstore($t->{media_url}, $germplasm_info_temp_file_path);
                        $germplasm_info_ona_id = $t->{id};
                    }
                } else {
                    getstore($t->{media_url}, $germplasm_info_temp_file_path);
                    $germplasm_info_ona_id = $t->{id};
                }
            }
        }
    }

    my @previous_file_lines;
    my %previous_file_lookup;
    my $old_header_row;
    my @old_header_row_array;
    if ($cross_wihlist_ona_id){
        print STDERR "Previous cross_wishlist temp file $cross_wishlist_temp_file_path\n";
        open(my $fh, '<', $cross_wishlist_temp_file_path)
            or die "Could not open file '$cross_wishlist_temp_file_path' $!";
        $old_header_row = <$fh>;
        @old_header_row_array = split ',', $old_header_row;
        while ( my $row = <$fh> ){
            chomp $row;
            push @previous_file_lines, $row;
            my @previous_file_line_contents = split ',', $row;
            my $previous_female_obs_unit_id = $previous_file_line_contents[2];
            $previous_female_obs_unit_id =~ s/"//g;
            $previous_file_lookup{$previous_female_obs_unit_id} = \@previous_file_line_contents;
        }
    }
    #print STDERR Dumper \@previous_file_lines;

    my @previous_germplasm_info_lines;
    my %seen_info_obs_units;
    if ($germplasm_info_ona_id){
        print STDERR "PREVIOUS germplasm_info temp file $germplasm_info_temp_file_path\n";
        open(my $fh, '<', $germplasm_info_temp_file_path)
            or die "Could not open file '$germplasm_info_temp_file_path' $!";
        my $header_row = <$fh>;
        while ( my $row = <$fh> ){
            chomp $row;
            push @previous_germplasm_info_lines, $row;
            my @previous_file_line_contents = split ',', $row;
            my $previous_obs_unit_id = $previous_file_line_contents[2];
            $previous_obs_unit_id =~ s/"//g;
            $seen_info_obs_units{$previous_obs_unit_id}++;
        }
    }

    my $germplasm_info_file_header = '"ObservationUnitType","ObservationUnitName","ObservationUnitID","PlotName","PlotID","PlotBlockNumber","PlotNumber","PlotRepNumber","PlotRowNumber","PlotColNumber","PlotTier","PlotIsAControl","PlotSourceSeedlotName","PlotSourceSeedlotTransactionOperator","PlotSourceSeedlotNumSeedPerPlot","PlantName","PlantID","PlantNumber","TrialYear","TrialName","TrialID","LocationName","LocationID","PlantingDate","AccessionName","AccessionID","AccessionNameAndPlotNumber","AccessionNameAndPlotNumberAndPlantNumber","AccessionSynonyms","AccessionPedigree","AccessionGenus","AccessionSpecies","AccessionPloidyLevel","AccessionGenomeStructure","AccessionVariety","AccessionDonors","AccessionCountryOfOrigin","AccessionState","AccessionInstituteCode","AccessionInstituteName","AccessionBiologicalStatusOfAccessionCode","AccessionNotes","AccessionNumber","AccessionPUI","AccessionSeedSource","AccessionTypeOfGermplasmStorageCode","AccessionAcquisitionDate","AccessionOrganization","AccessionPopulationName","AccessionProgenyAccessionNames","PlotImageFileNames","AccessionImageFileNames","CrossWishlistTimestamp","CrossWishlistCreatedByUsername"';
    my @germplasm_info_lines;

    my %accession_id_hash;
    my %female_and_male_trials;
    while ( my ($key,$value) = each %$female_design_layout){
        my $accession_id = $value->{accession_id};
        $accession_id_hash{$accession_id} = $value;
        $female_and_male_trials{female}->{design}->{$key} = $value;
    }
    while ( my ($key,$value) = each %$male_design_layout){
        my $accession_id = $value->{accession_id};
        $accession_id_hash{$accession_id} = $value;
        $female_and_male_trials{male}->{design}->{$key} = $value;
    }
    $female_and_male_trials{female}->{location_name} = $female_location->[1];
    $female_and_male_trials{female}->{location_id} = $female_location->[0];
    $female_and_male_trials{female}->{trial_id} = $female_trial_id;
    $female_and_male_trials{female}->{trial_name} = $female_trial->get_name();
    $female_and_male_trials{female}->{planting_date} = $female_trial->get_planting_date() || " ";
    $female_and_male_trials{female}->{year} = $female_trial->get_year();
    $female_and_male_trials{male}->{location_name} = $male_location->[1];
    $female_and_male_trials{male}->{location_id} = $male_location->[0];
    $female_and_male_trials{male}->{trial_id} = $male_trial_id;
    $female_and_male_trials{male}->{trial_name} = $male_trial->get_name();
    $female_and_male_trials{male}->{planting_date} = $male_trial->get_planting_date() || " ";
    $female_and_male_trials{male}->{year} = $male_trial->get_year();

    my @accession_ids = keys %accession_id_hash;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $stock_search = CXGN::Stock::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        stock_id_list=>\@accession_ids,
        stock_type_id=>$accession_cvterm_id,
        stockprop_columns_view=>{'variety'=>1, 'stock_synonym'=>1, 'state'=>1, 'notes'=>1, 'organization'=>1, 'accession number'=>1, 'PUI'=>1, 'seed source'=>1, 'institute code'=>1, 'institute name'=>1, 'biological status of accession code'=>1, 'country of origin'=>1, 'type of germplasm storage code'=>1, 'acquisition date'=>1, 'ploidy_level'=>1, 'genome_structure'=>1},
        include_obsolete => 1
	});
    my ($result, $total_count) = $stock_search->search();
    my %accession_info_hash;
    foreach (@$result){
        $accession_info_hash{$_->{stock_id}} = $_;
    }

    my %plot_id_hash;
    while ( my ($k,$v) = each %female_and_male_trials){
        my $design = $v->{design};
        my $location_name = $v->{location_name};
        my $location_id = $v->{location_id};
        my $trial_id = $v->{trial_id};
        my $trial_name = $v->{trial_name};
        my $planting_date = $v->{planting_date};
        my $trial_year = $v->{year};

        while ( my ($key,$value) = each %$design){
            my $plot_id = $value->{plot_id};
            $plot_id_hash{$plot_id} = $value;
            my $plant_names = $value->{plant_names};
            my $plant_ids = $value->{plant_ids};
            my $plot_name = $value->{plot_name};
            my $accession_name = $value->{accession_name};
            my $accession_id = $value->{accession_id};
            my $plot_number = $value->{plot_number};
            my $block_number = $value->{block_number} || '';
            my $rep_number = $value->{rep_number} || '';
            my $row_number = $value->{row_number} || '';
            my $col_number = $value->{col_number} || '';
            my $is_a_control = $value->{is_a_control} || '';
            my $tier = $row_number && $col_number ? $row_number."/".$col_number : '';
            my $seedlot_name = $value->{seedlot_name} || '';
            my $seedlot_transaction_operator = $value->{seed_transaction_operator} || '';
            my $seedlot_num_seed_per_plot = $value->{num_seed_per_plot} || '';

#            print STDERR "GERMPLASM PLANT NAMES =".Dumper($plant_names)."\n";
            my $plant_number = 1;
            my $plant_index = 0;
            my $plant_num = @$plant_names;
#            print STDERR "GERMPLASM PLANT NUMBER =".Dumper($plant_num)."\n";
            if ($plant_num != 0){
                foreach (@$plant_names){
                    my $plant_id = $plant_ids->[$plant_index];
                    if (!exists($seen_info_obs_units{$plant_id})){
                        my $accession_stock = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$accession_id});
                        my $accession_info = $accession_info_hash{$accession_id};
                        my $synonyms = join(',',@{$accession_info->{synonyms}});
                        #my $pedigree = $accession_stock->get_pedigree_string("Parents");
                        my $pedigree = "NA";
                        my $genus = $accession_stock->get_genus || '';
                        my $species = $accession_stock->get_species || '';
                        my $variety = $accession_info->{variety};
                        #my $donors = encode_json($accession_stock->donors);
                        my $donors = "NA";
                        my $countryoforigin = $accession_info->{'country of origin'};
                        my $state = $accession_info->{'state'};
                        my $institute_code = $accession_info->{'institute code'};
                        my $institute_name = $accession_info->{'institute name'};
                        my $bio = $accession_info->{'biological status of accession code'};
                        my $notes = $accession_info->{notes};
                        my $accession_number = $accession_info->{'accession number'};
                        my $pui = $accession_info->{'PUI'};
                        my $ploidy_level = $accession_info->{'ploidy_level'};
                        my $genome_structure = $accession_info->{'genome_structure'};
                        my $seedsource = $accession_info->{'seed source'};
                        my $storage_code = $accession_info->{'type of germplasm storage code'};
                        my $acquisition_date = $accession_info->{'acquisition date'};
                        my $organization = $accession_info->{organization};
                        my $population = $accession_stock->population_name || '';
                        #my $stock_descendant_hash = $accession_stock->get_descendant_hash();
                        #my $descendants = $stock_descendant_hash->{descendants};
                        #my @descendents_array;
                        #while (my($k,$v) = each %$descendants){
                        #    push @descendents_array, $v->{name};
                        #}
                        #my $descendents_string = join ',', @descendents_array;
                        my $descendents_string = "NA";
                        my $t = time;
                        my $entry_timestamp = strftime '%F %T', localtime $t;
                        $entry_timestamp .= sprintf ".%03d", ($t-int($t))*1000;
                        push @germplasm_info_lines, '"plant","'.$_.'","'.$plant_id.'","'.$plot_name.'","'.$plot_id.'","'.$block_number.'","'.$plot_number.'","'.$rep_number.'","'.$row_number.'","'.$col_number.'","'.$tier.'","'.$is_a_control.'","'.$seedlot_name.'","'.$seedlot_transaction_operator.'","'.$seedlot_num_seed_per_plot.'","'.$_.'","'.$plant_id.'","'.$plant_number.'","'.$trial_year.'","'.$trial_name.'","'.$trial_id.'","'.$location_name.'","'.$location_id.'","'.$planting_date.'","'.$accession_name.'","'.$accession_id.'","'.$accession_name.'_'.$plot_number.'","'.$accession_name.'_'.$plot_number.'_'.$plant_number.'","'.$synonyms.'","'.$pedigree.'","'.$genus.'","'.$species.'","'.$ploidy_level.'","'.$genome_structure.'","'.$variety.'","'.$donors.'","'.$countryoforigin.'","'.$state.'","'.$institute_code.'","'.$institute_name.'","'.$bio.'","'.$notes.'","'.$accession_number.'","'.$pui.'","'.$seedsource.'","'.$storage_code.'","'.$acquisition_date.'","'.$organization.'","'.$population.'","'.$descendents_string.'","NA","NA","'.$entry_timestamp.'","'.$user_name.'"';

                        $seen_info_obs_units{$plant_id}++;
                    }
                    $plant_number++;
                    $plant_index++;
                }
            } elsif ($plant_num == 0) {
                if (!exists($seen_info_obs_units{$plot_id})){
                    my $accession_stock = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$accession_id});
                    my $accession_info = $accession_info_hash{$accession_id};
                    my $synonyms = join(',',@{$accession_info->{synonyms}});
                    #my $pedigree = $accession_stock->get_pedigree_string("Parents");
                    my $pedigree = "NA";
                    my $genus = $accession_stock->get_genus || '';
                    my $species = $accession_stock->get_species || '';
                    my $variety = $accession_info->{variety};
                    #my $donors = encode_json($accession_stock->donors);
                    my $donors = "NA";
                    my $countryoforigin = $accession_info->{'country of origin'};
                    my $state = $accession_info->{'state'};
                    my $institute_code = $accession_info->{'institute code'};
                    my $institute_name = $accession_info->{'institute name'};
                    my $bio = $accession_info->{'biological status of accession code'};
                    my $notes = $accession_info->{notes};
                    my $accession_number = $accession_info->{'accession number'};
                    my $pui = $accession_info->{'PUI'};
                    my $ploidy_level = $accession_info->{'ploidy_level'};
                    my $genome_structure = $accession_info->{'genome_structure'};
                    my $seedsource = $accession_info->{'seed source'};
                    my $storage_code = $accession_info->{'type of germplasm storage code'};
                    my $acquisition_date = $accession_info->{'acquisition date'};
                    my $organization = $accession_info->{organization};
                    my $population = $accession_stock->population_name || '';
                    #my $stock_descendant_hash = $accession_stock->get_descendant_hash();
                    #my $descendants = $stock_descendant_hash->{descendants};
                    #my @descendents_array;
                    #while (my($k,$v) = each %$descendants){
                    #    push @descendents_array, $v->{name};
                    #}
                    #my $descendents_string = join ',', @descendents_array;
                    my $descendents_string = "NA";
                    my $t = time;
                    my $entry_timestamp = strftime '%F %T', localtime $t;
                    $entry_timestamp .= sprintf ".%03d", ($t-int($t))*1000;
                    push @germplasm_info_lines, '"plot","'.$plot_name.'","'.$plot_id.'","'.$plot_name.'","'.$plot_id.'","'.$block_number.'","'.$plot_number.'","'.$rep_number.'","'.$row_number.'","'.$col_number.'","'.$tier.'","'.$is_a_control.'","'.$seedlot_name.'","'.$seedlot_transaction_operator.'","'.$seedlot_num_seed_per_plot.'","","","","'.$trial_year.'","'.$trial_name.'","'.$trial_id.'","'.$location_name.'","'.$location_id.'","'.$planting_date.'","'.$accession_name.'","'.$accession_id.'","'.$accession_name.'_'.$plot_number.'","","'.$synonyms.'","'.$pedigree.'","'.$genus.'","'.$species.'","'.$ploidy_level.'","'.$genome_structure.'","'.$variety.'","'.$donors.'","'.$countryoforigin.'","'.$state.'","'.$institute_code.'","'.$institute_name.'","'.$bio.'","'.$notes.'","'.$accession_number.'","'.$pui.'","'.$seedsource.'","'.$storage_code.'","'.$acquisition_date.'","'.$organization.'","'.$population.'","'.$descendents_string.'","NA","NA","'.$entry_timestamp.'","'.$user_name.'"';

                    $seen_info_obs_units{$plot_id}++;
                }
            }
        }
    }

    my $header = '"FemaleObservationUnitType","FemaleObservationUnitName","FemaleObservationUnitID","FemalePlotID","FemalePlotName","FemaleAccessionName","FemaleAccessionID","FemalePlotNumber","FemaleAccessionNameAndPlotNumber","FemaleBlockNumber","FemaleRepNumber","FemalePlantName","FemalePlantID","FemalePlantNumber","FemaleAccessionNameAndPlotNumberAndPlantNumber","Timestamp","CrossWishlistCreatedByUsername","NumberMales"';
    my @lines;
    my $max_male_num = 0;
    foreach my $female_id (keys %individual_cross_plot_ids){
        my $male_ids = $ordered_data{$female_id};
        my $female_plot_ids = $individual_cross_plot_ids{$female_id}->{female_plot_ids};
        #my $male_plot_ids = $individual_cross_plot_ids{$female_id}->{male_plot_ids};
        #my %allowed_male_plot_ids = map {$_=>1} @$male_plot_ids;
        my %allowed_male_genotypes = %{$individual_cross_plot_ids{$female_id}->{male_genotypes}};
        #print STDERR Dumper $female_plots;
        #print STDERR Dumper $male_ids;
        foreach my $female_plot_id (@$female_plot_ids){
            my $female = $plot_id_hash{$female_plot_id};
            my $plot_name = $female->{plot_name};
            my $plot_id = $female->{plot_id};
            my $accession_name = $female->{accession_name};
            my $accession_id = $female->{accession_id};
            my $plot_number = $female->{plot_number};
            my $block_number = $female->{block_number} || '';
            my $rep_number = $female->{rep_number} || '';
            my $num_males = 0;
            my $plant_names = $female->{plant_names};
            my $plant_ids = $female->{plant_ids};
            my $plant_number = 1;
            my $plant_index = 0;

#            print STDERR "WISHLIST PLANT NAMES =".Dumper($plant_names)."\n";
            my $plant_num = @$plant_names;
#            print STDERR "WISHLIST PLANT NUMBER =".Dumper($plant_num)."\n";

            if ($plant_num != 0) {
                foreach (@$plant_names){
                    $num_males = 0;
                    my $plant_id = $plant_ids->[$plant_index];
                    if ($previous_file_lookup{$plant_id}){
                        $num_males = $previous_file_lookup{$plant_id}->[17];
                        $num_males =~ s/"//g;
                        my %seen_males_ids;
                        foreach my $i (18..scalar(@{$previous_file_lookup{$plant_id}})-1){
                            my $previous_male_id = $previous_file_lookup{$plant_id}->[$i];
                            $previous_male_id =~ s/"//g;
                            $seen_males_ids{$previous_male_id}++;
                        }
                        foreach my $male_id (@$male_ids){
                            if (!$seen_males_ids{$male_id}){
                                push @{$previous_file_lookup{$plant_id}}, '"'.$male_id.'"';
                                $num_males++;
                            }
                        }
                        $previous_file_lookup{$plant_id}->[17] = '"'.$num_males.'"';
                    } else {
                        my $t = time;
                        my $entry_timestamp = strftime '%F %T', localtime $t;
                        $entry_timestamp .= sprintf ".%03d", ($t-int($t))*1000;
                        my $line = '"plant","'.$_.'","'.$plant_id.'","'.$plot_id.'","'.$plot_name.'","'.$accession_name.'","'.$accession_id.'","'.$plot_number.'","'.$accession_name.'_'.$plot_number.'","'.$block_number.'","'.$rep_number.'","'.$_.'","'.$plant_id.'","'.$plant_number.'","'.$accession_name.'_'.$plot_number.'_'.$plant_number.'","'.$entry_timestamp.'","'.$user_name.'","';

                        my @male_segments;
                        foreach my $male_id (@$male_ids){
                            push @male_segments, ',"'.$male_id.'"';
                            $num_males++;
                        }
                        $line .= $num_males.'"';
                        foreach (@male_segments){
                            $line .= $_;
                        }
                        push @lines, $line;
                    }
                    $plant_number++;
                    $plant_index++;

                    if ($num_males > $max_male_num){
                        $max_male_num = $num_males;
                    }
                }
            } elsif ($plant_num == 0){
                if ($previous_file_lookup{$female_plot_id}){
                    $num_males = $previous_file_lookup{$female_plot_id}->[17];
                    $num_males =~ s/"//g;
                    my %seen_males_ids;
                    foreach my $i (18..scalar(@{$previous_file_lookup{$female_plot_id}})-1){
                        my $previous_male_id = $previous_file_lookup{$female_plot_id}->[$i];
                        $previous_male_id =~ s/"//g;
                        $seen_males_ids{$previous_male_id}++;
                    }
                    foreach my $male_id (@$male_ids){
                        if (!$seen_males_ids{$male_id}){
                            push @{$previous_file_lookup{$female_plot_id}}, '"'.$male_id.'"';
                            $num_males++;
                        }
                    }
                    $previous_file_lookup{$female_plot_id}->[17] = '"'.$num_males.'"';
                } else {
                    my $t = time;
                    my $entry_timestamp = strftime '%F %T', localtime $t;
                    $entry_timestamp .= sprintf ".%03d", ($t-int($t))*1000;
                    my $line = '"plot","'.$plot_name.'","'.$plot_id.'","'.$plot_id.'","'.$plot_name.'","'.$accession_name.'","'.$accession_id.'","'.$plot_number.'","'.$accession_name.'_'.$plot_number.'","'.$block_number.'","'.$rep_number.'","","","","","'.$entry_timestamp.'","'.$user_name.'","';

                    my @male_segments;
                    foreach my $male_id (@$male_ids){
                        push @male_segments, ',"'.$male_id.'"';
                        $num_males++;
                    }
                    $line .= $num_males.'"';
                    foreach (@male_segments){
                        $line .= $_;
                    }
                    push @lines, $line;
                }

                if ($num_males > $max_male_num){
                    $max_male_num = $num_males;
                }
            }
        }
    }
    for (1 .. $max_male_num){
        $header .= ',"MaleAccessionName'.$_.'"';
    }

    my %priority_order_hash;
    foreach (@$data){
        push @{$priority_order_hash{$_->{priority}}}, [$_->{female_id}, $_->{male_id}];
    }
    my @new_header_row = split ',', $header;
    #print STDERR Dumper \%priority_order_hash;
    #print STDERR Dumper \@lines;
    #print STDERR Dumper \@germaplasm_info_lines;

    if (scalar(@old_header_row_array)>scalar(@new_header_row)){
        chomp $old_header_row;
        $header = $old_header_row;
    }

    my $dir = $c->tempfiles_subdir('download');
    my ($file_path1, $uri1) = $c->tempfile( TEMPLATE => 'download/cross_wishlist_downloadXXXXX');
    $file_path1 .= '.tsv';
    $uri1 .= '.tsv';
    my @header1 = ('Female Accession', 'Male Accession', 'Priority');
    open(my $F1, ">", $file_path1) || die "Can't open file ".$file_path1;
        print $F1 join "\t", @header1;
        print $F1 "\n";
        foreach my $p (keys %priority_order_hash){
            my $entries = $priority_order_hash{$p};
            foreach (@$entries){
                print $F1 uri_decode($_->[0])."\t".$_->[1]."\t".$p."\n";
            }
        }
    close($F1);
    print STDERR Dumper $file_path1;
    #print STDERR Dumper $uri1;
    my $urlencoded_filename1 = $urlencode{$uri1};
    #print STDERR Dumper $urlencoded_filename1;
    #$c->stash->{rest}->{filename} = $urlencoded_filename1;

    my ($file_path2, $uri2) = $c->tempfile( TEMPLATE => "download/cross_wishlist_XXXXX");
    $file_path2 .= '.csv';
    $uri2 .= '.csv';
    open(my $F, ">", $file_path2) || die "Can't open file ".$file_path2;
        print $F $header."\n";
        foreach (values %previous_file_lookup){
            my $line_string = join ',', @$_;
            print $F $line_string."\n";
        }
        foreach (@lines){
            print $F $_."\n";
        }
    close($F);
    print STDERR Dumper $file_path2;
    #print STDERR Dumper $uri2;
    my $urlencoded_filename2 = $urlencode{$uri2};
    #print STDERR Dumper $urlencoded_filename2;
    #$c->stash->{rest}->{filename} = $urlencoded_filename2;

    my $archive_name;
    if ($is_test_form){
        $archive_name = 'cross_wishlist_test.csv';
    } elsif ($separate_crosswishlist_by_location){
        $archive_name = 'cross_wishlist_'.$female_location_name.'.csv';
    } else {
        $archive_name = 'cross_wishlist_'.$site_name.'.csv';
    }

    my $file_type;
    if ($is_test_form) {
        $file_type = 'cross_wishlist_test_'.$ona_form_id;
    } elsif ($separate_crosswishlist_by_location) {
        $file_type = 'cross_wishlist_'.$female_location_name.'_'.$ona_form_id;
    } else {
        $file_type = 'cross_wishlist_'.$ona_form_id;
    }

    my $uploader = CXGN::UploadFile->new({
       include_timestamp => 0,
       tempfile => $file_path2,
       subdirectory => 'cross_wishlist_'.$site_name.'_'.$ona_form_id,
       archive_path => $c->config->{archive_path},
       archive_filename => $archive_name,
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $c->user->get_object->get_user_type()
    });
    my $uploaded_file = $uploader->archive();
    my $md5 = $uploader->get_md5($uploaded_file);
#    print STDERR "WISHLIST UPLOADED FILE =".Dumper($uploaded_file)."\n";

    my $wishlist_md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $wishlist_md_row->insert();
    my $wishlist_md5checksum = $md5->hexdigest();
    my $wishlist_file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($uploaded_file),
        dirname => dirname($uploaded_file),
        filetype => $file_type,
        md5checksum => $wishlist_md5checksum,
        metadata_id => $wishlist_md_row->metadata_id(),
    });

    my ($file_path3, $uri3) = $c->tempfile( TEMPLATE => "download/cross_wishlist_accession_info_XXXXX");
    $file_path3 .= '.csv';
    $uri3 .= '.csv';
    open(my $F3, ">", $file_path3) || die "Can't open file ".$file_path3;
        print $F3 $germplasm_info_file_header."\n";
        foreach (@previous_germplasm_info_lines){
            print $F3 $_."\n";
        }
        foreach (@germplasm_info_lines){
            print $F3 $_."\n";
        }
    close($F3);
    print STDERR Dumper $file_path3;
    #print STDERR Dumper $uri3;
    my $urlencoded_filename3 = $urlencode{$uri3};
    #print STDERR Dumper $urlencoded_filename3;
    #$c->stash->{rest}->{filename} = $urlencoded_filename3;

    my $germplasm_info_archive_name;
    if ($is_test_form){
        $germplasm_info_archive_name = 'germplasm_info_test.csv';
    } elsif ($separate_crosswishlist_by_location){
        $germplasm_info_archive_name = 'germplasm_info_'.$female_location_name.'.csv';
    } else {
        $germplasm_info_archive_name = 'germplasm_info_'.$site_name.'.csv';
    }

    $uploader = CXGN::UploadFile->new({
       include_timestamp => 0,
       tempfile => $file_path3,
       subdirectory => 'cross_wishlist_'.$site_name.'_'.$ona_form_id,
       archive_path => $c->config->{archive_path},
       archive_filename => $germplasm_info_archive_name,
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $c->user->get_object->get_user_type()
    });
    my $germplasm_info_uploaded_file = $uploader->archive();
    my $germplasm_info_md5 = $uploader->get_md5($germplasm_info_uploaded_file);
#    print STDERR "GERMPLASM INFO UPLOADED FILE =".Dumper($germplasm_info_uploaded_file)."\n";
    my $germplasm_info_md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $germplasm_info_md_row->insert();
    my $germplasm_info_md5checksum = $germplasm_info_md5->hexdigest();
    my $germplasm_info_file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($germplasm_info_uploaded_file),
        dirname => dirname($germplasm_info_uploaded_file),
        filetype => $file_type,
        md5checksum => $germplasm_info_md5checksum,
        metadata_id => $germplasm_info_md_row->metadata_id(),
    });

    my $odk_crossing_data_service_name = $c->config->{odk_crossing_data_service_name};
    my $odk_crossing_data_service_url = $c->config->{odk_crossing_data_service_url};

    $c->stash->{rest}->{success} = 'The cross wishlist file can be downloaded <a href="'.$uri2.'">here</a>. The germplasm info file can be downloaded <a href="'.$uri3.'">here</a>.';

    if ($odk_crossing_data_service_name eq 'NULL') {
        $c->detach();
    } else {

        my $ua = LWP::UserAgent->new;
        $ua->credentials( 'api.ona.io:443', 'DJANGO', $c->config->{odk_crossing_data_service_username}, $c->config->{odk_crossing_data_service_password} );
        my $login_resp = $ua->get("https://api.ona.io/api/v1/user.json");

        my $server_endpoint = "https://api.ona.io/api/v1/metadata";

        if ($cross_wihlist_ona_id){
            my $delete_resp = $ua->delete(
                $server_endpoint."/$cross_wihlist_ona_id"
            );
            if ($delete_resp->is_success) {
                print STDERR "Deleted cross wishlist file on ONA $cross_wihlist_ona_id, in order to replace the file.\n";
            }
            else {
                print STDERR "ERROR: Did not delete cross wishlist file on ONA $cross_wihlist_ona_id, in order to replace the file.\n";
                #print STDERR Dumper $delete_resp;
            }
        }
        if ($germplasm_info_ona_id){
            my $delete_resp = $ua->delete(
                $server_endpoint."/$germplasm_info_ona_id"
            );
            if ($delete_resp->is_success) {
                print STDERR "Deleted germplasm info file on ONA $germplasm_info_ona_id, in order to replace the file.\n";
            }
            else {
                print STDERR "ERROR: Did not delete cross wishlist file $germplasm_info_ona_id, in order to replace the file.\n";
                #print STDERR Dumper $delete_resp;
            }
        }

        my $resp = $ua->post(
            $server_endpoint,
            Content_Type => 'form-data',
            Content => [
                data_file => [ $uploaded_file, $uploaded_file, Content_Type => 'text/plain', ],
                "xform"=>$ona_form_id,
                "data_type"=>"media",
                "data_value"=>$uploaded_file
            ]
        );

        if ($resp->is_success) {
            my $message = $resp->decoded_content;
            my $message_hash = decode_json $message;
            #print STDERR Dumper $message_hash;
            if ($message_hash->{id}){
                $c->stash->{rest}->{success} .= 'The cross wishlist is now ready to be used on the ODK tablet application. Files uploaded to ONA here: <a href="'.$message_hash->{media_url}.'">'.$message_hash->{data_value}.'</a> with <a href="'.$message_hash->{url}.'">metadata entry</a>.';
            } else {
                $c->stash->{rest}->{error} = 'The cross wishlist was not posted to ONA. Please try again.';
            }
        } else {
            #print STDERR Dumper $resp;
            $c->stash->{rest}->{error} = "There was an error submitting cross wishlist to ONA. Please try again.";
        }

        my $germplasm_info_resp = $ua->post(
            $server_endpoint,
            Content_Type => 'form-data',
            Content => [
                data_file => [ $germplasm_info_uploaded_file, $germplasm_info_uploaded_file, Content_Type => 'text/plain', ],
                "xform"=>$ona_form_id,
                "data_type"=>"media",
                "data_value"=>$germplasm_info_uploaded_file
            ]
        );

        if ($germplasm_info_resp->is_success) {
            my $message = $germplasm_info_resp->decoded_content;
            my $message_hash = decode_json $message;
            #print STDERR Dumper $message_hash;
            if ($message_hash->{id}){
                $c->stash->{rest}->{success} .= 'The germplasm info file is now ready to be used on the ODK tablet application. Files uploaded to ONA here: <a href="'.$message_hash->{media_url}.'">'.$message_hash->{data_value}.'</a> with <a href="'.$message_hash->{url}.'">metadata entry</a>.';
            } else {
                $c->stash->{rest}->{error} .= 'The germplasm info file was not posted to ONA. Please try again.';
            }
        } else {
            #print STDERR Dumper $germplasm_info_resp;
            $c->stash->{rest}->{error} .= "There was an error submitting germplasm info file to ONA. Please try again.";
        }
    }

}

sub list_cross_wishlists : Path('/ajax/cross/list_cross_wishlists') : ActionClass('REST') { }

sub list_cross_wishlists_GET : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $q = "SELECT file_table.id, file_table.file_name, mdf.dirname, mdf.filetype, mdf.comment, mdmd.create_date, mdmd.create_person_id, p.first_name, p.last_name
        FROM
        (SELECT mf.file_id AS id,mf.basename AS file_name FROM metadata.md_files AS mf WHERE file_id IN (SELECT MAX(file_id) AS file_id FROM metadata.md_files
        WHERE filetype ilike 'cross_wishlist_%' group by basename))
        AS file_table
        JOIN metadata.md_files as mdf ON (file_table.id = mdf.file_id)
        JOIN metadata.md_metadata AS mdmd ON (mdf.metadata_id = mdmd.metadata_id)
        JOIN sgn_people.sp_person as p ON(p.sp_person_id = mdmd.create_person_id);";

    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @files;
    while(my ($file_id, $basename, $dirname, $filetype, $comment, $create_date, $sp_person_id, $first_name, $last_name) = $h->fetchrow_array()){
        push @files, [$file_id, $basename, $dirname, $filetype, $comment, $create_date, $sp_person_id, $first_name, $last_name];
    }
    #print STDERR Dumper \@files;
    $c->stash->{rest} = {"success" => 1, "files"=>\@files};
}


sub create_wishlist_by_uploading : Path('/ajax/cross/create_wishlist_by_uploading') : ActionClass('REST') { }

sub create_wishlist_by_uploading_POST : Args(0) {

    my ($self, $c) = @_;

    if (!$c->user){
        $c->stash->{rest}->{error} = "You must be logged in to actually create a cross wishlist.";
        $c->detach();
    }

    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my $female_trial_id = $c->req->param('cross_wishlist_upload_female_trial_id');
    my $male_trial_id = $c->req->param('cross_wishlist_upload_male_trial_id');

#    print STDERR "FEMALE TRIAL ID =".Dumper($female_trial_id)."\n";
#    print STDERR "MALE TRIAL ID =".Dumper($male_trial_id)."\n";

    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('wishlist_file');
    my $upload_type = 'WishlistExcel';
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "wishlist_upload";
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
            $c->stash->{rest} = {error=>'You must be logged in to upload wishlist!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload wishlist!'};
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

    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="wishlist upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";
    #parse uploaded file with appropriate plugin
    $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin($upload_type);
    $parsed_data = $parser->parse();
    #print STDERR "Dumper of parsed data:\t" . Dumper($parsed_data) . "\n";

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

    my $wishlist_ref = $parsed_data->{'wishlist'};
    my @wishlist = @$wishlist_ref;
#    print STDERR "WISHLIST ARRAY =".Dumper($parsed_data)."\n";
    my %selected_cross_hash;
    my %selected_females;
    my %selected_males;
    foreach (@wishlist){
        push @{$selected_cross_hash{$_->{female_id}}->{$_->{priority}}}, $_->{male_id};
        $selected_females{$_->{female_id}}++;
        $selected_males{$_->{male_id}}++;
    }
#    print STDERR "CROSS HASH =".Dumper(\%selected_cross_hash)."\n";

    my %ordered_wishlist;
    foreach my $female_id (keys %selected_cross_hash){
        foreach my $priority (sort keys %{$selected_cross_hash{$female_id}}){
            my $males = $selected_cross_hash{$female_id}->{$priority};
            foreach my $male_id (@$males){
                push @{$ordered_wishlist{$female_id}}, $male_id;
            }
        }
    }
#    print STDERR "ORDERED WISHLIST =".Dumper(\%ordered_wishlist)."\n";

    my $female_trial_layout = CXGN::Trial::TrialLayout->new({ schema => $chado_schema, trial_id => $female_trial_id, experiment_type=>'field_layout' });
    my $design_layout = $female_trial_layout->get_design();
#    print STDERR "LAYOUT =".Dumper($design_layout)."\n";

    my @selected_plot_ids;
    my %female_accessions_in_trial;
    my @missing_accessions_in_trial;

    foreach my $hash_ref (values %$design_layout) {
        my %selected_plot_hash = ();
        my %plot_info_hash = %$hash_ref;
        my $accession_name = $plot_info_hash{'accession_name'};
        foreach my $female_accession_name (sort keys %ordered_wishlist) {
            if ($accession_name eq $female_accession_name) {
                my $female_plot_id = $plot_info_hash{'plot_id'};
                $selected_plot_hash{'female_plot_id'} = $female_plot_id;
                $selected_plot_hash{'cross_female_accession_name'} = $female_accession_name;
                my $males = $ordered_wishlist{$female_accession_name};
                my $males_string = join ',', @$males;
                $selected_plot_hash{'male_genotypes_string'} = $males_string;
                push @selected_plot_ids, \%selected_plot_hash;
                $female_accessions_in_trial{$female_accession_name}++;

            }
        }
    }
    #    print STDERR "SELECTED PLOT IDS =".Dumper(\@selected_plot_ids)."\n";

    my @wishlist_female_accessions = keys %ordered_wishlist;
    my @accessions_not_in_trial = grep {not $female_accessions_in_trial{$_}} @wishlist_female_accessions;
#    print STDERR "ACCESSIONS NOT IN TRIAL =".Dumper(\@accessions_not_in_trial)."\n";

    if (scalar(@accessions_not_in_trial) > 0){
        my $trial_error = "The following accessions are not in the provided female trial: ".join(',',@accessions_not_in_trial);
        $c->stash->{rest} = {error_string => $trial_error };
        $c->detach();
    } else {
        $c->stash->{rest} = { selected_plot_ids => \@selected_plot_ids, cross_combinations => \@wishlist };
    }

}


###
1;#
###
