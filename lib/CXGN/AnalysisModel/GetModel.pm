package CXGN::AnalysisModel::GetModel;

=head1 NAME

CXGN::AnalysisModel::GetModel - A Moose object to handle retrieving models and their training data files

=head1 USAGE

my $m = CXGN::AnalysisModel::GetModel->new({
    bcs_schema=>$bcs_schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    nd_protocol_id=>$model_id
});
my $saved_model_object = $m->get_model();

CLASS METHOD:
my $analysis_models_by_user = CXGN::AnalysisModel::GetModel::get_models_by_user($bcs_schema, $sp_person_id);
my $analysis_by_model = CXGN::AnalysisModel::GetModel::get_analyses_by_model($bcs_schema, $model_id);

=head1 AUTHORS

Nicolas Morales <nm529@cornell.edu>

=cut

use Moose;
use Data::Dumper;
use DateTime;
use CXGN::UploadFile;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::People::Schema;
use File::Basename qw | basename dirname|;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1
);

has 'nd_protocol_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

sub get_model {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $phenome_schema = $self->phenome_schema();
    my $metadata_schema = $self->metadata_schema();
    my $nd_protocol_id = $self->nd_protocol_id();
    my $model_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, basename, dirname, md_files.file_id, md_files.filetype, nd_protocol.type_id, nd_experiment.nd_experiment_id, nd_experiment.type_id, property.type_id, property.value
        FROM nd_protocol
        JOIN nd_protocolprop AS property ON(nd_protocol.nd_protocol_id=property.nd_protocol_id)
        LEFT JOIN nd_experiment_protocol ON(nd_protocol.nd_protocol_id=nd_experiment_protocol.nd_protocol_id)
        LEFT JOIN nd_experiment ON(nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id AND nd_experiment.type_id=$model_experiment_type_cvterm_id)
        LEFT JOIN phenome.nd_experiment_md_files AS nd_experiment_md_files ON(nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id)
        LEFT JOIN metadata.md_files AS md_files ON(md_files.file_id=nd_experiment_md_files.file_id)
        WHERE nd_protocol.nd_protocol_id=?;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute($nd_protocol_id);
    my %result;
    while (my ($model_id, $model_name, $model_description, $basename, $filename, $file_id, $filetype, $model_type_id, $nd_experiment_id, $experiment_type_id, $property_type_id, $property_value) = $model_h->fetchrow_array()) {
        $result{model_id} = $model_id;
        $result{model_name} = $model_name;
        $result{model_description} = $model_description;
        $result{model_type_id} = $model_type_id;
        $result{model_type_name} = $schema->resultset("Cv::Cvterm")->find({cvterm_id => $model_type_id })->name();
        $result{model_experiment_type_id} = $experiment_type_id;
        $result{model_experiment_id} = $nd_experiment_id;
        $result{model_properties} = decode_json $property_value;
        if ($filename && $basename) {
            $result{model_files}->{$filetype} = $filename."/".$basename;
        }
        if ($basename) {
            $result{model_file_ids}->{$file_id} = $basename;
        }
    }
    return \%result;
}

sub store_analysis_model_files {
    my $self = shift;
    my $obj = shift;
    my $schema = $self->bcs_schema();
    my $phenome_schema = $self->phenome_schema();
    my $metadata_schema = $self->metadata_schema();
    my $nd_protocol_id = $self->nd_protocol_id();
    my $analysis_project_id = $obj->{project_id};
    my $archived_model_file_type = $obj->{archived_model_file_type};
    my $model_file = $obj->{model_file};
    my $archived_training_data_file_type = $obj->{archived_training_data_file_type};
    my $archived_training_data_file = $obj->{archived_training_data_file};
    my $archived_auxiliary_files = $obj->{archived_auxiliary_files};
    my $archive_path = $obj->{archive_path};
    my $user_id = $obj->{user_id};
    my $user_role = $obj->{user_role};

    my $model_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();
    my $location_id = $schema->resultset("NaturalDiversity::NdGeolocation")->search({description=>'[Computation]'})->first->nd_geolocation_id();
    my $nd_experiment_params = {
        nd_geolocation_id => $location_id,
        type_id => $model_experiment_type_cvterm_id,
        nd_experiment_protocols => [{nd_protocol_id => $nd_protocol_id}]
    };
    if ($analysis_project_id) {
        $nd_experiment_params->{nd_experiment_projects} = [{project_id => $analysis_project_id}];
    }
	my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create($nd_experiment_params);
    my $nd_experiment_id = $experiment->nd_experiment_id();

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ##SAVING MODEL FILE
    my $model_file_md_file_id;
    if ($model_file) {
        my $model_original_name = basename($model_file);

        my $uploader = CXGN::UploadFile->new({
            tempfile => $model_file,
            subdirectory => $archived_model_file_type,
            archive_path => $archive_path,
            archive_filename => $model_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            return { error => "Could not save file $model_original_name in archive." };
        }
        print STDERR "Archived Model File: $archived_filename_with_path\n";

        my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
        my $file_row = $metadata_schema->resultset("MdFiles")->create({
            basename => basename($archived_filename_with_path),
            dirname => dirname($archived_filename_with_path),
            filetype => $archived_model_file_type,
            md5checksum => $md5->hexdigest(),
            metadata_id => $md_row->metadata_id()
        });

        my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $nd_experiment_id,
            file_id => $file_row->file_id()
        });

        $model_file_md_file_id = $file_row->file_id();
        # unlink($model_file);
    }

    #SAVING TRAINING DATA FILE (Main phenotype file)

    my $model_aux_original_name = basename($archived_training_data_file);

    my $uploader_autoencoder = CXGN::UploadFile->new({
        tempfile => $archived_training_data_file,
        subdirectory => $archived_training_data_file_type,
        archive_path => $archive_path,
        archive_filename => $model_aux_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_aux_filename_with_path = $uploader_autoencoder->archive();
    my $md5_aux = $uploader_autoencoder->get_md5($archived_aux_filename_with_path);
    if (!$archived_aux_filename_with_path) {
        return { error => "Could not save file $model_aux_original_name in archive." };
    }
    print STDERR "Archived Auxiliary Model File: $archived_aux_filename_with_path\n";

    my $md_row_aux = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    my $file_row_aux = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($archived_aux_filename_with_path),
        dirname => dirname($archived_aux_filename_with_path),
        filetype => $archived_training_data_file_type,
        md5checksum => $md5_aux->hexdigest(),
        metadata_id => $md_row_aux->metadata_id()
    });

    my $experiment_files_pheno = $phenome_schema->resultset("NdExperimentMdFiles")->create({
        nd_experiment_id => $nd_experiment_id,
        file_id => $file_row_aux->file_id()
    });

    # SAVING AUXILIARY FILES, LIKE AUXILIARY TRAINING DATA AND PREPROCESSING MODELS

    if ($archived_auxiliary_files && scalar(@$archived_auxiliary_files) > 0) {
        foreach my $a (@$archived_auxiliary_files) {
            my $auxiliary_model_file = $a->{auxiliary_model_file};
            my $auxiliary_model_file_archive_type = $a->{auxiliary_model_file_archive_type};

            my $model_aux_original_name = basename($auxiliary_model_file);

            my $uploader_autoencoder = CXGN::UploadFile->new({
                tempfile => $auxiliary_model_file,
                subdirectory => $auxiliary_model_file_archive_type,
                archive_path => $archive_path,
                archive_filename => $model_aux_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_aux_filename_with_path = $uploader_autoencoder->archive();
            my $md5_aux = $uploader_autoencoder->get_md5($archived_aux_filename_with_path);
            if (!$archived_aux_filename_with_path) {
                return { error => "Could not save file $model_aux_original_name in archive." };
            }
            print STDERR "Archived Auxiliary Model File: $archived_aux_filename_with_path\n";

            my $md_row_aux = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
            my $file_row_aux = $metadata_schema->resultset("MdFiles")->create({
                basename => basename($archived_aux_filename_with_path),
                dirname => dirname($archived_aux_filename_with_path),
                filetype => $auxiliary_model_file_archive_type,
                md5checksum => $md5_aux->hexdigest(),
                metadata_id => $md_row_aux->metadata_id()
            });

            my $experiment_files_aux = $phenome_schema->resultset("NdExperimentMdFiles")->create({
                nd_experiment_id => $nd_experiment_id,
                file_id => $file_row_aux->file_id()
            });

            # unlink($auxiliary_model_file);
        }
    }
}

sub get_models_by_user {
    my $schema = shift;
    my $sp_person_id = shift;
    my $analysis_model_type = shift;

    my $analysis_model_experiment_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $where = '';
    if ($analysis_model_type) {
        my $model_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $analysis_model_type, 'protocol_type')->cvterm_id();
        $where = ' AND nd_protocol.type_id='.$model_type_cvterm_id;
    }

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, basename, dirname, md.file_id, md.filetype, nd_protocol.type_id, nd_experiment.type_id, property.type_id, property.value
        FROM metadata.md_files AS md
        JOIN metadata.md_metadata AS meta ON (md.metadata_id=meta.metadata_id)
        JOIN sgn_people.sp_person AS sp ON (meta.create_person_id = sp.sp_person_id)
        JOIN phenome.nd_experiment_md_files using(file_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_protocol using(nd_experiment_id)
        JOIN nd_protocol using(nd_protocol_id)
        JOIN nd_protocolprop AS property ON(nd_protocol.nd_protocol_id=property.nd_protocol_id)
        WHERE sp.sp_person_id=? AND nd_experiment.type_id=$analysis_model_experiment_id
        $where;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute($sp_person_id);
    my %result;
    while (my ($model_id, $model_name, $model_description, $basename, $filename, $file_id, $filetype, $model_type_id, $experiment_type_id, $property_type_id, $property_value) = $model_h->fetchrow_array()) {
        $result{$model_id}->{model_id} = $model_id;
        $result{$model_id}->{model_name} = $model_name;
        $result{$model_id}->{model_description} = $model_description;
        $result{$model_id}->{model_type_id} = $model_type_id;
        $result{$model_id}->{model_type_name} = $schema->resultset("Cv::Cvterm")->find({cvterm_id => $model_type_id })->name();
        $result{$model_id}->{model_experiment_type_id} = $experiment_type_id;
        $result{$model_id}->{model_properties} = decode_json $property_value;
        $result{$model_id}->{model_files}->{$filetype} = $filename."/".$basename;
        $result{$model_id}->{model_file_ids}->{$file_id} = $basename;
    }
    return \%result;
}

sub get_analyses_by_model {
    my $schema = shift;
    my $model_id = shift;

    my $analysis_experiment_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_experiment', 'experiment_type')->cvterm_id();

    my $model_q = "SELECT project.project_id, project.name, project.description
        FROM project
        JOIN nd_experiment_project using(project_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_protocol using(nd_experiment_id)
        JOIN nd_protocol using(nd_protocol_id)
        WHERE nd_protocol.nd_protocol_id=? AND nd_experiment.type_id=$analysis_experiment_id;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute($model_id);
    my @results;
    while (my ($analysis_id, $analysis_name, $description) = $model_h->fetchrow_array()) {
        push @results, {
            analysis_id => $analysis_id,
            analysis_name => $analysis_name,
            description => $description
        };
    }
    return \@results;
}

1;
