
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
        WHERE project_image.type_id in ($sql);";

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
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $statistics_select = $c->req->param('statistics_select');
    my $field_trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];

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
    my @sorted_trait_names = sort keys %$unique_traits;

    my %germplasm_name_encoder;
    my $germplasm_name_encoded = 1;
    my %trait_name_encoder;
    my $trait_name_encoded = 1;
    my %phenotype_data;
    foreach my $obs_unit (@$data){
        my $germplasm_name = $obs_unit->{germplasm_uniquename};
        my $observations = $obs_unit->{observations};
        if (!exists($germplasm_name_encoder{$germplasm_name})) {
            $germplasm_name_encoder{$germplasm_name} = $germplasm_name_encoded;
            $germplasm_name_encoded++;
        }
        foreach (@$observations){
            $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$_->{trait_name}} = $_->{value};
        }
    }
    foreach my $trait_name (@sorted_trait_names) {
        if (!exists($trait_name_encoder{$trait_name})) {
            $trait_name_encoder{$trait_name} = 't'.$trait_name_encoded;
            $trait_name_encoded++;
        }
    }

    my @data_matrix;
    my @data_total;
    foreach (@$data) {
        my $germplasm_name = $_->{germplasm_uniquename};
        my @row = ($_->{obsunit_rep}, $germplasm_name_encoder{$germplasm_name});
        my @row2 = ($_->{observationunit_uniquename}, $_->{obsunit_rep}, $germplasm_name);
        foreach my $t (@sorted_trait_names) {
            if (defined($phenotype_data{$_->{observationunit_uniquename}}->{$t})) {
                push @row, $phenotype_data{$_->{observationunit_uniquename}}->{$t} + 0;
                push @row2, $phenotype_data{$_->{observationunit_uniquename}}->{$t} + 0;
            } else {
                print STDERR $_->{observationunit_uniquename}." : $t : $germplasm_name : NA \n";
                push @row, 'NA';
                push @row2, 'NA';
            }
        }
        push @data_matrix, @row;
        push @data_total, \@row2;
    }

    my @phenotype_header = ("replicate", "germplasmName");
    foreach (@sorted_trait_names) {
        push @phenotype_header, $trait_name_encoder{$_};
    }

    my $rmatrix = R::YapRI::Data::Matrix->new({
        name => 'matrix1',
        coln => scalar(@phenotype_header),
        rown => scalar(@$data),
        colnames => \@phenotype_header,
        data => \@data_matrix
    });

    my @results;
    if ($statistics_select eq 'lmer_germplasmname') {
        foreach my $t (@sorted_trait_names) {
            my $rbase = R::YapRI::Base->new();
            my $r_block = $rbase->create_block('r_block');
            $rmatrix->send_rbase($rbase, 'r_block');
            $r_block->add_command('library(lme4)');
            $r_block->add_command('mixed.lmer <- lmer('.$trait_name_encoder{$t}.' ~ replicate + (1|germplasmName), data = data.frame(matrix1), na.action = na.omit )');
            $r_block->add_command('mixed.lmer.summary <- summary(mixed.lmer)');
            $r_block->add_command('mixed.lmer.matrix <- matrix(NA,nrow = 1, ncol = 1)');
            $r_block->add_command('mixed.lmer.matrix[1,1] <- mixed.lmer.summary$varcor$germplasmName[1,1]/(mixed.lmer.summary$varcor$germplasmName[1,1] + (mixed.lmer.summary$sigma)^2)');
            $r_block->run_block();
            my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','mixed.lmer.matrix');
            #print STDERR Dumper $result_matrix;
            push @results, [$t, ($result_matrix->{data}->[0] * 100)];
        }
    }

    $c->stash->{rest} = \@results;
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

    my $return = _perform_plot_polygon_assign($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $stock_polygons, $assign_plot_polygons_type, $user_id, $user_name, $user_role, 1);

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
    print STDERR "Plot Polygon Assign Type: $assign_plot_polygons_type \n";

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        if ($from_web_interface) {
            my $last_point = pop @$polygon;
        }
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

    my $pm = Parallel::ForkManager->new(floor(int($number_system_cores)*0.5));
    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
        push @plot_polygon_image_urls, $data_structure_reference->{plot_polygon_image_url};
        push @plot_polygon_image_fullpaths, $data_structure_reference->{plot_polygon_image_fullpath};
    });

    foreach my $stock_name (keys %$polygon_objs) {
        my $pid = $pm->start and next;

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

        $pm->finish(0, { plot_polygon_image_url => $plot_polygon_image_url, plot_polygon_image_fullpath => $plot_polygon_image_fullpath });
    }
    $pm->wait_all_children;

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, success => 1, drone_run_band_template_id => $drone_run_band_plot_polygons->projectprop_id
    };
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
    my $field_trial_id = $c->req->param('field_trial_id');

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_camera_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($field_trial_id) {
        $where_clause = ' WHERE field_trial.project_id = ? ';
    }

    my $q = "SELECT project.project_id, project.name, project.description, drone_run_type.value, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description, drone_run_camera_type.value FROM project
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        LEFT JOIN projectprop AS drone_run_type ON (project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        LEFT JOIN projectprop AS drone_run_camera_type ON (project.project_id=drone_run_camera_type.project_id AND drone_run_camera_type.type_id=$drone_run_camera_cvterm_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);
    my @result;
    while (my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $drone_run_camera_type) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_project_id'>";
        }
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$drone_run_project_id\">$drone_run_project_name</a>",
            $drone_run_type,
            $drone_run_project_description,
            $drone_run_date_display,
            $drone_run_camera_type,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $field_trial_project_description
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}


sub get_plot_polygon_types : Path('/api/drone_imagery/plot_polygon_types') : ActionClass('REST') { }
sub get_plot_polygon_types_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json $c->req->param('drone_run_ids') : [];

    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
    my $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);

    my @where_clause;
    push @where_clause, "project_md_image.type_id in ($project_image_type_id_list_sql)";

    if ($field_trial_id) {
        push @where_clause, "field_trial.project_id = ?";
    }
    if ($drone_run_ids && scalar(@$drone_run_ids)>0) {
        my $sql = join ("," , @$drone_run_ids);
        push @where_clause, "drone_run.project_id in ($sql)";
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
        $where_clause
        GROUP BY drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name
        ORDER BY drone_run_band.project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $project_md_image_type_id, $project_md_image_type_name, $plot_polygon_count) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$project_md_image_type_id' checked>";
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
        $where_clause = ' WHERE project.project_id = ? ';
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
    $h->execute($drone_run_project_id);
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
                push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_band_project_id' data-background_removed_threshold_type='$background_removed_threshold_type' $checked $disabled>";
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

    if (!$planting_date) {
        return { drone_run_date => $drone_date, error => 'The planting date is not set on the field trial, so we could not get the time of this flight automaticaly; however you can still select the time manually'};
    }

    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $drone_date_time_object = Time::Piece->strptime($drone_date, "%Y-%B-%d");
    my $time_diff = $drone_date_time_object - $planting_date_time_object;
    my $time_diff_weeks = $time_diff->weeks;
    my $rounded_time_diff_weeks = round($time_diff_weeks);
    print STDERR Dumper $rounded_time_diff_weeks;

    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute("week $rounded_time_diff_weeks", 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    if (!$week_cvterm_id) {
        return { planting_date => $planting_date, drone_run_date => $drone_date, time_difference_weeks => $time_diff_weeks, rounded_time_difference_weeks => $rounded_time_diff_weeks, error => 'The time ontology term was not found automatically! Maybe the field trial planting date or the drone run date are not correct in the database? The maximum number of weeks currently allowed between these two dates is 54 weeks. This should not be possible, please contact us; however you can still select the time manually'};
    }

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');

    return { planting_date => $planting_date, drone_run_date => $drone_date, time_difference_weeks => $time_diff_weeks, rounded_time_difference_weeks => $rounded_time_diff_weeks, time_ontology_cvterm_id => $week_cvterm_id, time_ontology_term => $week_term};
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
            my $plot_polygon_original_denoised_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0);
        }

        for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
            $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
            my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
            $archive_remove_background_temp_image .= '.png';

            my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0);
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

    my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, $user_id, $user_name, $user_role);

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
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
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

    my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, $user_id, $user_name, $user_role);

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

    my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{index}->{(%{$vi_map{$vi}->{index}})[0]}->[0], $user_id, $user_name, $user_role, 0);
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
    
    my $fourier_transform_hpf20_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20}->{(%{$vi_map{$vi}->{ft_hpf20}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30}->{(%{$vi_map{$vi}->{ft_hpf30}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40}->{(%{$vi_map{$vi}->{ft_hpf40}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{index_threshold_background}})[0], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
    my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

    my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{index_threshold_background}->{(%{$vi_map{$vi}->{index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf20_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_index_threshold_background}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf20_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_index_threshold_background}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf30_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_index_threshold_background}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf40_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $threshold_masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0], $user_id, $user_name, $user_role);
    my $threshold_masked_image_id = $threshold_masked_return->{masked_image_id};

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[1], $user_id, $user_name, $user_role, 0);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[2], $user_id, $user_name, $user_role, 0);

    if ($vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[3]) {
        $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[3], $user_id, $user_name, $user_role, 0);
    }

    my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    if ($vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}) {
        my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

        my $plot_polygon_ft_hpf20_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0);
    }

    if ($vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}) {
        my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

        my $plot_polygon_ft_hpf30_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0);
    }

    if ($vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}) {
        my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

        my $plot_polygon_ft_hpf40_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0);
    }

    my $masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{original_index_mask_background}})[0], $user_id, $user_name, $user_role);
    my $masked_image_id = $masked_return->{masked_image_id};

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[1], $user_id, $user_name, $user_role, 0);

    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[2], $user_id, $user_name, $user_role, 0);

    if ($vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[3]) {
        $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[3], $user_id, $user_name, $user_role, 0);
    }

    my $fourier_transform_hpf20_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf20_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0);

    if ($vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}) {
        my $fourier_transform_hpf20_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

        my $plot_polygon_ft_hpf20_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0);
    }

    if ($vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}) {
        my $fourier_transform_hpf30_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

        my $plot_polygon_ft_hpf30_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0);
    }

    if ($vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}) {
        my $fourier_transform_hpf40_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

        my $plot_polygon_ft_hpf40_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0);
    }
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

    my $fourier_transform_hpf20_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf20_imagery_type, '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_plot_polygon_type, $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf30_imagery_type, '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf30_plot_polygon_type, $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf40_imagery_type, '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf40_plot_polygon_type, $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf20_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf20_background_threshold_removed_imagery_type, '20', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf20_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf30_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf30_background_threshold_removed_imagery_type, '30', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf30_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf30_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0);

    my $fourier_transform_hpf40_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf40_background_threshold_removed_imagery_type, '40', 'frequency', $user_id, $user_name, $user_role);

    my $plot_polygon_ft_hpf40_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf40_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0);
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

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_rgb_imagery', $user_id, $user_name, $user_role, 0);

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

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_nrn_imagery', $user_id, $user_name, $user_role, 0);

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

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_nren_imagery', $user_id, $user_name, $user_role, 0);

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

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, image_width => $size[0], image_height => $size[1] };
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
        $in_progress_indicator = $drone_run_band_remove_background_threshold_rs->first->value();
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
            my $pm = Parallel::ForkManager->new(floor(int($number_system_cores)*0.5));
            foreach my $plot_polygon_type (@{$project_observation_unit_plot_polygons_types{$drone_run_band_project_type}->{$standard_process_type}}) {
                my $pid = $pm->start and next;
                my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygon_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, 1);
                if ($return->{error}){
                    print STDERR Dumper $return->{error};
                }
                $pm->finish();
            }
            $pm->wait_all_children;
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

    my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygons_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, undef);

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

    my $return = _perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id, $time_cvterm_id, $phenotype_methods, $standard_process_type, $user_id, $user_name, $user_role);

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
        foreach (@$result) {
            my $image_id = $_->{image_id};
            my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            my $image_url = $image->get_image_url("original");
            my $image_fullpath = $image->get_filename('original_converted', 'full');
            my $image_source_tag_small = $image->get_img_src_tag("tiny");
            push @image_paths, $image_fullpath;

            if ($phenotype_method ne 'zonal') {
                my $dir = $c->tempfiles_subdir('/'.$temp_images_subdir);
                my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_images_subdir.'/imageXXXX');
                $archive_temp_image .= '.png';
                push @out_paths, $archive_temp_image;
            }

            push @stocks, {
                stock_id => $_->{stock_id},
                stock_uniquename => $_->{stock_uniquename},
                stock_type_id => $_->{stock_type_id},
                image => '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>',
                image_id => $image_id
            };
        }
        #print STDERR Dumper \@image_paths;
        my $image_paths_string = join ',', @image_paths;
        my $out_paths_string = join ',', @out_paths;

        if ($out_paths_string) {
            $out_paths_string = ' --outfile_paths '.$out_paths_string;
        }

        my $dir = $c->tempfiles_subdir('/'.$temp_results_subdir);
        my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_results_subdir.'/imageXXXX');

        my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/'.$calculate_phenotypes_script.' --image_paths \''.$image_paths_string.'\' '.$out_paths_string.' --results_outfile_path \''.$archive_temp_results.'\''.$calculate_phenotypes_extra_args;
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
                if ($header_cols[0] ne 'nonzero_pixel_count' ||
                    $header_cols[1] ne 'total_pixel_sum' ||
                    $header_cols[2] ne 'mean_pixel_value' ||
                    $header_cols[3] ne 'harmonic_mean_value' ||
                    $header_cols[4] ne 'median_pixel_value' ||
                    $header_cols[5] ne 'variance_pixel_value' ||
                    $header_cols[6] ne 'stdev_pixel_value' ||
                    $header_cols[7] ne 'pstdev_pixel_value' ||
                    $header_cols[8] ne 'min_pixel_value' ||
                    $header_cols[9] ne 'max_pixel_value' ||
                    $header_cols[10] ne 'minority_pixel_value' ||
                    $header_cols[11] ne 'minority_pixel_count' ||
                    $header_cols[12] ne 'majority_pixel_value' ||
                    $header_cols[13] ne 'majority_pixel_count' ||
                    $header_cols[14] ne 'pixel_variety_count'
                ) {
                    $c->stash->{rest} = { error => "Pheno results must have header: 'nonzero_pixel_count', 'total_pixel_sum', 'mean_pixel_value', 'harmonic_mean_value', 'median_pixel_value', 'variance_pixel_value', 'stdev_pixel_value', 'pstdev_pixel_value', 'min_pixel_value', 'max_pixel_value', 'minority_pixel_value', 'minority_pixel_count', 'majority_pixel_value', 'majority_pixel_count', 'pixel_variety_count'" };
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
                    #print STDERR Dumper \@columns;
                    $stocks[$line]->{result} = \@columns;

                    $plots_seen{$stocks[$line]->{stock_uniquename}} = 1;
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$non_zero_pixel_count_composed_trait_name} = [$columns[0], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$total_pixel_sum_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$mean_pixel_value_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$harmonic_mean_pixel_value_composed_trait_name} = [$columns[3], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$median_pixel_value_composed_trait_name} = [$columns[4], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_variance_composed_trait_name} = [$columns[5], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_standard_dev_composed_trait_name} = [$columns[6], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_pstandard_dev_composed_trait_name} = [$columns[7], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minimum_pixel_value_composed_trait_name} = [$columns[8], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$maximum_pixel_value_composed_trait_name} = [$columns[9], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minority_pixel_value_composed_trait_name} = [$columns[10], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minority_pixel_count_composed_trait_name} = [$columns[11], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$majority_pixel_value_composed_trait_name} = [$columns[12], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$majority_pixel_count_composed_trait_name} = [$columns[13], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_group_count_composed_trait_name} = [$columns[14], $timestamp, $user_name, '', $stocks[$line]->{image_id}];

                    $line++;
                }
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

            my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
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
                #overwrite_values=>1,
                ignore_new_values=>1,
                metadata_hash=>\%phenotype_metadata
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

sub drone_imagery_train_keras_model : Path('/api/drone_imagery/train_keras_model') : ActionClass('REST') { }
sub drone_imagery_train_keras_model_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $field_trial_id = $c->req->param('field_trial_id');
    my $trait_id = $c->req->param('trait_id');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');
    my $archive_temp_result_agg_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/resultaggXXXX');

    my @result_agg;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my %data_hash;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$data_hash{$_->{stock_id}}->{image_fullpaths}}, $image_fullpath;
    }

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$schema,
        search_type=>'MaterializedViewTable',
        data_level=>'plot',
        trait_list=>[$trait_id],
        trial_list=>[$field_trial_id],
        include_timestamp=>0,
        exclude_phenotype_outlier=>0,
    );
    my @data = $phenotypes_search->get_phenotype_matrix();

    my $phenotype_header = shift @data;
    foreach (@data) {
        $data_hash{$_->[21]}->{trait_value} = $_->[39];
    }
    #print STDERR Dumper \%data_hash;

    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputfileXXXX');
    my $archive_temp_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/modelfileXXXX');

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        foreach my $data (values %data_hash){
            my $image_fullpaths = $data->{image_fullpaths};
            my $value = $data->{trait_value};
            if ($value) {
                foreach (@$image_fullpaths) {
                    print $F '"'.$_.'",';
                    print $F '"'.$value.'"';
                    print $F "\n";
                }
            }
        }
    close($F);

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/BasicCNN.py --input_image_label_file \''.$archive_temp_input_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\'';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my @header_cols;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        my $header = <$fh>;
        if ($csv->parse($header)) {
            @header_cols = $csv->fields();
        }
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @result_agg, \@columns;
        }
    close($fh);
    #print STDERR Dumper \@result_agg;

    print STDERR Dumper $archive_temp_result_agg_file;
    open($F, ">", $archive_temp_result_agg_file) || die "Can't open file ".$archive_temp_result_agg_file;
        foreach my $data (@result_agg){
            print $F join ',', @$data;
            print $F "\n";
        }
    close($F);

    $c->stash->{rest} = { success => 1, results => \@result_agg };
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
