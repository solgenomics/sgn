
=head1 NAME

SGN::Controller::AJAX::DroneRover::DroneRover - a REST controller class to provide the
functions for uploading and analyzing drone rover point clouds

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneRover::DroneRover;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use CXGN::UploadFile;
use SGN::Image;
use URI::Encode qw(uri_encode uri_decode);
use File::Basename qw | basename dirname|;
use File::Slurp qw(write_file);
use File::Temp 'tempfile';
use File::Spec::Functions;
use File::Copy;
use CXGN::Calendar;
use Image::Size;
use Text::CSV;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Onto;
use Time::Piece;
use POSIX;
use Math::Round;
use Parallel::ForkManager;
use List::MoreUtils qw(first_index);
use List::Util qw(sum);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use CXGN::Location;
use CXGN::Trial;
use CXGN::Trial::TrialLayoutDownload;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub drone_rover_get_vehicles : Path('/api/drone_rover/rover_vehicles') : ActionClass('REST') { }
sub drone_rover_get_vehicles_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $private_company_id = $c->req->param('private_company_id');
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'user', $private_company_id, 'user_access');

    my $private_companies_sql = '';
    if ($private_company_id) {
        $private_companies_sql = $private_company_id;
    }
    else {
        my $private_companies = CXGN::PrivateCompany->new( { schema => $bcs_schema } );
        my ($private_companies_array, $private_companies_ids, $allowed_private_company_ids_hash, $allowed_private_company_access_hash, $private_company_access_is_private_hash) = $private_companies->get_users_private_companies($user_id, 0);
        $private_companies_sql = join ',', @$private_companies_ids;
    }

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'imaging_event_vehicle_rover', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stock.description, stock.private_company_id, company.name, stockprop.value
        FROM stock
        JOIN sgn_people.private_company AS company ON(stock.private_company_id=company.private_company_id)
        JOIN stockprop ON(stock.stock_id=stockprop.stock_id AND stockprop.type_id=$imaging_vehicle_properties_cvterm_id)
        WHERE stock.type_id=$imaging_vehicle_cvterm_id AND stock.private_company_id IN($private_companies_sql);";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @vehicles;
    while (my ($stock_id, $name, $description, $private_company_id, $private_company_name, $prop) = $h->fetchrow_array()) {
        my $prop_hash = decode_json $prop;
        my @batt_info;
        foreach (sort keys %{$prop_hash->{batteries}}) {
            my $p = $prop_hash->{batteries}->{$_};
            push @batt_info, "$_: Usage = ".$p->{usage}." Obsolete = ".$p->{obsolete};
        }
        my $batt_info_string = join '<br/>', @batt_info;
        my $private_company = "<a href='/company/$private_company_id'>$private_company_name</a>";
        push @vehicles, [$name, $description, $private_company, $batt_info_string]
    }
    $h = undef;

    $c->stash->{rest} = { data => \@vehicles };
}

sub drone_rover_get_collection : Path('/api/drone_rover/get_collection') : ActionClass('REST') { }
sub drone_rover_get_collection_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $collection_number = $c->req->param('collection_number');
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'user', undef, undef);

    my $earthsense_collections_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'earthsense_ground_rover_collections_archived', 'project_property')->cvterm_id();

    my $q = "SELECT projectprop.value
        FROM projectprop
        WHERE projectprop.type_id=$earthsense_collections_cvterm_id AND projectprop.project_id=?;";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);
    my ($prop_json) = $h->fetchrow_array();
    $h = undef;
    my $collections = decode_json $prop_json;
    my $collection = $collections->{$collection_number} || {};

    if (exists($collection->{plot_polygons})) {
        foreach my $stock_id (sort keys %{$collection->{plot_polygons}} ) {
            my $file_id = $collection->{plot_polygons}->{$stock_id}->{file_id};
            my $stock = $bcs_schema->resultset("Stock::Stock")->find({stock_id => $stock_id});
            my $stock_name = $stock->uniquename;

            push @{$collection->{plot_polygons_names}}, [$stock_name, $file_id];
        }
    }

    $c->stash->{rest} = $collection;
}

sub drone_rover_get_point_cloud : Path('/api/drone_rover/get_point_cloud') : ActionClass('REST') { }
sub drone_rover_get_point_cloud_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $point_cloud_file_id = $c->req->param('point_cloud_file_id');
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'user', 0, 0);

    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id=>$point_cloud_file_id});
    my $point_cloud_file = $file_row->dirname."/".$file_row->basename;

    my @points;
    open(my $fh, "<", $point_cloud_file) || die "Can't open file ".$point_cloud_file;
        while ( my $row = <$fh> ){
            my ($x, $y, $z) = split ' ', $row;
            push @points, {
                x => $x,
                y => $y,
                z => $z
            };
        }
    close($fh);

    $c->stash->{rest} = { success => 1, points => \@points };
}

sub drone_rover_plot_polygons_test_pheno_range_correlations : Path('/api/drone_rover/plot_polygons_test_pheno_range_correlations') : ActionClass('REST') { }
sub drone_rover_plot_polygons_test_pheno_range_correlations_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    my $trait_ids = decode_json $c->req->param('trait_ids');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $obsunit_level = $c->req->param('observation_unit_level');
    my $correlation_type = $c->req->param('correlation_type');
    my $range_min = $c->req->param('range_min');
    my $range_max = $c->req->param('range_max');
    my $column_min = $c->req->param('column_min');
    my $column_max = $c->req->param('column_max');
    my $range_start = $c->req->param('range_start');
    my $range_stop = $c->req->param('range_stop');
    my $column_start = $c->req->param('column_start');
    my $column_stop = $c->req->param('column_stop');
    my $columns_question = $c->req->param('columns_question');
    my $additional_pheno = $c->req->param('additional_pheno') ? decode_json $c->req->param('additional_pheno') : {};
    my $additional_traits = $c->req->param('additional_traits') ? decode_json $c->req->param('additional_traits') : {};

    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'submitter', 0, 0);

    if (scalar(@$trait_ids) > 1) {
        $c->stash->{rest} = { error => "Please only select one trait for the testing of correlations!"};
        return;
    }
    my $selected_trait_id = $trait_ids->[0];

    my $column_min_from_1 = $column_min - ($column_min - 1);
    my $column_max_from_1 = $column_max - ($column_min - 1);
    my $range_min_from_1 = $range_min - ($range_min - 1);
    my $range_max_from_1 = $range_max - ($range_min - 1);

    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $bcs_schema, trial_id => $field_trial_id, experiment_type => 'field_layout'});
    my $design = $trial_layout->get_design();
    # print STDERR Dumper $design;

    my $collection_across = $columns_question;
    my $collection_along = $collection_across eq 'col_number' ? 'row_number' : 'col_number';

    my %row_col_hash;
    my %row_col_hash_lookup;
    my %collection_along_vals;
    my %collection_across_vals;
    foreach my $p (values %$design) {
        my $plot_name = $p->{plot_name};
        my $plot_id = $p->{plot_id};
        my $collection_along_val = $p->{$collection_along};
        my $collection_across_val = $p->{$collection_across};

        $row_col_hash{$collection_along_val}->{$collection_across_val} = {
            plot_name => $plot_name,
            plot_id => $plot_id
        };

        $row_col_hash_lookup{$plot_name} = {
            $collection_along => $collection_along_val,
            $collection_across => $collection_across_val
        };

        $collection_along_vals{$collection_along_val}++;
        $collection_across_vals{$collection_across_val}++;
    }
    my @collection_along_vals_sorted = sort {$a <=> $b} keys %collection_along_vals;
    my @collection_along_vals_sorted_rev = sort {$b <=> $a} keys %collection_along_vals;
    my @collection_across_vals_sorted = sort {$a <=> $b} keys %collection_across_vals;
    my @collection_across_vals_sorted_rev = sort {$b <=> $a} keys %collection_across_vals;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$bcs_schema,
            data_level=>$obsunit_level,
            trait_list=>$trait_ids,
            trial_list=>[$field_trial_id],
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
        return;
    }

    my %phenotype_data;
    my %phenotype_data_htp;
    my %trait_hash;
    my %seen_obsunit_ids;
    my %seen_along_vals;
    my %seen_across_vals;
    foreach my $obs_unit (@$data){
        my $obsunit_id = $obs_unit->{observationunit_uniquename};
        my $obsunit_along_val = $obs_unit->{"obsunit_".$collection_along};
        my $obsunit_across_val = $obs_unit->{"obsunit_".$collection_across};
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            $phenotype_data{$obsunit_along_val}->{$obsunit_across_val}->{$_->{trait_id}} = $_->{value};
            $trait_hash{$_->{trait_id}} = $_->{trait_name};
        }

        while (my ($trait_id_additional, $trait_name_additional) = each %$additional_traits) {
            my $ph = $additional_pheno->{$obsunit_id}->{$trait_name_additional};
            if ($ph) {
                my $additional_value = $ph->[0];

                $phenotype_data_htp{$obsunit_across_val}->{$trait_id_additional} = $additional_value;
                $trait_hash{$trait_id_additional} = $trait_name_additional;
                $seen_along_vals{$obsunit_along_val}++;
                $seen_across_vals{$obsunit_across_val}++;
            }
        }

        $seen_obsunit_ids{$obsunit_id}++;
    }
    my @sorted_obs_units = sort keys %seen_obsunit_ids;
    my @seen_along_vals_sorted = sort {$a <=> $b} keys %seen_along_vals;
    my @seen_across_vals_sorted = sort {$a <=> $b} keys %seen_across_vals;
    my @seen_across_vals_sorted_reverse = sort {$b <=> $a} keys %seen_across_vals;
    print STDERR Dumper \@seen_along_vals_sorted;

    while (my ($trait_id_additional, $trait_name_additional) = each %$additional_traits) {
        push @$trait_ids, $trait_id_additional;
    }

    my $header_string = join ',', @$trait_ids;

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_trial_correlation";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;

    my @result;
    my $is_first_result = 1;
    foreach my $collection_along_val (@collection_along_vals_sorted) {

        my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
        my ($stats_out_tempfile_fh, $stats_out_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

        open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
            print $F $header_string."\n";

            foreach my $seen_across_val (@seen_across_vals_sorted) {
                my @line = ();
                my $pheno_vals = $phenotype_data{$collection_along_val}->{$seen_across_val};
                my $pheno_vals_htp = $phenotype_data_htp{$seen_across_val};

                foreach my $t (@$trait_ids) {
                    if (exists($pheno_vals->{$t})) {
                        my $val = $pheno_vals->{$t};
                        push @line, $val;
                    }
                    if (exists($pheno_vals_htp->{$t})) {
                        my $val = $pheno_vals_htp->{$t};
                        push @line, $val;
                    }
                }
                my $line_string = join ',', @line;
                print $F "$line_string\n";
            }
        close($F);

        my $cmd = 'R -e "library(data.table);
        mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
        res <- cor(mat, method=\''.$correlation_type.'\', use = \'complete.obs\')
        res_rounded <- round(res, 2)
        write.table(res_rounded, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $csv = Text::CSV->new({ sep_char => "\t" });
        open(my $fh, '<', $stats_out_tempfile) or die "Could not open file '$stats_out_tempfile' $!";
            print STDERR "Opened $stats_out_tempfile\n";
            my $header = <$fh>;
            my @header_cols;
            if ($csv->parse($header)) {
                @header_cols = $csv->fields();
            }

            my @header_trait_names = ("Trait");
            foreach (@header_cols) {
                push @header_trait_names, $trait_hash{$_};
            }
            if ($is_first_result) {
                push @result, \@header_trait_names;
            }

            my $row = <$fh>;
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }

            my $trait_id = shift @columns;
            my @line = ($trait_hash{$trait_id}."_Tested $collection_along_val", @columns);
            push @result, \@line;
        close($fh);

        $is_first_result = 0;
    }

    foreach my $collection_along_val (@collection_along_vals_sorted) {

        my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
        my ($stats_out_tempfile_fh, $stats_out_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

        open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
            print $F $header_string."\n";

            foreach my $seen_across_val (@seen_across_vals_sorted_reverse) {
                my @line = ();
                my $pheno_vals = $phenotype_data{$collection_along_val}->{$seen_across_val};
                my $pheno_vals_htp = $phenotype_data_htp{$seen_across_val};

                foreach my $t (@$trait_ids) {
                    if (exists($pheno_vals->{$t})) {
                        my $val = $pheno_vals->{$t};
                        push @line, $val;
                    }
                    if (exists($pheno_vals_htp->{$t})) {
                        my $val = $pheno_vals_htp->{$t};
                        push @line, $val;
                    }
                }
                my $line_string = join ',', @line;
                print $F "$line_string\n";
            }
        close($F);

        my $cmd = 'R -e "library(data.table);
        mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
        res <- cor(mat, method=\''.$correlation_type.'\', use = \'complete.obs\')
        res_rounded <- round(res, 2)
        write.table(res_rounded, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $csv = Text::CSV->new({ sep_char => "\t" });
        open(my $fh, '<', $stats_out_tempfile) or die "Could not open file '$stats_out_tempfile' $!";
            print STDERR "Opened $stats_out_tempfile\n";
            my $header = <$fh>;
            my @header_cols;
            if ($csv->parse($header)) {
                @header_cols = $csv->fields();
            }

            my $row = <$fh>;
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }

            my $trait_id = shift @columns;
            my @line = ($trait_hash{$trait_id}."_Tested Reverse $collection_along_val", @columns);
            push @result, \@line;
        close($fh);
    }

    $c->stash->{rest} = {
        success => 1,
        result => \@result
    };
}

sub drone_rover_plot_polygons_process_apply : Path('/api/drone_rover/plot_polygons_process_apply') : ActionClass('REST') { }
sub drone_rover_plot_polygons_process_apply_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_collection_number = $c->req->param('drone_run_collection_number');
    my $drone_run_collection_project_id = $c->req->param('drone_run_collection_project_id');
    my $phenotype_types = decode_json $c->req->param('phenotype_types');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $polygon_template_metadata = decode_json $c->req->param('polygon_template_metadata');
    my $polygons_to_plot_names = decode_json $c->req->param('polygons_to_plot_names');
    my $private_company_id = $c->req->param('company_id');
    my $private_company_is_private = $c->req->param('is_private');
    my $is_test = $c->req->param('is_test');
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'submitter', $private_company_id, 'submitter_access');

    my $earthsense_collections_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'earthsense_ground_rover_collections_archived', 'project_property')->cvterm_id();
    my $project_md_file_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'rover_collection_filtered_plot_point_cloud', 'project_md_file')->cvterm_id();
    my $stock_md_file_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'stock_filtered_plot_point_cloud', 'stock_md_file')->cvterm_id();

    my %stock_ids_all;
    my %stock_info;
    foreach my $stock_name (keys %$polygons_to_plot_names) {
        my $stock = $bcs_schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids_all{$stock_name} = $stock->stock_id;
        $stock_info{$stock->stock_id}->{stock_uniquename} = $stock_name;
    }

    my $drone_run_time = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_get_weeks_drone_run_after_planting($bcs_schema, $drone_run_project_id);
    my $time_cvterm_id = $drone_run_time->{time_ontology_day_cvterm_id};

    my $project = CXGN::Trial->new({ bcs_schema => $bcs_schema, trial_id => $drone_run_project_id });
    my ($field_trial_drone_run_project_ids_in_same_orthophoto, $field_trial_drone_run_project_names_in_same_orthophoto, $field_trial_ids_in_same_orthophoto, $field_trial_names_in_same_orthophoto,  $field_trial_drone_run_projects_in_same_orthophoto, $field_trial_drone_run_band_projects_in_same_orthophoto, $field_trial_drone_run_band_project_ids_in_same_orthophoto_project_type_hash, $related_rover_event_collections, $related_rover_event_collections_hash) = $project->get_field_trial_drone_run_projects_in_same_orthophoto();
    print STDERR Dumper $related_rover_event_collections;
    print STDERR Dumper $related_rover_event_collections_hash;

    my @all_field_trial_ids = ($field_trial_id);
    push @all_field_trial_ids, @$field_trial_ids_in_same_orthophoto;

    my %all_field_trial_layouts;
    foreach my $trial_id (@all_field_trial_ids) {
        my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $bcs_schema, trial_id => $trial_id, experiment_type => 'field_layout'});
        my $design = $trial_layout->get_design();
        foreach my $p (values %$design) {
            $all_field_trial_layouts{$p->{plot_id}} = $related_rover_event_collections_hash->{$trial_id}->{$drone_run_collection_number};
        }
    }

    my $image_width = $polygon_template_metadata->{image_width};
    my $image_height = $polygon_template_metadata->{image_height};

    my $q = "SELECT value FROM projectprop WHERE project_id = ? AND type_id=$earthsense_collections_cvterm_id;";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_collection_project_id);
    my ($prop_json) = $h->fetchrow_array();
    my $earthsense_collection = decode_json $prop_json;
    $h = undef;
    # print STDERR Dumper $earthsense_collection;
    my $point_cloud_file = $earthsense_collection->{processing}->{point_cloud_side_filtered_output};

    my $dir = $c->tempfiles_subdir('/drone_rover_plot_polygons');
    my $bulk_input_temp_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_rover_plot_polygons/bulkinputXXXX');
    my $phenotype_output_temp_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_rover_plot_polygons/bulkinputXXXX');
    $phenotype_output_temp_file .= '.csv';

    my @plot_polygons_cut;

    open(my $F, ">", $bulk_input_temp_file) || die "Can't open file ".$bulk_input_temp_file;
    while (my($plot_name, $polygon) = each %$polygons_to_plot_names) {
        my $stock_id = $stock_ids_all{$plot_name};

        my $x1_ratio = $polygon->[0]->[0]/$image_width;
        my $y1_ratio = $polygon->[0]->[1]/$image_height;
        my $x2_ratio = $polygon->[1]->[0]/$image_width;
        my $y2_ratio = $polygon->[3]->[1]/$image_height;

        my $plot_polygons_temp_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_rover_plot_polygons/plotpointcloudXXXX');
        $plot_polygons_temp_file .= '.xyz';

        print $F "$stock_id\t$plot_polygons_temp_file\t$x1_ratio\t$y1_ratio\t$x2_ratio\t$y2_ratio\n";

        push @plot_polygons_cut, {
            stock_id => $stock_id,
            temp_file => $plot_polygons_temp_file,
            polygon_ratios => {
                x1 => $x1_ratio,
                x2 => $x2_ratio,
                y1 => $y1_ratio,
                y2 => $y2_ratio
            }
        };
    }
    close($F);

    my $lidar_point_cloud_plot_polygons_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/PointCloudProcess/PointCloudPlotPolygons.py --pointcloud_xyz_file $point_cloud_file --plot_polygons_ratio_file $bulk_input_temp_file --phenotype_ouput_file $phenotype_output_temp_file ";
    print STDERR $lidar_point_cloud_plot_polygons_cmd."\n";
    my $lidar_point_cloud_plot_polygons_status = system($lidar_point_cloud_plot_polygons_cmd);

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $archive_file_type = 'point_cloud_statistics_phenotypes';

    my $archived_pheno_filename_with_path;
    my %saved_point_cloud_files;
    if (!$is_test) {
        my $pheno_temp_filename = basename($phenotype_output_temp_file);
        my $uploader = CXGN::UploadFile->new({
            tempfile => $phenotype_output_temp_file,
            subdirectory => $archive_file_type,
            archive_path => $c->config->{archive_path},
            archive_filename => $pheno_temp_filename,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        $archived_pheno_filename_with_path = $uploader->archive();
        my $archive_pheno_md5 = $uploader->get_md5($archived_pheno_filename_with_path);
        if (!$archived_pheno_filename_with_path) {
            $c->stash->{message} = "Could not save file $pheno_temp_filename in archive.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        print STDERR "Archived Point Cloud Pheno File: $archived_pheno_filename_with_path\n";

        my $q_project_md_file = "INSERT INTO phenome.project_md_file (project_id, file_id, type_id) VALUES (?,?,?);";
        my $h_project_md_file = $bcs_schema->storage->dbh()->prepare($q_project_md_file);

        my $q_stock_md_file = "INSERT INTO phenome.stock_md_file (stock_id, file_id, type_id) VALUES (?,?,?);";
        my $h_stock_md_file = $bcs_schema->storage->dbh()->prepare($q_stock_md_file);

        my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});

        print STDERR Dumper \%all_field_trial_layouts;
        foreach (@plot_polygons_cut) {
            my $stock_id = $_->{stock_id};
            my $temp_file = $_->{temp_file};
            my $polygon_ratios = $_->{polygon_ratios};
            my $drone_run_project_id = $all_field_trial_layouts{$stock_id}->{drone_run_project_id};
            my $project_collection_id = $all_field_trial_layouts{$stock_id}->{drone_run_collection_project_id};
            my $collection_number = $all_field_trial_layouts{$stock_id}->{drone_run_collection_number};

            my $temp_filename = basename($temp_file);
            my $uploader = CXGN::UploadFile->new({
                tempfile => $temp_file,
                subdirectory => "earthsense_rover_collections_plot_polygons",
                second_subdirectory => "$drone_run_collection_project_id",
                archive_path => $c->config->{archive_path},
                archive_filename => $temp_filename,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = {error=>'Could not archive '.$temp_filename.'!'};
                $c->detach();
            }

            my $file_row = $metadata_schema->resultset("MdFiles")->create({
                basename => basename($archived_filename_with_path),
                dirname => dirname($archived_filename_with_path),
                filetype => "earthsense_rover_collections_plot_polygon_point_clouds",
                md5checksum => $md5->hexdigest(),
                metadata_id => $md_row->metadata_id()
            });
            my $plot_polygon_file_id = $file_row->file_id();

            $h_project_md_file->execute($project_collection_id, $plot_polygon_file_id, $project_md_file_cvterm_id);
            $h_stock_md_file->execute($stock_id, $plot_polygon_file_id, $stock_md_file_cvterm_id);

            $saved_point_cloud_files{$drone_run_project_id}->{$project_collection_id}->{$collection_number}->{$stock_id} = {
                file_id => $plot_polygon_file_id,
                polygon_ratios => $polygon_ratios
            };
            $stock_info{$stock_id}->{file_id} = $plot_polygon_file_id;
        }
        print STDERR Dumper \%saved_point_cloud_files;

        $h_project_md_file = undef;
        $h_stock_md_file = undef;
    }

    my $point_cloud_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'EarthSense Filtered Point Cloud|ISOL:0010001')->cvterm_id;

    my $average_height_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average Point Height|G2F:0010001')->cvterm_id;
    my $average_length_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average Point Length|G2F:0010002')->cvterm_id;
    my $average_span_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average Point Span|G2F:0010003')->cvterm_id;
    my $average_3d_volume_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average 3D Volume|G2F:0010004')->cvterm_id;
    my $average_height_density_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average Height Density|G2F:0010005')->cvterm_id;
    my $average_length_density_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average Length Density|G2F:0010006')->cvterm_id;
    my $average_span_density_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average Span Density|G2F:0010007')->cvterm_id;
    my $average_3d_density_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Average 3D Density|G2F:0010008')->cvterm_id;
    my $number_of_points_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Number of Points|G2F:0010009')->cvterm_id;
    my $max_height_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Maximum Point Height Value|G2F:0010010')->cvterm_id;
    my $max_length_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Maximum Point Length Value|G2F:0010011')->cvterm_id;
    my $max_span_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Maximum Point Span Value|G2F:0010012')->cvterm_id;
    my $min_height_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Minimum Point Height Value|G2F:0010013')->cvterm_id;
    my $min_length_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Minimum Point Length Value|G2F:0010014')->cvterm_id;
    my $min_span_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($bcs_schema, 'Minimum Point Span Value|G2F:0010015')->cvterm_id;

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($bcs_schema, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
        object => [],
        attribute => [$point_cloud_cvterm_id],
        method => [],
        unit => [],
        trait => [$average_height_cvterm_id, $average_length_cvterm_id, $average_span_cvterm_id, $average_3d_volume_cvterm_id, $average_height_density_cvterm_id, $average_length_density_cvterm_id, $average_span_density_cvterm_id, $average_3d_density_cvterm_id, $number_of_points_cvterm_id, $max_height_cvterm_id, $max_length_cvterm_id, $max_span_cvterm_id, $min_height_cvterm_id, $min_length_cvterm_id, $min_span_cvterm_id],
        tod => [],
        toy => [$time_cvterm_id],
        gen => [],
    });
    my $existing_traits = $traits->{existing_traits};
    my $new_traits = $traits->{new_traits};
    #print STDERR Dumper $new_traits;
    #print STDERR Dumper $existing_traits;
    my %new_trait_names;
    foreach (@$new_traits) {
        my $components = $_->[0];
        $new_trait_names{$_->[1]} = join ',', @$components;
    }

    my $onto = CXGN::Onto->new( { schema => $bcs_schema } );
    my $new_terms = $onto->store_composed_term(\%new_trait_names);

    my $average_height_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_height_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_length_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_length_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_span_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_span_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_3d_volume_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_3d_volume_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_height_density_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_height_density_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_length_density_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_length_density_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_span_density_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_span_density_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $average_3d_density_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$average_3d_density_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $num_points_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$number_of_points_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $max_height_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$max_height_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $max_length_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$max_length_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $max_span_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$max_span_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $min_height_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$min_height_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $min_length_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$min_length_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);
    my $min_span_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($bcs_schema, [$min_span_cvterm_id, $point_cloud_cvterm_id, $time_cvterm_id]);

    my $average_height_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_height_composed_cvterm_id, 'extended');
    my $average_length_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_length_composed_cvterm_id, 'extended');
    my $average_span_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_span_composed_cvterm_id, 'extended');
    my $average_3d_volume_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_3d_volume_composed_cvterm_id, 'extended');
    my $average_height_density_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_height_density_composed_cvterm_id, 'extended');
    my $average_length_density_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_length_density_composed_cvterm_id, 'extended');
    my $average_span_density_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_span_density_composed_cvterm_id, 'extended');
    my $average_3d_density_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $average_3d_density_composed_cvterm_id, 'extended');
    my $num_points_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $num_points_composed_cvterm_id, 'extended');
    my $max_height_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $max_height_composed_cvterm_id, 'extended');
    my $max_length_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $max_length_composed_cvterm_id, 'extended');
    my $max_span_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $max_span_composed_cvterm_id, 'extended');
    my $min_height_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $min_height_composed_cvterm_id, 'extended');
    my $min_length_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $min_length_composed_cvterm_id, 'extended');
    my $min_span_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($bcs_schema, $min_span_composed_cvterm_id, 'extended');

    my %trait_id_map = (
        $average_height_composed_cvterm_id => $average_height_composed_trait_name,
        $average_length_composed_cvterm_id => $average_length_composed_trait_name,
        $average_span_composed_cvterm_id => $average_span_composed_trait_name,
        $average_3d_volume_composed_cvterm_id => $average_3d_volume_composed_trait_name,
        $average_height_density_composed_cvterm_id => $average_height_density_composed_trait_name,
        $average_length_density_composed_cvterm_id => $average_length_density_composed_trait_name,
        $average_span_density_composed_cvterm_id => $average_span_density_composed_trait_name,
        $average_3d_density_composed_cvterm_id => $average_3d_density_composed_trait_name,
        $num_points_composed_cvterm_id => $num_points_composed_trait_name,
        $max_height_composed_cvterm_id => $max_height_composed_trait_name,
        $max_length_composed_cvterm_id => $max_length_composed_trait_name,
        $max_span_composed_cvterm_id => $max_span_composed_trait_name,
        $min_height_composed_cvterm_id => $min_height_composed_trait_name,
        $min_length_composed_cvterm_id => $min_length_composed_trait_name,
        $min_span_composed_cvterm_id => $min_span_composed_trait_name
    );

    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $phenotype_output_temp_file) or die "Could not open file '$phenotype_output_temp_file' $!";

        print STDERR "Opened $phenotype_output_temp_file\n";
        my $header = <$fh>;
        my @header_cols;
        if ($csv->parse($header)) {
            @header_cols = $csv->fields();
        }

        my $line = 0;
        my %point_cloud_stat_phenotype_data;
        my %plots_seen;
        if ($header_cols[0] ne 'stock_id' ||
            $header_cols[1] ne 'num_points' ||
            $header_cols[2] ne 'length_max' ||
            $header_cols[3] ne 'height_max' ||
            $header_cols[4] ne 'span_max' ||
            $header_cols[5] ne 'length_min' ||
            $header_cols[6] ne 'height_min' ||
            $header_cols[7] ne 'span_min' ||
            $header_cols[8] ne 'length_average' ||
            $header_cols[9] ne 'height_average' ||
            $header_cols[10] ne 'span_average' ||
            $header_cols[11] ne 'average_volume' ||
            $header_cols[12] ne 'length_density' ||
            $header_cols[13] ne 'height_density' ||
            $header_cols[14] ne 'span_density' ||
            $header_cols[15] ne 'average_density'
        ) {
            $c->stash->{rest} = { error => "Pheno results must have header: 'stock_id','num_points','length_max','height_max','span_max','length_min','height_min','span_min','length_average','height_average','span_average','average_volume','length_density','height_density','span_density','average_density'" };
            return;
        }

        my @traits_seen = (
            $average_height_composed_trait_name,
            $average_length_composed_trait_name,
            $average_span_composed_trait_name,
            $average_3d_volume_composed_trait_name,
            $average_height_density_composed_trait_name,
            $average_length_density_composed_trait_name,
            $average_span_density_composed_trait_name,
            $average_3d_density_composed_trait_name,
            $num_points_composed_trait_name,
            $max_height_composed_trait_name,
            $max_length_composed_trait_name,
            $max_span_composed_trait_name,
            $min_height_composed_trait_name,
            $min_length_composed_trait_name,
            $min_span_composed_trait_name
        );

        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }

            my $stock_id = $columns[0];
            my $stock_uniquename = $stock_info{$stock_id}->{stock_uniquename};
            my $file_id = $stock_info{$stock_id}->{file_id};

            #print STDERR Dumper \@columns;

            $plots_seen{$stock_uniquename} = 1;
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$num_points_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$max_length_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$max_height_composed_trait_name} = [$columns[3], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$max_span_composed_trait_name} = [$columns[4], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$min_length_composed_trait_name} = [$columns[5], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$min_height_composed_trait_name} = [$columns[6], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$min_span_composed_trait_name} = [$columns[7], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_length_composed_trait_name} = [$columns[8], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_height_composed_trait_name} = [$columns[9], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_span_composed_trait_name} = [$columns[10], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_3d_volume_composed_trait_name} = [$columns[11], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_length_density_composed_trait_name} = [$columns[12], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_height_density_composed_trait_name} = [$columns[13], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_span_density_composed_trait_name} = [$columns[14], $timestamp, $user_name, '', '', '', $file_id];
            $point_cloud_stat_phenotype_data{$stock_uniquename}->{$average_3d_density_composed_trait_name} = [$columns[15], $timestamp, $user_name, '', '', '', $file_id];

            $line++;
        }

    close $fh;
    print STDERR "Read $line lines in results file\n";

    if ($is_test) {
        $c->stash->{rest} = {
            pheno_data => \%point_cloud_stat_phenotype_data,
            traits => \%trait_id_map
        };
        $c->detach();
    }

    if ($line > 0) {
        my %phenotype_metadata = (
            'archived_file' => $archived_pheno_filename_with_path,
            'archived_file_type' => $archive_file_type,
            'operator' => $user_name,
            'date' => $timestamp
        );
        my @plot_units_seen = keys %plots_seen;

        my $store_args = {
            basepath=>$c->config->{basepath},
            dbhost=>$c->config->{dbhost},
            dbname=>$c->config->{dbname},
            dbuser=>$c->config->{dbuser},
            dbpass=>$c->config->{dbpass},
            bcs_schema=>$bcs_schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>\@plot_units_seen,
            trait_list=>\@traits_seen,
            values_hash=>\%point_cloud_stat_phenotype_data,
            has_timestamps=>1,
            metadata_hash=>\%phenotype_metadata,
            private_company_id=>$private_company_id,
            private_company_phenotype_is_private=>$private_company_is_private,
        };

        my $overwrite_phenotype_values = 1;
        if ($overwrite_phenotype_values) {
            $store_args->{overwrite_values} = $overwrite_phenotype_values;
        }
        my $ignore_new_phenotype_values = 0;
        if ($ignore_new_phenotype_values) {
            $store_args->{ignore_new_values} = $ignore_new_phenotype_values;
        }

        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
            $store_args
        );
        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
        my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});
    }

    while (my($drone_run_project_id, $o1) = each %saved_point_cloud_files) {

        my $earthsense_collections_drone_run_projectprop_rs = $bcs_schema->resultset("Project::Projectprop")->search({
            project_id => $drone_run_project_id,
            type_id => $earthsense_collections_cvterm_id
        });
        if ($earthsense_collections_drone_run_projectprop_rs->count > 1) {
            $c->stash->{rest} = {error => "There should not be more than one EarthSense collections projectprop!"};
            $c->detach();
        }
        my $earthsense_collections_drone_run_projectprop_rs_first = $earthsense_collections_drone_run_projectprop_rs->first;
        my $earthsense_collections_drone_run = decode_json $earthsense_collections_drone_run_projectprop_rs_first->value();

        while (my($drone_run_collection_project_id, $o2) = each %$o1) {
            while (my($drone_run_collection_number, $plot_polygons) = each %$o2) {

                my $earthsense_collections_projectprop_rs = $bcs_schema->resultset("Project::Projectprop")->search({
                    project_id => $drone_run_collection_project_id,
                    type_id => $earthsense_collections_cvterm_id
                });
                if ($earthsense_collections_projectprop_rs->count > 1) {
                    $c->stash->{rest} = {error => "There should not be more than one EarthSense collections projectprop!"};
                    $c->detach();
                }
                my $earthsense_collections_projectprop_rs_first = $earthsense_collections_projectprop_rs->first;
                my $earthsense_collections = decode_json $earthsense_collections_projectprop_rs_first->value();

                $earthsense_collections->{plot_polygons} = $plot_polygons;
                $earthsense_collections->{polygon_template_metadata} = $polygon_template_metadata;

                $earthsense_collections_projectprop_rs_first->value(encode_json $earthsense_collections);
                $earthsense_collections_projectprop_rs_first->update();

                $earthsense_collections_drone_run->{$drone_run_collection_number}->{plot_polygons} = $plot_polygons;
                $earthsense_collections_drone_run->{$drone_run_collection_number}->{polygon_template_metadata} = $polygon_template_metadata;
            }
        }

        $earthsense_collections_drone_run_projectprop_rs_first->value(encode_json $earthsense_collections_drone_run);
        $earthsense_collections_drone_run_projectprop_rs_first->update();
    }

    $c->stash->{rest} = \%saved_point_cloud_files;
}

sub processed_plot_point_cloud_count : Path('/api/drone_rover/processed_plot_point_cloud_count') : ActionClass('REST') { }
sub processed_plot_point_cloud_count_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 0, 0, 0);

    my $project_collection_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_collection_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_md_file_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rover_collection_filtered_plot_point_cloud', 'project_md_file')->cvterm_id();
    my $earthsense_collection_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'earthsense_collection_number', 'project_property')->cvterm_id();

    my $q = "SELECT drone_run.project_id, project_md_file.type_id, collection_number.value
        FROM project AS drone_rover_collection
        JOIN projectprop AS collection_number ON(drone_rover_collection.project_id=collection_number.project_id AND collection_number.type_id=$earthsense_collection_number_cvterm_id)
        JOIN project_relationship AS drone_rover_collection_rel ON(drone_rover_collection.project_id=drone_rover_collection_rel.subject_project_id AND drone_rover_collection_rel.type_id=$project_collection_relationship_type_id)
        JOIN project AS drone_run ON(drone_run.project_id=drone_rover_collection_rel.object_project_id)
        JOIN phenome.project_md_file AS project_md_file ON(drone_rover_collection.project_id=project_md_file.project_id)
        JOIN metadata.md_files AS md_file ON(md_file.file_id=project_md_file.file_id)
        WHERE project_md_file.type_id = $project_md_file_cvterm_id;";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my %unique_drone_runs;
    while (my ($drone_run_project_id, $project_md_file_type_id, $collection_number) = $h->fetchrow_array()) {
        $unique_drone_runs{$drone_run_project_id}->{$collection_number}++;
        $unique_drone_runs{$drone_run_project_id}->{total_plot_point_cloud_count}++;
    }
    $h = undef;
    # print STDERR Dumper \%unique_drone_runs;

    $c->stash->{rest} = { data => \%unique_drone_runs };
}

sub drone_rover_collections_field_names : Path('/api/drone_rover/collections_field_names') : ActionClass('REST') { }
sub drone_rover_collections_field_names_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'submitter', 0, 0);
    my $drone_run_project_id = $c->req->param('drone_run_id');

    my $earthsense_collections_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'earthsense_ground_rover_collections_archived', 'project_property')->cvterm_id();

    my $q = "SELECT projectprop.value
        FROM projectprop
        WHERE projectprop.type_id = $earthsense_collections_cvterm_id AND projectprop.project_id=?;";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);

    my ($collections_json) = $h->fetchrow_array();
    $h = undef;

    my $collections = decode_json $collections_json;
    # print STDERR Dumper $collections;

    my @field_names;
    foreach my $collection_number (sort keys %$collections) {
        my $o = $collections->{$collection_number};
        my $field_name = $o->{run_info}->{field}->{name};
        my $database_field_name = $o->{run_info}->{field}->{database_field_name};
        push @field_names, [$collection_number, $field_name, $database_field_name];
    }

    $c->stash->{rest} = {
        success => 1,
        data => $collections,
        field_names => \@field_names
    };
}

sub drone_rover_collections_field_names_link : Path('/api/drone_rover/collections_field_names_link') : ActionClass('REST') { }
sub drone_rover_collections_field_names_link_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover($c, 'submitter', 0, 0);
    my $drone_run_project_id = $c->req->param('drone_run_id');
    my $field_collection_names = decode_json $c->req->param('field_collection_names');

    my $earthsense_collections_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'earthsense_ground_rover_collections_archived', 'project_property')->cvterm_id();

    my $q = "SELECT projectprop.projectprop_id, projectprop.value
        FROM projectprop
        WHERE projectprop.type_id = $earthsense_collections_cvterm_id AND projectprop.project_id=?;";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);

    my ($projectprop_id, $collections_json) = $h->fetchrow_array();
    $h = undef;

    my $collections = decode_json $collections_json;
    # print STDERR Dumper $collections;

    foreach (@$field_collection_names) {
        my $collection_number = $_->[0];
        my $collection_field_name = $_->[1];
        my $field_name = $_->[2];

        if ($collection_field_name ne $collections->{$collection_number}->{run_info}->{field}->{name}) {
            $c->stash->{rest} = { error => "Collection field names are not matching! This should not happen!" };
            $c->detach();
        }

        $collections->{$collection_number}->{run_info}->{field}->{database_field_name} = $field_name;
    }
    my $collections_save = encode_json $collections;

    my $q2 = "UPDATE projectprop SET value = ? WHERE projectprop_id = ?;";
    my $h2 = $schema->storage->dbh->prepare($q2);
    $h2->execute($collections_save, $projectprop_id);
    $h2 = undef;

    $c->stash->{rest} = { success => 1 };
}

sub _check_user_login_drone_rover {
    my $c = shift;
    my $check_priv = shift;
    my $original_private_company_id = shift;
    my $user_access = shift;

    my $login_check_return = CXGN::Login::_check_user_login($c, $check_priv, $original_private_company_id, $user_access);
    if ($login_check_return->{error}) {
        $c->stash->{rest} = $login_check_return;
        $c->detach();
    }
    my ($user_id, $user_name, $user_role) = @{$login_check_return->{info}};

    return ($user_id, $user_name, $user_role);
}

1;
