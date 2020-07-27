
=head1 NAME

SGN::Controller::AJAX::DroneImagery::DroneImagery - a REST controller class to provide the
functions for uploading and analyzing drone imagery

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery::DroneImagery;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use CXGN::UploadFile;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use URI::Encode qw(uri_encode uri_decode);
use File::Basename qw | basename dirname|;
use File::Slurp qw(write_file);
use File::Temp 'tempfile';
use CXGN::Calendar;
use Image::Size;
use Text::CSV;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::FileResponse;
use CXGN::Onto;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use CXGN::Tag;
use CXGN::DroneImagery::ImageTypes;
use Time::Piece;
use POSIX;
use Math::Round;
use Parallel::ForkManager;
use CXGN::NOAANCDC;
use CXGN::BreederSearch;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BreedersToolbox::Accessions;
use CXGN::Genotype::GRM;
use CXGN::AnalysisModel::SaveModel;
use CXGN::AnalysisModel::GetModel;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub raw_drone_imagery_plot_image_count : Path('/api/drone_imagery/raw_drone_imagery_plot_image_count') : ActionClass('REST') { }
sub raw_drone_imagery_plot_image_count_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $drone_run_band_drone_run_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $project_image_type_id_hash = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my $sql = join ("," , (keys %$project_image_type_id_hash));
    my $q = "SELECT drone_run.project_id, project_image_type.name, project_image_type.cvterm_id
        FROM project AS drone_run_band
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_relationship_id)
        JOIN project AS drone_run ON(drone_run.project_id=drone_run_band_rel.object_project_id)
        JOIN phenome.project_md_image AS project_image ON(drone_run_band.project_id=project_image.project_id)
        JOIN cvterm AS project_image_type ON(project_image_type.cvterm_id=project_image.type_id)
        JOIN metadata.md_image AS image ON(image.image_id=project_image.image_id)
        WHERE project_image.type_id in ($sql) AND image.obsolete='f';";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my %unique_drone_runs;
    while (my ($drone_run_project_id, $project_image_type_name, $project_image_type_id) = $h->fetchrow_array()) {
        $unique_drone_runs{$drone_run_project_id}->{$project_image_type_id_hash->{$project_image_type_id}->{display_name}}++;
        $unique_drone_runs{$drone_run_project_id}->{total_plot_image_count}++;
    }
    #print STDERR Dumper \%unique_drone_runs;

    $c->stash->{rest} = { data => \%unique_drone_runs };
}

sub drone_imagery_analysis_query : Path('/api/drone_imagery/analysis_query') : ActionClass('REST') { }
sub drone_imagery_analysis_query_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $main_production_site = $c->config->{main_production_site_url};

    my $project_image_type_id_list_all = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @project_image_type_id_list_array = keys %$project_image_type_id_list_all;

    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];
    my $return_format = $c->req->param('format') || 'csv';
    my $trial_name_list = $c->req->param('trial_name_list');
    my $trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $project_image_type_id_list = $c->req->param('project_image_type_id_list') ? decode_json $c->req->param('project_image_type_id_list') : \@project_image_type_id_list_array;

    my %return;

    if ($trial_name_list) {
        my @trial_names = split ',', $trial_name_list;
        my $trial_search = CXGN::Trial::Search->new({
            bcs_schema=>$schema,
            trial_name_list=>\@trial_names
        });
        my ($result, $total_count) = $trial_search->search();
        foreach (@$result) {
            push @$trial_id_list, $_->{trial_id};
        }
    }

    my @drone_run_band_project_id_list;
    foreach (@$trial_id_list) {
        my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_});
        my $drone_run_bands = $trial->get_drone_run_bands_from_field_trial();
        foreach my $d (@$drone_run_bands) {
            push @drone_run_band_project_id_list, $d->[0];
        }
    }

    print STDERR Dumper \@drone_run_band_project_id_list;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>\@drone_run_band_project_id_list,
        project_image_type_id_list=>$project_image_type_id_list
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR "Query found ".scalar(@$result)." Images\n";

    my %image_data_hash;
    my %project_image_type_names;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$image_data_hash{$_->{stock_id}}->{$_->{drone_run_band_project_name}.$_->{project_image_type_name}}}, $main_production_site.$image_url;
        $project_image_type_names{$_->{drone_run_band_project_name}.$_->{project_image_type_name}}++;
    }
    my @project_image_names_list = sort keys %project_image_type_names;

    my %data_hash;
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$schema,
        search_type=>'MaterializedViewTable',
        data_level=>'plot',
        trait_list=>$trait_id_list,
        trial_list=>$trial_id_list,
        include_timestamp=>0,
        exclude_phenotype_outlier=>0,
    );
    my @data = $phenotypes_search->get_phenotype_matrix();

    my $phenotype_header = shift @data;
    my @total_phenotype_header = (@$phenotype_header, @project_image_names_list);
    foreach (@data) {
        $data_hash{$_->[21]} = $_;
    }

    while (my($stock_id, $image_info_hash) = each %image_data_hash) {
        foreach (@project_image_names_list) {
            my $image_string = $image_info_hash->{$_} ? join ',', @{$image_info_hash->{$_}} : '';
            push @{$data_hash{$stock_id}}, $image_string;
        }
    }
    #print STDERR Dumper \%data_hash;
    my @data_array = values %data_hash;
    my @data_total = (\@total_phenotype_header, @data_array);

    if ($return_format eq 'csv') {
        my $dir = $c->tempfiles_subdir('download');
        my ($download_file_path, $download_uri) = $c->tempfile( TEMPLATE => 'download/drone_imagery_analysis_csv_'.'XXXXX');
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $download_file_path,
            absolute_file_uri => $main_production_site.$download_uri,
            format => $return_format,
            data => \@data_total
        });
        my @data_files = $file_response->get_datafiles();
        $return{file} = $data_files[0];
    } elsif ($return_format eq 'xls') {
        my $dir = $c->tempfiles_subdir('download');
        my ($download_file_path, $download_uri) = $c->tempfile( TEMPLATE => 'download/drone_imagery_analysis_xls_'.'XXXXX');
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $download_file_path,
            absolute_file_uri => $main_production_site.$download_uri,
            format => $return_format,
            data => \@data_total
        });
        my @data_files = $file_response->get_datafiles();
        $return{file} = $data_files[0];
    } elsif ($return_format eq 'json') {
        $return{header} = \@total_phenotype_header;
        $return{data} = \@data_array;
    }

    $c->stash->{rest} = \%return;
}

sub drone_imagery_calculate_statistics : Path('/api/drone_imagery/calculate_statistics') : ActionClass('REST') { }
sub drone_imagery_calculate_statistics_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $statistics_select = $c->req->param('statistics_select');
    my $field_trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $field_trial_id_list_string = join ',', @$field_trial_id_list;
    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];
    my $compute_from_parents = $c->req->param('compute_from_parents') eq 'yes' ? 1 : 0;
    my $protocol_id = $c->req->param('protocol_id');
    my $tolparinv = $c->req->param('tolparinv');

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_drone_statistics";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_fh, $stats_out_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_row_fh, $stats_out_tempfile_row) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_col_fh, $stats_out_tempfile_col) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my $grm_file;

    my @results;
    my %result_blup_data;
    my %result_blup_spatial_data;
    my @sorted_trait_names;
    my @unique_accession_names;
    my @unique_plot_names;
    my $statistical_ontology_term;
    my $analysis_result_values_type;
    my $analysis_model_language = "R";
    my $analysis_model_training_data_file_type;
    my $field_trial_design;

    if ($statistics_select eq 'lmer_germplasmname_replicate' || $statistics_select eq 'sommer_grm_spatial_genetic_blups') {

        my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
            'MaterializedViewTable',
            {
                bcs_schema=>$schema,
                data_level=>'plot',
                trait_list=>$trait_id_list,
                trial_list=>$field_trial_id_list,
                include_timestamp=>0,
                exclude_phenotype_outlier=>0
            }
        );
        my ($data, $unique_traits) = $phenotypes_search->search();
        @sorted_trait_names = sort keys %$unique_traits;

        if (scalar(@$data) == 0) {
            $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
            return;
        }

        my %trait_name_encoder;
        my %trait_name_encoder_rev;
        my $trait_name_encoded = 1;
        my %phenotype_data;
        my %stock_info;
        my %unique_accessions;
        foreach my $obs_unit (@$data){
            my $germplasm_name = $obs_unit->{germplasm_uniquename};
            my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
            $unique_accessions{$germplasm_name}++;
            $stock_info{"S".$germplasm_stock_id} = {
                uniquename => $germplasm_name
            };
            my $observations = $obs_unit->{observations};
            foreach (@$observations){
                $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$_->{trait_name}} = $_->{value};
            }
        }
        @unique_accession_names = sort keys %unique_accessions;

        foreach my $trait_name (@sorted_trait_names) {
            if (!exists($trait_name_encoder{$trait_name})) {
                my $trait_name_e = 't'.$trait_name_encoded;
                $trait_name_encoder{$trait_name} = $trait_name_e;
                $trait_name_encoder_rev{$trait_name_e} = $trait_name;
                $trait_name_encoded++;
            }
        }

        my @data_matrix;
        my %obsunit_row_col;
        my %seen_plot_names;
        foreach (@$data) {
            my $germplasm_name = $_->{germplasm_uniquename};
            my $germplasm_stock_id = $_->{germplasm_stock_id};
            my $obsunit_stock_id = $_->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
            my $row_number = $_->{obsunit_row_number};
            my $col_number = $_->{obsunit_col_number};
            my @row = ($_->{obsunit_rep}, $_->{obsunit_block}, "S".$germplasm_stock_id, $row_number, $col_number, $row_number, $col_number);
            $obsunit_row_col{$row_number}->{$col_number} = {
                stock_id => $obsunit_stock_id,
                stock_uniquename => $obsunit_stock_uniquename
            };
            $seen_plot_names{$obsunit_stock_uniquename}++;
            foreach my $t (@sorted_trait_names) {
                if (defined($phenotype_data{$obsunit_stock_uniquename}->{$t})) {
                    push @row, $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0;
                } else {
                    print STDERR $obsunit_stock_uniquename." : $t : $germplasm_name : NA \n";
                    push @row, 'NA';
                }
            }
            push @data_matrix, \@row;
        }

        my @phenotype_header = ("replicate", "block", "id", "rowNumber", "colNumber", "rowNumberFactor", "colNumberFactor");
        my $num_col_before_traits = scalar(@phenotype_header);
        foreach (@sorted_trait_names) {
            push @phenotype_header, $trait_name_encoder{$_};
        }
        my $header_string = join ',', @phenotype_header;

        open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
            print $F $header_string."\n";
            foreach (@data_matrix) {
                my $line = join ',', @$_;
                print $F "$line\n";
            }
        close($F);

        if ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {

            my %seen_accession_stock_ids;
            foreach my $trial_id (@$field_trial_id_list) {
                my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
                my $accessions = $trial->get_accessions();
                foreach (@$accessions) {
                    $seen_accession_stock_ids{$_->{stock_id}}++;
                }
            }
            my @accession_ids = keys %seen_accession_stock_ids;

            my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
            my $tmp_grm_dir = $shared_cluster_dir_config."/tmp_genotype_download_grm";
            mkdir $tmp_grm_dir if ! -d $tmp_grm_dir;
            my ($grm_tempfile_fh, $grm_tempfile) = tempfile("wizard_download_grm_XXXXX", DIR=> $tmp_grm_dir);
            my ($grm_out_tempfile_fh, $grm_out_tempfile) = tempfile("wizard_download_grm_XXXXX", DIR=> $tmp_grm_dir);

            my $geno = CXGN::Genotype::GRM->new({
                bcs_schema=>$schema,
                grm_temp_file=>$grm_tempfile,
                people_schema=>$people_schema,
                cache_root=>$c->config->{cache_file_path},
                accession_id_list=>\@accession_ids,
                protocol_id=>$protocol_id,
                get_grm_for_parental_accessions=>$compute_from_parents,
                download_format=>'three_column_reciprocal',
                # minor_allele_frequency=>$minor_allele_frequency,
                # marker_filter=>$marker_filter,
                # individuals_filter=>$individuals_filter
            });
            my $grm_data = $geno->download_grm(
                'data',
                $shared_cluster_dir_config,
                $c->config->{backend},
                $c->config->{cluster_host},
                $c->config->{'web_cluster_queue'},
                $c->config->{basepath}
            );

            open(my $F2, ">", $grm_out_tempfile) || die "Can't open file ".$grm_out_tempfile;
                print $F2 $grm_data;
            close($F2);
            $grm_file = $grm_out_tempfile;
        }

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        if ($statistics_select eq 'lmer_germplasmname_replicate') {
            $statistical_ontology_term = "Univariate linear mixed model genetic BLUPs using germplasmName computed using LMER R|SGNSTAT:0000002";
            $analysis_result_values_type = "analysis_result_values_match_accession_names";
            $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_lmer_germplasmname_replicate_phenotype_file";

            foreach my $t (@sorted_trait_names) {
                my $cmd = 'R -e "library(lme4); library(data.table);
                mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
                mix <- lmer('.$trait_name_encoder{$t}.' ~ replicate + (1|id), data = mat, na.action = na.omit );
                #mix.summary <- summary(mix);
                #ve <- mix.summary\$varcor\$id[1,1]/(mix.summary\$varcor\$id[1,1] + (mix.summary\$sigma)^2);
                write.table(ranef(mix)\$id, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                my $status = system($cmd);

                my $csv = Text::CSV->new({ sep_char => "\t" });

                open(my $fh, '<', $stats_out_tempfile)
                    or die "Could not open file '$stats_out_tempfile' $!";

                    print STDERR "Opened $stats_out_tempfile\n";
                    my $header = <$fh>;
                    my @header_cols;
                    if ($csv->parse($header)) {
                        @header_cols = $csv->fields();
                    }

                    while (my $row = <$fh>) {
                        my @columns;
                        if ($csv->parse($row)) {
                            @columns = $csv->fields();
                        }
                        my $stock_id = $columns[0];
                        my $stock_name = $stock_info{$stock_id}->{uniquename};
                        my $value = $columns[1];
                        $result_blup_data{$stock_name}->{$t} = [$value, $timestamp, $user_name, '', ''];
                    }
                close($fh);
            }
        }
        elsif ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {
            $statistical_ontology_term = "Multivariate linear mixed model genetic BLUPs using genetic relationship matrix and row and column spatial effects computed using Sommer R|SGNSTAT:0000001";
            $analysis_result_values_type = "analysis_result_values_match_accession_names";
            $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_spatial_genetic_blups_phenotype_file";

            @unique_plot_names = sort keys %seen_plot_names;

            my @encoded_traits = values %trait_name_encoder;
            my $encoded_trait_string = join ',', @encoded_traits;
            my $number_traits = scalar(@encoded_traits);

            my $cmd = 'R -e "library(sommer); library(data.table); library(reshape2);
            mat <- data.frame(fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\'));
            geno_mat_3col <- data.frame(fread(\''.$grm_file.'\', header=FALSE, sep=\'\t\'));
            geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
            geno_mat[is.na(geno_mat)] <- 0;
            mat\$rowNumber <- as.numeric(mat\$rowNumber);
            mat\$colNumber <- as.numeric(mat\$colNumber);
            mat\$rowNumberFactor <- as.factor(mat\$rowNumberFactor);
            mat\$colNumberFactor <- as.factor(mat\$colNumberFactor);
            mix <- mmer(cbind('.$encoded_trait_string.')~1, random=~vs(id, Gu=geno_mat, Gtc=unsm('.$number_traits.')) +vs(rowNumberFactor, Gtc=diag('.$number_traits.')) +vs(colNumberFactor, Gtc=diag('.$number_traits.')), rcov=~vs(units, Gtc=unsm('.$number_traits.')), data=mat, tolparinv='.$tolparinv.');
            #gen_cor <- cov2cor(mix\$sigma\$\`u:id\`);
            write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            write.table(mix\$U\$\`u:rowNumberFactor\`, file=\''.$stats_out_tempfile_row.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            write.table(mix\$U\$\`u:colNumberFactor\`, file=\''.$stats_out_tempfile_col.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
            print STDERR Dumper $cmd;
            my $status = system($cmd);

            my $csv = Text::CSV->new({ sep_char => "\t" });

            open(my $fh, '<', $stats_out_tempfile)
                or die "Could not open file '$stats_out_tempfile' $!";

                print STDERR "Opened $stats_out_tempfile\n";
                my $header = <$fh>;
                my @header_cols;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                while (my $row = <$fh>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    my $col_counter = 0;
                    foreach my $encoded_trait (@header_cols) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $stock_id = $columns[0];

                        my $stock_name = $stock_info{$stock_id}->{uniquename};
                        my $value = $columns[$col_counter+1];
                        $result_blup_data{$stock_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];
                        $col_counter++;
                    }
                }
            close($fh);

            my %result_blup_row_data;
            my @row_numbers;
            open(my $fh_row, '<', $stats_out_tempfile_row)
                or die "Could not open file '$stats_out_tempfile_row' $!";

                print STDERR "Opened $stats_out_tempfile_row\n";
                my $header_row = <$fh_row>;
                my @header_cols_row;
                if ($csv->parse($header_row)) {
                    @header_cols_row = $csv->fields();
                }

                while (my $row_row = <$fh_row>) {
                    my @columns_row;
                    if ($csv->parse($row_row)) {
                        @columns_row = $csv->fields();
                    }
                    my $col_counter_row = 0;
                    foreach my $encoded_trait (@header_cols_row) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $row_id = $columns_row[0];
                        push @row_numbers, $row_id;
                        my $value = $columns_row[$col_counter_row+1];
                        $result_blup_row_data{$row_id}->{$trait} = $value;
                        $col_counter_row++;
                    }
                }
            close($fh_row);

            my %result_blup_col_data;
            my @col_numbers;
            open(my $fh_col, '<', $stats_out_tempfile_col)
                or die "Could not open file '$stats_out_tempfile_col' $!";

                print STDERR "Opened $stats_out_tempfile_col\n";
                my $header_col = <$fh_col>;
                my @header_cols_col;
                if ($csv->parse($header_col)) {
                    @header_cols_col = $csv->fields();
                }

                while (my $row_col = <$fh_col>) {
                    my @columns_col;
                    if ($csv->parse($row_col)) {
                        @columns_col = $csv->fields();
                    }
                    my $col_counter_col = 0;
                    foreach my $encoded_trait (@header_cols_col) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $col_id = $columns_col[0];
                        push @col_numbers, $col_id;
                        my $value = $columns_col[$col_counter_col+1];
                        $result_blup_col_data{$col_id}->{$trait} = $value;
                        $col_counter_col++;
                    }
                }
            close($fh_col);

            foreach my $trait (@sorted_trait_names) {
                foreach my $row (@row_numbers) {
                    foreach my $col (@col_numbers) {
                        my $uniquename = $obsunit_row_col{$row}->{$col}->{stock_uniquename};
                        my $stock_id = $obsunit_row_col{$row}->{$col}->{stock_id};

                        my $row_val = $result_blup_row_data{$row}->{$trait};
                        my $col_val = $result_blup_col_data{$col}->{$trait};
                        $result_blup_spatial_data{$uniquename}->{$trait} = [$row_val*$col_val, $timestamp, $user_name, '', ''];
                    }
                }
            }

            my $field_trial_design_full = CXGN::Trial->new({bcs_schema => $schema, trial_id=>$field_trial_id_list->[0]})->get_layout()->get_design();
            # print STDERR Dumper $field_trial_design_full;
            while (my($plot_number, $plot_obj) = each %$field_trial_design_full) {
                $field_trial_design->{$plot_number} = {
                    stock_name => $plot_obj->{accession_name},
                    block_number => $plot_obj->{block_number},
                    col_number => $plot_obj->{col_number},
                    row_number => $plot_obj->{row_number},
                    plot_name => $plot_obj->{plot_name},
                    plot_number => $plot_obj->{plot_number},
                    rep_number => $plot_obj->{rep_number},
                    is_a_control => $plot_obj->{is_a_control}
                };
            }
        }
    }
    elsif ($statistics_select eq 'marss_germplasmname_block') {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
        my $status = $bs->test_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});
        if ($status->{'error'}) {
            $c->stash->{rest} = { error => $status->{'error'}};
            return;
        }
        my $results_ref = $bs->metadata_query(['trials', 'accessions'], {'accessions' => {'trials' => $field_trial_id_list_string}}, {'accessions' => {'trials'=>1}});
        my %unique_accession_ids;
        foreach (@{$results_ref->{results}}) {
            $unique_accession_ids{$_->[0]}++;
        }
        my @unique_accession_ids = keys %unique_accession_ids;
        if (scalar(@unique_accession_ids) == 0) {
            $c->stash->{rest} = { error => "There are no common accessions in the trials you have selected! If that is the case, please just select one at a time."};
            return;
        }
        print STDERR scalar(@unique_accession_ids)." Common Accessions\n";

        my $marss_prediction_selection = $c->req->param('statistics_select_marss_options');

        my $drone_run_related_time_cvterms_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
        my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
        my $drone_run_time_q = "SELECT drone_run_project.project_id, project_relationship.object_project_id, projectprop.value
            FROM project AS drone_run_band_project
            JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
            JOIN project AS drone_run_project ON (drone_run_project.project_id = drone_run_band_rel.object_project_id)
            JOIN project_relationship ON (drone_run_project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
            LEFT JOIN projectprop ON (drone_run_band_project.project_id = projectprop.project_id AND projectprop.type_id=$drone_run_related_time_cvterms_json_cvterm_id)
            WHERE project_relationship.object_project_id IN ($field_trial_id_list_string) ;";
        my $h = $schema->storage->dbh()->prepare($drone_run_time_q);
        $h->execute();
        while( my ($drone_run_project_id, $field_trial_project_id, $related_time_terms_json) = $h->fetchrow_array()) {
            my $related_time_terms;
            if (!$related_time_terms_json) {
                $related_time_terms = _perform_gdd_calculation_and_drone_run_time_saving($schema, $field_trial_project_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, 50, 'average_daily_temp_sum');
            }
            else {
                $related_time_terms = decode_json $related_time_terms_json;
            }
            if (!exists($related_time_terms->{gdd_average_temp})) {
                $related_time_terms = _perform_gdd_calculation_and_drone_run_time_saving($schema, $field_trial_project_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, 50, 'average_daily_temp_sum');
            }
        }

        my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
            'MaterializedViewTable',
            {
                bcs_schema=>$schema,
                data_level=>'plot',
                trait_list=>$trait_id_list,
                trial_list=>$field_trial_id_list,
                accession_list=>\@unique_accession_ids,
                include_timestamp=>0,
                exclude_phenotype_outlier=>0
            }
        );
        my ($data, $unique_traits) = $phenotypes_search->search();
        my @sorted_trait_names = sort keys %$unique_traits;

        if (scalar(@$data) == 0) {
            $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
            return;
        }

        my %germplasm_name_encoder;
        my $germplasm_name_encoded = 1;
        my %trait_name_encoder;
        my $trait_name_encoded = 1;
        my %phenotype_data;
        my %seen_gdd_times;
        my %seen_germplasm_names;
        foreach my $obs_unit (@$data){
            my $germplasm_name = $obs_unit->{germplasm_uniquename};
            my $observations = $obs_unit->{observations};
            if (!exists($germplasm_name_encoder{$germplasm_name})) {
                $germplasm_name_encoder{$germplasm_name} = $germplasm_name_encoded;
                $germplasm_name_encoded++;
            }
            foreach (@$observations){
                my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                my $gdd_time = $related_time_terms_json->{gdd_average_temp} + 0;
                $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$gdd_time} = $_->{value};
                $seen_gdd_times{$gdd_time}++;
            }
            $seen_germplasm_names{$germplasm_name} = $obs_unit->{germplasm_stock_id};
        }
        my @sorted_gdd_time_points = sort {$a <=> $b} keys %seen_gdd_times;

        my %data_matrix;
        my %germplasm_pheno_hash;
        foreach (@$data) {
            my $germplasm_name = $_->{germplasm_uniquename};
            my $obsunit_name = $_->{observationunit_uniquename};
            $germplasm_pheno_hash{$germplasm_name}->{obsunit_rep} = $_->{obsunit_rep};
            $germplasm_pheno_hash{$germplasm_name}->{obsunit_block} = $_->{obsunit_block};
            $germplasm_pheno_hash{$germplasm_name}->{germplasm_encoded} = $germplasm_name_encoder{$germplasm_name};
            foreach my $t (@sorted_gdd_time_points) {
                if (defined($phenotype_data{$obsunit_name}->{$t})) {
                    $germplasm_pheno_hash{$germplasm_name}->{$t} = $phenotype_data{$obsunit_name}->{$t} + 0;
                } else {
                    print STDERR "Using NA for ".$obsunit_name." : $t : $germplasm_name :  \n";
                }
            }
        }
        foreach my $g (keys %seen_germplasm_names) {
            my @row = ($germplasm_pheno_hash{$g}->{obsunit_rep}, $germplasm_pheno_hash{$g}->{obsunit_block}, $germplasm_pheno_hash{$g}->{germplasm_encoded});
            foreach my $t (@sorted_gdd_time_points) {
                push @row, $germplasm_pheno_hash{$g}->{$t};
            }
            push @{$data_matrix{$g}}, @row;
        }

        my @phenotype_header = ("replicate", "block", "germplasmName");
        my $num_col_before_traits = scalar(@phenotype_header);
        foreach (@sorted_gdd_time_points) {
            push @phenotype_header, "$_";
        }

        print STDERR Dumper \%data_matrix;
        print STDERR Dumper \@phenotype_header;

        foreach (keys %seen_germplasm_names) {
            my $germplasm_stock_id = $seen_germplasm_names{$_};
            my $dir = $c->tempfiles_subdir('/drone_imagery_analysis_plot');
            my $temp_plot = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_analysis_plot/imageXXXX');
            $temp_plot .= '.jpg';

            my $germplasm_data = $data_matrix{$_};
            my $num_rows = scalar(@$germplasm_data)/scalar(@phenotype_header);
            my $rmatrix = R::YapRI::Data::Matrix->new({
                name => 'matrix1',
                coln => scalar(@phenotype_header),
                rown => $num_rows,
                colnames => \@phenotype_header,
                data => $germplasm_data
            });

            my $rbase = R::YapRI::Base->new();
            my $r_block = $rbase->create_block('r_block');
            $rmatrix->send_rbase($rbase, 'r_block');
            $r_block->add_command('library(MARSS)');
            $r_block->add_command('library(ggplot2)');
            $r_block->add_command('header <- colnames(matrix1)');
            $r_block->add_command('gdd_times <- header[-c(1:'.$num_col_before_traits.')]');
            $r_block->add_command('matrix_transposed <- t(matrix1)');
            $r_block->add_command('result_matrix <- matrix(NA,nrow = 3*'.$num_rows.', ncol = length(matrix_transposed[ ,1]))');
            $r_block->add_command('jpeg("'.$temp_plot.'")');

            my $row_number = 1;
            foreach my $t (1..$num_rows) {
                $r_block->add_command('row'.$t.' <- matrix_transposed[ , '.$t.']');
                $r_block->add_command('replicate'.$t.' <- row'.$t.'[1]');
                $r_block->add_command('block'.$t.' <- row'.$t.'[2]');
                $r_block->add_command('germplasmName'.$t.' <- row'.$t.'[3]');
                $r_block->add_command('time_series'.$t.' <- row'.$t.'[-c(1:'.$num_col_before_traits.')]');
                $r_block->add_command('for (i in range(1:length(time_series'.$t.'))) { if (time_series'.$t.'[i] == "NA") { time_series'.$t.'[i] <- NA } }');
                $r_block->add_command('time_series_original'.$t.' <- time_series'.$t.'');
                if ($marss_prediction_selection eq 'marss_predict_last_two_time_points') {
                    $r_block->add_command('time_series'.$t.'[c(length(time_series'.$t.')-1, length(time_series'.$t.') )] <- NA');
                }
                elsif ($marss_prediction_selection eq 'marss_predict_last_time_point') {
                    $r_block->add_command('time_series'.$t.'[length(time_series'.$t.')] <- NA');
                }
                else {
                    die "MARSS predict option not selected\n";
                }
                #$r_block->add_command('mars_model'.$t.' <- list(B=matrix("phi"), U=matrix(0), Q=matrix("sig.sq.w"), Z=matrix("a"), A=matrix(0), R=matrix("sig.sq.v"), x0=matrix("mu"), tinitx=0 )');
                $r_block->add_command('mars_model'.$t.' <- list(B="unconstrained", U="zero", Q="unconstrained", Z="identity", A="zero", R="diagonal and unequal", tinitx=1 )');
                $r_block->add_command('mars_fit'.$t.' <- MARSS(time_series'.$t.', model=mars_model'.$t.', method="kem")');
                $r_block->add_command('minimum_y_val'.$t.' <- min( c( min(as.numeric(time_series_original'.$t.'), na.rm=T), min(as.numeric(mars_fit'.$t.'$ytT)), na.rm=T) , na.rm=T)');
                $r_block->add_command('maximum_y_val'.$t.' <- max( c( max(as.numeric(time_series_original'.$t.'), na.rm=T), max(as.numeric(mars_fit'.$t.'$ytT)), na.rm=T) , na.rm=T)');
                $r_block->add_command('maximum_y_std'.$t.' <- max( mars_fit'.$t.'$ytT.se, na.rm=T)');
                $r_block->add_command('result_matrix['.$row_number.',] <- c(replicate'.$t.', block'.$t.', germplasmName'.$t.', time_series_original'.$t.')');
                $row_number++;
                $r_block->add_command('result_matrix['.$row_number.',] <- c(replicate'.$t.', block'.$t.', germplasmName'.$t.', mars_fit'.$t.'$ytT)');
                $row_number++;
                $r_block->add_command('result_matrix['.$row_number.',] <- c(replicate'.$t.', block'.$t.', germplasmName'.$t.', mars_fit'.$t.'$ytT.se)');
                $row_number++;

                if ($t == 1) {
                    $r_block->add_command('plot(gdd_times, time_series_original'.$t.', type="b", col="gray", main="State Space '.$_.'", xlab="Growing Degree Days", ylab="Phenotype", ylim = c(minimum_y_val'.$t.'-maximum_y_std'.$t.'-0.05*maximum_y_val'.$t.', maximum_y_val'.$t.'+maximum_y_std'.$t.'+0.05*maximum_y_val'.$t.') )');
                }
                else {
                    $r_block->add_command('lines(gdd_times, time_series_original'.$t.', type="b", col="gray")');
                }
                $r_block->add_command('points(gdd_times[which(is.na(time_series'.$t.'))], mars_fit'.$t.'$ytT[which(is.na(time_series'.$t.'))], col="blue", lty=2)');
                $r_block->add_command('points(gdd_times[which(is.na(time_series'.$t.'))], c(mars_fit'.$t.'$ytT + qnorm(0.975)*mars_fit'.$t.'$ytT.se)[which(is.na(time_series'.$t.'))], col="red", lty=2)');
                $r_block->add_command('points(gdd_times[which(is.na(time_series'.$t.'))], c(mars_fit'.$t.'$ytT - qnorm(0.975)*mars_fit'.$t.'$ytT.se)[which(is.na(time_series'.$t.'))], col="red", lty=2)');
                # $r_block->add_command('legend("topleft", col=c("blue", "gray", "red"), legend = c("Predicted", "Observed", "SE"), lty=1 )');
            }
            $r_block->add_command('dev.off()');
            $r_block->run_block();
            my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','result_matrix');
            #print STDERR Dumper $result_matrix;

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5checksum = $image->calculate_md5sum($temp_plot);
            my $q = "SELECT md_image.image_id
                FROM metadata.md_image AS md_image
                JOIN phenome.stock_image AS stock_image USING(image_id)
                WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND stock_image.stock_id = ?;";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute($md5checksum, $germplasm_stock_id);
            my ($saved_image_id) = $h->fetchrow_array();

            my $plot_image_fullpath;
            my $plot_image_url;
            my $plot_image_id;
            if ($saved_image_id) {
                print STDERR Dumper "Image $temp_plot has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $plot_image_fullpath = $image->get_filename('original_converted', 'full');
                $plot_image_url = $image->get_image_url('original');
                $plot_image_id = $image->get_image_id();
            } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($temp_plot, 'stock', $germplasm_stock_id);
                $plot_image_fullpath = $image->get_filename('original_converted', 'full');
                $plot_image_url = $image->get_image_url('original');
                $plot_image_id = $image->get_image_id();
            }

            push @results, ["TimeSeries", $result_matrix, $plot_image_url];
        }
    }
    else {
        $c->stash->{rest} = { error => "Not supported $statistics_select!"};
        return;
    }

    #print STDERR Dumper \@results;
    #print STDERR Dumper \%result_blup_data;
    $c->stash->{rest} = {
        results => \@results,
        result_blup_genetic_data => \%result_blup_data,
        result_blup_spatial_data => \%result_blup_spatial_data,
        unique_traits => \@sorted_trait_names,
        unique_accessions => \@unique_accession_names,
        unique_plots => \@unique_plot_names,
        statistics_select => $statistics_select,
        grm_file => $grm_file,
        stats_tempfile => $stats_tempfile,
        stats_out_tempfile => $stats_out_tempfile,
        stats_out_tempfile_col => $stats_out_tempfile_col,
        stats_out_tempfile_row => $stats_out_tempfile_row,
        statistical_ontology_term => $statistical_ontology_term,
        analysis_result_values_type => $analysis_result_values_type,
        analysis_model_type => $statistics_select,
        analysis_model_language => $analysis_model_language,
        application_name => "NickMorales Mixed Models",
        application_version => "V1.01",
        analysis_model_training_data_file_type => $analysis_model_training_data_file_type,
        field_trial_design => $field_trial_design
    };
}

sub drone_imagery_calculate_statistics_store_analysis : Path('/api/drone_imagery/calculate_statistics_store_analysis') : ActionClass('REST') { }
sub drone_imagery_calculate_statistics_store_analysis_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $analysis_name = $c->req->param('analysis_name');
    my $analysis_description = $c->req->param('analysis_description');
    my $analysis_model_type = $c->req->param('statistics_select');
    my $accession_names = $c->req->param('accession_names');
    my $trait_names = $c->req->param('trait_names');
    my $training_data_file = $c->req->param('training_data_file');
    my $phenotype_data_hash = $c->req->param('phenotype_data_hash');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $a = CXGN::Analysis->new({
        bcs_schema => $bcs_schema,
        people_schema => $people_schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        name => $analysis_name,
    });

    $a->description($analysis_description);
    $a->user_id($user_id);

    my $model_string = '';

    #print STDERR Dumper("STOCKS HERE: ".$stocks);
    $a->accession_names($accession_names);
    $a->metadata()->traits($trait_names);
    #$a->metadata()->analysis_protocol($params->{analysis_protocol});
    $a->metadata()->model($model_string);
    
    my ($verified_warning, $verified_error);

    print STDERR "Storing the analysis...\n";
    eval {
        ($verified_warning, $verified_error) = $a->create_and_store_analysis_design();
    };

    my @errors;
    my @warnings;

    if ($@) {
        push @errors, $@;
    }
    elsif ($verified_warning) {
        push @warnings, $verified_warning;
    }
    elsif ($verified_error) {
        push @errors, $verified_error;
    }

    if (@errors) {
        print STDERR "SORRY! Errors: ".join("\n", @errors);
        $c->stash->{rest} = { error => join "; ", @errors };
        return;
    }

    print STDERR "Store analysis values...\n";
    #print STDERR "value hash: ".Dumper($values);
    print STDERR "traits: ".join(",",@$trait_names);

    my $plots;
    my $values;
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    eval {
        $a->store_analysis_values(
            $c->dbic_schema("CXGN::Metadata::Schema"),
            $c->dbic_schema("CXGN::Phenome::Schema"),
            $values, # value_hash
            $plots,
            $trait_names,
            $user_name,
            $c->config->{basepath},
            $c->config->{dbhost},
            $c->config->{dbname},
            $c->config->{dbuser},
            $c->config->{dbpass},
            $temp_file_nd_experiment_id,
        );
    };

    if ($@) {
        print STDERR "An error occurred storing analysis values ($@).\n";
        $c->stash->{rest} = {
            error => "An error occurred storing the values ($@).\n"
        };
        return;
    }

    $c->stash->{rest} = { success => 1 };
}

sub drone_imagery_rotate_image : Path('/api/drone_imagery/rotate_image') : ActionClass('REST') { }
sub drone_imagery_rotate_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $angle_rotation = $c->req->param('angle');
    my $view_only = $c->req->param('view_only');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
    my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
    $archive_rotate_temp_image .= '.png';

    my $return = _perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $angle_rotation, $view_only, $user_id, $user_name, $user_role, $archive_rotate_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_rotate {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $drone_run_band_project_id = shift;
    my $image_id = shift;
    my $angle_rotation = shift;
    my $view_only = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_rotate_temp_image = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Rotate.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_rotate_temp_image.'\' --angle '.$angle_rotation;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $linking_table_type_id;
    if ($view_only) {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
    } else {
        my $rotated_stitched_temporary_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
        my $rotated_stitched_temporary_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$rotated_stitched_temporary_drone_images_cvterm_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($rotated_stitched_temporary_result, $rotated_stitched_temporary_total_count) = $rotated_stitched_temporary_images_search->search();
        foreach (@$rotated_stitched_temporary_result){
            my $temp_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $temp_image->delete(); #Sets to obsolete
        }
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();

        my $rotated_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($rotated_stitched_result, $rotated_stitched_total_count) = $rotated_stitched_images_search->search();
        foreach (@$rotated_stitched_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        my $drone_run_band_rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
        my $drone_run_band_rotate_angle = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$drone_run_band_rotate_angle_type_id,
            project_id=>$drone_run_band_project_id,
            rank=>0,
            value=>$angle_rotation
        },
        {
            key=>'projectprop_c1'
        });
    }

    my $rotated_image_fullpath;
    my $rotated_image_url;
    my $rotated_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_rotate_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_rotate_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
        $rotated_image_url = $image->get_image_url('original');
        $rotated_image_id = $image->get_image_id();
    } else {
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_rotate_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
        $rotated_image_url = $image->get_image_url('original');
        $rotated_image_id = $image->get_image_id();
    }

    unlink($archive_rotate_temp_image);
    return {
        rotated_image_id => $rotated_image_id, image_url => $image_url, image_fullpath => $image_fullpath, rotated_image_url => $rotated_image_url, rotated_image_fullpath => $rotated_image_fullpath
    };
}

sub drone_imagery_get_contours : Path('/api/drone_imagery/get_contours') : ActionClass('REST') { }
sub drone_imagery_get_contours_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contours_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_contours');
    my $archive_contours_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_contours/imageXXXX');
    $archive_contours_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageContours/GetContours.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_contours_temp_image.'\'';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my @size = imgsize($archive_contours_temp_image);

    my $contours_image_fullpath;
    my $contours_image_url;
    my $contours_image_id;

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_contours_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_contours_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $contours_image_fullpath = $image->get_filename('original_converted', 'full');
        $contours_image_url = $image->get_image_url('original');
        $contours_image_id = $image->get_image_id();
    } else {
        my $previous_contour_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_contour_result, $previous_contour_total_count) = $previous_contour_images_search->search();
        foreach (@$previous_contour_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_contours_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $contours_image_fullpath = $image->get_filename('original_converted', 'full');
        $contours_image_url = $image->get_image_url('original');
        $contours_image_id = $image->get_image_id();
    }

    unlink($archive_contours_temp_image);
    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, contours_image_id => $contours_image_id, contours_image_url => $contours_image_url, contours_image_fullpath => $contours_image_fullpath, image_width => $size[0], image_height => $size[1] };
}

sub drone_imagery_retrieve_parameter_template : Path('/api/drone_imagery/retrieve_parameter_template') : ActionClass('REST') { }
sub drone_imagery_retrieve_parameter_template_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $template_projectprop_id = $c->req->param('plot_polygons_template_projectprop_id');

    my $rs = $schema->resultset("Project::Projectprop")->find({projectprop_id => $template_projectprop_id});
    my $plot_polygons = decode_json $rs->value;

    $c->stash->{rest} = {
        success => 1,
        parameter => $plot_polygons
    };
}

sub drone_imagery_assign_plot_polygons : Path('/api/drone_imagery/assign_plot_polygons') : ActionClass('REST') { }
sub drone_imagery_assign_plot_polygons_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');
    my $assign_plot_polygons_type = $c->req->param('assign_plot_polygons_type');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_plot_polygon_assign($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $stock_polygons, $assign_plot_polygons_type, $user_id, $user_name, $user_role, 1, 0);

    $c->stash->{rest} = $return;
}

sub _perform_plot_polygon_assign {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $stock_polygons = shift;
    my $assign_plot_polygons_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $from_web_interface = shift;
    my $ignore_previous_image_check = shift;
    print STDERR "Plot Polygon Assign Type: $assign_plot_polygons_type \n";

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    # print STDERR Dumper $polygon_objs;

    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        if ($from_web_interface) {
            my $last_point = pop @$polygon;
        }
        if (scalar(@$polygon) != 4){
            # print STDERR Dumper $polygon;
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.' should be 4 long!'};
            $c->detach();
        }
        $polygon_objs->{$stock_name} = $polygon;

        my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids{$stock_name} = $stock->stock_id;
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for plot polygons for a drone run band";
    }

    my $save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons = decode_json $previous_plot_polygons_rs->first->value;
    }
    foreach my $stock_name (keys %$polygon_objs) {
        $save_stock_polygons->{$stock_name} = $polygon_objs->{$stock_name};
    }

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_plot_polygons_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=> encode_json($save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $assign_plot_polygons_type, 'project_md_image')->cvterm_id();

    my @found_stock_ids = values %stock_ids;
    if (!$ignore_previous_image_check) {
        my $previous_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            drone_run_band_project_id_list=>[$drone_run_band_project_id],
            project_image_type_id=>$linking_table_type_id,
            stock_id_list=>\@found_stock_ids
        });
        my ($previous_result, $previous_total_count) = $previous_images_search->search();

        if (scalar(@$previous_result) == scalar(@found_stock_ids)) {
            print STDERR "Plot polygon assignment for $assign_plot_polygons_type on project $drone_run_band_project_id has already occured. Skipping \n";
            return {warning => "Plot polygon assignment already occured for $assign_plot_polygons_type on project $drone_run_band_project_id."};
        }
    }

    my $image_tag_id = CXGN::Tag::exists_tag_named($schema->storage->dbh, $assign_plot_polygons_type);
    if (!$image_tag_id) {
        my $image_tag = CXGN::Tag->new($schema->storage->dbh);
        $image_tag->set_name($assign_plot_polygons_type);
        $image_tag->set_description('Drone run band project type for plot polygon assignment: '.$assign_plot_polygons_type);
        $image_tag->set_sp_person_id($user_id);
        $image_tag_id = $image_tag->store();
    }
    my $image_tag = CXGN::Tag->new($schema->storage->dbh, $image_tag_id);

    my $corresponding_channel = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema)->{$linking_table_type_id}->{corresponding_channel};
    my $image_band_index_string = '';
    if (defined($corresponding_channel)) {
        $image_band_index_string = "--image_band_index $corresponding_channel";
    }

    my @plot_polygon_image_fullpaths;
    my @plot_polygon_image_urls;

    # my $pm = Parallel::ForkManager->new(floor(int($number_system_cores)*0.5));
    # $pm->run_on_finish( sub {
    #     my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
    #     push @plot_polygon_image_urls, $data_structure_reference->{plot_polygon_image_url};
    #     push @plot_polygon_image_fullpaths, $data_structure_reference->{plot_polygon_image_fullpath};
    # });

    foreach my $stock_name (keys %$polygon_objs) {
        #my $pid = $pm->start and next;

        my $polygon = $polygon_objs->{$stock_name};
        my $polygons = encode_json [$polygon];
        my $stock_id = $stock_ids{$stock_name};

        my $dir = $c->tempfiles_subdir('/drone_imagery_plot_polygons');
        my $archive_plot_polygons_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_plot_polygons/imageXXXX');
        $archive_plot_polygons_temp_image .= '.png';

        my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageCropping/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_plot_polygons_temp_image' --polygon_json '$polygons' $image_band_index_string --polygon_type rectangular_square";
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $plot_polygon_image_fullpath;
        my $plot_polygon_image_url;
        $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        my $md5checksum = $image->calculate_md5sum($archive_plot_polygons_temp_image);
        my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
            JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
            WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        my $h = $schema->storage->dbh->prepare($q);
        $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id, $stock_id);
        my ($image_id) = $h->fetchrow_array();

        if ($image_id) {
            print STDERR Dumper "Image $archive_plot_polygons_temp_image has already been added to the database and will not be added again.";
            $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
            $plot_polygon_image_url = $image->get_image_url('original');
        } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($archive_plot_polygons_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id, $user_name);
            $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
            $plot_polygon_image_url = $image->get_image_url('original');
            my $added_image_tag_id = $image->add_tag($image_tag);
        }
        unlink($archive_plot_polygons_temp_image);

        #$pm->finish(0, { plot_polygon_image_url => $plot_polygon_image_url, plot_polygon_image_fullpath => $plot_polygon_image_fullpath });
    }
    #$pm->wait_all_children;

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, success => 1, drone_run_band_template_id => $drone_run_band_plot_polygons->projectprop_id
    };
}

sub drone_imagery_manual_assign_plot_polygon_save_partial_template : Path('/api/drone_imagery/manual_assign_plot_polygon_save_partial_template') : ActionClass('REST') { }
sub drone_imagery_manual_assign_plot_polygon_save_partial_template_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my @image_ids = $c->req->param('image_ids[]');
    my $polygon_json = $c->req->param('polygon');
    my $polygon_plot_numbers_json = $c->req->param('polygon_plot_numbers');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $angle_rotated = $c->req->param('angle_rotated');
    my $partial_template_name = $c->req->param('partial_template_name');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_hash = decode_json $polygon_json;
    my $polygon_plot_numbers_hash = decode_json $polygon_plot_numbers_json;

    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();

    my $q = "SELECT stock.uniquename FROM stock
        JOIN stockprop USING(stock_id)
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        WHERE project_id = $field_trial_id
        AND nd_experiment.type_id = $field_experiment_cvterm_id
        AND stockprop.type_id = $plot_number_cvterm_id
        AND stockprop.value = ?;";
    my $h = $schema->storage->dbh->prepare($q);

    my %stock_polygon;
    while (my ($generated_index, $plot_number) = each %$polygon_plot_numbers_hash) {
        $h->execute($plot_number);
        my ($uniquename) = $h->fetchrow_array();
        my $plot_polygon = $polygon_hash->{$generated_index};
        my $last_point = pop @$plot_polygon;
        if (scalar(@$plot_polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$uniquename.' should be 4 long!'};
            $c->detach();
        }
        $stock_polygon{$uniquename} = $plot_polygon;
    }

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();

    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$manual_plot_polygon_template_partial, project_id=>$drone_run_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for partial plot polygon template for a drone run";
    }

    my @save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        @save_stock_polygons = @{decode_json $previous_plot_polygons_rs->first->value};
    }
    push @save_stock_polygons, {
        template_name => $partial_template_name,
        image_id => $image_ids[3], #NIR image id
        polygon => $polygon_hash,
        stock_polygon => \%stock_polygon
    };

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$manual_plot_polygon_template_partial,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=> encode_json(\@save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_manual_assign_plot_polygon : Path('/api/drone_imagery/manual_assign_plot_polygon') : ActionClass('REST') { }
sub drone_imagery_manual_assign_plot_polygon_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my @image_ids = $c->req->param('image_ids[]');
    my $polygon_json = $c->req->param('polygon');
    my $polygon_plot_numbers_json = $c->req->param('polygon_plot_numbers');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $angle_rotated = $c->req->param('angle_rotated');
    my $partial_template_name = $c->req->param('partial_template_name');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_hash = decode_json $polygon_json;
    my $polygon_plot_numbers_hash = decode_json $polygon_plot_numbers_json;

    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();

    my $q = "SELECT stock.uniquename FROM stock
        JOIN stockprop USING(stock_id)
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        WHERE project_id = $field_trial_id
        AND nd_experiment.type_id = $field_experiment_cvterm_id
        AND stockprop.type_id = $plot_number_cvterm_id
        AND stockprop.value = ?;";
    my $h = $schema->storage->dbh->prepare($q);

    my %stock_polygon;
    while (my ($generated_index, $plot_number) = each %$polygon_plot_numbers_hash) {
        $h->execute($plot_number);
        my ($uniquename) = $h->fetchrow_array();
        my $plot_polygon = $polygon_hash->{$generated_index};
        my $last_point = pop @$plot_polygon;
        if (scalar(@$plot_polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$uniquename.' should be 4 long!'};
            $c->detach();
        }
        $stock_polygon{$uniquename} = $plot_polygon;
    }

    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q_drone_run_bands = "SELECT drone_run_band.project_id, drone_run_band_project_type.value
        FROM project AS drone_run
        JOIN project_relationship ON (drone_run.project_id = project_relationship.object_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project as drone_run_band ON (drone_run_band.project_id=project_relationship.subject_project_id)
        JOIN projectprop AS drone_run_band_project_type ON (drone_run_band_project_type.project_id=drone_run_band.project_id AND drone_run_band_project_type.type_id=$drone_run_band_project_type_cvterm_id)
        WHERE drone_run.project_id=?;";
    my $h_drone_run_bands = $schema->storage->dbh->prepare($q_drone_run_bands);
    $h_drone_run_bands->execute($drone_run_project_id);
    my %drone_run_bands_all;
    while (my ($drone_run_band_id, $drone_run_band_type) = $h_drone_run_bands->fetchrow_array()) {
        $drone_run_bands_all{$drone_run_band_type} = $drone_run_band_id;
    }
    print STDERR Dumper \%drone_run_bands_all;

    my $drone_image_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @plot_polygon_type_ids = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id()
    );
    my @plot_polygon_type_objects;
    foreach (@plot_polygon_type_ids) {
        push @plot_polygon_type_objects, $drone_image_types->{$_};
    }

    my $stock_polygons = encode_json \%stock_polygon;
    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');

    foreach my $index (0..scalar(@image_ids)-1) {
        my $drone_run_band_project_type = $plot_polygon_type_objects[$index]->{drone_run_project_types}->[0];
        my $plot_polygon_type = $plot_polygon_type_objects[$index]->{name};
        my $image_id = $image_ids[$index];
        my $drone_run_band_project_id = $drone_run_bands_all{$drone_run_band_project_type};

        my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
        $archive_rotate_temp_image .= '.png';

        my $rotate_return = _perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $angle_rotated, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
        my $rotated_image_id = $rotate_return->{rotated_image_id};

        my $return = _perform_plot_polygon_assign($c, $schema, $metadata_schema, $rotated_image_id, $drone_run_band_project_id, $stock_polygons, $plot_polygon_type, $user_id, $user_name, $user_role, 0, 1);
    }

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_save_plot_polygons_template : Path('/api/drone_imagery/save_plot_polygons_template') : ActionClass('REST') { }
sub drone_imagery_save_plot_polygons_template_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        my $last_point = pop @$polygon;
        if (scalar(@$polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.' should be 4 long!'};
            $c->detach();
        }
        $polygon_objs->{$stock_name} = $polygon;

        my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids{$stock_name} = $stock->stock_id;
    }

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for plot polygons for a drone run band";
    }

    my $save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons = decode_json $previous_plot_polygons_rs->first->value;
    }
    foreach my $stock_name (keys %$polygon_objs) {
        $save_stock_polygons->{$stock_name} = $polygon_objs->{$stock_name};
    }

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_plot_polygons_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=> encode_json($save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = {success => 1, drone_run_band_template_id => $drone_run_band_plot_polygons->projectprop_id};
}

sub drone_imagery_denoise : Path('/api/drone_imagery/denoise') : ActionClass('REST') { }
sub drone_imagery_denoise_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
    my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
    $archive_denoise_temp_image .= '.png';

    my $return = _perform_image_denoise($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_denoise {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_denoise_temp_image = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Denoise.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_denoise_temp_image.'\'';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_denoised_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_denoised_result, $previous_denoised_total_count) = $previous_denoised_images_search->search();
    foreach (@$previous_denoised_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $denoised_image_fullpath;
    my $denoised_image_url;
    my $denoised_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_denoise_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_denoise_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
        $denoised_image_url = $image->get_image_url('original');
        $denoised_image_id = $image->get_image_id();
    } else {
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_denoise_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
        $denoised_image_url = $image->get_image_url('original');
        $denoised_image_id = $image->get_image_id();
    }

    unlink($archive_denoise_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, denoised_image_id => $denoised_image_id, denoised_image_url => $denoised_image_url, denoised_image_fullpath => $denoised_image_fullpath
    };
}

sub drone_imagery_remove_background_display : Path('/api/drone_imagery/remove_background_display') : ActionClass('REST') { }
sub drone_imagery_remove_background_display_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold = $c->req->param('lower_threshold');
    my $upper_threshold = $c->req->param('upper_threshold');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold && !defined($lower_threshold)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold'};
        $c->detach();
    }
    if (!$upper_threshold && !defined($upper_threshold)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold'};
        $c->detach();
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_threshold '.$lower_threshold.' --upper_threshold '.$upper_threshold;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_temporary_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_background_removed_temp_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_temp_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');

    unlink($archive_remove_background_temp_image);
    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath };
}

sub drone_imagery_remove_background_save : Path('/api/drone_imagery/remove_background_save') : ActionClass('REST') { }
sub drone_imagery_remove_background_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $image_type = $c->req->param('image_type');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold = $c->req->param('lower_threshold');
    my $upper_threshold = $c->req->param('upper_threshold') || '255';
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold && !defined($lower_threshold)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold'};
        $c->detach();
    }
    if (!$upper_threshold && !defined($upper_threshold)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold'};
        $c->detach();
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $return = _perform_image_background_remove_threshold($c, $schema, $image_id, $drone_run_band_project_id, $image_type, $lower_threshold, $upper_threshold, $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_background_remove_threshold {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $image_type = shift;
    my $lower_threshold = shift;
    my $upper_threshold = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_remove_background_temp_image = shift;
    print STDERR "Background Remove Threshold Image Type: $image_type\n";

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type, 'project_md_image')->cvterm_id();
    my $drone_run_band_remove_background_threshold_type_id;
    my $imagery_attribute_map = CXGN::DroneImagery::ImageTypes::get_imagery_attribute_map();

    if ($imagery_attribute_map->{$image_type}->{name} eq 'threshold') {
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $imagery_attribute_map->{$image_type}->{key}, 'project_property')->cvterm_id();
    }
    if (!$drone_run_band_remove_background_threshold_type_id) {
        die "Remove background threshold not found: $image_type\n";
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_threshold '.$lower_threshold.' --upper_threshold '.$upper_threshold;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $previous_background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');
    my $removed_background_image_id = $image->get_image_id();

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>"Lower Threshold:$lower_threshold. Upper Threshold:$upper_threshold"
    },
    {
        key=>'projectprop_c1'
    });

    unlink($archive_remove_background_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_id => $removed_background_image_id, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath
    };
}

sub drone_imagery_remove_background_percentage_save : Path('/api/drone_imagery/remove_background_percentage_save') : ActionClass('REST') { }
sub drone_imagery_remove_background_percentage_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $image_type_list = $c->req->param('image_type_list');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold_percentage = $c->req->param('lower_threshold_percentage');
    my $upper_threshold_percentage = $c->req->param('upper_threshold_percentage');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold_percentage && !defined($lower_threshold_percentage)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold percentage'};
        $c->detach();
    }
    if (!$upper_threshold_percentage && !defined($upper_threshold_percentage)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold percentage'};
        $c->detach();
    }

    my @image_types = split ',', $image_type_list;
    my @returns;
    foreach my $image_type (@image_types) {
        my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
        my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
        $archive_remove_background_temp_image .= '.png';

        my $return = _perform_image_background_remove_threshold_percentage($c, $schema, $image_id, $drone_run_band_project_id, $image_type, $lower_threshold_percentage, $upper_threshold_percentage, $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
        push @returns, $return;
    }

    $c->stash->{rest} = \@returns;
}

sub _perform_image_background_remove_threshold_percentage {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $image_type = shift;
    my $lower_threshold_percentage = shift;
    my $upper_threshold_percentage = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_remove_background_temp_image = shift;
    print STDERR "Remove background threshold percentage $image_type\n";

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type, 'project_md_image')->cvterm_id();
    my $drone_run_band_remove_background_threshold_type_id;
    my $imagery_attribute_map = CXGN::DroneImagery::ImageTypes::get_imagery_attribute_map();

    if ($imagery_attribute_map->{$image_type}->{name} eq 'threshold') {
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $imagery_attribute_map->{$image_type}->{key}, 'project_property')->cvterm_id();
    }
    if (!$drone_run_band_remove_background_threshold_type_id) {
        die "Remove background threshold not found: $image_type\n";
    }

    my $corresponding_channel = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($schema)->{$linking_table_type_id}->{corresponding_channel};
    my $image_band_index_string = '';
    if (defined($corresponding_channel)) {
        $image_band_index_string = "--image_band_index $corresponding_channel";
    }

    my $previous_background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackgroundPercentage.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_percentage \''.$lower_threshold_percentage.'\' --upper_percentage \''.$upper_threshold_percentage.'\' '.$image_band_index_string;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');
    my $removed_background_image_id = $image->get_image_id();

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>"Lower Threshold Percentage:$lower_threshold_percentage. Upper Threshold Percentage:$upper_threshold_percentage"
    },
    {
        key=>'projectprop_c1'
    });

    unlink($archive_remove_background_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_id => $removed_background_image_id, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath
    };
}

sub get_drone_run_projects : Path('/api/drone_imagery/drone_runs') : ActionClass('REST') { }
sub get_drone_run_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $field_trial_ids = $c->req->param('field_trial_ids');

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_camera_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_gdd_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_averaged_temperature_growing_degree_days', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($field_trial_ids) {
        $where_clause = ' WHERE field_trial.project_id IN ('.$field_trial_ids.') ';
    }

    my $q = "SELECT project.project_id, project.name, project.description, drone_run_type.value, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description, drone_run_camera_type.value, drone_run_gdd.value FROM project
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        LEFT JOIN projectprop AS drone_run_type ON (project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        LEFT JOIN projectprop AS drone_run_camera_type ON (project.project_id=drone_run_camera_type.project_id AND drone_run_camera_type.type_id=$drone_run_camera_cvterm_id)
        LEFT JOIN projectprop AS drone_run_gdd ON (project.project_id=drone_run_gdd.project_id AND drone_run_gdd.type_id=$drone_run_gdd_cvterm_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $drone_run_camera_type, $drone_run_gdd) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            my $checkbox = "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_project_id' ";
            if ($checkbox_select_all) {
                $checkbox .= "checked";
            }
            $checkbox .= ">";
            push @res, $checkbox;
        }
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$drone_run_project_id\">$drone_run_project_name</a>",
            $drone_run_type,
            $drone_run_project_description,
            $drone_run_date_display,
            $drone_run_gdd,
            $drone_run_camera_type,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $field_trial_project_description
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}


sub get_plot_polygon_types_images : Path('/api/drone_imagery/plot_polygon_types_images') : ActionClass('REST') { }
sub get_plot_polygon_types_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $field_trial_ids = $c->req->param('field_trial_ids');
    my $stock_ids = $c->req->param('stock_ids');
    my $field_trial_images_only = $c->req->param('field_trial_images_only');
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json $c->req->param('drone_run_ids') : [];
    my $drone_run_band_ids = $c->req->param('drone_run_band_ids') ? decode_json $c->req->param('drone_run_band_ids') : [];

    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id_list;
    if (!$field_trial_images_only) {
        $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
    }
    else {
        $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($bcs_schema);
    }
    my $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);

    my @where_clause;
    push @where_clause, "project_md_image.type_id in ($project_image_type_id_list_sql)";

    if ($field_trial_ids) {
        push @where_clause, "field_trial.project_id IN ($field_trial_ids)";
    }
    if ($drone_run_ids && scalar(@$drone_run_ids)>0) {
        my $sql = join ("," , @$drone_run_ids);
        push @where_clause, "drone_run.project_id IN ($sql)";
    }
    if ($drone_run_band_ids && scalar(@$drone_run_band_ids)>0) {
        my $sql = join ("," , @$drone_run_band_ids);
        push @where_clause, "drone_run_band.project_id IN ($sql)";
    }
    my $stock_image_join = '';
    if ($stock_ids) {
        my @stock_ids_array = split ',', $stock_ids;
        my $stock_id_sql = join (",", @stock_ids_array);
        $stock_image_join = 'JOIN metadata.md_image AS md_image ON (md_image.image_id=project_md_image.image_id) JOIN phenome.stock_image AS stock_image ON (md_image.image_id=stock_image.image_id)';
        push @where_clause, "stock_image.stock_id IN ($stock_id_sql)";
    }
    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, project_md_image.image_id
        FROM project AS drone_run_band
        LEFT JOIN projectprop AS drone_run_band_type ON (drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_project_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band.project_id = drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_project_relationship_type_id)
        JOIN project AS drone_run ON (drone_run.project_id=drone_run_band_rel.object_project_id)
        LEFT JOIN projectprop AS drone_run_type ON (drone_run.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=field_trial_rel.object_project_id)
        JOIN phenome.project_md_image AS project_md_image ON (drone_run_band.project_id = project_md_image.project_id)
        JOIN cvterm AS project_md_image_type ON (project_md_image_type.cvterm_id = project_md_image.type_id)
        $stock_image_join
        $where_clause
        GROUP BY drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, project_md_image.image_id
        ORDER BY drone_run_band.project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $project_md_image_type_id, $project_md_image_type_name, $image_id) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            my $input = "<input type='checkbox' name='$checkbox_select_name' value='$image_id' ";
            if ($checkbox_select_all) {
                $input .= "checked";
            }
            $input .= ">";
            push @res, $input;
        }
        my $image = SGN::Image->new($bcs_schema->storage->dbh, $image_id, $c);
        my $image_id = $image->get_image_id;
        my $image_name = $image->get_name() || '';
        my $image_description = $image->get_description() || '';
        my $image_img = $image->get_image_url("medium");
        my $original_img = $image->get_image_url("large");
        my $small_image = $image->get_image_url("tiny");
        my $image_page = "/image/view/$image_id";
        my $colorbox = qq|<a href="$image_img"  title="<a href=$image_page>Go to image page ($image_name)</a>" class="image_search_group" rel="gallery-figures"><img src="$small_image" width="40" height="30" border="0" alt="$image_description" /></a>|;

        push @res, (
            $colorbox,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $drone_run_project_name,
            $drone_run_band_project_name,
            $drone_run_band_type,
            $project_md_image_type_name
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}

sub _get_standard_4_polygon_types {
    return (
        'observation_unit_polygon_rgb_imagery' => 1, #77976, 77689
        'observation_unit_polygon_nrn_imagery' => 1, #77980, 77693
        'observation_unit_polygon_nren_imagery' => 1, #77981, 77694
        # 'observation_unit_polygon_green_background_removed_threshold_imagery' => 1, #77995, 77708
        # 'observation_unit_polygon_red_background_removed_threshold_imagery' => 1, #77996, 77709
        # 'observation_unit_polygon_red_edge_background_removed_threshold_imagery' => 1, #77997, 77710
        # 'observation_unit_polygon_green_imagery' => 1, #77983, 77696
        # 'observation_unit_polygon_red_imagery' => 1, #77984, 77697
        # 'observation_unit_polygon_red_edge_imagery' => 1, #77985, 77698
        # 'observation_unit_polygon_nir_imagery' => 1, #77986, 77699
        'observation_unit_polygon_nir_background_removed_threshold_imagery' => 1, #77998, 77711
        #'observation_unit_polygon_vari_imagery' => 1, #78003, 77716
        #'observation_unit_polygon_ndvi_imagery' => 1, #78004, 77717
        # 'observation_unit_polygon_ndre_imagery' => 1, #78005, 77718
        #'observation_unit_polygon_background_removed_ndre_imagery' => 1, #78009, 77722
    );
}

sub _get_standard_9_polygon_types {
    return (
        'observation_unit_polygon_rgb_imagery' => 1, #77976, 77689
        'observation_unit_polygon_nrn_imagery' => 1, #77980, 77693
        'observation_unit_polygon_nren_imagery' => 1, #77981, 77694
        # 'observation_unit_polygon_green_background_removed_threshold_imagery' => 1, #77995, 77708
        # 'observation_unit_polygon_red_background_removed_threshold_imagery' => 1, #77996, 77709
        'observation_unit_polygon_red_edge_background_removed_threshold_imagery' => 1, #77997, 77710
        # 'observation_unit_polygon_green_imagery' => 1, #77983, 77696
        # 'observation_unit_polygon_red_imagery' => 1, #77984, 77697
        # 'observation_unit_polygon_red_edge_imagery' => 1, #77985, 77698
        # 'observation_unit_polygon_nir_imagery' => 1, #77986, 77699
        'observation_unit_polygon_nir_background_removed_threshold_imagery' => 1, #77998, 77711
        'observation_unit_polygon_vari_imagery' => 1, #78003, 77716
        'observation_unit_polygon_ndvi_imagery' => 1, #78004, 77717
        'observation_unit_polygon_ndre_imagery' => 1, #78005, 77718
        'observation_unit_polygon_tgi_imagery' => 1, #78005, 77718
        #'observation_unit_polygon_background_removed_ndre_imagery' => 1, #78009, 77722
    );
}

sub _get_standard_ndvi_ndre_polygon_types {
    return (
        'observation_unit_polygon_red_imagery' => 1, #77984, 77697
        'observation_unit_polygon_red_edge_imagery' => 1, #77985, 77698
        'observation_unit_polygon_nir_imagery' => 1, #77986, 77699
    );
}

sub get_plot_polygon_types : Path('/api/drone_imagery/plot_polygon_types') : ActionClass('REST') { }
sub get_plot_polygon_types_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $checkbox_select_standard_ndvi_ndre = $c->req->param('checkbox_select_standard_ndvi_ndre');
    my $checkbox_select_standard_4 = $c->req->param('checkbox_select_standard_4');
    my $checkbox_select_standard_9 = $c->req->param('checkbox_select_standard_9');
    my $field_trial_ids = $c->req->param('field_trial_ids');
    my $stock_ids = $c->req->param('stock_ids');
    my $field_trial_images_only = $c->req->param('field_trial_images_only');
    my $field_trial_images_only_2d = $c->req->param('field_trial_images_only_2d');
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json $c->req->param('drone_run_ids') : [];
    my $drone_run_band_ids = $c->req->param('drone_run_band_ids') ? decode_json $c->req->param('drone_run_band_ids') : [];

    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id_list_sql;
    if ($field_trial_images_only_2d) {
        my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
        my @image_type_ids;
        while (my ($key, $val) = each %$project_image_type_id_list) {
            if (scalar(@{$val->{channels}}) == 1) {
                push @image_type_ids, $key;
            }
        }
        $project_image_type_id_list_sql = join ",", @image_type_ids;
    }
    elsif (!$field_trial_images_only) {
        my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
        $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);
    }
    else {
        my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($bcs_schema);
        $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);
    }

    my %standard_ndvi_ndre = _get_standard_ndvi_ndre_polygon_types();
    my %standard_4 = _get_standard_4_polygon_types();
    my %standard_9 = _get_standard_9_polygon_types();

    my @where_clause;
    push @where_clause, "project_md_image.type_id in ($project_image_type_id_list_sql)";

    if ($field_trial_ids) {
        push @where_clause, "field_trial.project_id IN ($field_trial_ids)";
    }
    if ($drone_run_ids && scalar(@$drone_run_ids)>0) {
        my $sql = join ("," , @$drone_run_ids);
        push @where_clause, "drone_run.project_id IN ($sql)";
    }
    if ($drone_run_band_ids && scalar(@$drone_run_band_ids)>0) {
        my $sql = join ("," , @$drone_run_band_ids);
        push @where_clause, "drone_run_band.project_id IN ($sql)";
    }
    my $stock_image_join = '';
    if ($stock_ids) {
        my @stock_ids_array = split ',', $stock_ids;
        my $stock_id_sql = join (",", @stock_ids_array);
        $stock_image_join = 'JOIN metadata.md_image AS md_image ON (md_image.image_id=project_md_image.image_id) JOIN phenome.stock_image AS stock_image ON (md_image.image_id=stock_image.image_id)';
        push @where_clause, "stock_image.stock_id IN ($stock_id_sql)";
    }
    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, count(project_md_image.image_id)
        FROM project AS drone_run_band
        LEFT JOIN projectprop AS drone_run_band_type ON (drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_project_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band.project_id = drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_project_relationship_type_id)
        JOIN project AS drone_run ON (drone_run.project_id=drone_run_band_rel.object_project_id)
        LEFT JOIN projectprop AS drone_run_type ON (drone_run.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=field_trial_rel.object_project_id)
        JOIN phenome.project_md_image AS project_md_image ON (drone_run_band.project_id = project_md_image.project_id)
        JOIN cvterm AS project_md_image_type ON (project_md_image_type.cvterm_id = project_md_image.type_id)
        $stock_image_join
        $where_clause
        GROUP BY drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name
        ORDER BY drone_run_band.project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $project_md_image_type_id, $project_md_image_type_name, $plot_polygon_count) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            my $input = "<input type='checkbox' name='$checkbox_select_name' value='$project_md_image_type_id' ";
            if ($checkbox_select_all) {
                $input .= "checked";
            }
            elsif ($checkbox_select_standard_4) {
                if (exists($standard_4{$project_md_image_type_name})) {
                    $input .= "checked disabled";
                }
                else {
                    $input .= "disabled";
                }
            }
            elsif ($checkbox_select_standard_9) {
                if (exists($standard_9{$project_md_image_type_name})) {
                    $input .= "checked disabled";
                }
                else {
                    $input .= "disabled";
                }
            }
            elsif ($checkbox_select_standard_ndvi_ndre) {
                if (exists($standard_ndvi_ndre{$project_md_image_type_name})) {
                    $input .= "checked disabled";
                }
                else {
                    $input .= "disabled";
                }
            }
            $input .= ">";
            push @res, $input;
        }
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $drone_run_project_name,
            $drone_run_band_project_name,
            $drone_run_band_type,
            $project_md_image_type_name,
            $plot_polygon_count
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}


# jQuery('#drone_image_upload_drone_bands_table').DataTable({
#     destroy : true,
#     ajax : '/api/drone_imagery/drone_run_bands?select_checkbox_name=upload_drone_imagery_drone_run_band_select&drone_run_project_id='+drone_run_project_id
# });
sub get_drone_run_band_projects : Path('/api/drone_imagery/drone_run_bands') : ActionClass('REST') { }
sub get_drone_run_band_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_project_ids = $c->req->param('drone_run_project_ids') ? decode_json $c->req->param('drone_run_project_ids') : [];
    my $exclude_drone_run_band_project_id = $c->req->param('exclude_drone_run_band_project_id') || 0;
    my $select_all = $c->req->param('select_all') || 0;
    my $disable = $c->req->param('disable') || 0;

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($drone_run_project_id) {
        $where_clause = ' WHERE project.project_id = '.$drone_run_project_id.' ';
    }
    if ($drone_run_project_ids && scalar(@$drone_run_project_ids)>0) {
        my $sql = join ",", @$drone_run_project_ids;
        $where_clause = ' WHERE project.project_id IN ('.$sql.') ';
    }

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, project.project_id, project.name, project.description, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description) = $h->fetchrow_array()) {
        my @res;
        if ($drone_run_band_project_id != $exclude_drone_run_band_project_id) {
            my $background_removed_threshold_type;
            if ($drone_run_band_type eq 'Blue (450-520nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_blue';
            }
            elsif ($drone_run_band_type eq 'Green (515-600nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_green';
            }
            elsif ($drone_run_band_type eq 'Red (600-690nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_red';
            }
            elsif ($drone_run_band_type eq 'Red Edge (690-750nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_red_edge';
            }
            elsif ($drone_run_band_type eq 'NIR (780-3000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_nir';
            }
            elsif ($drone_run_band_type eq 'MIR (3000-50000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_mir';
            }
            elsif ($drone_run_band_type eq 'FIR (50000-1000000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_fir';
            }
            elsif ($drone_run_band_type eq 'Thermal IR (9000-14000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_tir';
            }
            elsif ($drone_run_band_type eq 'Black and White Image') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_bw';
            }
            elsif ($drone_run_band_type eq 'RGB Color Image') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_rgb_channel_1,threshold_background_removed_stitched_drone_imagery_rgb_channel_2,threshold_background_removed_stitched_drone_imagery_rgb_channel_3';
            }
            if ($checkbox_select_name){
                my $checked = $select_all ? 'checked' : '';
                my $disabled = $disable ? 'disabled' : '';
                my $extra_data = $background_removed_threshold_type ? "data-background_removed_threshold_type='$background_removed_threshold_type'" : '';
                push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_band_project_id' $extra_data $checked $disabled>";
            }
            my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
            push @res, (
                $drone_run_band_name,
                $drone_run_band_description,
                $drone_run_band_type,
                $drone_run_project_name,
                $drone_run_project_description,
                $drone_run_date_display,
                "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
                $field_trial_project_description
            );
            push @result, \@res;
        }
    }

    $c->stash->{rest} = { data => \@result };
}

sub get_week_after_planting_date : Path('/api/drone_imagery/get_weeks_after_planting_date') : ActionClass('REST') { }
sub get_week_after_planting_date_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');

    $c->stash->{rest} = _perform_get_weeks_drone_run_after_planting($schema, $drone_run_project_id);
}

sub _perform_get_weeks_drone_run_after_planting {
    my $schema = shift;
    my $drone_run_project_id = shift;

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my $drone_run_date_rs = $schema->resultset('Project::Projectprop')->search({project_id=>$drone_run_project_id, type_id=>$project_start_date_type_id});
    if ($drone_run_date_rs->count != 1) {
        return { error => 'There is no drone run date saved! This should not be possible, please contact us; however you can still select the time manually.'};
    }
    my $drone_run_date = $drone_run_date_rs->first->value;
    my $drone_date = $calendar_funcs->display_start_date($drone_run_date);

    my $field_trial_rs = $schema->resultset("Project::ProjectRelationship")->search({subject_project_id=>$drone_run_project_id, type_id=>$project_relationship_type_id});
    if ($field_trial_rs->count != 1) {
        return { drone_run_date => $drone_date, error => 'There is no field trial saved to the drone run! This should not be possible, please contact us; however you can still select the time manually'};
    }
    my $trial_id = $field_trial_rs->first->object_project_id;
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $planting_date = $trial->get_planting_date();

    my $drone_date_time_object = Time::Piece->strptime($drone_date, "%Y-%B-%d");
    my $drone_date_full_calendar_datetime = $drone_date_time_object->strftime("%Y/%m/%d %H:%M:%S");

    if (!$planting_date) {
        return { drone_run_date => $drone_date, drone_run_date_calendar => $drone_date_full_calendar_datetime, error => 'The planting date is not set on the field trial, so we could not get the time of this flight automaticaly; however you can still select the time manually'};
    }

    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $planting_date_full_calendar_datetime = $planting_date_time_object->strftime("%Y/%m/%d %H:%M:%S");
    my $time_diff = $drone_date_time_object - $planting_date_time_object;
    my $time_diff_weeks = $time_diff->weeks;
    my $time_diff_days = $time_diff->days;
    my $rounded_time_diff_weeks = round($time_diff_weeks);
    if ($rounded_time_diff_weeks == 0) {
        $rounded_time_diff_weeks = 1;
    }
    print STDERR Dumper $rounded_time_diff_weeks;

    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute("week $rounded_time_diff_weeks", 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    $h->execute("day $time_diff_days", 'cxgn_time_ontology');
    my ($day_cvterm_id) = $h->fetchrow_array();

    if (!$week_cvterm_id) {
        return { planting_date => $planting_date, planting_date_calendar => $planting_date_full_calendar_datetime, drone_run_date => $drone_date, drone_run_date_calendar => $drone_date_full_calendar_datetime, time_difference_weeks => $time_diff_weeks, time_difference_days => $time_diff_days, rounded_time_difference_weeks => $rounded_time_diff_weeks, error => 'The time ontology term was not found automatically! Maybe the field trial planting date or the drone run date are not correct in the database? The maximum number of weeks currently allowed between these two dates is 54 weeks. This should not be possible, please contact us; however you can still select the time manually'};
    }

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
    my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

    return { planting_date => $planting_date, planting_date_calendar => $planting_date_full_calendar_datetime, drone_run_date => $drone_date, drone_run_date_calendar => $drone_date_full_calendar_datetime, time_difference_weeks => $time_diff_weeks, time_difference_days => $time_diff_days, rounded_time_difference_weeks => $rounded_time_diff_weeks, time_ontology_week_cvterm_id => $week_cvterm_id, time_ontology_week_term => $week_term, time_ontology_day_cvterm_id => $day_cvterm_id, time_ontology_day_term => $day_term};
}

sub standard_process_apply : Path('/api/drone_imagery/standard_process_apply') : ActionClass('REST') { }
sub standard_process_apply_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $apply_drone_run_band_project_ids = decode_json $c->req->param('apply_drone_run_band_project_ids');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $vegetative_indices = decode_json $c->req->param('vegetative_indices');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $standard_process_type = $c->req->param('standard_process_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash;
    foreach (@$vegetative_indices) {
        $vegetative_indices_hash{$_}++;
    }

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        WHERE drone_run_band.project_id = $drone_run_band_project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name) = $h->fetchrow_array();

    my %selected_drone_run_band_types;
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $q2 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE project_md_image.type_id = $project_image_type_id
        AND drone_run_band.project_id = ?
        AND metadata.md_image.obsolete = 'f';";

    my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
    $h2->execute($drone_run_band_project_id);
    my ($image_id, $drone_run_band_type, $drone_run_band_project_id_q) = $h2->fetchrow_array();
    $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id_q;

    my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

    my %drone_run_band_info;
    foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {
        my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
        $h2->execute($apply_drone_run_band_project_id);
        my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h2->fetchrow_array();
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

        my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
        my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
        $archive_rotate_temp_image .= '.png';

        my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
        my $rotated_image_id = $rotate_return->{rotated_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
        $archive_temp_image .= '.png';

        my $cropping_return = _perform_image_cropping($c, $bcs_schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image);
        my $cropped_image_id = $cropping_return->{cropped_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
        my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
        $archive_denoise_temp_image .= '.png';

        my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
        my $denoised_image_id = $denoise_return->{denoised_image_id};

        $drone_run_band_info{$drone_run_band_project_id} = {
            original_denoised_image_id => $denoised_image_id,
            rotate_value => $rotate_value,
            cropping_value => $cropping_value,
            drone_run_band_type => $drone_run_band_type,
            drone_run_project_id => $drone_run_project_id,
            drone_run_project_name => $drone_run_project_name,
            plot_polygons_value => $plot_polygons_value
        };

        my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
        my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
        my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

        foreach (@denoised_plot_polygon_type) {
            my $plot_polygon_original_denoised_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0, 0);
        }

        for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
            $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
            my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
            $archive_remove_background_temp_image .= '.png';

            my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0);
        }
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_minimal_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role);

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub standard_process_minimal_vi_apply : Path('/api/drone_imagery/standard_process_minimal_vi_apply') : ActionClass('REST') { }
sub standard_process_minimal_vi_apply_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my $extended_process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $extended_processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_extended_completed', 'project_property')->cvterm_id();
    my $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash = (
        'TGI' => 1,
        'VARI' => 1,
        'NDVI' => 1,
        'NDRE' => 1
    );

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my %selected_drone_run_band_types;
    my %drone_run_band_info;
    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name, drone_run_band.project_id, drone_run_band.name, drone_run_band_type.value, project_md_image.image_id
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = $project_image_type_id)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE drone_run.project_id = $drone_run_project_id_input
        AND metadata.md_image.obsolete = 'f';";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name, $drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_type, $denoised_image_id) = $h->fetchrow_array()) {
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;
        $drone_run_band_info{$drone_run_band_project_id} = {
            drone_run_project_id => $drone_run_project_id,
            drone_run_project_name => $drone_run_project_name,
            drone_run_band_project_id => $drone_run_band_project_id,
            drone_run_band_project_name => $drone_run_band_project_name,
            drone_run_band_type => $drone_run_band_type,
            rotate_value => $rotate_value,
            plot_polygons_value => $plot_polygons_value,
            cropping_value => $cropping_value,
            original_denoised_image_id => $denoised_image_id
        };
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_minimal_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role);

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    _perform_extended_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role);

    $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub standard_process_extended_apply : Path('/api/drone_imagery/standard_process_extended_apply') : ActionClass('REST') { }
sub standard_process_extended_apply_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_days_cvterm_id');
    my $standard_process_type = $c->req->param('standard_process_type');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_extended_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash = (
        'TGI' => 1,
        'VARI' => 1,
        'NDVI' => 1,
        'NDRE' => 1
    );

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my %selected_drone_run_band_types;
    my %drone_run_band_info;
    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name, drone_run_band.project_id, drone_run_band.name, drone_run_band_type.value, project_md_image.image_id
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = $project_image_type_id)
        WHERE drone_run.project_id = $drone_run_project_id_input;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name, $drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_type, $denoised_image_id) = $h->fetchrow_array()) {
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;
        $drone_run_band_info{$drone_run_band_project_id} = {
            drone_run_project_name => $drone_run_project_name,
            drone_run_band_project_id => $drone_run_band_project_id,
            drone_run_band_project_name => $drone_run_band_project_name,
            drone_run_band_type => $drone_run_band_type,
            rotate_value => $rotate_value,
            plot_polygons_value => $plot_polygons_value,
            cropping_value => $cropping_value,
            denoised_image_id => $denoised_image_id
        };
    }

    my $original_denoised_imagery_terms = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

    my $q2 = "SELECT project_md_image.image_id
        FROM project AS drone_run_band
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = ?)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE drone_run_band.project_id = ?
        AND metadata.md_image.obsolete = 'f';";

    my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
    foreach (keys %drone_run_band_info) {
        my $threshold_term = $original_denoised_imagery_terms->{$drone_run_band_info{$_}->{drone_run_band_type}}->{imagery_types}->{threshold_background};
        if ($threshold_term) {
            my $image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $threshold_term, 'project_md_image')->cvterm_id();
            $h2->execute($image_type_id, $_);
            my ($threshold_image_id) = $h2->fetchrow_array();
            $drone_run_band_info{$_}->{thresholded_image_id} = $threshold_image_id;
        }
    }

    foreach my $drone_run_band_project_id (keys %drone_run_band_info) {
        my $image_id = $drone_run_band_info{$drone_run_band_project_id}->{denoised_image_id};
        my $drone_run_band_type = $drone_run_band_info{$drone_run_band_project_id}->{drone_run_band_type};
        my $denoised_image_id = $drone_run_band_info{$drone_run_band_project_id}->{denoised_image_id};
        my $plot_polygons_value = $drone_run_band_info{$drone_run_band_project_id}->{plot_polygons_value};
        my $background_removed_threshold_image_id = $drone_run_band_info{$drone_run_band_project_id}->{thresholded_image_id};

        if ($original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{20}) {
            my @ft_hpf20_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{20}};
            my @ft_hpf30_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{30}};
            my @ft_hpf40_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{40}};
            my @ft_hpf20_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{20}};
            my @ft_hpf30_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{30}};
            my @ft_hpf40_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{40}};
            my @ft_hpf20_background_threshold_removed_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{'20_threshold_background'}};
            my @ft_hpf30_background_threshold_removed_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{'30_threshold_background'}};
            my @ft_hpf40_background_threshold_removed_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{'40_threshold_background'}};
            my @ft_hpf20_background_threshold_removed_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{'20_threshold_background'}};
            my @ft_hpf30_background_threshold_removed_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{'30_threshold_background'}};
            my @ft_hpf40_background_threshold_removed_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{'40_threshold_background'}};

            for my $iterator (0..(scalar(@ft_hpf20_imagery_types)-1)) {
                _perform_extended_base_standard_process($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_imagery_types[$iterator], $ft_hpf20_plot_polygon_types[$iterator], $ft_hpf30_imagery_types[$iterator], $ft_hpf30_plot_polygon_types[$iterator], $ft_hpf40_imagery_types[$iterator], $ft_hpf40_plot_polygon_types[$iterator], $background_removed_threshold_image_id, $ft_hpf20_background_threshold_removed_imagery_types[$iterator], $ft_hpf20_background_threshold_removed_plot_polygon_types[$iterator], $ft_hpf30_background_threshold_removed_imagery_types[$iterator], $ft_hpf30_background_threshold_removed_plot_polygon_types[$iterator], $ft_hpf40_background_threshold_removed_imagery_types[$iterator], $ft_hpf40_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role);
            }
        }
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_extended_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role);

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);

    $c->stash->{rest} = {success => 1};
}

sub _perform_standard_process_minimal_vi_calc {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $denoised_image_id = shift;
    my $merged_drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $plot_polygons_value = shift;
    my $vi = shift;
    my $bands = shift;

    my $vi_map_hash = CXGN::DroneImagery::ImageTypes::get_vegetative_index_image_type_term_map();
    my %vi_map = %$vi_map_hash;

    my $index_return = _perform_vegetative_index_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $vi, 0, $bands, $user_id, $user_name, $user_role);
    my $index_image_id = $index_return->{index_image_id};

    my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{index}->{(%{$vi_map{$vi}->{index}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
}

sub _perform_standard_process_extended_vi_calc {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $denoised_image_id = shift;
    my $merged_drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $plot_polygons_value = shift;
    my $vi = shift;
    my $bands = shift;

    my $vi_map_hash = CXGN::DroneImagery::ImageTypes::get_vegetative_index_image_type_term_map();
    my %vi_map = %$vi_map_hash;
    my $index_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, (%{$vi_map{$vi}->{index}})[0], 'project_md_image')->cvterm_id();
    my $q = "SELECT project_md_image.image_id
            FROM project AS drone_run_band
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = $index_image_type_id)
            JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
            WHERE drone_run_band.project_id = $merged_drone_run_band_project_id
            AND metadata.md_image.obsolete = 'f';";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($index_image_id) = $h->fetchrow_array();

    #my $fourier_transform_hpf20_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20}->{(%{$vi_map{$vi}->{ft_hpf20}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30}->{(%{$vi_map{$vi}->{ft_hpf30}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40}->{(%{$vi_map{$vi}->{ft_hpf40}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{index_threshold_background}})[0], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
    my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

    my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{index_threshold_background}->{(%{$vi_map{$vi}->{index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf20_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_index_threshold_background}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf20_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_index_threshold_background}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf30_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_index_threshold_background}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf40_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $threshold_masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0], $user_id, $user_name, $user_role);
    #my $threshold_masked_image_id = $threshold_masked_return->{masked_image_id};

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[1], $user_id, $user_name, $user_role, 0, 0);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[2], $user_id, $user_name, $user_role, 0, 0);

    #if ($vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[3]) {
    #    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[3], $user_id, $user_name, $user_role, 0, 0);
    #}

    #my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #if ($vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf20_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #}

    #if ($vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf30_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #}

    #if ($vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf40_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #}

    # my $masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{original_index_mask_background}})[0], $user_id, $user_name, $user_role);
    # my $masked_image_id = $masked_return->{masked_image_id};

    # $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #
    # $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[1], $user_id, $user_name, $user_role, 0, 0);
    #
    # $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[2], $user_id, $user_name, $user_role, 0, 0);
    #
    # if ($vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[3]) {
    #     $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[3], $user_id, $user_name, $user_role, 0, 0);
    # }

    #my $fourier_transform_hpf20_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf20_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);

    #if ($vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf20_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf20_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #}

    #if ($vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf30_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf30_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #}

    #if ($vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf40_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf40_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0);
    #}
}

sub _perform_extended_base_standard_process {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $denoised_image_id = shift;
    my $drone_run_band_project_id = shift;
    my $plot_polygons_value = shift;
    my $ft_hpf20_imagery_type = shift;
    my $ft_hpf20_plot_polygon_type = shift;
    my $ft_hpf30_imagery_type = shift;
    my $ft_hpf30_plot_polygon_type = shift;
    my $ft_hpf40_imagery_type = shift;
    my $ft_hpf40_plot_polygon_type = shift;
    my $background_removed_threshold_image_id = shift;
    my $ft_hpf20_background_threshold_removed_imagery_type = shift;
    my $ft_hpf20_background_threshold_removed_plot_polygon_type = shift;
    my $ft_hpf30_background_threshold_removed_imagery_type = shift;
    my $ft_hpf30_background_threshold_removed_plot_polygon_type = shift;
    my $ft_hpf40_background_threshold_removed_imagery_type = shift;
    my $ft_hpf40_background_threshold_removed_plot_polygon_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    #my $fourier_transform_hpf20_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf20_imagery_type, '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf30_imagery_type, '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf30_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf40_imagery_type, '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf40_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf20_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf20_background_threshold_removed_imagery_type, '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf30_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf30_background_threshold_removed_imagery_type, '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf30_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0);

    #my $fourier_transform_hpf40_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf40_background_threshold_removed_imagery_type, '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf40_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0);
}

sub _perform_minimal_vi_standard_process {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $vegetative_indices = shift;
    my $selected_drone_run_band_types = shift;
    my $drone_run_band_info = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    if (exists($vegetative_indices->{'TGI'}) || exists($vegetative_indices->{'VARI'})) {
        if(exists($selected_drone_run_band_types->{'Blue (450-520nm)'}) && exists($selected_drone_run_band_types->{'Green (515-600nm)'}) && exists($selected_drone_run_band_types->{'Red (600-690nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{drone_run_project_id}, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{drone_run_project_name}, $selected_drone_run_band_types->{'Blue (450-520nm)'}, $selected_drone_run_band_types->{'Green (515-600nm)'}, $selected_drone_run_band_types->{'Red (600-690nm)'}, 'BGR', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{rotate_value}, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{cropping_value}, $user_id, $user_name, $user_role, $archive_temp_image);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_rgb_imagery', $user_id, $user_name, $user_role, 0, 0);

            if (exists($vegetative_indices->{'TGI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'TGI', 'BGR');
            }
            if (exists($vegetative_indices->{'VARI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'VARI', 'BGR');
            }
        }
        if (exists($selected_drone_run_band_types->{'RGB Color Image'})) {
            if (exists($vegetative_indices->{'TGI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{original_denoised_image_id}, $selected_drone_run_band_types->{'RGB Color Image'}, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'TGI', 'BGR');
            }
            if (exists($vegetative_indices->{'VARI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{original_denoised_image_id}, $selected_drone_run_band_types->{'RGB Color Image'}, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'VARI', 'BGR');
            }
        }
    }
    if (exists($vegetative_indices->{'NDVI'})) {
        if(exists($selected_drone_run_band_types->{'NIR (780-3000nm)'}) && exists($selected_drone_run_band_types->{'Red (600-690nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_id}, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_name}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, $selected_drone_run_band_types->{'Red (600-690nm)'}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, 'NRN', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{rotate_value}, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{cropping_value}, $user_id, $user_name, $user_role, $archive_temp_image);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_nrn_imagery', $user_id, $user_name, $user_role, 0, 0);

            _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'NDVI', 'NRN');
        }
    }
    if (exists($vegetative_indices->{'NDRE'})) {
        if(exists($selected_drone_run_band_types->{'NIR (780-3000nm)'}) && exists($selected_drone_run_band_types->{'Red Edge (690-750nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_id}, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_name}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, $selected_drone_run_band_types->{'Red Edge (690-750nm)'}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, 'NReN', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{rotate_value}, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{cropping_value}, $user_id, $user_name, $user_role, $archive_temp_image);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_nren_imagery', $user_id, $user_name, $user_role, 0, 0);

            _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'NDRE', 'NReN');
        }
    }
}

sub _perform_extended_vi_standard_process {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $vegetative_indices = shift;
    my %vegetative_indices_hash = %$vegetative_indices;
    my $selected_drone_run_band_types_input = shift;
    my %selected_drone_run_band_types = %$selected_drone_run_band_types_input;
    my $drone_run_band_info = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    if (exists($vegetative_indices_hash{'TGI'}) || exists($vegetative_indices_hash{'VARI'})) {
        if(exists($selected_drone_run_band_types{'Merged 3 Bands BGR'}) ) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'Merged 3 Bands BGR'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            if (exists($vegetative_indices_hash{'TGI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'TGI', 'BGR');
            }
            if (exists($vegetative_indices_hash{'VARI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $selected_drone_run_band_types{'Merged 3 Bands BGR'}, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'VARI', 'BGR');
            }
        }
        if (exists($selected_drone_run_band_types{'RGB Color Image'})) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'RGB Color Image'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            if (exists($vegetative_indices_hash{'TGI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'TGI', 'BGR');
            }
            if (exists($vegetative_indices_hash{'VARI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'VARI', 'BGR');
            }
        }
    }
    if (exists($vegetative_indices_hash{'NDVI'})) {
        if(exists($selected_drone_run_band_types{'Merged 3 Bands NRN'}) ) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'Merged 3 Bands NRN'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'NDVI', 'NRN');
        }
    }
    if (exists($vegetative_indices_hash{'NDRE'})) {
        if(exists($selected_drone_run_band_types{'Merged 3 Bands NReN'}) ) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'Merged 3 Bands NReN'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'NDRE', 'NReN');
        }
    }
}

sub get_project_md_image : Path('/api/drone_imagery/get_project_md_image') : ActionClass('REST') { }
sub get_project_md_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $project_image_type_name = $c->req->param('project_image_type_name');

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $project_image_type_name, 'project_md_image')->cvterm_id();

    my $q = "SELECT project_md_image.image_id
        FROM project AS drone_run_band
        JOIN phenome.project_md_image AS project_md_image USING(project_id)
        WHERE project_md_image.type_id = $project_image_type_id AND project_id = $drone_run_band_project_id
        ORDER BY project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($image_id) = $h->fetchrow_array()) {
        push @result, {
            image_id => $image_id
        };
    }

    $c->stash->{rest} = { data => \@result };
}

sub drone_imagery_get_image : Path('/api/drone_imagery/get_image') : ActionClass('REST') { }
sub drone_imagery_get_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $size = $c->req->param('size') || 'original';
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url($size);
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    my @size = imgsize($image_fullpath);

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        image_id_list=>[$image_id],
    });
    my ($result, $total_count) = $images_search->search();
    my $drone_run_band_project_id = $result->[0]->{drone_run_band_project_id};

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, image_width => $size[0], image_height => $size[1], drone_run_band_project_id => $drone_run_band_project_id };
}

sub drone_imagery_remove_image : Path('/api/drone_imagery/remove_image') : ActionClass('REST') { }
sub drone_imagery_remove_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $resp = $image->delete(); #Sets to obsolete

    $c->stash->{rest} = { status => $resp };
}

sub drone_imagery_crop_image : Path('/api/drone_imagery/crop_image') : ActionClass('REST') { }
sub drone_imagery_crop_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $polygon = $c->req->param('polygon');
    my $polygon_obj = decode_json $polygon;
    if (scalar(@$polygon_obj) != 4){
        $c->stash->{rest} = {error=>'Polygon should be 4 long!'};
        $c->detach();
    }
    my $polygons = encode_json [$polygon_obj];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $return = _perform_image_cropping($c, $schema, $drone_run_band_project_id, $image_id, $polygons, $user_id, $user_name, $user_role, $archive_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_cropping {
    my $c = shift;
    my $schema = shift;
    my $drone_run_band_project_id = shift;
    my $image_id = shift;
    my $polygons = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_temp_image = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageCropping/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_temp_image' --polygon_json '$polygons' --polygon_type rectangular_square";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_cropped_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_cropped_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $cropped_image_fullpath = $image->get_filename('original_converted', 'full');
    my $cropped_image_url = $image->get_image_url('original');
    my $cropped_image_id = $image->get_image_id();

    my $drone_run_band_cropped_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $drone_run_band_cropped_polygon = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_cropped_polygon_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>$polygons
    },
    {
        key=>'projectprop_c1'
    });

    unlink($archive_temp_image);
    return {
        cropped_image_id => $cropped_image_id, image_url => $image_url, image_fullpath => $image_fullpath, cropped_image_url => $cropped_image_url, cropped_image_fullpath => $cropped_image_fullpath
    };
}

sub drone_imagery_calculate_fourier_transform : Path('/api/drone_imagery/calculate_fourier_transform') : ActionClass('REST') { }
sub drone_imagery_calculate_fourier_transform_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $image_type = $c->req->param('image_type');
    my $high_pass_filter = $c->req->param('high_pass_filter');
    my $high_pass_filter_type = $c->req->param('high_pass_filter_type') || 'frequency';

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_fourier_transform_calculation($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $image_type, $high_pass_filter, $high_pass_filter_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_fourier_transform_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type;
    my $image_type = shift;
    my $high_pass_filter = shift;
    my $high_pass_filter_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    print STDERR "FT Linking Table Type: $image_type\n";
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type, 'project_md_image')->cvterm_id();
    my $image_channel_lookup = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($schema)->{$linking_table_type_id}->{corresponding_channel};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_fourier_transform_hpf_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_fourier_transform_hpf_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/FourierTransform.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image' --image_band_index ".$image_channel_lookup." --frequency_threshold $high_pass_filter --frequency_threshold_method $high_pass_filter_type";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $ft_image_fullpath;
    my $ft_image_url;
    my $ft_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $ft_image_fullpath = $image->get_filename('original_converted', 'full');
        $ft_image_url = $image->get_image_url('original');
        $ft_image_id = $image->get_image_id();
    } else {
        my $previous_index_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_result, $previous_total_count) = $previous_index_images_search->search();
        foreach (@$previous_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $ft_image_fullpath = $image->get_filename('original_converted', 'full');
        $ft_image_url = $image->get_image_url('original');
        $ft_image_id = $image->get_image_id();
    }

    unlink($archive_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, ft_image_id => $ft_image_id, ft_image_url => $ft_image_url, ft_image_fullpath => $ft_image_fullpath
    };
}

sub drone_imagery_calculate_vegetative_index : Path('/api/drone_imagery/calculate_vegetative_index') : ActionClass('REST') { }
sub drone_imagery_calculate_vegetative_index_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $vegetative_index = $c->req->param('vegetative_index');
    my $image_type = $c->req->param('image_type');
    my $view_only = $c->req->param('view_only');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_vegetative_index_calculation($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $vegetative_index, $view_only, $image_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_vegetative_index_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $vegetative_index = shift;
    my $view_only = shift;
    my $image_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $index_script = '';
    my $linking_table_type_id;
    if ($image_type eq 'BGR') {
        if ($vegetative_index eq 'TGI') {
            $index_script = 'TGI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
        if ($vegetative_index eq 'VARI') {
            $index_script = 'VARI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    elsif ($image_type eq 'NRN') {
        if ($vegetative_index eq 'NDVI') {
            $index_script = 'NDVI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    elsif ($image_type eq 'NReN') {
        if ($vegetative_index eq 'NDRE') {
            $index_script = 'NDRE';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    if (!$linking_table_type_id) {
        die "Could not get vegetative index image type id\n";
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_vegetative_index_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_vegetative_index_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/VegetativeIndex/$index_script.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $index_image_fullpath;
    my $index_image_url;
    my $index_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($view_only == 1 && $saved_image_id) {
        print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    } else {
        my $previous_index_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_result, $previous_total_count) = $previous_index_images_search->search();
        foreach (@$previous_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    }

    unlink($archive_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, index_image_id => $index_image_id, index_image_url => $index_image_url, index_image_fullpath => $index_image_fullpath
    };
}

sub drone_imagery_mask_remove_background : Path('/api/drone_imagery/mask_remove_background') : ActionClass('REST') { }
sub drone_imagery_mask_remove_background_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $mask_image_id = $c->req->param('mask_image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $mask_type = $c->req->param('mask_type');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_image_background_remove_mask($c, $schema, $image_id, $mask_image_id, $drone_run_band_project_id, $mask_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_image_background_remove_mask {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $mask_image_id = shift;
    my $drone_run_band_project_id = shift;
    my $mask_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $mask_image = SGN::Image->new( $schema->storage->dbh, $mask_image_id, $c );
    my $mask_image_url = $mask_image->get_image_url("original");
    my $mask_image_fullpath = $mask_image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_mask_remove_background');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_mask_remove_background/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MaskRemoveBackground.py --image_path '$image_fullpath' --mask_image_path '$mask_image_fullpath' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $mask_type, 'project_md_image')->cvterm_id();;

    my $previous_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $masked_image_fullpath = $image->get_filename('original_converted', 'full');
    my $masked_image_url = $image->get_image_url('original');
    my $masked_image_id = $image->get_image_id();

    unlink($archive_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, masked_image_id => $masked_image_id, masked_image_url => $masked_image_url, masked_image_fullpath => $masked_image_fullpath
    };
}

sub drone_imagery_get_plot_polygon_images : Path('/api/drone_imagery/get_plot_polygon_images') : ActionClass('REST') { }
sub drone_imagery_get_plot_polygon_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $plot_polygons_type = $c->req->param('plot_polygons_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygons_type, 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my @image_paths;
    my @image_urls;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @image_urls, $image_url;
        push @image_paths, $image_fullpath;
    }

    $c->stash->{rest} = { image_urls => \@image_urls };
}

sub drone_imagery_merge_bands : Path('/api/drone_imagery/merge_bands') : ActionClass('REST') { }
sub drone_imagery_merge_bands_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_project_name = $c->req->param('drone_run_project_name');
    my $band_1_drone_run_band_project_id = $c->req->param('band_1_drone_run_band_project_id');
    my $band_2_drone_run_band_project_id = $c->req->param('band_2_drone_run_band_project_id');
    my $band_3_drone_run_band_project_id = $c->req->param('band_3_drone_run_band_project_id');
    my $merged_image_type = $c->req->param('merged_image_type');

    my $return = _perform_image_merge($c, $schema, $metadata_schema, $drone_run_project_id, $drone_run_project_name, $band_1_drone_run_band_project_id, $band_2_drone_run_band_project_id, $band_3_drone_run_band_project_id, $merged_image_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_image_merge {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $drone_run_project_id = shift;
    my $drone_run_project_name = shift;
    my $band_1_drone_run_band_project_id = shift;
    my $band_2_drone_run_band_project_id = shift;
    my $band_3_drone_run_band_project_id = shift;
    my $merged_image_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    if (!$band_1_drone_run_band_project_id || !$band_2_drone_run_band_project_id || !$band_3_drone_run_band_project_id) {
        $c->stash->{rest} = { error => 'Please select 3 drone run bands' };
        $c->detach();
    }
    my @drone_run_bands = ($band_1_drone_run_band_project_id, $band_2_drone_run_band_project_id, $band_3_drone_run_band_project_id);

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$project_image_type_id,
        drone_run_band_project_id_list=>\@drone_run_bands,
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my %drone_run_bands_images;
    foreach (@$result) {
        $drone_run_bands_images{$_->{drone_run_band_project_id}} = $_->{image_id};
    }
    #print STDERR Dumper \%drone_run_bands_images;

    my @image_filesnames;
    foreach (@drone_run_bands) {
        my $image = SGN::Image->new( $schema->storage->dbh, $drone_run_bands_images{$_}, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @image_filesnames, $image_fullpath;
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_merge_bands');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_merge_bands/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MergeChannels.py --image_path_band_1 '".$image_filesnames[0]."' --image_path_band_2 '".$image_filesnames[1]."' --image_path_band_3 '".$image_filesnames[2]."' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $band_1_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_1_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;
    my $band_2_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_2_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;
    my $band_3_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_3_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;

    my $merged_drone_run_band_id;
    my $project_rs_check = $schema->resultset("Project::Project")->find({
        name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)"
    });
    if ($project_rs_check) {
        $merged_drone_run_band_id = $project_rs_check->project_id;
    } else {
        my $project_rs = $schema->resultset("Project::Project")->create({
            name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)",
            description => "Merged $band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)",
            projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => 'Merged 3 Bands '.$merged_image_type}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $drone_run_project_id}]
        });
        $merged_drone_run_band_id = $project_rs->project_id();
    }

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $merged_drone_run_band_id, $linking_table_type_id);
    my $merged_image_fullpath = $image->get_filename('original_converted', 'full');
    my $merged_image_url = $image->get_image_url('original');
    my $merged_image_id = $image->get_image_id();

    unlink($archive_temp_image);
    return {
        merged_drone_run_band_project_id => $merged_drone_run_band_id, merged_image_url => $merged_image_url, merged_image_fullpath => $merged_image_fullpath, merged_image_id => $merged_image_id
    };
}

sub _perform_phenotype_automated {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $drone_run_project_id = shift;
    my $time_cvterm_id = shift;
    my $phenotype_types = shift;
    my $standard_process_type = shift;
    my $ignore_new_phenotype_values = shift;
    my $overwrite_phenotype_values = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $drone_run_phenotype_calc_progress_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_phenotype_calculation_in_progress', 'project_property')->cvterm_id();
    my $drone_run_phenotype_calc_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_phenotype_calc_progress_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $in_progress_indicator = 1;
    while ($in_progress_indicator == 1) {
        sleep(30);
        print STDERR "Waiting for drone standard image process to finish before calculating phenotypes\n";
        my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
        my $drone_run_band_remove_background_threshold_rs = $schema->resultset('Project::Projectprop')->search({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id,
        });
        $in_progress_indicator = $drone_run_band_remove_background_threshold_rs->first ? $drone_run_band_remove_background_threshold_rs->first->value() : 0;
    }

    my $project_image_type_id_map = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my %project_observation_unit_plot_polygons_types;
    while (my ($k, $v) = each %$project_image_type_id_map) {
        foreach my $p (@{$v->{drone_run_project_types}}) {
            if (!$p) {
                die "No project for ".$v->{name}."\n";
            }
            foreach my $t (@{$v->{standard_process}}) {
                if (!$t) {
                    die "No standard process type for ".$v->{name}."\n";
                }
                push @{$project_observation_unit_plot_polygons_types{$p}->{$t}}, $v->{name};
            }
        }
    }

    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band_project_type.value
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_project_type ON (drone_run_band_project_type.project_id=drone_run_band.project_id AND drone_run_band_project_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        WHERE project.project_id = ?;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);

    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_project_type) = $h->fetchrow_array()) {
        foreach my $phenotype_method (@$phenotype_types) {
            #my $pm = Parallel::ForkManager->new(floor(int($number_system_cores)*0.5));
            foreach my $plot_polygon_type (@{$project_observation_unit_plot_polygons_types{$drone_run_band_project_type}->{$standard_process_type}}) {
                #my $pid = $pm->start and next;
                my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygon_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, 1, $ignore_new_phenotype_values, $overwrite_phenotype_values);
                if ($return->{error}){
                    print STDERR Dumper $return->{error};
                }
                #$pm->finish();
            }
            #$pm->wait_all_children;
        }
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    $drone_run_phenotype_calc_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_phenotype_calc_progress_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    return {
        success => 1
    };
}

sub drone_imagery_get_drone_run_image_counts : Path('/api/drone_imagery/get_drone_run_image_counts') : ActionClass('REST') { }
sub drone_imagery_get_drone_run_image_counts_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_id = $c->req->param('drone_run_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $plot_polygon_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @plot_polygon_minimal_cvterm_ids;
    while (my ($plot_polygon_type_cvterm_id, $plot_polygon_type) = each %$plot_polygon_types) {
        my $processes = $plot_polygon_type->{standard_process};
        foreach (@$processes) {
            if ($_ eq 'minimal') {
                push @plot_polygon_minimal_cvterm_ids, $plot_polygon_type_cvterm_id;
            }
        }
    }

    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $q = "SELECT value FROM stockprop WHERE stock_id=? and type_id=$plot_number_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);

    my %plot_image_counts;
    my %plot_numbers;
    foreach my $plot_polygons_images_cvterm_id (@plot_polygon_minimal_cvterm_ids) {
        my $images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            drone_run_project_id_list=>[$drone_run_id],
            project_image_type_id=>$plot_polygons_images_cvterm_id
        });
        my ($result, $total_count) = $images_search->search();
        foreach (@$result) {
            my $plot_id = $_->{stock_id};
            my $plot_name = $_->{stock_uniquename};
            $plot_image_counts{$plot_name}->{$_->{project_image_type_name}}++;
            $h->execute($plot_id);
            my ($plot_number) = $h->fetchrow_array();
            $plot_numbers{$plot_name} = $plot_number;
        }
    }

    my @return;
    while (my ($stock_name, $obj) = each %plot_image_counts) {
        my $image_counts_string = '';
        while (my ($image_type, $count) = each %$obj) {
            $image_counts_string .= "$image_type: $count<br/>";
        }
        push @return, {plot_name => $stock_name, plot_number => $plot_numbers{$stock_name}, image_counts => $image_counts_string};
    }

    $c->stash->{rest} = {data => \@return};
}

sub drone_imagery_update_details : Path('/api/drone_imagery/update_details') : ActionClass('REST') { }
sub drone_imagery_update_details_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_date = $c->req->param('drone_run_date');
    my $description = $c->req->param('description');
    my $drone_run_name = $c->req->param('drone_run_name');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$drone_run_project_id});

    if ($drone_run_date) {
        $trial->set_drone_run_date($drone_run_date);
    }
    if ($description) {
        $trial->set_description($description);
    }
    if ($drone_run_name) {
        $trial->set_name($drone_run_name);
    }

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_calculate_phenotypes : Path('/api/drone_imagery/calculate_phenotypes') : ActionClass('REST') { }
sub drone_imagery_calculate_phenotypes_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $phenotype_method = $c->req->param('method');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $plot_polygons_type = $c->req->param('plot_polygons_type');
    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygons_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, undef, undef, 1);

    $c->stash->{rest} = $return;
}

sub drone_imagery_generate_phenotypes : Path('/api/drone_imagery/generate_phenotypes') : ActionClass('REST') { }
sub drone_imagery_generate_phenotypes_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my $standard_process_type = $c->req->param('standard_process_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my @standard_processes = split ',', $standard_process_type;
    my $return;
    foreach my $standard_process_type (@standard_processes) {
        $return = _perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id, $time_cvterm_id, $phenotype_methods, $standard_process_type, undef, 1, $user_id, $user_name, $user_role);
    }

    $c->stash->{rest} = $return;
}

sub _perform_phenotype_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type = shift;
    my $phenotype_method = shift;
    my $time_cvterm_id = shift;
    my $plot_polygons_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_delimiter = shift;
    my $composable_cvterm_format = shift;
    my $do_not_run_materialized_view_refresh = shift;
    my $ignore_new_phenotype_values = shift;
    my $overwrite_phenotype_values = shift;

    print STDERR Dumper [$drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygons_type];

    my $non_zero_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Nonzero Pixel Count|G2F:0000014')->cvterm_id;
    my $total_pixel_sum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Total Pixel Sum|G2F:0000015')->cvterm_id;
    my $mean_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Mean Pixel Value|G2F:0000016')->cvterm_id;
    my $harmonic_mean_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Harmonic Mean Pixel Value|G2F:0000017')->cvterm_id;
    my $median_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Median Pixel Value|G2F:0000018')->cvterm_id;
    my $pixel_variance_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Variance|G2F:0000019')->cvterm_id;
    my $pixel_standard_dev_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Standard Deviation|G2F:0000020')->cvterm_id;
    my $pixel_pstandard_dev_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Population Standard Deviation|G2F:0000021')->cvterm_id;
    my $minimum_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minimum Pixel Value|G2F:0000022')->cvterm_id;
    my $maximum_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Maximum Pixel Value|G2F:0000023')->cvterm_id;
    my $minority_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minority Pixel Value|G2F:0000024')->cvterm_id;
    my $minority_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minority Pixel Count|G2F:0000025')->cvterm_id;
    my $majority_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Value|G2F:0000026')->cvterm_id;
    my $majority_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Count|G2F:0000027')->cvterm_id;
    my $pixel_group_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Group Count|G2F:0000028')->cvterm_id;

    my $drone_run_band_project_type_cvterm_id;
    if ($drone_run_band_project_type eq 'Black and White Image') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Black and White Image|ISOL:0000003')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Blue (450-520nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Blue (450-520nm)|ISOL:0000004')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Green (515-600nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Green (515-600nm)|ISOL:0000005')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Red (600-690nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red (600-690nm)|ISOL:0000006')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Red Edge (690-750nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red Edge (690-750nm)|ISOL:0000007')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'NIR (780-3000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NIR (780-3000nm)|ISOL:0000008')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'MIR (3000-50000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'MIR (3000-50000nm)|ISOL:0000009')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'FIR (50000-1000000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FIR (50000-1000000nm)|ISOL:0000010')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Thermal IR (9000-14000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Thermal IR (9000-14000nm)|ISOL:0000011')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Raster DSM') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Raster DSM|ISOL:0000323')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'RGB Color Image') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'RGB Color Image|ISOL:0000002')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Merged 3 Bands BGR') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands BGR|ISOL:0000012')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Merged 3 Bands NRN') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands NRN|ISOL:0000013')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Merged 3 Bands NReN') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands NReN|ISOL:0000014')->cvterm_id;
    }

    if (!$drone_run_band_project_type_cvterm_id) {
        die "No drone run band project type term found: $drone_run_band_project_type\n";
    }

    my $observation_unit_plot_polygon_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my %isol_terms_map;
    while (my($k, $v) = each %$observation_unit_plot_polygon_types) {
        $isol_terms_map{$v->{name}} = {
            ISOL_name => $v->{ISOL_name},
            corresponding_channel => $v->{corresponding_channel},
            channels => $v->{channels}
        };
    }
    my $drone_run_band_plot_polygons_preprocess_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $isol_terms_map{$plot_polygons_type}->{ISOL_name})->cvterm_id;;
    if (!$drone_run_band_plot_polygons_preprocess_cvterm_id) {
        die "Could not get preprocess cvterm for $plot_polygons_type\n";
    }

    my $image_band_selected = $isol_terms_map{$plot_polygons_type}->{corresponding_channel};
    if (!defined($image_band_selected) && $phenotype_method eq 'zonal') {
        return {error => "No corresponding image band for this type $plot_polygons_type!"};
    }

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygons_type, 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR Dumper $total_count;

    my @header_cols;
    my @stocks;
    if ($total_count == 0) {
        return {error => "No plot polygon images for this type $plot_polygons_type!"};
    } else {

        my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
            object => [],
            attribute => [$drone_run_band_project_type_cvterm_id],
            method => [],
            unit => [],
            trait => [$non_zero_pixel_count_cvterm_id, $total_pixel_sum_cvterm_id, $mean_pixel_value_cvterm_id, $harmonic_mean_pixel_value_cvterm_id, $median_pixel_value_cvterm_id, $pixel_variance_cvterm_id, $pixel_standard_dev_cvterm_id, $pixel_pstandard_dev_cvterm_id, $minimum_pixel_value_cvterm_id, $maximum_pixel_value_cvterm_id, $minority_pixel_value_cvterm_id, $minority_pixel_count_cvterm_id, $majority_pixel_value_cvterm_id, $majority_pixel_count_cvterm_id, $pixel_group_count_cvterm_id],
            tod => [$drone_run_band_plot_polygons_preprocess_cvterm_id],
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

        my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
        my $new_terms = $onto->store_composed_term(\%new_trait_names);

        my $non_zero_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$non_zero_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $total_pixel_sum_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$total_pixel_sum_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $harmonic_mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$harmonic_mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $median_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$median_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_variance_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_variance_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_standard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_standard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_pstandard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_pstandard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minimum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minimum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $maximum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$maximum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $majority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $majority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_group_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_group_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);

        my $non_zero_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $non_zero_pixel_count_composed_cvterm_id, 'extended');
        my $total_pixel_sum_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $total_pixel_sum_composed_cvterm_id, 'extended');
        my $mean_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $mean_pixel_value_composed_cvterm_id, 'extended');
        my $harmonic_mean_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $harmonic_mean_pixel_value_composed_cvterm_id, 'extended');
        my $median_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $median_pixel_value_composed_cvterm_id, 'extended');
        my $pixel_variance_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_variance_composed_cvterm_id, 'extended');
        my $pixel_standard_dev_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_standard_dev_composed_cvterm_id, 'extended');
        my $pixel_pstandard_dev_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_pstandard_dev_composed_cvterm_id, 'extended');
        my $minimum_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minimum_pixel_value_composed_cvterm_id, 'extended');
        my $maximum_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $maximum_pixel_value_composed_cvterm_id, 'extended');
        my $majority_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minority_pixel_value_composed_cvterm_id, 'extended');
        my $majority_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minority_pixel_count_composed_cvterm_id, 'extended');
        my $minority_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $majority_pixel_value_composed_cvterm_id, 'extended');
        my $minority_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $majority_pixel_count_composed_cvterm_id, 'extended');
        my $pixel_group_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_group_count_composed_cvterm_id, 'extended');

        my $temp_images_subdir = '';
        my $temp_results_subdir = '';
        my $calculate_phenotypes_script = '';
        my $linking_table_type_id;
        my $calculate_phenotypes_extra_args = '';
        my $archive_file_type = '';
        if ($phenotype_method eq 'zonal') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_zonal_stats';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_zonal_stats_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeZonalStats.py';
            $calculate_phenotypes_extra_args = ' --image_band_index '.$image_band_selected.' --plot_polygon_type '.$plot_polygons_type. ' --margin_percent 5';
            $archive_file_type = 'zonal_statistics_image_phenotypes';
        } elsif ($phenotype_method eq 'sift') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_sift';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_sift_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeSift.py';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_sift_drone_imagery', 'project_md_image')->cvterm_id();
        } elsif ($phenotype_method eq 'orb') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_orb';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_orb_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeOrb.py';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_orb_drone_imagery', 'project_md_image')->cvterm_id();
        } elsif ($phenotype_method eq 'surf') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_surf';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_surf_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeSurf.py';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_surf_drone_imagery', 'project_md_image')->cvterm_id();
        } elsif ($phenotype_method eq 'fourier_transform') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_fourier_transform';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_fourier_transform_results';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_fourier_transform_drone_imagery', 'project_md_image')->cvterm_id();
            $calculate_phenotypes_script = 'CalculatePhenotypeFourierTransform.py';
            $calculate_phenotypes_extra_args = ' --image_band_index '.$image_band_selected.' --plot_polygon_type '.$plot_polygons_type. ' --margin_percent 5 --frequency_threshold 30 --frequency_threshold_method frequency';
            $archive_file_type = 'fourier_transform_image_phenotypes';
        }

        my @image_paths;
        my @out_paths;
        my %stock_images;
        my %stock_info;
        foreach (@$result) {
            my $image_id = $_->{image_id};
            my $stock_id = $_->{stock_id};
            my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            my $image_url = $image->get_image_url("original");
            my $image_fullpath = $image->get_filename('original_converted', 'full');
            my $image_source_tag_small = $image->get_img_src_tag("tiny");

            push @{$stock_images{$stock_id}}, $image_fullpath;
            $stock_info{$stock_id} = {
                stock_id => $stock_id,
                stock_uniquename => $_->{stock_uniquename},
                stock_type_id => $_->{stock_type_id},
                image => '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>',
                image_id => $image_id
            };
        }

        my $dir = $c->tempfiles_subdir('/drone_imagery_calculate_phenotypes_input_file_dir');
        my $temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_calculate_phenotypes_input_file_dir/fileXXXX');

        open(my $F, ">", $temp_input_file) || die "Can't open file ".$temp_input_file;
            foreach my $stock_id (sort keys %stock_images) {
                my $images_string = join ',', @{$stock_images{$stock_id}};
                print $F "$stock_id\t$images_string\n";

                if ($phenotype_method ne 'zonal') {
                    my $dir = $c->tempfiles_subdir('/'.$temp_images_subdir);
                    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_images_subdir.'/imageXXXX');
                    $archive_temp_image .= '.png';
                    push @out_paths, $archive_temp_image;
                }
            }
        close($F);

        my $out_paths_string = join ',', @out_paths;

        if ($out_paths_string) {
            $out_paths_string = ' --outfile_paths '.$out_paths_string;
        }

        $dir = $c->tempfiles_subdir('/'.$temp_results_subdir);
        my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_results_subdir.'/imageXXXX');

        my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/'.$calculate_phenotypes_script.' --image_paths_input_file \''.$temp_input_file.'\' '.$out_paths_string.' --results_outfile_path \''.$archive_temp_results.'\''.$calculate_phenotypes_extra_args;
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my $csv = Text::CSV->new({ sep_char => ',' });
        open(my $fh, '<', $archive_temp_results)
            or die "Could not open file '$archive_temp_results' $!";

            print STDERR "Opened $archive_temp_results\n";
            my $header = <$fh>;
            if ($csv->parse($header)) {
                @header_cols = $csv->fields();
            }

            my $line = 0;
            my %zonal_stat_phenotype_data;
            my %plots_seen;
            my @traits_seen;
            if ($phenotype_method eq 'zonal' || $phenotype_method eq 'fourier_transform') {
                if ($header_cols[0] ne 'stock_id' ||
                    $header_cols[1] ne 'nonzero_pixel_count' ||
                    $header_cols[2] ne 'total_pixel_sum' ||
                    $header_cols[3] ne 'mean_pixel_value' ||
                    $header_cols[4] ne 'harmonic_mean_value' ||
                    $header_cols[5] ne 'median_pixel_value' ||
                    $header_cols[6] ne 'variance_pixel_value' ||
                    $header_cols[7] ne 'stdev_pixel_value' ||
                    $header_cols[8] ne 'pstdev_pixel_value' ||
                    $header_cols[9] ne 'min_pixel_value' ||
                    $header_cols[10] ne 'max_pixel_value' ||
                    $header_cols[11] ne 'minority_pixel_value' ||
                    $header_cols[12] ne 'minority_pixel_count' ||
                    $header_cols[13] ne 'majority_pixel_value' ||
                    $header_cols[14] ne 'majority_pixel_count' ||
                    $header_cols[15] ne 'pixel_variety_count'
                ) {
                    $c->stash->{rest} = { error => "Pheno results must have header: 'stock_id', 'nonzero_pixel_count', 'total_pixel_sum', 'mean_pixel_value', 'harmonic_mean_value', 'median_pixel_value', 'variance_pixel_value', 'stdev_pixel_value', 'pstdev_pixel_value', 'min_pixel_value', 'max_pixel_value', 'minority_pixel_value', 'minority_pixel_count', 'majority_pixel_value', 'majority_pixel_count', 'pixel_variety_count'" };
                    return;
                }

                @traits_seen = (
                    $non_zero_pixel_count_composed_trait_name,
                    $total_pixel_sum_composed_trait_name,
                    $mean_pixel_value_composed_trait_name,
                    $harmonic_mean_pixel_value_composed_trait_name,
                    $median_pixel_value_composed_trait_name,
                    $pixel_variance_composed_trait_name,
                    $pixel_standard_dev_composed_trait_name,
                    $pixel_pstandard_dev_composed_trait_name,
                    $minimum_pixel_value_composed_trait_name,
                    $maximum_pixel_value_composed_trait_name,
                    $majority_pixel_value_composed_trait_name,
                    $majority_pixel_count_composed_trait_name,
                    $minority_pixel_value_composed_trait_name,
                    $minority_pixel_count_composed_trait_name,
                    $pixel_group_count_composed_trait_name
                );

                while ( my $row = <$fh> ){
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $stock_id = $columns[0];
                    my $stock_uniquename = $stock_info{$stock_id}->{stock_uniquename};
                    my $image_id = $stock_info{$stock_id}->{image_id};

                    #print STDERR Dumper \@columns;
                    $stock_info{$stock_id}->{result} = \@columns;

                    $plots_seen{$stock_uniquename} = 1;
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$non_zero_pixel_count_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$total_pixel_sum_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$mean_pixel_value_composed_trait_name} = [$columns[3], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$harmonic_mean_pixel_value_composed_trait_name} = [$columns[4], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$median_pixel_value_composed_trait_name} = [$columns[5], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_variance_composed_trait_name} = [$columns[6], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_standard_dev_composed_trait_name} = [$columns[7], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_pstandard_dev_composed_trait_name} = [$columns[8], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$minimum_pixel_value_composed_trait_name} = [$columns[9], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$maximum_pixel_value_composed_trait_name} = [$columns[10], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$minority_pixel_value_composed_trait_name} = [$columns[11], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$minority_pixel_count_composed_trait_name} = [$columns[12], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$majority_pixel_value_composed_trait_name} = [$columns[13], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$majority_pixel_count_composed_trait_name} = [$columns[14], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_group_count_composed_trait_name} = [$columns[15], $timestamp, $user_name, '', $image_id];

                    $line++;
                }
                @stocks = values %stock_info;
            }

        close $fh;
        print STDERR "Read $line lines in results file\n";

        if ($line > 0) {
            my %phenotype_metadata = (
                'archived_file' => $archive_temp_results,
                'archived_file_type' => $archive_file_type,
                'operator' => $user_name,
                'date' => $timestamp
            );
            my @plot_units_seen = keys %plots_seen;
            my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
            my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

            my $store_args = {
                basepath=>$c->config->{basepath},
                dbhost=>$c->config->{dbhost},
                dbname=>$c->config->{dbname},
                dbuser=>$c->config->{dbuser},
                dbpass=>$c->config->{dbpass},
                temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
                bcs_schema=>$schema,
                metadata_schema=>$metadata_schema,
                phenome_schema=>$phenome_schema,
                user_id=>$user_id,
                stock_list=>\@plot_units_seen,
                trait_list=>\@traits_seen,
                values_hash=>\%zonal_stat_phenotype_data,
                has_timestamps=>1,
                metadata_hash=>\%phenotype_metadata
            };

            if ($overwrite_phenotype_values) {
                $store_args->{overwrite_values} = $overwrite_phenotype_values;
            }
            if ($ignore_new_phenotype_values) {
                $store_args->{ignore_new_values} = $ignore_new_phenotype_values;
            }

            my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
                $store_args
            );
            my ($verified_warning, $verified_error) = $store_phenotypes->verify();
            my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

            if (!$do_not_run_materialized_view_refresh) {
                my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
                my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});
            }
        }

        my $count = 0;
        foreach (@out_paths) {
            my $stock = $stocks[$count];

            my $image_fullpath;
            my $image_url;
            my $image_source_tag_small;
            my $image_id;

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5checksum = $image->calculate_md5sum($_);
            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
            my ($saved_image_id) = $h->fetchrow_array();

            if ($saved_image_id) {
                print STDERR Dumper "Image $_ has already been added to the database and will not be added again.";
                $image_id = $saved_image_id;
                $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                $image_fullpath = $image->get_filename('original_converted', 'full');
                $image_url = $image->get_image_url('original');
                $image_source_tag_small = $image->get_img_src_tag("tiny");
            } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($_, 'project', $drone_run_band_project_id, $linking_table_type_id);
                $ret = $image->associate_stock($stock->{stock_id}, $user_name);
                $image_fullpath = $image->get_filename('original_converted', 'full');
                $image_url = $image->get_image_url('original');
                $image_source_tag_small = $image->get_img_src_tag("tiny");
                $image_id = $image->get_image_id;
            }

            $stocks[$count]->{image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $stocks[$count]->{image_path} = $image_fullpath;
            $stocks[$count]->{image_url} = $image_url;
            $count++;

            unlink($_);
        }
    }

    return {
        result_header => \@header_cols, results => \@stocks
    };
}

sub drone_imagery_compare_images : Path('/api/drone_imagery/compare_images') : ActionClass('REST') { }
sub drone_imagery_compare_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $stock_id_list = $c->req->param('stock_id') ? [$c->req->param('stock_id')] : [];
    my $comparison_type = $c->req->param('comparison_type');
    my $image_ids = $c->req->param('image_ids') ? decode_json($c->req->param('image_ids')) : [];
    my $drone_run_band_ids = $c->req->param('drone_run_band_ids') ? decode_json($c->req->param('drone_run_band_ids')) : [];
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json($c->req->param('drone_run_ids')) : [];
    my $plot_polygon_type_ids = $c->req->param('image_type_ids') ? decode_json($c->req->param('image_type_ids')) : [];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id_list=>$plot_polygon_type_ids,
        drone_run_project_id_list=>$drone_run_ids,
        drone_run_band_project_id_list=>$drone_run_band_ids,
        stock_id_list=>$stock_id_list,
        image_id_list=>$image_ids
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my %data_hash;
    my %unique_drone_run_band_project_names;
    my %unique_image_type_names;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $project_image_type_name = $_->{project_image_type_name};
        my $drone_run_band_project_name = $_->{drone_run_band_project_name};
        $unique_drone_run_band_project_names{$drone_run_band_project_name}++;
        $unique_image_type_names{$project_image_type_name}++;
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$data_hash{$drone_run_band_project_name}->{$project_image_type_name}->{image_fullpaths}}, $image_fullpath;
    }
    print STDERR Dumper \%data_hash;
    my @unique_drone_run_band_project_names_sort = sort keys %unique_drone_run_band_project_names;
    my @unique_image_type_names_sort = sort keys %unique_image_type_names;
    my $images1 = $data_hash{$unique_drone_run_band_project_names_sort[0]}->{$unique_image_type_names_sort[0]}->{image_fullpaths};
    my $image1 = $images1->[0];
    my $images2 = $data_hash{$unique_drone_run_band_project_names_sort[0]}->{$unique_image_type_names_sort[1]}->{image_fullpaths};
    my $image2 = $images2->[0];
    if (!$image2) {
        $images2 = $data_hash{$unique_drone_run_band_project_names_sort[1]}->{$unique_image_type_names_sort[1]}->{image_fullpaths};
        $image2 = $images2->[0];
    }
    if (!$image2) {
        $images2 = $data_hash{$unique_drone_run_band_project_names_sort[1]}->{$unique_image_type_names_sort[0]}->{image_fullpaths};
        $image2 = $images2->[0];
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_compare_images_dir');
    my $archive_temp_output = $c->tempfile( TEMPLATE => 'drone_imagery_compare_images_dir/outputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$archive_temp_output;

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/CompareTwoImagesPixelValues.py --image_path1 \''.$image1.'\' --image_path2 \''.$image2.'\' --image_type1 \''.$unique_image_type_names_sort[0].'\' --image_type2 \''.$unique_image_type_names_sort[1].'\' --outfile_path \''.$archive_temp_output_file.'\' ';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $c->stash->{rest} = { success => 1, result => $c->config->{main_production_site_url}.$archive_temp_output.".png" };
}

sub drone_imagery_train_keras_model : Path('/api/drone_imagery/train_keras_model') : ActionClass('REST') { }
sub drone_imagery_train_keras_model_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $trait_id = $c->req->param('trait_id');
    my @aux_trait_id = $c->req->param('aux_trait_id[]') ? $c->req->param('aux_trait_id[]') : ();
    my $model_type = $c->req->param('model_type');
    my $population_id = $c->req->param('population_id');
    my $protocol_id = $c->req->param('nd_protocol_id');
    my $use_parents_grm = $c->req->param('use_parents_grm') eq 'yes' ? 1 : 0;
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');
    my $archive_temp_result_agg_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/resultaggXXXX');

    my @accession_ids;
    if ($population_id && $population_id ne 'null') {
        my $accession_manager = CXGN::BreedersToolbox::Accessions->new(schema=>$schema);
        my $population_members = $accession_manager->get_population_members($population_id);
        foreach (@$population_members) {
            push @accession_ids, $_->{stock_id};
        }
    }

    my @result_agg;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids,
        accession_list=>\@accession_ids
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my %data_hash;
    my %seen_day_times;
    my %seen_image_types;
    my %seen_drone_run_band_project_ids;
    my %seen_drone_run_project_ids;
    my %seen_field_trial_ids;
    my %seen_stock_ids;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = int((split ' ', $time_days)[1]);
        $data_hash{$field_trial_id}->{$stock_id}->{$project_image_type_id}->{$days} = {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $seen_day_times{$days}++;
        $seen_image_types{$project_image_type_id}++;
        $seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $seen_drone_run_project_ids{$drone_run_project_id}++;
        $seen_field_trial_ids{$field_trial_id}++;
        $seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%seen_day_times;
    undef $result;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my @seen_plots = keys %seen_stock_ids;
    print STDERR Dumper \@seen_plots;
    my $plot_list_string = join ',', @seen_plots;
    my $q = "SELECT plot.stock_id, accession.stock_id, female_parent.stock_id, male_parent.stock_id
        FROM stock AS plot
        JOIN stock_relationship AS plot_acc_rel ON(plot_acc_rel.subject_id=plot.stock_id AND plot_acc_rel.type_id=$plot_of_cvterm_id)
        JOIN stock AS accession ON(plot_acc_rel.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
        JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
        JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
        WHERE plot.type_id=$plot_cvterm_id AND plot.stock_id IN ($plot_list_string);";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %plot_pedigrees_found = ();
    my %accession_pedigrees_found = ();
    my %unique_accession_ids_genotypes = ();
    while (my ($plot_stock_id, $accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
        $unique_accession_ids_genotypes{$accession_stock_id}++;
        $plot_pedigrees_found{$plot_stock_id} = {
            female_stock_id => $female_parent_stock_id,
            male_stock_id => $male_parent_stock_id
        };
        $accession_pedigrees_found{$accession_stock_id} = {
            female_stock_id => $female_parent_stock_id,
            male_stock_id => $male_parent_stock_id
        };
    }

    my %unique_genotype_accessions;
    if ($protocol_id) {
        my @accession_list = sort keys %unique_accession_ids_genotypes;
        my $geno = CXGN::Genotype::DownloadFactory->instantiate(
            'DosageMatrix',    #can be either 'VCF' or 'DosageMatrix'
            {
                bcs_schema=>$schema,
                people_schema=>$people_schema,
                cache_root_dir=>$c->config->{cache_file_path},
                accession_list=>\@accession_list,
                protocol_id_list=>[$protocol_id],
                compute_from_parents=>$use_parents_grm,
                return_only_first_genotypeprop_for_stock=>1,
                prevent_transpose=>1
            }
        );
        my $file_handle = $geno->download(
            $c->config->{cluster_shared_tempdir},
            $c->config->{backend},
            $c->config->{cluster_host},
            $c->config->{'web_cluster_queue'},
            $c->config->{basepath}
        );
        open my $geno_fh, "<&", $file_handle or die "Can't open output file: $!";
            my $header = <$geno_fh>;
            while (my $row = <$geno_fh>) {
                chomp($row);
                if ($row) {
                    my @line = split "\t", $row;
                    my $stock_id = shift @line;
                    my $out_line = join "\n", @line;
                    if ($out_line) {
                        my $geno_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/genoinputfileXXXX');
                        my $status = write_file($geno_temp_input_file, $out_line."\n");
                        $unique_genotype_accessions{$stock_id} = $geno_temp_input_file;
                    }
                }
            }
        close($geno_fh);
        @accession_ids = keys %unique_genotype_accessions;
    }

    my @trait_ids = ($trait_id);
    if (scalar(@aux_trait_id) > 0) {
        push @trait_ids, @aux_trait_id;
    }

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>'plot',
            trait_list=>\@trait_ids,
            trial_list=>\@field_trial_ids,
            plot_list=>\@seen_plots,
            accession_list=>\@accession_ids,
            exclude_phenotype_outlier=>0,
            include_timestamp=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    my %phenotype_data_hash;
    my %aux_data_hash;
    foreach my $d (@$data) {
        foreach my $o (@{$d->{observations}}) {
            if ($o->{trait_id} == $trait_id) {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{trait_value} = {
                    trait_name => $o->{trait_name},
                    value => $o->{value}
                };
            } else {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{aux_trait_value}->{$o->{trait_id}} = $o->{value};
            }
        }
        $aux_data_hash{$d->{trial_id}}->{$d->{observationunit_stock_id}} = $d;
    }
    #print STDERR Dumper \%data_hash;
    undef $data;

    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileXXXX');
    my $archive_temp_input_aux_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileauxXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputfileXXXX');
    my $archive_temp_autoencoder_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/autoencodermodelfileXXXX').".hdf5";
    my $archive_temp_loss_history_file_string = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/losshistoryXXXX');
    my $archive_temp_loss_history_file = $c->config->{basepath}."/".$archive_temp_loss_history_file_string;

    my $keras_project_name = basename($c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/keras_tuner_XXXX'));
    my $archive_temp_output_model_file = $c->config->{cluster_shared_tempdir}.'/'.$keras_project_name.'.hdf5';
    my $keras_tuner_dir = $c->config->{cluster_shared_tempdir};
    my $keras_tuner_output_project_dir = $keras_tuner_dir.$keras_project_name;

    my %output_images;

    open(my $F_aux, ">", $archive_temp_input_aux_file) || die "Can't open file ".$archive_temp_input_aux_file;
        print $F_aux 'stock_id,value,trait_name,field_trial_id,accession_id,female_id,male_id,output_image_file,genotype_file';
        if (scalar(@aux_trait_id)>0) {
            my $aux_trait_counter = 0;
            foreach (@aux_trait_id) {
                print $F_aux ",aux_trait_$aux_trait_counter";
                $aux_trait_counter++;
            }
        }
        print $F_aux "\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$germplasm_id,";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@aux_trait_id)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@aux_trait_id) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';
                            print STDERR Dumper $geno_file;

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$germplasm_id,";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@aux_trait_id)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@aux_trait_id) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
    close($F_aux);

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        print $F "stock_id,image_path,image_type,day,drone_run_project_id,value\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        foreach my $image_type (sort keys %seen_image_types) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
    close($F);

    undef %data_hash;
    undef %phenotype_data_hash;
    undef %aux_data_hash;

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }

    my $cmd = '';
    if ($model_type eq 'KerasTunerCNNSequentialSoftmaxCategorical') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --output_random_search_result_project \''.$keras_tuner_output_project_dir.'\' --keras_model_type simple_1_tuner --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'SimpleKerasTunerCNNSequentialSoftmaxCategorical') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --output_random_search_result_project \''.$keras_tuner_output_project_dir.'\' --keras_model_type simple_tuner --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    # elsif ($model_type eq 'KerasTunerCNNInceptionResNetV2') {
    #     $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --output_random_search_result_project \''.$keras_tuner_output_project_dir.'\' --keras_model_type inceptionresnetv2application_tuner --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    # }
    elsif ($model_type eq 'KerasCNNInceptionResNetV2ImageNetWeights') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type inceptionresnetv2application --keras_model_weights imagenet --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNInceptionResNetV2') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type inceptionresnetv2 --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type densenet121_lstm_imagenet --keras_model_weights imagenet --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNDenseNet121ImageNetWeights') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type densenet121application --keras_model_weights imagenet --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNSequentialSoftmaxCategorical') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type simple_1 --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNMLPExample') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type mlp_cnn_example --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    else {
        $c->stash->{rest} = {error => "$model_type not supported!"};
        $c->detach();
    }
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $line = '';
            foreach (@columns) {
                if ($_ eq ' ') {
                    $line .= '&nbsp;';
                }
                else {
                    $line .= $_;
                }
            }
            push @result_agg, $line;
        }
    close($fh);
    #print STDERR Dumper \@result_agg;

    open($F, ">", $archive_temp_result_agg_file) || die "Can't open file ".$archive_temp_result_agg_file;
        foreach my $data (@result_agg){
            print $F $data;
            print $F "\n";
        }
    close($F);

    my @loss_history;
    open(my $fh3, '<', $archive_temp_loss_history_file)
        or die "Could not open file '$archive_temp_loss_history_file' $!";

        while ( my $row = <$fh3> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @loss_history, $columns[0];
        }
    close($fh3);

    print STDERR "Train loss PLOT $archive_temp_loss_history_file \n";
    my $rmatrix = R::YapRI::Data::Matrix->new({
        name => 'matrix1',
        coln => 1,
        rown => scalar(@loss_history),
        colnames => ["loss"],
        data => \@loss_history
    });

    my $rbase = R::YapRI::Base->new();
    my $r_block = $rbase->create_block('r_block');
    $rmatrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('dataframe.matrix1 <- data.frame(matrix1)');
    $r_block->add_command('dataframe.matrix1$loss <- as.numeric(dataframe.matrix1$loss)');
    $r_block->add_command('png(filename=\''.$archive_temp_loss_history_file.'\')');
    $r_block->add_command('plot(seq(1,length(dataframe.matrix1$loss)), dataframe.matrix1$loss)');
    $r_block->add_command('dev.off()');
    $r_block->run_block();

    my @saved_trained_image_urls;
    if ($c->req->param('save_model') == 1) {
        my $model_name = $c->req->param('model_name');
        my $model_description = $c->req->param('model_description');

        my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_keras_trained', 'project_md_image')->cvterm_id();

        # my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        #     JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        #     JOIN phenome.stock_image AS stock_image ON(md_image.image_id = stock_image.image_id)
        #     WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        # my $h = $schema->storage->dbh->prepare($q);

        foreach my $stock_id (keys %output_images){
            my $image_file = $output_images{$stock_id}->{image_file};
            my $field_trial_id = $output_images{$stock_id}->{field_trial_id};
            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            # my $md5checksum = $image->calculate_md5sum($image_file);
            # $h->execute($md5checksum, $linking_table_type_id, $field_trial_id, $stock_id);
            # my ($saved_image_id) = $h->fetchrow_array();

            my $output_image_id;
            my $output_image_url;
            my $output_image_fullpath;
            # if ($saved_image_id) {
            #     print STDERR Dumper "Image $image_file has already been added to the database and will not be added again.";
            #     $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
            #     $output_image_fullpath = $image->get_filename('original_converted', 'full');
            #     $output_image_url = $image->get_image_url('original');
            #     $output_image_id = $image->get_image_id();
            # } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($image_file, 'project', $field_trial_id, $linking_table_type_id);
                my $stock_associate = $image->associate_stock($stock_id, $user_name);
                $output_image_fullpath = $image->get_filename('original_converted', 'full');
                $output_image_url = $image->get_image_url('original');
                $output_image_id = $image->get_image_id();
            # }
            push @saved_trained_image_urls, $output_image_url;
        }

        _perform_save_trained_keras_cnn_model($c, $schema, $metadata_schema, $phenome_schema, \@field_trial_ids, $archive_temp_output_model_file, $archive_temp_autoencoder_output_model_file, $archive_temp_input_file, $archive_temp_input_aux_file, $model_name, $model_description, $drone_run_ids, $plot_polygon_type_ids, $trait_id, $model_type, \@aux_trait_id, $protocol_id, $use_parents_grm, $user_id, $user_name, $user_role);
    }

    $c->stash->{rest} = { success => 1, results => \@result_agg, model_input_file => $archive_temp_input_file, model_input_aux_file => $archive_temp_input_aux_file, model_temp_file => $archive_temp_output_model_file, model_autoencoder_temp_file => $archive_temp_autoencoder_output_model_file, trait_id => $trait_id, loss_history => \@loss_history, loss_history_file => $archive_temp_loss_history_file_string, saved_trained_image_urls => \@saved_trained_image_urls };
}

sub drone_imagery_save_keras_model : Path('/api/drone_imagery/save_keras_model') : ActionClass('REST') { }
sub drone_imagery_save_keras_model_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $model_file = $c->req->param('model_file');
    my $archive_temp_autoencoder_output_model_file = $c->req->param('model_autoencoder_file');
    my $model_input_file = $c->req->param('model_input_file');
    my $model_input_aux_file = $c->req->param('model_input_aux_file');
    my $model_name = $c->req->param('model_name');
    my $model_description = $c->req->param('model_description');
    my $trait_id = $c->req->param('trait_id');
    my @aux_trait_id = $c->req->param('aux_trait_id[]') ? $c->req->param('aux_trait_id[]') : ();
    my $protocol_id = $c->req->param('protocol_id');
    my $use_parents_grm = $c->req->param('use_parents_grm');
    my $model_type = $c->req->param('model_type');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    _perform_save_trained_keras_cnn_model($c, $schema, $metadata_schema, $phenome_schema, \@field_trial_ids, $model_file, $model_input_file, $archive_temp_autoencoder_output_model_file, $model_input_aux_file, $model_name, $model_description, $drone_run_ids, $plot_polygon_type_ids, $trait_id, $model_type, \@aux_trait_id, $protocol_id, $use_parents_grm, $user_id, $user_name, $user_role);
}

sub _perform_save_trained_keras_cnn_model {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $field_trial_ids = shift;
    my $model_file = shift;
    my $archive_temp_autoencoder_output_model_file = shift;
    my $model_input_file = shift;
    my $model_input_aux_file = shift;
    my $model_name = shift;
    my $model_description = shift;
    my $drone_run_ids = shift;
    my $plot_polygon_type_ids = shift;
    my $trait_id = shift;
    my $model_type = shift;
    my $aux_trait_ids = shift;
    my $geno_protocol_id = shift;
    my $use_parents_grm = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my @field_trial_ids = @$field_trial_ids;
    my $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $m = CXGN::AnalysisModel::SaveModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        archive_path=>$c->config->{archive_path},
        model_name=>$model_name,
        model_description=>$model_description,
        model_type_cvterm_id=>$keras_cnn_cvterm_id,
        model_experiment_type_cvterm_id=>$keras_cnn_experiment_cvterm_id,
        model_properties=>{variable_name => $trait_name, variable_id => $trait_id, aux_trait_ids => $aux_trait_ids, model_type=>$model_type, image_type=>'standard_4_montage', nd_protocol_id => $geno_protocol_id, use_parents_grm => $use_parents_grm},
        archived_model_file_type=>'trained_keras_cnn_model',
        model_file=>$model_file,
        archived_training_data_file_type=>'trained_keras_cnn_model_input_data_file',
        archived_training_data_file=>$model_input_file,
        archived_auxiliary_files=>[
            {auxiliary_model_file => $archive_temp_autoencoder_output_model_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_autoencoder_model'},
            {auxiliary_model_file => $model_input_aux_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_model_input_aux_data_file'}
        ],
        user_id=>$user_id,
        user_role=>$user_role
    });
    my $saved_model = $m->save_model();

    $c->stash->{rest} = $saved_model;
}

sub drone_imagery_predict_keras_model : Path('/api/drone_imagery/predict_keras_model') : ActionClass('REST') { }
sub drone_imagery_predict_keras_model_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $model_id = $c->req->param('model_id');
    my $model_prediction_type = $c->req->param('model_prediction_type');
    my $population_id = $c->req->param('population_id');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my @aux_trait_ids = $c->req->param('aux_trait_ids[]') ? $c->req->param('aux_trait_ids[]') : ();
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $return = _perform_keras_cnn_predict($c, $schema, $metadata_schema, $people_schema, $phenome_schema, \@field_trial_ids, $model_id, $drone_run_ids, $plot_polygon_type_ids, $model_prediction_type, $population_id, \@allowed_composed_cvs, $composable_cvterm_format, $composable_cvterm_delimiter, \@aux_trait_ids, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_keras_cnn_predict {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $people_schema = shift;
    my $phenome_schema = shift;
    my $field_trial_ids = shift;
    my $model_id = shift;
    my $drone_run_ids = shift;
    my $plot_polygon_type_ids = shift;
    my $model_prediction_type = shift;
    my $population_id = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_format = shift;
    my $composable_cvterm_delimiter = shift;
    my $aux_trait_ids = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my @field_trial_ids = @$field_trial_ids;

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $plot_polygon_rgb_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_green_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_2', 'project_md_image')->cvterm_id();
    my $plot_polygon_red_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_3', 'project_md_image')->cvterm_id();
    my $plot_polygon_red_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', 'project_md_image')->cvterm_id();

    if (scalar(@$plot_polygon_type_ids) == 1) {
        #To match standard_4 image types of micasense
        $plot_polygon_type_ids = [$plot_polygon_rgb_cvterm_id, $plot_polygon_green_cvterm_id, $plot_polygon_red_cvterm_id, $plot_polygon_red_threshold_cvterm_id];
    }

    my @accession_ids;
    if ($population_id && $population_id ne 'null') {
        my $accession_manager = CXGN::BreedersToolbox::Accessions->new(schema=>$schema);
        my $population_members = $accession_manager->get_population_members($population_id);
        foreach (@$population_members) {
            push @accession_ids, $_->{stock_id};
        }
    }

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids,
        accession_list=>\@accession_ids
    });
    my ($result, $total_count) = $images_search->search();

    my %data_hash;
    my %seen_day_times;
    my %seen_image_types;
    my %seen_drone_run_band_project_ids;
    my %seen_drone_run_project_ids;
    my %seen_field_trial_ids;
    my %seen_stock_ids;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = int((split ' ', $time_days)[1]);
        $data_hash{$field_trial_id}->{$stock_id}->{$project_image_type_id}->{$days} = {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $seen_day_times{$days}++;
        $seen_image_types{$project_image_type_id}++;
        $seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $seen_drone_run_project_ids{$drone_run_project_id}++;
        $seen_field_trial_ids{$field_trial_id}++;
        $seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%seen_day_times;
    undef $result;
    my @seen_plots = keys %seen_stock_ids;

    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id;
    my $block_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();

    my $stock_ids_sql = join ',', @seen_plots;
    my $accession_ids_sql = '';
    if (scalar(@accession_ids)>0) {
        my $accession_ids_sql_string = join ',', @accession_ids;
        $accession_ids_sql = " AND germplasm.stock_id IN ($accession_ids_sql_string)";
    }
    my $stock_metadata_q = "SELECT stock.stock_id, stock.uniquename, germplasm.uniquename, germplasm.stock_id, plot_number.value, rep.value, block_number.value, col_number.value, row_number.value
        FROM stock
        JOIN stock_relationship ON(stock.stock_id=stock_relationship.subject_id AND stock_relationship.type_id=$plot_of_cvterm_id)
        JOIN stock AS germplasm ON(stock_relationship.object_id=germplasm.stock_id)
        LEFT JOIN stockprop AS plot_number ON(stock.stock_id=plot_number.stock_id AND plot_number.type_id=$plot_number_cvterm_id)
        LEFT JOIN stockprop AS rep ON(stock.stock_id=rep.stock_id AND rep.type_id=$replicate_cvterm_id)
        LEFT JOIN stockprop AS block_number ON(stock.stock_id=block_number.stock_id AND block_number.type_id=$block_number_cvterm_id)
        LEFT JOIN stockprop AS col_number ON(stock.stock_id=col_number.stock_id AND col_number.type_id=$col_number_cvterm_id)
        LEFT JOIN stockprop AS row_number ON(stock.stock_id=row_number.stock_id AND row_number.type_id=$row_number_cvterm_id)
        WHERE stock.type_id=$plot_cvterm_id AND stock.stock_id IN ($stock_ids_sql) $accession_ids_sql";
    my $stock_metadata_h = $schema->storage->dbh()->prepare($stock_metadata_q);
    $stock_metadata_h->execute();
    my %stock_info;
    while (my ($stock_id, $stock_uniquename, $germplasm_uniquename, $germplasm_stock_id, $plot_number, $rep, $block, $col, $row) = $stock_metadata_h->fetchrow_array()) {
        $stock_info{$stock_id} = {
            uniquename => $stock_uniquename,
            germplasm_uniquename => $germplasm_uniquename,
            germplasm_stock_id => $germplasm_stock_id,
            plot_number => $plot_number,
            replicate => $rep,
            block_number => $block,
            row_number => $row,
            col_number => $col
        };
    }

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $plot_list_string = join ',', @seen_plots;
    my $q = "SELECT plot.stock_id, accession.stock_id, female_parent.stock_id, male_parent.stock_id
        FROM stock AS plot
        JOIN stock_relationship AS plot_acc_rel ON(plot_acc_rel.subject_id=plot.stock_id AND plot_acc_rel.type_id=$plot_of_cvterm_id)
        JOIN stock AS accession ON(plot_acc_rel.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
        JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
        JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
        WHERE plot.type_id=$plot_cvterm_id AND plot.stock_id IN ($plot_list_string);";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %plot_pedigrees_found = ();
    my %unique_accession_ids_genotypes;
    while (my ($plot_stock_id, $accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
        $unique_accession_ids_genotypes{$accession_stock_id}++;
        $plot_pedigrees_found{$plot_stock_id} = {
            female_stock_id => $female_parent_stock_id,
            male_stock_id => $male_parent_stock_id
        };
    }

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    my $trait_id = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{variable_id};
    my $trained_trait_name = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{variable_name};
    my $aux_trait_ids_previous = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{aux_trait_ids};
    my $model_type = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{model_type};
    my $nd_protocol_id = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{nd_protocol_id};
    my $use_parents_grm = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{use_parents_grm};
    my $trained_image_type = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{image_type};
    my $model_file = $saved_model_object->{model_files}->{trained_keras_cnn_model};
    my $training_autoencoder_model_file = $saved_model_object->{model_files}->{trained_keras_cnn_autoencoder_model};
    my $training_input_data_file = $saved_model_object->{model_files}->{trained_keras_cnn_model_input_data_file};
    my $training_input_aux_data_file = $saved_model_object->{model_files}->{trained_keras_cnn_model_input_aux_data_file};

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');

    my %unique_genotype_accessions;
    if ($nd_protocol_id) {
        my @accession_list = sort keys %unique_accession_ids_genotypes;
        my $geno = CXGN::Genotype::DownloadFactory->instantiate(
            'DosageMatrix',    #can be either 'VCF' or 'DosageMatrix'
            {
                bcs_schema=>$schema,
                people_schema=>$people_schema,
                cache_root_dir=>$c->config->{cache_file_path},
                accession_list=>\@accession_list,
                protocol_id_list=>[$nd_protocol_id],
                compute_from_parents=>$use_parents_grm,
                return_only_first_genotypeprop_for_stock=>1,
                prevent_transpose=>1
            }
        );
        my $file_handle = $geno->download(
            $c->config->{cluster_shared_tempdir},
            $c->config->{backend},
            $c->config->{cluster_host},
            $c->config->{'web_cluster_queue'},
            $c->config->{basepath}
        );
        open my $geno_fh, "<&", $file_handle or die "Can't open output file: $!";
            my $header = <$geno_fh>;
            while (my $row = <$geno_fh>) {
                chomp($row);
                if ($row) {
                    my @line = split "\t", $row;
                    my $stock_id = shift @line;
                    my $out_line = join "\n", @line;
                    if ($out_line) {
                        my $geno_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/genoinputfileXXXX');
                        my $status = write_file($geno_temp_input_file, $out_line."\n");
                        $unique_genotype_accessions{$stock_id} = $geno_temp_input_file;
                    }
                }
            }
        close($geno_fh);
        @accession_ids = keys %unique_genotype_accessions;
    }

    my @trait_ids = ($trait_id);
    if (scalar(@$aux_trait_ids) > 0) {
        push @trait_ids, @$aux_trait_ids;
    }

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>'plot',
            trait_list=>\@trait_ids,
            trial_list=>\@field_trial_ids,
            plot_list=>\@seen_plots,
            accession_list=>\@accession_ids,
            exclude_phenotype_outlier=>0,
            include_timestamp=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    my %phenotype_data_hash;
    my %aux_data_hash;
    foreach my $d (@$data) {
        foreach my $o (@{$d->{observations}}) {
            if ($o->{trait_id} == $trait_id) {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{trait_value} = {
                    trait_name => $o->{trait_name},
                    value => $o->{value}
                };
            } else {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{aux_trait_value}->{$o->{trait_id}} = $o->{value};
            }
        }
        $aux_data_hash{$d->{trial_id}}->{$d->{observationunit_stock_id}} = $d;
    }
    undef $data;

    $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_predict_dir');
    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/inputfileXXXX');
    my $archive_temp_input_aux_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/inputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputfileXXXX');
    my $archive_temp_output_evaluation_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputevaluationfileXXXX');
    my $archive_temp_output_activation_file = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputactivationfileXXXX');
    my $archive_temp_output_corr_plot = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/corrplotXXXX').".png";
    my $archive_temp_output_corr_plot_file = $c->config->{basepath}."/".$archive_temp_output_corr_plot;
    $archive_temp_output_activation_file .= ".pdf";
    my $archive_temp_output_activation_file_path = $c->config->{basepath}."/".$archive_temp_output_activation_file;

    my %predicted_stock_ids;
    my %output_images;

    open(my $F_aux, ">", $archive_temp_input_aux_file) || die "Can't open file ".$archive_temp_input_aux_file;
        print $F_aux 'stock_id,value,trait_name,field_trial_id,accession_id,female_id,male_id,output_image_file,genotype_file';
        if (scalar(@$aux_trait_ids)>0) {
            my $aux_trait_counter = 0;
            foreach (@$aux_trait_ids) {
                print $F_aux ",aux_trait_$aux_trait_counter";
                $aux_trait_counter++;
            }
        }
        print $F_aux "\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            $predicted_stock_ids{$stock_id}++;
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$germplasm_id,";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@$aux_trait_ids)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@$aux_trait_ids) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            $predicted_stock_ids{$stock_id}++;
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$d->{germplasm_stock_id},";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@$aux_trait_ids)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@$aux_trait_ids) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
    close($F_aux);

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        print $F "stock_id,image_path,image_type,day,drone_run_project_id,value\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        foreach my $image_type (sort keys %seen_image_types) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
    close($F);

    undef %data_hash;
    undef %aux_data_hash;

    print STDERR "Predicting $trained_trait_name from Keras CNN $model_type\n";

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/PredictKerasCNN.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_image_aux_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --input_model_file_path \''.$model_file.'\' --input_autoencoder_model_file_path \''.$training_autoencoder_model_file.'\' --keras_model_type_name \''.$model_type.'\' --training_data_input_file \''.$training_input_data_file.'\' --training_aux_data_input_file \''.$training_input_aux_data_file.'\' --outfile_evaluation_path \''.$archive_temp_output_evaluation_file.'\' --outfile_activation_path \''.$archive_temp_output_activation_file_path.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my @saved_trained_image_urls;
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_keras_trained', 'project_md_image')->cvterm_id();
    foreach my $stock_id (keys %output_images){
        my $image_file = $output_images{$stock_id}->{image_file};
        my $field_trial_id = $output_images{$stock_id}->{field_trial_id};
        my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        # my $md5checksum = $image->calculate_md5sum($image_file);
        # my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        #     JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        #     JOIN phenome.stock_image AS stock_image ON(md_image.image_id = stock_image.image_id)
        #     WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        # my $h = $schema->storage->dbh->prepare($q);
        # $h->execute($md5checksum, $linking_table_type_id, $field_trial_id, $stock_id);
        # my ($saved_image_id) = $h->fetchrow_array();

        my $output_image_id;
        my $output_image_url;
        my $output_image_fullpath;
        # if ($saved_image_id) {
        #     print STDERR Dumper "Image $image_file has already been added to the database and will not be added again.";
        #     $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        #     $output_image_fullpath = $image->get_filename('original_converted', 'full');
        #     $output_image_url = $image->get_image_url('original');
        #     $output_image_id = $image->get_image_id();
        # } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($image_file, 'project', $field_trial_id, $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id, $user_name);
            $output_image_fullpath = $image->get_filename('original_converted', 'full');
            $output_image_url = $image->get_image_url('original');
            $output_image_id = $image->get_image_id();
        # }
        $output_images{$stock_id}->{image_id} = $output_image_id;
        push @saved_trained_image_urls, $output_image_url;
    }

    my @result_agg;
    my @data_matrix;
    my $data_matrix_rows = 0;
    my @data_matrix_colnames = ('stock_id', 'germplasm_stock_id', 'replicate', 'block_number', 'row_number', 'col_number', 'growing_degree_days', 'previous_value', 'prediction');
    my @simple_data_matrix;

    my @predictions;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        print STDERR "Opened $archive_temp_output_file\n";
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $prediction = shift @columns;
            push @predictions, $prediction;
        }
    close($fh);
    #print STDERR Dumper \@predictions;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $keras_predict_image_type_id;
    my $keras_predict_model_type_id;
    if ($trained_image_type eq 'standard_4_montage') {
        $keras_predict_image_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Standard 4 Image Montage|ISOL:0000324')->cvterm_id;
    }
    if ($model_type eq 'KerasTunerCNNSequentialSoftmaxCategorical') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasTunerCNNSequentialSoftmaxCategorical|ISOL:0000326')->cvterm_id;
    }
    if ($model_type eq 'SimpleKerasTunerCNNSequentialSoftmaxCategorical') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted SimpleKerasTunerCNNSequentialSoftmaxCategorical|ISOL:0000327')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNInceptionResNetV2ImageNetWeights') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNInceptionResNetV2ImageNetWeights|ISOL:0000328')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNInceptionResNetV2') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNInceptionResNetV2|ISOL:0000329')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNLSTMDenseNet121ImageNetWeights|ISOL:0000330')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNDenseNet121ImageNetWeights') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNDenseNet121ImageNetWeights|ISOL:0000331')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNSequentialSoftmaxCategorical') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNSequentialSoftmaxCategorical|ISOL:0000332')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNMLPExample') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNMLPExample|ISOL:0000333')->cvterm_id;
    }

    my $trained_trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trained_trait_name)->cvterm_id;

    my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
        object => [],
        attribute => [$keras_predict_image_type_id],
        method => [],
        unit => [],
        trait => [$trained_trait_cvterm_id],
        tod => [$keras_predict_model_type_id],
        toy => [],
        gen => [],
    });
    my $existing_traits = $traits->{existing_traits};
    my $new_traits = $traits->{new_traits};
    # print STDERR Dumper $new_traits;
    # print STDERR Dumper $existing_traits;
    my %new_trait_names;
    foreach (@$new_traits) {
        my $components = $_->[0];
        $new_trait_names{$_->[1]} = join ',', @$components;
    }

    my $onto = CXGN::Onto->new( { schema => $schema } );
    my $new_terms = $onto->store_composed_term(\%new_trait_names);

    my $keras_predict_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$trained_trait_cvterm_id, $keras_predict_image_type_id, $keras_predict_model_type_id]);
    my $keras_predict_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $keras_predict_composed_cvterm_id, 'extended');

    my %keras_features_phenotype_data;
    my $iter = 0;
    my %seen_stock_names;
    #print STDERR Dumper \%phenotype_data_hash;
    foreach my $sorted_stock_id (sort keys %predicted_stock_ids) {
        my $prediction = $predictions[$iter];
        my $stock_uniquename = $stock_info{$sorted_stock_id}->{uniquename};
        my $previous_value = $phenotype_data_hash{$sorted_stock_id} ? $phenotype_data_hash{$sorted_stock_id}->{trait_value}->{value} : '';
        my $image_id = $output_images{$sorted_stock_id}->{image_id};

        $keras_features_phenotype_data{$stock_uniquename}->{$keras_predict_composed_trait_name} = [$prediction, $timestamp, $user_name, '', $image_id];
        $seen_stock_names{$stock_uniquename}++;

        if ($previous_value){
            push @data_matrix, ($sorted_stock_id, $stock_info{$sorted_stock_id}->{germplasm_stock_id}, $stock_info{$sorted_stock_id}->{replicate}, $stock_info{$sorted_stock_id}->{block_number}, $stock_info{$sorted_stock_id}->{row_number}, $stock_info{$sorted_stock_id}->{col_number}, $stock_info{$sorted_stock_id}->{drone_run_related_time_cvterm_json}->{gdd_average_temp}, $previous_value, $prediction);
            push @simple_data_matrix, ($previous_value, $prediction);
            $data_matrix_rows++;
        }
        push @result_agg, [$stock_uniquename, $sorted_stock_id, $prediction, $previous_value];
        $iter++;
    }

    my @traits_seen = (
        $keras_predict_composed_trait_name
    );

    print STDERR "Read $iter lines in results file\n";

    if ($iter > 0) {
        my %phenotype_metadata = (
            'archived_file' => $archive_temp_output_file,
            'archived_file_type' => 'image_keras_prediction_output',
            'operator' => $user_name,
            'date' => $timestamp
        );
        my @plot_units_seen = keys %seen_stock_names;
        my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
            basepath=>$c->config->{basepath},
            dbhost=>$c->config->{dbhost},
            dbname=>$c->config->{dbname},
            dbuser=>$c->config->{dbuser},
            dbpass=>$c->config->{dbpass},
            temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
            bcs_schema=>$schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>\@plot_units_seen,
            trait_list=>\@traits_seen,
            values_hash=>\%keras_features_phenotype_data,
            has_timestamps=>1,
            metadata_hash=>\%phenotype_metadata,
            ignore_new_values=>undef,
            overwrite_values=>1
        });
        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
        my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});
    }

    undef %data_hash;
    undef %phenotype_data_hash;

    print STDERR "CNN Prediction Correlation\n";
    my @model_results;
    my @simple_data_matrix_colnames = ("previous_value", "prediction");
    print STDERR Dumper \@simple_data_matrix;
    my $rmatrix = R::YapRI::Data::Matrix->new({
        name => 'matrix1',
        coln => scalar(@simple_data_matrix_colnames),
        rown => $data_matrix_rows,
        colnames => \@simple_data_matrix_colnames,
        data => \@simple_data_matrix
    });

    print STDERR "CORR PLOT $archive_temp_output_corr_plot_file \n";
    my $rbase = R::YapRI::Base->new();
    my $r_block = $rbase->create_block('r_block');
    $rmatrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('dataframe.matrix1 <- data.frame(matrix1)');
    $r_block->add_command('dataframe.matrix1$previous_value <- as.numeric(dataframe.matrix1$previous_value)');
    $r_block->add_command('dataframe.matrix1$prediction <- as.numeric(dataframe.matrix1$prediction)');
    $r_block->add_command('mixed.lmer.matrix <- matrix(NA,nrow = 1, ncol = 1)');
    $r_block->add_command('mixed.lmer.matrix[1,1] <- cor(dataframe.matrix1$previous_value, dataframe.matrix1$prediction)');

    $r_block->add_command('png(filename=\''.$archive_temp_output_corr_plot_file.'\')');
    $r_block->add_command('plot(dataframe.matrix1$previous_value, dataframe.matrix1$prediction)');
    $r_block->add_command('dev.off()');
    $r_block->run_block();
    my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','mixed.lmer.matrix');
    print STDERR Dumper $result_matrix;
    push @model_results, $result_matrix->{data}->[0];

    my @data_matrix_clean;
    foreach (@data_matrix) {
        if ($_) {
            push @data_matrix_clean, $_ + 0;
        }
        else {
            push @data_matrix_clean, 'NA';
        }
    }
    #print STDERR Dumper \@data_matrix_clean;

    if ($model_prediction_type eq 'cnn_prediction_mixed_model') {
        print STDERR "CNN Prediction Mixed Model\n";

        my $rmatrix = R::YapRI::Data::Matrix->new({
            name => 'matrix1',
            coln => scalar(@data_matrix_colnames),
            rown => $data_matrix_rows,
            colnames => \@data_matrix_colnames,
            data => \@data_matrix_clean
        });

        my $rbase = R::YapRI::Base->new();
        my $r_block = $rbase->create_block('r_block');
        $rmatrix->send_rbase($rbase, 'r_block');
        $r_block->add_command('library(lme4)');
        $r_block->add_command('dataframe.matrix1 <- data.frame(matrix1)');
        $r_block->add_command('dataframe.matrix1$previous_value <- as.numeric(dataframe.matrix1$previous_value)');
        $r_block->add_command('dataframe.matrix1$prediction <- as.numeric(dataframe.matrix1$prediction)');
        $r_block->add_command('mixed.lmer <- lmer(previous_value ~ prediction + replicate + (1|germplasm_stock_id), data = dataframe.matrix1, na.action = na.omit )');
        # $r_block->add_command('mixed.lmer.summary <- summary(mixed.lmer)');
        $r_block->add_command('mixed.lmer.matrix <- matrix(NA,nrow = 1, ncol = 2)');
        $r_block->add_command('mixed.lmer.matrix[1,1] <- cor(predict(mixed.lmer), dataframe.matrix1$previous_value)');

        $r_block->add_command('mixed.lmer <- lmer(prediction ~ replicate + (1|germplasm_stock_id), data = dataframe.matrix1 )');
        # $r_block->add_command('mixed.lmer.summary <- summary(mixed.lmer)');
        $r_block->add_command('mixed.lmer.matrix[1,2] <- cor(predict(mixed.lmer), dataframe.matrix1$previous_value)');
        $r_block->run_block();
        my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','mixed.lmer.matrix');
        print STDERR Dumper $result_matrix;
        push @model_results, $result_matrix->{data}->[0];
        push @model_results, $result_matrix->{data}->[1];
    }

    my @evaluation_results;
    open(my $fh_eval, '<', $archive_temp_output_evaluation_file)
        or die "Could not open file '$archive_temp_output_evaluation_file' $!";

        while ( my $row = <$fh_eval> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $line = '';
            foreach (@columns) {
                if ($_ eq ' ') {
                    $line .= '&nbsp;';
                }
                else {
                    $line .= $_;
                }
            }
            push @evaluation_results, $line;
        }
    close($fh_eval);

    return { success => 1, results => \@result_agg, evaluation_results => \@evaluation_results, activation_output => $archive_temp_output_activation_file, corr_plot => $archive_temp_output_corr_plot, trained_trait_name => $trained_trait_name, mixed_model_results => \@model_results };
}

sub drone_imagery_autoencoder_keras_vi_model : Path('/api/drone_imagery/perform_autoencoder_vi') : ActionClass('REST') { }
sub drone_imagery_autoencoder_keras_vi_model_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $autoencoder_model_type = $c->req->param('autoencoder_model_type');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $return = _perform_autoencoder_keras_cnn_vi($c, $schema, $metadata_schema, $people_schema, $phenome_schema, \@field_trial_ids, $drone_run_ids, $plot_polygon_type_ids, $autoencoder_model_type, \@allowed_composed_cvs, $composable_cvterm_format, $composable_cvterm_delimiter, $time_cvterm_id, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_autoencoder_keras_cnn_vi {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $people_schema = shift;
    my $phenome_schema = shift;
    my $field_trial_ids = shift;
    my $drone_run_ids = shift;
    my $plot_polygon_type_ids = shift;
    my $autoencoder_model_type = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_format = shift;
    my $composable_cvterm_delimiter = shift;
    my $time_cvterm_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my @field_trial_ids = @$field_trial_ids;

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids
    });
    my ($result, $total_count) = $images_search->search();

    if ($total_count == 0) {
        return {error => "No plot-polygon images!"};
    }

    my %data_hash;
    my %seen_day_times;
    my %seen_image_types;
    my %seen_drone_run_band_project_ids;
    my %seen_drone_run_project_ids;
    my %seen_field_trial_ids;
    my %seen_stock_ids;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = int((split ' ', $time_days)[1]);
        push @{$data_hash{$field_trial_id}->{$stock_id}->{$project_image_type_id}->{$days}}, {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $seen_day_times{$days}++;
        $seen_image_types{$project_image_type_id}++;
        $seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $seen_drone_run_project_ids{$drone_run_project_id}++;
        $seen_field_trial_ids{$field_trial_id}++;
        $seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%seen_day_times;
    undef $result;
    my @seen_plots = keys %seen_stock_ids;

    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id;
    my $block_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();

    my $stock_ids_sql = join ',', @seen_plots;
    my $stock_metadata_q = "SELECT stock.stock_id, stock.uniquename, germplasm.uniquename, germplasm.stock_id, plot_number.value, rep.value, block_number.value, col_number.value, row_number.value
        FROM stock
        JOIN stock_relationship ON(stock.stock_id=stock_relationship.subject_id AND stock_relationship.type_id=$plot_of_cvterm_id)
        JOIN stock AS germplasm ON(stock_relationship.object_id=germplasm.stock_id)
        LEFT JOIN stockprop AS plot_number ON(stock.stock_id=plot_number.stock_id AND plot_number.type_id=$plot_number_cvterm_id)
        LEFT JOIN stockprop AS rep ON(stock.stock_id=rep.stock_id AND rep.type_id=$replicate_cvterm_id)
        LEFT JOIN stockprop AS block_number ON(stock.stock_id=block_number.stock_id AND block_number.type_id=$block_number_cvterm_id)
        LEFT JOIN stockprop AS col_number ON(stock.stock_id=col_number.stock_id AND col_number.type_id=$col_number_cvterm_id)
        LEFT JOIN stockprop AS row_number ON(stock.stock_id=row_number.stock_id AND row_number.type_id=$row_number_cvterm_id)
        WHERE stock.type_id=$plot_cvterm_id AND stock.stock_id IN ($stock_ids_sql) ";
    my $stock_metadata_h = $schema->storage->dbh()->prepare($stock_metadata_q);
    $stock_metadata_h->execute();
    my %stock_info;
    while (my ($stock_id, $stock_uniquename, $germplasm_uniquename, $germplasm_stock_id, $plot_number, $rep, $block, $col, $row) = $stock_metadata_h->fetchrow_array()) {
        $stock_info{$stock_id} = {
            stock_uniquename => $stock_uniquename,
            germplasm_uniquename => $germplasm_uniquename,
            germplasm_stock_id => $germplasm_stock_id,
            plot_number => $plot_number,
            replicate => $rep,
            block_number => $block,
            row_number => $row,
            col_number => $col
        };
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_autoencoder_dir');
    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/inputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputfileXXXX');
    my $archive_temp_output_images_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputfileXXXX');

    my %predicted_stock_ids;
    my %output_images;

    my @autoencoder_vi_image_type_ids = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id()
    );

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        print $F "stock_id\tred_image_string\tred_edge_image_string\tnir_image_string\n";

        foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
            foreach my $stock_id (sort keys %seen_stock_ids) {
                print $F "$stock_id";
                foreach my $image_type (@autoencoder_vi_image_type_ids) {
                    my @imgs;
                    foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                        my $images = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                        foreach (@$images) {
                            push @imgs, $_->{image};
                        }
                    }
                    my $img_string = join ',', @imgs;
                    print $F "\t$img_string";
                }
                print $F "\n";
            }
        }
    close($F);

    open(my $F2, ">", $archive_temp_output_images_file) || die "Can't open file ".$archive_temp_output_images_file;
        print $F2 "stock_id\tred_image_encoded\tred_edge_image_encoded\tnir_image_encoded\n";

        foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
            foreach my $stock_id (sort keys %seen_stock_ids) {
                my $archive_temp_output_red_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputimagefileXXXX');
                $archive_temp_output_red_image_file .= ".png";
                my $archive_temp_output_rededge_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputimagefileXXXX');
                $archive_temp_output_rededge_image_file .= ".png";
                my $archive_temp_output_nir_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputimagefileXXXX');
                $archive_temp_output_nir_image_file .= ".png";

                my @autoencoded_image_files = ($archive_temp_output_red_image_file, $archive_temp_output_rededge_image_file, $archive_temp_output_nir_image_file);
                $output_images{$stock_id} = \@autoencoded_image_files;
                my $img_string = join "\t", @autoencoded_image_files;
                print $F2 "$stock_id\t$img_string\n";
            }
        }
    close($F2);

    undef %data_hash;

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/CalculatePhenotypeAutoEncoderVegetationIndices.py --input_image_file \''.$archive_temp_input_file.'\' --output_encoded_images_file \''.$archive_temp_output_images_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --autoencoder_model_type \''.$autoencoder_model_type.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my @saved_trained_image_urls;
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_keras_autoencoder_decoded', 'project_md_image')->cvterm_id();
    foreach my $stock_id (keys %output_images){
        my $autoencoded_images = $output_images{$stock_id};
        foreach my $image_file (@$autoencoded_images) {
            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($image_file, 'project', $drone_run_ids->[0], $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id, $user_name);
            my $output_image_fullpath = $image->get_filename('original_converted', 'full');
            my $output_image_url = $image->get_image_url('original');
            my $output_image_id = $image->get_image_id();
            push @saved_trained_image_urls, $output_image_url;
        }
    }

    my $ndvi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDVI Vegetative Index Image|ISOL:0000131')->cvterm_id;
    my $ndre_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDRE Vegetative Index Image|ISOL:0000132')->cvterm_id;

    my $keras_autoencoder_model_type_id;
    if ($autoencoder_model_type eq 'keras_autoencoder_64_32_filters_16_latent') {
        $keras_autoencoder_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Autoencoder 64_32_Conv_16_Latent|ISOL:0000336')->cvterm_id;
    }

    my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
        object => [],
        attribute => [],
        method => [],
        unit => [],
        trait => [$ndvi_cvterm_id, $ndre_cvterm_id],
        tod => [$keras_autoencoder_model_type_id],
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

    my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
    my $new_terms = $onto->store_composed_term(\%new_trait_names);

    my $autoencoder_ndvi_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$ndvi_cvterm_id, $keras_autoencoder_model_type_id, $time_cvterm_id]);
    my $autoencoder_ndre_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$ndre_cvterm_id, $keras_autoencoder_model_type_id, $time_cvterm_id]);

    my $autoencoder_ndvi_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $autoencoder_ndvi_composed_cvterm_id, 'extended');
    my $autoencoder_ndre_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $autoencoder_ndre_composed_cvterm_id, 'extended');

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        print STDERR "Opened $archive_temp_output_file\n";
        my $line = 0;
        my %autoencoder_vi_phenotype_data;
        my %plots_seen;

        my @traits_seen = (
            $autoencoder_ndvi_composed_trait_name,
            $autoencoder_ndre_composed_trait_name
        );

        my $header = <$fh>;
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }

            my $stock_id = $columns[0];
            my $stock_uniquename = $stock_info{$stock_id}->{stock_uniquename};

            #print STDERR Dumper \@columns;
            $stock_info{$stock_id}->{result} = \@columns;

            $plots_seen{$stock_uniquename} = 1;
            $autoencoder_vi_phenotype_data{$stock_uniquename}->{$autoencoder_ndvi_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', undef];
            $autoencoder_vi_phenotype_data{$stock_uniquename}->{$autoencoder_ndre_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', undef];

            $line++;
        }
        my @stocks = values %stock_info;

    close($fh);
    print STDERR "Read $line lines in results file\n";

    if ($line > 0) {
        my %phenotype_metadata = (
            'archived_file' => $archive_temp_output_file,
            'archived_file_type' => 'keras_autoencoder_vegetation_indices',
            'operator' => $user_name,
            'date' => $timestamp
        );
        my @plot_units_seen = keys %plots_seen;
        my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

        my $store_args = {
            basepath=>$c->config->{basepath},
            dbhost=>$c->config->{dbhost},
            dbname=>$c->config->{dbname},
            dbuser=>$c->config->{dbuser},
            dbpass=>$c->config->{dbpass},
            temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
            bcs_schema=>$schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>\@plot_units_seen,
            trait_list=>\@traits_seen,
            values_hash=>\%autoencoder_vi_phenotype_data,
            has_timestamps=>1,
            metadata_hash=>\%phenotype_metadata,
            overwrite_values=>1,
            #ignore_new_values=>1
        };

        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
            $store_args
        );
        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
        my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});
    }

    return { success => 1 };
}

sub drone_imagery_delete_drone_run : Path('/api/drone_imagery/delete_drone_run') : ActionClass('REST') { }
sub drone_imagery_delete_drone_run_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR "DELETING DRONE RUN\n";

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id],
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR Dumper $total_count;

    my %drone_run_band_project_ids;
    my %image_ids;
    foreach (@$result) {
        $drone_run_band_project_ids{$_->{drone_run_band_project_id}}++;
        $image_ids{$_->{image_id}}++;
    }
    my @drone_run_band_ids = keys %drone_run_band_project_ids;
    my @drone_run_image_ids = keys %image_ids;

    foreach (keys %image_ids) {
        my $image = SGN::Image->new( $schema->storage->dbh, $_, $c );
        $image->delete(); #Sets to obsolete
    }

    my $drone_run_band_project_ids_sql = join ",", @drone_run_band_ids;
    my $drone_run_band_image_ids_sql = join ",", @drone_run_image_ids;
    my $q1 = "DELETE FROM phenome.project_md_image WHERE project_id in ($drone_run_band_project_ids_sql);";
    my $q2 = "DELETE FROM project WHERE project_id in ($drone_run_band_project_ids_sql);";
    my $q3 = "DELETE FROM project WHERE project_id = $drone_run_project_id;";
    my $h1 = $schema->storage->dbh()->prepare($q1);
    $h1->execute();
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute();
    my $h3 = $schema->storage->dbh()->prepare($q3);
    $h3->execute();

    my $q4 = "
        DROP TABLE IF EXISTS temp_drone_image_pheno_deletion;
        CREATE TEMP TABLE temp_drone_image_pheno_deletion AS
        (SELECT phenotype_id, nd_experiment_id, image_id
        FROM phenotype
        JOIN nd_experiment_phenotype using(phenotype_id)
        JOIN phenome.nd_experiment_md_images AS nd_experiment_md_images using(nd_experiment_id)
        WHERE nd_experiment_md_images.image_id IN ($drone_run_band_image_ids_sql) );
        DELETE FROM phenotype WHERE phenotype_id IN (SELECT phenotype_id FROM temp_drone_image_pheno_deletion);
        DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_drone_image_pheno_deletion);
        DELETE FROM phenome.nd_experiment_md_images WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_drone_image_pheno_deletion);
        DELETE FROM nd_experiment WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_drone_image_pheno_deletion);
        DROP TABLE IF EXISTS temp_drone_image_pheno_deletion;
        ";
    my $h4 = $schema->storage->dbh()->prepare($q4);
    $h4->execute();

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_growing_degree_days : Path('/api/drone_imagery/growing_degree_days') : ActionClass('REST') { }
sub drone_imagery_growing_degree_days_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $formula = $c->req->param('formula');
    my $gdd_base_temperature = $c->req->param('gdd_base_temperature');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $gdd_result = _perform_gdd_calculation_and_drone_run_time_saving($schema, $field_trial_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, $gdd_base_temperature, $formula);
    print STDERR Dumper $gdd_result;

    $c->stash->{rest} = {success => 1};
}

sub _perform_gdd_calculation_and_drone_run_time_saving {
    my $schema = shift;
    my $field_trial_id = shift;
    my $drone_run_project_id = shift;
    my $noaa_ncdc_access_token = shift;
    my $gdd_base_temperature = shift;
    my $formula = shift;

    my $field_trial = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $field_trial_id
    });
    my $planting_date = $field_trial->get_planting_date();
    my $noaa_station_id = $field_trial->get_location_noaa_station_id();

    my $drone_run_project = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $drone_run_project_id
    });
    my $project_start_date = $drone_run_project->get_project_start_date();
    my $drone_run_bands = $drone_run_project->get_associated_image_band_projects();

    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $planting_date_datetime = $planting_date_time_object->strftime("%Y-%m-%d");
    my $project_start_date_time_object = Time::Piece->strptime($project_start_date, "%Y-%B-%d");
    my $project_start_date_datetime = $project_start_date_time_object->strftime("%Y-%m-%d");

    my $gdd = CXGN::NOAANCDC->new({
        bcs_schema => $schema,
        start_date => $planting_date_datetime, #YYYY-MM-DD
        end_date => $project_start_date_datetime, #YYYY-MM-DD
        noaa_station_id => $noaa_station_id,
        noaa_ncdc_access_token => $noaa_ncdc_access_token
    });
    my $gdd_result;
    my %related_cvterms;
    if ($formula eq 'average_daily_temp_sum') {
        $gdd_result = $gdd->get_temperature_averaged_gdd($gdd_base_temperature);
        $related_cvterms{gdd_average_temp} = $gdd_result;

        $drone_run_project->set_temperature_averaged_gdd($gdd_result);

        foreach (@$drone_run_bands) {
            my $drone_run_band = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_->[0]});
            $drone_run_band->set_temperature_averaged_gdd($gdd_result);
        }
    }

    my $time_diff = $project_start_date_time_object - $planting_date_time_object;
    my $time_diff_weeks = $time_diff->weeks;
    my $time_diff_days = $time_diff->days;
    my $rounded_time_diff_weeks = round($time_diff_weeks);

    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute("week $rounded_time_diff_weeks", 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    $h->execute("day $time_diff_days", 'cxgn_time_ontology');
    my ($day_cvterm_id) = $h->fetchrow_array();

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
    my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

    $related_cvterms{week} = $week_term;
    $related_cvterms{day} = $day_term;
    my $related_cvterms_result = encode_json \%related_cvterms;

    $drone_run_project->set_related_time_cvterms_json($related_cvterms_result);

    foreach (@$drone_run_bands) {
        my $drone_run_band = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_->[0]});
        $drone_run_band->set_related_time_cvterms_json($related_cvterms_result);
    }

    return \%related_cvterms;
}

sub drone_imagery_retrain_mask_rcnn : Path('/api/drone_imagery/retrain_mask_rcnn') : ActionClass('REST') { }
sub drone_imagery_retrain_mask_rcnn_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $model_name = $c->req->param('model_name');
    my $model_description = $c->req->param('model_description');
    my $model_type = $c->req->param('model_type');

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();
    my $q = "SELECT value FROM projectprop WHERE type_id=$manual_plot_polygon_template_partial;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute();

    my @result;
    my %unique_image_ids;
    while (my ($value) = $h->fetchrow_array()) {
        if ($value) {
            my $partial_templates = decode_json $value;
            foreach my $t (@$partial_templates) {
                my $image_id = $t->{image_id};
                my $polygon = $t->{polygon};
                my $stock_polygon = $t->{stock_polygon};
                my $template_name = $t->{template_name};
                my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                my $image_url = $image->get_image_url("original");
                my $image_fullpath = $image->get_filename('original_converted', 'full');
                my @size = imgsize($image_fullpath);

                push @{$unique_image_ids{$image_id}->{p}}, {
                    polygon => $polygon,
                    template_name => $template_name
                };
                $unique_image_ids{$image_id}->{width} = $size[0];
                $unique_image_ids{$image_id}->{height} = $size[1];
                $unique_image_ids{$image_id}->{image_fullpath} = $image_fullpath;
                $unique_image_ids{$image_id}->{image_url} = $image_url;
            }
        }
    }
    # print STDERR Dumper \%unique_image_ids;

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $denoised_stitched_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_polygons_q = "SELECT project.project_id, image_type.image_id, polygons.value
        FROM project
        JOIN projectprop AS polygons ON (project.project_id=polygons.project_id AND polygons.type_id=$drone_run_band_plot_polygons_type_id)
        JOIN phenome.project_md_image AS image_type ON(project.project_id=image_type.project_id AND image_type.type_id=$denoised_stitched_type_id)
        JOIN metadata.md_image AS image ON(image_type.image_id=image.image_id)
        WHERE image.obsolete = 'f';";
    my $drone_run_band_polygons_h = $schema->storage->dbh->prepare($drone_run_band_polygons_q);
    $drone_run_band_polygons_h->execute();
    while (my ($project_id, $image_id, $polygon_json) = $drone_run_band_polygons_h->fetchrow_array()) {
        my $polygons = decode_json $polygon_json;
        # print STDERR Dumper $polygons;
        # print STDERR Dumper $image_id;

        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my @size = imgsize($image_fullpath);

        push @{$unique_image_ids{$image_id}->{p}}, {
            polygon => $polygons,
            template_name => $project_id
        };

        $unique_image_ids{$image_id}->{width} = $size[0];
        $unique_image_ids{$image_id}->{height} = $size[1];
        $unique_image_ids{$image_id}->{image_fullpath} = $image_fullpath;
        $unique_image_ids{$image_id}->{image_url} = $image_url;
    }
    # print STDERR Dumper \%unique_image_ids;

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_input_annotations_dir');
    my $output_dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_dir');
    my $temp_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_dir/outputmodelfileXXXX').".h5";
    my $temp_output_dir = $c->config->{basepath}."/".$output_dir;
    my $temp_input_dir = $c->config->{basepath}."/".$dir;
    print STDERR Dumper $temp_input_dir;

    my $temp_model_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_dir/annotationfileXXXX');
    open(my $F_model, ">", $temp_model_input_file) || die "Can't open file ".$temp_model_input_file;
        print $F_model "<annotations>\n";

        while (my ($image_id, $p) = each %unique_image_ids) {
            my $file_path = $p->{image_fullpath};
            my $width = $p->{width};
            my $height = $p->{height};
            my $temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_input_annotations_dir/inputannotationfileXXXX');
            # print STDERR Dumper $archive_temp_input_file;

            open(my $F_img, ">", $temp_input_file) || die "Can't open file ".$temp_input_file;
                print $F_img "<annotation>\n";
                print $F_img "\t<image_id>$image_id</image_id>\n";
                print $F_img "\t<image_path>$file_path</image_path>\n";
                print $F_img "\t<size>\n";
                print $F_img "\t\t<width>$width</width>\n";
                print $F_img "\t\t<height>$height</height>\n";
                print $F_img "\t</size>\n";

                print $F_model "<annotation>\n";
                print $F_model "\t<image_id>$image_id</image_id>\n";
                print $F_model "\t<image_path>$file_path</image_path>\n";
                print $F_model "\t<size>\n";
                print $F_model "\t\t<width>$width</width>\n";
                print $F_model "\t\t<height>$height</height>\n";
                print $F_model "\t</size>\n";

                foreach my $poly (@{$p->{p}}) {
                    foreach my $po (values %{$poly->{polygon}}) {
                        my $xmin = 1000000;
                        my $ymin = 1000000;
                        my $xmax = 0;
                        my $ymax = 0;
                        foreach my $ob (@$po) {
                            if ($ob->{x} < $xmin) {
                                $xmin = round($ob->{x});
                            }
                            if ($ob->{y} < $ymin) {
                                $ymin = round($ob->{y});
                            }
                            if ($ob->{x} > $xmax) {
                                $xmax = round($ob->{x});
                            }
                            if ($ob->{y} > $ymax) {
                                $ymax = round($ob->{y});
                            }
                        }
                        print $F_img "\t<object>\n";
                        print $F_img "\t\t<name>".$poly->{template_name}."</name>\n";
                        print $F_img "\t\t<bndbox>\n";
                        print $F_img "\t\t\t<xmin>$xmin</xmin>\n";
                        print $F_img "\t\t\t<ymin>$ymin</ymin>\n";
                        print $F_img "\t\t\t<xmax>$xmax</xmax>\n";
                        print $F_img "\t\t\t<ymax>$ymax</ymax>\n";
                        print $F_img "\t\t</bndbox>\n";
                        print $F_img "\t</object>\n";

                        print $F_model "\t<object>\n";
                        print $F_model "\t\t<name>".$poly->{template_name}."</name>\n";
                        print $F_model "\t\t<bndbox>\n";
                        print $F_model "\t\t\t<xmin>$xmin</xmin>\n";
                        print $F_model "\t\t\t<ymin>$ymin</ymin>\n";
                        print $F_model "\t\t\t<xmax>$xmax</xmax>\n";
                        print $F_model "\t\t\t<ymax>$ymax</ymax>\n";
                        print $F_model "\t\t</bndbox>\n";
                        print $F_model "\t</object>\n";
                    }
                }
                print $F_img "</annotation>\n";

                print $F_model "</annotation>\n";
            close($F_img);
        }
        print $F_model "</annotations>\n";
    close($F_model);

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }
    my $cmd = $c->config->{python_executable_maskrcnn_env}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/MaskRCNNBoundingBoxTrain.py --input_annotations_dir \''.$temp_input_dir.'\' --output_model_path \''.$temp_output_model_file.'\' --output_model_dir \''.$temp_output_dir.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $keras_mask_r_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_mask_r_cnn_model', 'protocol_type')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $m = CXGN::AnalysisModel::SaveModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        archive_path=>$c->config->{archive_path},
        model_name=>$model_name,
        model_description=>$model_description,
        model_type_cvterm_id=>$keras_mask_r_cnn_cvterm_id,
        model_experiment_type_cvterm_id=>$keras_cnn_experiment_cvterm_id,
        model_properties=>{model_type=>$model_type, image_type=>'all_annotated_plot_images'},
        archived_model_file_type=>'trained_keras_mask_r_cnn_model',
        model_file=>$temp_output_model_file,
        archived_training_data_file_type=>'trained_keras_mask_r_cnn_model_input_data_file',
        archived_training_data_file=>$temp_model_input_file,
        # archived_auxiliary_files=>[
        #     {auxiliary_model_file => $archive_temp_autoencoder_output_model_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_autoencoder_model'},
        #     {auxiliary_model_file => $model_input_aux_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_model_input_aux_data_file'}
        # ],
        user_id=>$user_id,
        user_role=>$user_role
    });
    my $saved_model = $m->save_model();

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_predict_mask_rcnn : Path('/api/drone_imagery/predict_mask_rcnn') : ActionClass('REST') { }
sub drone_imagery_predict_mask_rcnn_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $model_id = $c->req->param('model_id');
    my $image_id = $c->req->param('image_id');

    my $time = DateTime->now();
    my $timestamp = $time->ymd();

    my $keras_mask_r_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_mask_r_cnn_model', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    my $model_type = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{model_type};
    my $trained_image_type = $saved_model_object->{model_properties}->{$model_properties_cvterm_id}->{image_type};
    my $model_file = $saved_model_object->{model_files}->{trained_keras_mask_r_cnn_model};
    my $training_input_data_file = $saved_model_object->{model_files}->{trained_keras_mask_r_cnn_model_input_data_file};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    my @size = imgsize($image_fullpath);
    my $width = $size[0];
    my $height = $size[1];

    my $output_dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_predict_dir');
    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_predict_input_annotations_dir');
    my $model_dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_predict_input_model_dir');
    my $temp_input_dir = $c->config->{basepath}."/".$dir;
    my $temp_model_dir = $c->config->{basepath}."/".$model_dir;
    print STDERR Dumper $temp_input_dir;

    my $archive_temp_output_results_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_predict_dir/outputfileXXXX');
    my $archive_temp_output_activation_file = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_predict_input_model_dir/outputactivationfileXXXX');
    $archive_temp_output_activation_file .= ".pdf";
    my $archive_temp_output_activation_file_path = $c->config->{basepath}."/".$archive_temp_output_activation_file;

    my $temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_predict_input_annotations_dir/inputannotationfileXXXX');
    # print STDERR Dumper $archive_temp_input_file;

    open(my $F_img, ">", $temp_input_file) || die "Can't open file ".$temp_input_file;
        print $F_img "<annotation>\n";
        print $F_img "\t<image_id>$image_id</image_id>\n";
        print $F_img "\t<image_path>$image_fullpath</image_path>\n";
        print $F_img "\t<size>\n";
        print $F_img "\t\t<width>$width</width>\n";
        print $F_img "\t\t<height>$height</height>\n";
        print $F_img "\t</size>\n";
        print $F_img "</annotation>\n";
    close($F_img);

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }
    my $cmd = $c->config->{python_executable_maskrcnn_env}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/MaskRCNNBoundingBoxPredict.py --input_annotations_dir \''.$temp_input_dir.'\' --model_path \''.$model_file.'\' --model_dir \''.$temp_model_dir.'\' --outfile_annotated \''.$archive_temp_output_activation_file_path.'\' --results_outfile \''.$archive_temp_output_results_file.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my @bounding_boxes;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_results_file) or die "Could not open file '$archive_temp_output_results_file' $!";
        print STDERR "Opened $archive_temp_output_results_file\n";
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            print STDERR Dumper \@columns;
            push @bounding_boxes, \@columns;
        }
    close($fh);

    $c->stash->{rest} = {success => 1, activation_output => $archive_temp_output_activation_file, bounding_boxes => \@bounding_boxes};
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    return ($user_id, $user_name, $user_role);
}

1;
