
=head1 NAME

SGN::Controller::AJAX::ImageAnalysis - a REST controller class to provide image analysis including
functions for necrosis image analysis https://github.com/solomonnsumba/Necrosis-_Web_Server

=head1 DESCRIPTION

=head1 AUTHOR

Bryan Ellerbrock <bje24@cornell.edu>

=cut

package SGN::Controller::AJAX::ImageAnalysis;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use LWP::Simple;
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
use List::Util qw/sum/;
use Parallel::ForkManager;
use CXGN::Image::Search;
use CXGN::Trait::Search;
use File::Slurp;
use File::Basename;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub create_run_project : Path('/ajax/image_analysis/create_run_project') : ActionClass('REST') { }

sub create_run_project_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    $phenome_schema->storage->dbh($schema->storage->dbh);

    print STDERR "create_run_project_POST called\n";

    if (!$c->user()) {
        $c->stash->{rest} = { error => "Must be logged in!" };
        $c->detach();
    }
    my $user_id   = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $user_role = $c->user()->roles();

    my $trial_id           = $c->req->param('trial_id');
    my $run_name           = $c->req->param('run_name');
    my $service_name       = $c->req->param('service_name');
    my $run_date           = $c->req->param('run_date');
    my $analysis_info_json = $c->req->param('analysis_info_json') || '{}';
    my $analysis_metadata = decode_json($analysis_info_json);
    $analysis_metadata = $analysis_metadata->{analysis_metadata} if $analysis_metadata->{analysis_metadata};
    print STDERR "Analysis info json create test: $analysis_info_json";
    my $source_stock_id    = $c->req->param('source_stock_id');
    my $source_image_id    = $c->req->param('source_image_id');
    my $trait_ids          = $c->req->param('trait_ids');

    my $overlay_image_id   = $c->req->param('overlay_image_id');

    my $tissue_samples = decode_json(
        $c->req->param('tissue_samples') || '[]'
    );

    print STDERR "Params: trial_id=$trial_id, " .
        "source_stock_id=$source_stock_id, " .
        "source_image_id=$source_image_id\n";

    unless ($trial_id && $source_stock_id && $source_image_id) {
        $c->stash->{rest} = {
            error => "trial_id, source_stock_id, source_image_id required"
        };
        $c->detach();
    }
    unless (@$tissue_samples) {
        $c->stash->{rest} = {
            error => "At least one tissue_sample required"
        };
        $c->detach();
    }

    my $trial = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id   => $trial_id
    });
    my $geolocation_id = $trial->get_location()->[0];
    my $trial_name     = $trial->get_name();

    print STDERR "Trial: $trial_name, geolocation: $geolocation_id\n";

    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'design', 'project_property' )->cvterm_id();

    my $analysis_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_run_project_type', 'project_property' )->cvterm_id();

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'project_start_date', 'project_property' )->cvterm_id();

    my $analysis_run_params_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_run_parameters_json', 'project_property' )->cvterm_id();

    my $analysis_job_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_job_id', 'project_property' )->cvterm_id();

    my $analysis_pipeline_name_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_pipeline_name', 'project_property' )->cvterm_id();

    my $analysis_pipeline_version_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_pipeline_version', 'project_property' )->cvterm_id();

    my $analysis_run_timestamp_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_run_timestamp', 'project_property' )->cvterm_id();

    my $analysis_input_filename_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_input_filename', 'project_property' )->cvterm_id();

    my $analysis_qc_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_qc_json', 'project_property' )->cvterm_id();

    my $analysis_traits_emitted_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_traits_emitted_json', 'project_property' )->cvterm_id();

    my $analysis_raw_result_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_raw_result_json', 'project_property' )->cvterm_id();

    my $analysis_run_on_trial_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_run_on_field_trial', 'project_relationship' )->cvterm_id();

    my $image_analysis_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_experiment', 'experiment_type' )->cvterm_id();

    # project_md_image types
    my $source_image_type_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_source_image', 'project_md_image' )->cvterm_id();

    my $overlay_image_type_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_result_overlay', 'project_md_image' )->cvterm_id();

    my $sample_result_image_type_id = SGN::Model::Cvterm->get_cvterm_row( $schema, 'image_analysis_tissue_sample_result_image', 'stock_md_image' )->cvterm_id();

    my $calendar_funcs = CXGN::Calendar->new({});
    my $run_date_event = $calendar_funcs->check_value_format($run_date);

    my @projectprops = (
        { type_id => $design_cvterm_id,
          value   => 'image_analysis_run' },
        { type_id => $analysis_run_type_cvterm_id,
          value   => $service_name },
        { type_id => $project_start_date_type_id,
          value   => $run_date_event },
        { type_id => $analysis_run_params_cvterm_id,
          value   => $analysis_info_json },
    );

        my $run_timestamp = $analysis_metadata->{run_timestamp} || $analysis_metadata->{timestamp};

    my %metadata_props = (
        $analysis_job_id_cvterm_id           => $analysis_metadata->{job_id},
        $analysis_pipeline_name_cvterm_id    => $analysis_metadata->{pipeline_name},
        $analysis_pipeline_version_cvterm_id => $analysis_metadata->{pipeline_version},
        $analysis_run_timestamp_cvterm_id    => $run_timestamp,
        $analysis_input_filename_cvterm_id   => $analysis_metadata->{input_filename},
        $analysis_qc_json_cvterm_id          => $analysis_metadata->{qc_json},
        $analysis_traits_emitted_cvterm_id   => $analysis_metadata->{traits_emitted_json},
        $analysis_raw_result_cvterm_id       => $analysis_metadata->{raw_result_json},
    );

    foreach my $type_id (keys %metadata_props) {
        my $value = $metadata_props{$type_id};
        next unless defined $value && $value ne '';
        push @projectprops, {
            type_id => $type_id,
            value   => $value,
        };
    }

    my @trait_terms;
    if ($analysis_metadata->{traits_emitted_json}) {
        my $emitted = eval {
            decode_json($analysis_metadata->{traits_emitted_json})
        };
        if ($@) {
            print STDERR "Failed to parse traits_emitted_json: $@\n";
        }
        elsif (ref($emitted) eq 'ARRAY') {
            @trait_terms = @$emitted;
        }
    }

    my @trait_cvterm_ids;
    if ($trait_ids) {
        my $tids = eval { decode_json($trait_ids) };
        if (!$@ && ref($tids) eq 'ARRAY') {
            my %seen;
            @trait_cvterm_ids =
                grep { !$seen{$_}++ }
                grep { defined $_ && /^\d+$/ }
                @$tids;
        }
    }

    print STDERR "Resolved " . scalar(@trait_cvterm_ids) .
                " of " . scalar(@trait_terms) . " emitted traits\n";

    my $run_project_id;

    eval {
        $schema->txn_do(sub {

            my @nd_experiment_stocks = ({
                stock_id => $source_stock_id,
                type_id  => $image_analysis_experiment_type_id,
            });

            foreach my $sample (@$tissue_samples) {
                push @nd_experiment_stocks, {
                    stock_id => $sample->{stock_id},
                    type_id  => $image_analysis_experiment_type_id,
                };
            }

            my $nd_experiment_rs =
                $schema->resultset(
                    'NaturalDiversity::NdExperiment'
                )->create({
                    nd_geolocation_id    => $geolocation_id,
                    type_id              => $image_analysis_experiment_type_id,
                    nd_experiment_stocks => \@nd_experiment_stocks,
                });

            my $nd_experiment_id = $nd_experiment_rs->nd_experiment_id();
            print STDERR "Created nd_experiment: $nd_experiment_id\n";

            # Create image_analysis_run project
            my $project =
                $schema->resultset('Project::Project')->create({
                    name        => $run_name,
                    description =>
                        "Image analysis using $service_name " .
                        "on trial $trial_name.",
                    projectprops => \@projectprops,
                    project_relationship_subject_projects => [{
                        type_id           =>
                            $analysis_run_on_trial_rel_cvterm_id,
                        object_project_id => $trial_id,
                    }],
                    nd_experiment_projects => [{
                        nd_experiment_id => $nd_experiment_id,
                    }],
                });

            $run_project_id = $project->project_id();
            print STDERR "Created run project: $run_project_id\n";

            foreach my $trait_cvterm_id (@trait_cvterm_ids) {
                $schema->resultset('Project::Projectprop')->find_or_create({
                    project_id => $run_project_id,
                    type_id    => $trait_cvterm_id,
                    value      => 1,
                });
            }
            print STDERR "Associated " . scalar(@trait_cvterm_ids) .
                         " traits with project $run_project_id\n";

            my $dbh = $schema->storage->dbh();

            # Link source image to run project
            my $sth = $dbh->prepare(
                "INSERT INTO phenome.project_md_image (project_id, image_id, type_id)
                SELECT ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM phenome.project_md_image
                    WHERE project_id = ? AND image_id = ? AND type_id = ?
                )"
            );

            $sth->execute(
                $run_project_id, $source_image_id, $source_image_type_id,
                $run_project_id, $source_image_id, $source_image_type_id
            );
            print STDERR "Linked source image: $source_image_id\n";

            # Link overlay image to run project
            if ($overlay_image_id) {
                $sth->execute(
                    $run_project_id, $overlay_image_id, $overlay_image_type_id,
                    $run_project_id, $overlay_image_id, $overlay_image_type_id
                );
                print STDERR "Linked overlay image: $overlay_image_id\n";
            }
        });
    };

    if ($@) {
        print STDERR "create_run_project error: $@\n";
        $c->stash->{rest} = {
            error => "Failed to create run project: $@"
        };
        $c->detach();
    }

    print STDERR "create_run_project success: $run_project_id\n";

    $c->stash->{rest} = {
        success            => 1,
        run_project_id     => $run_project_id,
        run_name           => $run_name,
        traits_associated  => scalar(@trait_cvterm_ids),
    };
}

sub run_object_results : Path('/ajax/image_analysis/run_object_results') : ActionClass('REST') { }

sub run_object_results_GET : Args(0) {
    my ($self, $c) = @_;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $run_project_id = $c->req->param('run_project_id');

    unless ($run_project_id) {
        $c->stash->{rest} = { error => "run_project_id is required" };
        return;
    }

    # CVterm IDs for the projectprops 
    my $raw_result_cvterm_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_raw_result_json', 'project_property'
        )->cvterm_id();

    my $traits_emitted_cvterm_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_traits_emitted_json', 'project_property'
        )->cvterm_id();

    my $overlay_image_type_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_result_overlay', 'project_md_image'
        )->cvterm_id();


    my $raw_prop = $schema->resultset('Project::Projectprop')->find({
        project_id => $run_project_id,
        type_id    => $raw_result_cvterm_id,
    });

    unless ($raw_prop && $raw_prop->value) {
        $c->stash->{rest} = {
            error      => "No stored analysis results found for this run project.",
            table_data => [],
        };
        return;
    }

    my $raw_result = eval { decode_json($raw_prop->value) };
    if ($@ || !$raw_result) {
        print STDERR "run_object_results: failed to parse raw_result_json: $@\n";
        $c->stash->{rest} = {
            error      => "Failed to parse stored analysis results.",
            table_data => [],
        };
        return;
    }

    my $source_stock_name = $self->_get_source_stock_name($c, $schema, $run_project_id);

    # Optional overlay image url (used as analyzed_link fallback)
    my $overlay_image_url;
    my $dbh = $schema->storage->dbh();
    my $img_sth = $dbh->prepare(
        "SELECT image_id FROM phenome.project_md_image
         WHERE project_id = ? AND type_id = ?
         LIMIT 1"
    );
    $img_sth->execute($run_project_id, $overlay_image_type_id);
    if (my ($overlay_image_id) = $img_sth->fetchrow_array()) {
        my $image = SGN::Image->new($schema->storage->dbh(), $overlay_image_id, $c);
        $overlay_image_url = $image->get_image_url("medium");
    }

    my $objects = $raw_result->{objects} || [];

    # Determine the list of traits to report
    my @traits_emitted;
    if (ref($raw_result->{traits_emitted}) eq 'ARRAY') {
        @traits_emitted = @{ $raw_result->{traits_emitted} };
    }
    else {
        # Fall back to the projectprop, then to keys seen on the first object
        my $te_prop = $schema->resultset('Project::Projectprop')->find({
            project_id => $run_project_id,
            type_id    => $traits_emitted_cvterm_id,
        });
        if ($te_prop && $te_prop->value) {
            my $te = eval { decode_json($te_prop->value) };
            @traits_emitted = @$te if !$@ && ref($te) eq 'ARRAY';
        }
        if (!@traits_emitted && @$objects && $objects->[0]->{traits}) {
            @traits_emitted = keys %{ $objects->[0]->{traits} };
        }
    }

    # Build a map of object number -> tissue sample stock.
    my $tissue_sample_type_id = eval {
        SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    };

    my %sample_by_num;

    my $sql = "SELECT DISTINCT s.stock_id, s.uniquename
                FROM nd_experiment_project nep
                JOIN nd_experiment_stock nes
                ON nes.nd_experiment_id = nep.nd_experiment_id
                JOIN stock s
                ON s.stock_id = nes.stock_id
                WHERE nep.project_id = ?";
    my @params = ($run_project_id);

    if ($tissue_sample_type_id) {
        $sql .= " AND s.type_id = ?";
        push @params, $tissue_sample_type_id;
    }

    my $ts_sth = $dbh->prepare($sql);
    $ts_sth->execute(@params);

    while (my ($sid, $sname) = $ts_sth->fetchrow_array()) {
        if ($sname =~ /sample(\d+)$/) {
            $sample_by_num{ int($1) } = { stock_id => $sid, name => $sname };
        }
    }

    my @table_data;

    foreach my $trait_term (@traits_emitted) {
        my ($trait_name, $trait_accession) = split /\|/, $trait_term, 2;

        my @details;
        my @values;

        foreach my $obj (@$objects) {
            my $obj_traits = $obj->{traits} || {};
            next unless exists $obj_traits->{$trait_term};

            my $trait_data = $obj_traits->{$trait_term};
            my $value = ref($trait_data) eq 'HASH'
                ? $trait_data->{value}
                : $trait_data;
            next unless defined $value;

            # object number from source_label (authoritative)
            my $object_num = $obj->{source_label} || '';
            (my $num_only = $object_num) =~ s/\D//g;
            $num_only = length($num_only) ? int($num_only) : undef;

            my $object_name = $object_num ne '' ? $object_num
                            : ($obj->{object_id} || '');

            # matching tissue sample (by sampleN == object number)
            my $sample = defined $num_only ? $sample_by_num{$num_only} : undef;

            push @details, {
                object_name        => $object_name,
                tissue_sample_name => $sample ? $sample->{name}     : undef,
                tissue_sample_id   => $sample ? $sample->{stock_id} : undef,
                analyzed_link      => $overlay_image_url || '',
                value              => $value,
            };
            push @values, $value + 0;
        }

        next unless @details;

        my $mean;
        if (@values) {
            my $sum = 0;
            $sum += $_ for @values;
            $mean = sprintf("%.4f", $sum / scalar(@values)) + 0;
        }

        push @table_data, {
            observationUnitName     => $source_stock_name,
            observationVariableName => $trait_name,
            observationVariableId   => $trait_accession,
            numberAnalyzed          => scalar(@details),
            value                   => $mean,
            details                 => \@details,
        };
    }

    $c->stash->{rest} = {
        success    => 1,
        table_data => \@table_data,
    };
}

# Resolve the source stock (observationUnitName) for a run project by walking nd_experiment_project -> nd_experiment_stock.

sub _get_source_stock_name {
    my ($self, $c, $schema, $run_project_id) = @_;

    my $source_stock_type_id = eval {
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_source_stock', 'nd_experiment_stock_type'
        )->cvterm_id();
    };

    my $dbh = $schema->storage->dbh();

    # Prefer the explicitly typed source stock if that type is used
    if ($source_stock_type_id) {
        my $sth = $dbh->prepare(
            "SELECT s.uniquename
               FROM nd_experiment_project nep
               JOIN nd_experiment_stock nes
                 ON nes.nd_experiment_id = nep.nd_experiment_id
               JOIN stock s
                 ON s.stock_id = nes.stock_id
              WHERE nep.project_id = ?
                AND nes.type_id = ?
              LIMIT 1"
        );
        $sth->execute($run_project_id, $source_stock_type_id);
        if (my ($name) = $sth->fetchrow_array()) {
            return $name;
        }
    }

    # Fallback: any stock linked to the project's nd_experiment
    my $sth2 = $dbh->prepare(
        "SELECT s.uniquename
           FROM nd_experiment_project nep
           JOIN nd_experiment_stock nes
             ON nes.nd_experiment_id = nep.nd_experiment_id
           JOIN stock s
             ON s.stock_id = nes.stock_id
          WHERE nep.project_id = ?
          LIMIT 1"
    );
    $sth2->execute($run_project_id);
    if (my ($name) = $sth2->fetchrow_array()) {
        return $name;
    }

    my $project = $schema->resultset('Project::Project')->find({
        project_id => $run_project_id,
    });
    return $project ? $project->name() : "Unknown";
}

sub check_run_name : Path('/ajax/image_analysis/check_run_name') : ActionClass('REST') { }

sub check_run_name_GET : Args(0) {
    my ($self, $c) = @_;

    my $schema   = $c->dbic_schema("Bio::Chado::Schema");
    my $run_name = $c->req->param('run_name');

    if (!defined $run_name || $run_name =~ /^\s*$/) {
        $c->stash->{rest} = { error => "run_name is required", exists => 0 };
        return;
    }

    $run_name =~ s/^\s+|\s+$//g;

    my $existing = $schema->resultset('Project::Project')->find({ name => $run_name });

    $c->stash->{rest} = {
        exists => $existing ? 1 : 0,
    };
}

sub image_analysis_submit : Path('/ajax/image_analysis/submit') : ActionClass('REST') { }
sub image_analysis_submit_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $image_ids = decode_json $c->req->param('selected_image_ids');
    my $service = $c->req->param('service');
    my $trait = $c->req->param('trait');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $main_production_site_url = $c->config->{main_production_site_url};
    _log_analysis_activity($c,$image_ids,$service,$trait);

    unless (ref($image_ids) eq 'ARRAY') { $image_ids = [$image_ids]; }

    my $trait_details;
    my $record_number;

    if ($service ne "multi-trait") {
    my ($trait_name, $db_accession) = split(/\|/, $trait);
    my ($db, $accession) = split(/:/, $db_accession);
        ($trait_details, $record_number) = CXGN::Trait::Search->new({
        bcs_schema=>$schema,
        ontology_db_name_list => [$db],
        accession_list => [$accession]
    })->search();
    }
    print STDERR "image ids:" . Dumper $image_ids;
    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        image_id_list=>$image_ids,
    });

    my ($result, $records_total) = $image_search->search();
    my %seen_image;
    $result = [ grep { !$seen_image{ $_->{image_id} }++ } @$result ];
    print STDERR "image search result:" . Dumper $result;
    my @image_urls;
    my @image_files;
    foreach (@$result) {
        my $image = SGN::Image->new($schema->storage->dbh, $_->{image_id}, $c);
        my $original_img = $main_production_site_url.$image->get_image_url("original");
        my $image_file = $image->get_filename('original_converted', 'full');
        push @image_urls, $original_img;
        push @image_files, $image_file;
    }
    print STDERR "IMAGE URLS: ".Dumper(\@image_urls);
    print STDERR "IMAGE FILES: ".Dumper(\@image_files);

    my $service_details_json = $c->config->{image_analysis_services} || '{}';

    my %service_details = %{decode_json($service_details_json)};
    
    my $image_type_name = $service_details{$service}->{'image_type_name'};

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type_name, 'project_md_image')->cvterm_id();

    my $image_tag_id = CXGN::Tag::exists_tag_named($schema->storage->dbh, $image_type_name);
    if (!$image_tag_id) {
        my $image_tag = CXGN::Tag->new($schema->storage->dbh);
        $image_tag->set_name($image_type_name);
        $image_tag->set_description('Image analysis result image: '.$image_type_name);
        $image_tag->set_sp_person_id($user_id);
        $image_tag_id = $image_tag->store();
    }
    my $image_tag = CXGN::Tag->new($schema->storage->dbh, $image_tag_id);
    my $ua = LWP::UserAgent->new(
        ssl_opts => {
                        verify_hostname => 0,
                        timeout         => 60,
                    }
    );
    my $it = 0;

    my $image_link;
    foreach (@image_files) {
        my $dir = $c->tempfiles_subdir('/'.$image_type_name);
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');
        $archive_temp_image .= '.png';
        my %res;

        if (defined $service_details{$service}->{'server_endpoint'}) { # submit image to external service for processing
            print STDERR "Using endpoint ".$service_details{$service}->{'server_endpoint'}." to analyze image test\n";
            my $resp = $ua->post(
                $service_details{$service}->{'server_endpoint'},
                Content_Type => 'form-data',
                Content => [
                    image => [ $_, $_, Content_Type => 'image/png' ],
                ]
            );
            if ($resp->is_success) {
                my $message = $resp->decoded_content;
                my $message_hashref = decode_json $message;
                print STDERR "response message trait: " . Dumper $message_hashref;
                my $is_multi_trait = (exists $message_hashref->{objects}[0]{traits});
                print STDERR "is multi trait: $is_multi_trait";

                my $rc;
                if ($is_multi_trait) {
                    $image_link = $message_hashref->{derived_images}[0]{url};
                } else{
                    $image_link = $message_hashref->{image_link};
                }
                print STDERR "image link: $image_link";
                $rc = getstore($image_link, $archive_temp_image);
                if (is_error($rc)) {
                    die "getstore of ".$message_hashref->{image_link}." failed with $rc";
                }
                print STDERR "MESSAGE HASHREF: ".Dumper($message_hashref);

                if ($is_multi_trait) {
                    my $formatted_data = format_multi_trait_data($message_hashref);

                    $res{'subanalyses'} = $formatted_data->{subanalyses};
                    $res{'analysis_info'} = $message_hashref->{info} || {};
                    $res{'pipeline_metadata'} = {
                        job_id            => $message_hashref->{job_id},
                        timestamp         => $message_hashref->{timestamp},
                        pipeline_name     => $message_hashref->{pipeline}{name},
                        pipeline_version  => $message_hashref->{pipeline}{version},
                        input_filename    => $message_hashref->{input}{image_filename},
                        qc_json           => encode_json($message_hashref->{qc} || {}),
                        output_mode       => $message_hashref->{output_mode},
                        traits_emitted_json => encode_json($message_hashref->{traits_emitted} || []),
                        raw_result_json   => $message, 
                    };
                } else {
                $res{'value'} = $message_hashref->{trait_value};
                $res{'analysis_info'} = $message_hashref->{info} || {};
                $res{'trait'} = $trait;
                $res{'trait_id'} = $trait_details->[0]->{trait_id};
		$res{'subanalyses'} = $message_hashref->{results};
                }
            }
            else {
                print STDERR Dumper $resp->status_line;
                $res{'error'} = $resp->status_line;
            }
        }
        elsif (defined $service_details{$service}->{'script'}) { # supply image to local script for processing
            my $script = $service_details{$service}->{'script'};
            print STDERR "Using script $script to analyze image\n";
            my $input_image = $service_details{$service}->{'input_image'};
            my $outfile_image = $service_details{$service}->{'outfile_image'};
            my $results_outfile = $service_details{$service}->{'results_outfile'};
            my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');

            my $cmd = $c->config->{python_executable} . ' ' . $c->config->{rootpath} .
                '/DroneImageScripts/' . $script . ' --' . $input_image . ' \'' . $_ .
                '\' --' . $outfile_image . ' \'' . $archive_temp_image . '\' --' .
                $results_outfile . ' \'' . $archive_temp_results . '\' ';
            # print STDERR Dumper $cmd;
            my $status = system($cmd);

            my $csv = Text::CSV->new({ sep_char => ',' });
            open(my $fh, '<', $archive_temp_results)
                or die "Could not open file '$archive_temp_results' $!";
            my $line = <$fh>;
            my @columns;
            if ($csv->parse($line)) {
                @columns = $csv->fields();
            }
            $res{'value'} = $columns[0];
            $res{'trait'} = $service_details{$service}->{'trait_name'};
        }

        $res{'original_image'} = $image_urls[$it];

        unless (defined $res{'error'}) {

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5 = $image->calculate_md5sum($archive_temp_image);
            my $stock_id = $result->[$it]->{stock_id};
            my $project_id = $result->[$it]->{project_id};
            print STDERR "project id: $project_id";

            my $project_where = ' ';
            my $project_join = ' ';
            if ($project_id) {
                $project_where = " AND project_md_image.type_id = $linking_table_type_id AND project_md_image.project_id = $project_id ";
                $project_join = " JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id) ";
            }

            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                $project_join
                JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f'
                $project_where
                AND stock_image.stock_id = $stock_id
                AND md_image.md5sum = '$md5';";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute();
            my ($saved_image_id) = $h->fetchrow_array();
            my $image_id;
            if ($saved_image_id) {
                print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $image_id = $image->get_image_id();
            }
            else {
                $image->set_sp_person_id($user_id);
                if ($project_id) {
                    my $ret = $image->process_image($archive_temp_image, 'project', $project_id, $linking_table_type_id);
                    if (!$ret ) {
                        return {error => "Image processing for $archive_temp_image did not work. Image not associated to stock_id $stock_id.<br/><br/>"};
                    }
                    my $stock_associate = $image->associate_stock($stock_id);
                }
                else {
                    my $ret = $image->process_image($archive_temp_image, 'stock', $stock_id);
                    if (!$ret ) {
                        return {error => "Image processing for $archive_temp_image did not work. Image not associated to stock_id $stock_id.<br/><br/>"};
                    }
                }
                print STDERR "Saved $archive_temp_image\n";
                $image_id = $image->get_image_id();
                my $added_image_tag_id = $image->add_tag($image_tag);
            }

            $res{'analyzed_image_id'} = $image_id;
            $res{'image_link'} = $image->get_image_url("original");
            $res{'analyzed_image_overlay'} = $image_link;
        }

        $result->[$it]->{result} = \%res;
        $it++;
    }

    print STDERR "Before grouping result is: ".Dumper($result);
    
    $c->stash->{rest} = { success => 1, results => $result };
}

sub image_analysis_group : Path('/ajax/image_analysis/group') : ActionClass('REST') { }
sub image_analysis_group_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $result = decode_json $c->req->param('result');
    #my $image_id = decode_json $c->req->param('image_id');
    print STDERR "IMAGE ANALYSIS RESULTS: ".Dumper($result);
    my %grouped_results = ();
    my @table_data = ();

    my ($uniquename, $next_uniquename, $trait, $value, $results_ref, $next_results_ref);
    # sort result hash array by $stock_id
    my @sorted_result = sort {$$a{"stock_id"} <=> $$b{"stock_id"} } @{$result};
    # my $old_uniquename = $sorted_result[0]->{'stock_uniquename'};
    $grouped_results{$sorted_result[0]->{'stock_uniquename'}}{$sorted_result[0]->{'result'}->{'trait'}} = [];

    my $pipeline_metadata = $sorted_result[0]->{result}{pipeline_metadata} || {};
    print STDERR "test group pipeline metadata" . Dumper $pipeline_metadata;

    my $is_multi_trait = 0;
    for (my $i = 0; $i <= $#sorted_result; $i++) {
        $results_ref = $sorted_result[$i];
        print STDERR "\n\nResults ref is ".Dumper($results_ref)."\n\n";
        $uniquename = $results_ref->{'stock_uniquename'};
        $trait = $results_ref->{'result'}->{'trait'};
        $value = $results_ref->{'result'}->{'value'};

        if ($trait && $value) {  # we have a single analysis
            print STDERR "Working on $trait for $uniquename. Saving the details \n";

	    my $analyzed_link = dirname($results_ref->{'result'}->{'image_link'})."/small.jpg";
	    
            push @{$grouped_results{$uniquename}{$trait}}, {
                        stock_id => $results_ref->{'stock_id'},
                        collector => $results_ref->{'image_username'},
                        original_link => $results_ref->{'result'}->{'original_image'},
                        analyzed_link => $analyzed_link,
                        image_name => $results_ref->{'image_original_filename'}.$results_ref->{'image_file_ext'},
                        trait_id => $results_ref->{'result'}->{'trait_id'},
                        value => $value + 0
                };
        }
        elsif (exists($results_ref->{result}->{subanalyses}) && ref($results_ref->{result}->{subanalyses}) eq "HASH")  { # multiple results are returned, for several sub-images
	    print STDERR "MULTIPLE RESULTS DETECTED!\n";
        my $project_id;

	    foreach my $sample (keys %{$results_ref->{result}->{subanalyses}}) {

            my $sample_data = $results_ref->{result}->{subanalyses}{$sample};

           # my $is_multi_trait = ref($sample_data) eq 'HASH' && !exists($results_ref->{result}{trait});
            my @trait_keys = grep { $_ ne 'object_metadata' } keys %{$sample_data};
            if (scalar(@trait_keys) > 1) {
                $is_multi_trait = 1;
            }

        my $stock_id = $results_ref->{stock_id};
            print STDERR "STOCK ID IS: $stock_id";
        my $projects_rs = $schema->resultset('NaturalDiversity::NdExperimentStock')->search({ stock_id => $stock_id })->search_related('nd_experiment')->search_related('nd_experiment_projects')->search_related('project');
        if (my $project = $projects_rs->next) {
            $project_id = $project->project_id;
        }
            print STDERR "PROJECT ID IS: $project_id\n";

        my $stock = $schema->resultset('Stock::Stock')->find({ stock_id => $stock_id });
        my $accession_id;
        my $stock_type;
        my $stock_type_name;
        if ($stock) {
            $stock_type = $stock->type;
            $stock_type_name = $stock_type->name;

            if ($stock_type_name eq 'plant') {
                my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();

                my $plot_rel = $schema->resultset("Stock::StockRelationship")->find({ object_id => $stock_id, type_id => $plant_of_cvterm_id, });
                my $plot_stock = $plot_rel ? $plot_rel->subject() : undef;

                my $plot_rel = $stock->search_related('stock_relationship_subjects', { 'type.name' => 'plant_of', }, {join => 'type' })->single;
                my $plot = $plot_rel ? $plot_rel->object : undef;

                if ($plot) {
                    my $acc_rel = $plot_stock->search_related('stock_relationship_subjects', { 'type.name' => 'plot_of', }, { join => 'type', })->single;

                    my $accession = $acc_rel ? $acc_rel->object : undef;
                    $accession_id = $accession ? $accession->stock_id : undef;
                }
            } elsif ($stock_type_name eq 'plot') {
                my $accession = $stock->search_related('stock_relationship_subjects', { 'type.name' => 'plot_of', }, { join => 'type', })->single;
                if ($accession) {
                    $accession_id = $accession->object->stock_id;
                }
            } else {
                $accession_id = $stock->stock_id;
            }
        }

        my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

        my $rs = $schema->resultset("Stock::StockRelationship")->search(
            {
                'me.object_id' => $stock_id,
                'me.type_id' => $tissue_sample_of_cvterm_id,
            },
            {
                prefetch => 'subject',
            }
        );

        my @samples;
        while (my $rel = $rs->next) {
            push @samples, $rel->subject->uniquename;
        }

        my $object_source_label = $sample_data->{object_metadata}{source_label};
        my $sample_num = $object_source_label;
        $sample_num =~ s/\D//g;
        $sample_num = int($sample_num);
        print STDERR "SAMPLE NUM: $sample_num";

        my $trait_id;
        $trait_id = $results_ref->{'result'}->{'trait_id'};
        my @trait_samples = grep { $_ =~ /$trait_id/ } @samples;

        my $max_num = 0;
        if (@trait_samples) {
            for my $s (@trait_samples) {
                if ($s =~ /_sample(\d+)$/) {
                    $max_num = $1 if $1 > $max_num;
                }
            }
        }

        my $image_id = $results_ref->{'image_id'};
        my @existingSamples = grep { $_ =~ /$image_id/ } @samples;
        my $image_analyzed = 0;
        if (@existingSamples) {
            $image_analyzed = 1;
            $max_num = 0;
        }

            if ($is_multi_trait) {
                print STDERR "RESULT IS MULTI TRAIT";
                my @trait_rows;
                my $test_trait_id = 70739; 
                my $test_trait_name;

                foreach my $trait_name (keys %{$sample_data}) {
                    next if $trait_name eq 'object_metadata';
                    if (exists $results_ref->{result}->{subanalyses}{$sample}{$trait_name}{trait_id}) {
                        $trait_id = $results_ref->{result}->{subanalyses}{$sample}{$trait_name}{trait_id};
                    } else {
                        my ($trimmed_trait_name) = split (/\|/, $trait_name);
                        print STDERR "trimmed trait name: $trimmed_trait_name";
                        $test_trait_name = 'apical branching';
                        my $cvterm = $schema->resultset('Cv::Cvterm')->find({
                            name => $trimmed_trait_name
                        });
                        print STDERR "cvterm test: $cvterm";
                        if ($cvterm) {
                            $trait_id = $cvterm->cvterm_id;
                        }
                    }
                    my $object_source_label = $sample_data->{object_metadata}{source_label};
                    my $sample_num = $object_source_label;
                    $sample_num =~ s/\D//g;
                    $sample_num = int($sample_num);
                    print STDERR "sample num test 2: $sample_num";

                    print STDERR "final trait_id test: $trait_id";

                    my $val = $sample_data->{$trait_name}{trait_value};
                    push @{$grouped_results{$uniquename}{$trait_name}}, {
                        stock_id      => $results_ref->{stock_id},
                        collector     => $results_ref->{image_username},
                        trial_id => $project_id,
                        accession_id => $accession_id,
                        original_link => $results_ref->{result}->{original_image},
                        analyzed_link => $results_ref->{result}->{image_link},
                        object_name    => $sample,
                        trait_name    => $test_trait_name,
                        trait_id      => $test_trait_id,
                        stock_type => $stock_type_name,
                        sample_num => $sample_num,
                        image_analyzed => $image_analyzed,
                        value         => $val + 0,
                        object_metadata => $sample_data->{object_metadata},
                        status => 'create',
                    };
                    $test_trait_id++;
                };
            } else {
                # print STDERR "stock type: $stock_type_name accession id: $accession_id";

                my $related_accession;
                        
                push @{$grouped_results{$uniquename}{$trait}}, {
                    stock_id => $results_ref->{stock_id},
                    collector => $results_ref->{image_username},
                    trial_id => $project_id,
                    accession_id => $accession_id,
                    original_link => $results_ref->{result}->{original_image},
                    analyzed_link => $results_ref->{result}->{subanalyses}->{$sample}->{image_link},
                    #image_name => dirname($results_ref->{image_original_filename}."_".$sample."_".$results_ref->{image_file_ext}),
                    image_name => $sample,
                    trait_name => $results_ref->{result}->{trait},
                    trait_id => $results_ref->{'result'}->{'trait_id'},
                    stock_type => $stock_type_name,
                    sample_num => $max_num,
                    image_analyzed => $image_analyzed,
                    value => $results_ref->{result}->{subanalyses}->{$sample}->{trait_value}+0,
                    status => 'create',
                };
            }
	     
	    }
	    print STDERR "SUBANALYSIS IMAGE RESULTS: ".Dumper(\%grouped_results);
	} else { # if no result returned for an image, include it with error details.
            print STDERR "No usable analysis data in this results_ref \n";
            push @{$grouped_results{$uniquename}{$trait}}, {
		stock_id => $results_ref->{'stock_id'},
		collector => $results_ref->{'image_username'},
		original_link => $results_ref->{'result'}->{'original_image'},
		analyzed_link => 'Error: ' . $results_ref->{'result'}->{'error'},
		image_name => $results_ref->{'image_original_filename'}.$results_ref->{'image_file_ext'},
		trait_id => $results_ref->{'result'}->{'trait_id'},
		value => 'NA'
	    };
        }

        $next_results_ref = $sorted_result[$i+1];
        $next_uniquename = $next_results_ref->{'stock_uniquename'};

        if (!defined $next_results_ref || $next_uniquename ne $uniquename) {

            print STDERR "Calculating mean value for $uniquename\n";

            my $uniquename_data = $grouped_results{$uniquename};

            foreach my $trait (keys %{$uniquename_data}) {
                next unless defined $trait && $trait ne '';

                my $details = $uniquename_data->{$trait};
                my @values = map { $_->{'value'}} @{$uniquename_data->{$trait}};
                @values= grep { $_ ne 'NA' } @values; # remove NAs before calculating mean
                # print STDERR "\n\n\nVALUES ARE @values and length is ". scalar @values . "\n\n\n"
                my $mean_value = @values ? sprintf("%.2f", sum(@values)/@values) : undef;
                print STDERR "Mean value is $mean_value\n";
                print STDERR "Trait Id: " . $uniquename_data->{$trait}[0]->{'trait_id'};
                push @table_data, {
                    observationUnitDbId => $uniquename_data->{$trait}[0]->{'stock_id'},
                    observationUnitName => $uniquename,
                    collector => $uniquename_data->{$trait}[0]->{'collector'},
                    observationTimeStamp => localtime()->datetime,
                    observationVariableDbId => $uniquename_data->{$trait}[0]->{'trait_id'},
                    observationVariableName => $trait,
                    studyDbId => $uniquename_data->{$trait}[0]->{'trial_id'},
                    germplasmDbId => $uniquename_data->{$trait}[0]->{'accession_id'},
                    stock_type => $uniquename_data->{$trait}[0]->{'stock_type'},
                    sample_num => $uniquename_data->{$trait}[0]->{'sample_num'},
                    image_analyzed => $uniquename_data->{$trait}[0]->{'image_analyzed'},
                    value => $mean_value,
                    details => $details,
                    numberAnalyzed => scalar @values
                    # Add previously observed trait value
                };
            }
        }
        
    }
    
    my $image_overlay = $results_ref->{result}{analyzed_image_overlay};
    print STDERR "table data is ".Dumper(@table_data);
    $c->stash->{rest} = { success => 1, results => { table_data => \@table_data, analyzed_image_overlay => $image_overlay, multi_trait_analysis => $is_multi_trait, analysis_metadata => $pipeline_metadata}};
}

sub format_multi_trait_data {
    my $message_hashref = shift;
    my %subanalyses;
    my $image_link;

    foreach my $obj (@{$message_hashref->{objects}}) {
        my $source_label = $obj->{source_label};
        my $sample_name = $obj->{object_id};

        foreach my $trait_key (keys %{$obj->{traits}}) {
            my $trait_val = $obj->{traits}{$trait_key}{value};

            if (exists $message_hashref->{$trait_key}{image_link}) {
                $image_link = $message_hashref->{$trait_key}{image_link};
            }
            $subanalyses{$sample_name}{$trait_key} = {
                trait_value => $trait_val,
                image_link => $image_link
            };
        }
        $subanalyses{$sample_name}{object_metadata} = {
            object_id     => $obj->{object_id},
            source_label  => $source_label,
            bbox          => $obj->{bbox},
            qc            => $obj->{qc},
        };
    }

    return {
        subanalyses => \%subanalyses,
        image_link => $message_hashref->{derived_images}[0]{url},
        info => {
            object_count => $message_hashref->{qc}->{object_count},
            job_id => $message_hashref->{job_id}
        }
    };
}

sub get_image_file : Path('/get_image_file') Args(0) {
    my ($self, $c) = @_;
    my $url = $c->req->params->{url};

    my $ua = LWP::UserAgent->new;
    my $res = $ua->get($url);

    if ($res->is_success) {
        $c->res->content_type($res->header('Content-Type'));
        $c->res->body($res->decoded_content(charset => 'none'));
    } else {
        $c->res->status(500);
        $c->res->body("Failed to fetch image");
    }
}

sub get_activity_data : Path('/ajax/image_analysis/activity') Args(0) {
  my $self = shift;
  my $c = shift;

  my @activity;
  my $logfile = $c->config->{image_analysis_log};
  if (-e $logfile) {
        my @file_data = read_file($logfile, chomp => 1);
        foreach my $line (@file_data) {
            my @values = split("\t", $line);
            my @ts_parts = split(" ", $values[0]);
            push @activity, { date => $ts_parts[0]};
        }
    } else {
        $c->stash->{rest} = {error=>'No activity log set up.'};
        $c->detach();
    }

  my $json = JSON->new();
  $c->stash->{rest} = { activity => $json->encode(\@activity)};

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

sub _log_analysis_activity {
    my $c = shift;
    my $image_ids = shift;
    my $service = shift;
    my $trait = shift;
    my $now = DateTime->now();

    if ($c->config->{image_analysis_log}) {
	my $logfile = $c->config->{image_analysis_log};
	if (! -e $logfile) {
	    print STDERR "No log file available, returning.\n";
	    return;
	}
	print STDERR "Opening logfile $logfile...\n";
	my $F;
	eval { 
	    open ( $F, ">> :encoding(UTF-8)", $logfile) || die "Can't open logfile $logfile\n";

	};
	if ($@) {
	    print STDERR "Can't open logfile because of $@\n";
	}
	print $F join("\t", (
			  $now->year()."-".$now->month()."-".$now->day()." ".$now->hour().":".$now->minute(),
			  $c->user->get_object->get_username(),
			  $service,
			  $trait,
			  $image_ids
		      ));
	print $F "\n";
	close($F);
	print STDERR "Analysis submission logged in $logfile\n";
    }
    else {
	print STDERR "Note: set config variable image_analysis_log to obtain a log and graph of image analysis activity.\n";
    }
}

1;
