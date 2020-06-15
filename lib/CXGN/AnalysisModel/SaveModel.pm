package CXGN::AnalysisModel::SaveModel;

=head1 NAME

CXGN::AnalysisModel::SaveModel - A Moose object to handle saving and retriving models and their training data files

=head1 USAGE

my $m = CXGN::AnalysisModel::SaveModel->new({
    bcs_schema=>$bcs_schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    archive_path=>$archive_path,
    model_name=>'MyModel',
    model_description=>'Model description',
    model_language=>'R',
    model_type_cvterm_id=>$model_type_cvterm_id,
    model_properties=>{tolparinv=>00.01, attribute=>'myattribute', prop=>$prop, attribute=>'myattribute',...},
    application_name=>$application_name, #e.g. 'SolGS', 'MixedModelTool', 'DroneImageryCNN'
    application_version=>1,
    dataset_id=>12,
    is_public=>1,
    archived_model_file_type=>$archived_model_file_type,
    model_file=>$model_file,
    archived_training_data_file_type=>$archived_training_data_file_type,
    archived_training_data_file=>$archived_training_data_file,
    archived_auxiliary_files=>[{auxiliary_model_file => $archive_temp_autoencoder_output_model_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_autoencoder_model'},
    {auxiliary_model_file => $model_input_aux_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_model_input_aux_data_file'},{...}],
    user_id=>$user_id,
    user_role=>$user_role
});
my $saved_model_id = $m->save_model();

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

has 'archive_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'model_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'model_description' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'model_language' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'model_type_cvterm_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'model_properties' => (
    isa => 'HashRef',
    is => 'rw',
    required => 1
);

has 'application_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'application_version' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'dataset_id' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'is_public' => (
    isa => 'Str',
    is => 'rw',
);

has 'archived_model_file_type' => (
    isa => 'Str|Undef',
    is => 'rw',
    required => 1
);

has 'model_file' => (
    isa => 'Str|Undef',
    is => 'rw',
    required => 1
);

has 'archived_training_data_file_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'archived_training_data_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'archived_auxiliary_files' => (
    isa => 'ArrayRef|Undef',
    is => 'rw'
);

has 'user_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'user_role' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

sub save_model {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $phenome_schema = $self->phenome_schema();
    my $metadata_schema = $self->metadata_schema();
    my $model_name = $self->model_name();
    my $model_description = $self->model_description();
    my $model_language = $self->model_language();
    my $model_type_cvterm_id = $self->model_type_cvterm_id();
    my $model_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();
    my $model_properties = $self->model_properties();
    my $model_file = $self->model_file();
    my $application_name = $self->application_name();
    my $application_version = $self->application_version();
    my $dataset_id = $self->dataset_id();
    my $is_public = $self->is_public();
    my $archive_path = $self->archive_path();
    my $archived_model_file_type = $self->archived_model_file_type();
    my $archived_training_data_file_type = $self->archived_training_data_file_type();
    my $archived_training_data_file = $self->archived_training_data_file();
    my $archived_auxiliary_files = $self->archived_auxiliary_files();
    my $user_id = $self->user_id();
    my $user_role = $self->user_role();

    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();
    $model_properties->{application_name} = $application_name;
    $model_properties->{application_version} = $application_version;
    $model_properties->{model_is_public} = $is_public;
    $model_properties->{dataset_id} = $dataset_id;
    $model_properties->{model_language} = $model_language;
    my $model_properties_save = [{value => encode_json $model_properties, type_id=>$model_properties_cvterm_id}];

	my $protocol_id;
    my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->find({
        name => $model_name,
        type_id => $model_type_cvterm_id
    });
    if ($protocol_row) {
        return { error => "The model name: $model_name has already been used! Please use a new name." };
    }
    else {
        $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->create({
            name => $model_name,
            type_id => $model_type_cvterm_id,
            nd_protocolprops => $model_properties_save
        });
        $protocol_id = $protocol_row->nd_protocol_id();
    }

    my $q = "UPDATE nd_protocol SET description = ? WHERE nd_protocol_id = ?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($model_description, $protocol_id);

    my $location_id = $schema->resultset("NaturalDiversity::NdGeolocation")->search({description=>'[Computation]'})->first->nd_geolocation_id();

	my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
        nd_geolocation_id => $location_id,
        type_id => $model_experiment_type_cvterm_id,
        nd_experiment_protocols => [{nd_protocol_id => $protocol_id}],
    });
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
    }

    #SAVING TRAINING DATA FILE

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

    my $experiment_files_autoencoder = $phenome_schema->resultset("NdExperimentMdFiles")->create({
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

            my $experiment_files_autoencoder = $phenome_schema->resultset("NdExperimentMdFiles")->create({
                nd_experiment_id => $nd_experiment_id,
                file_id => $file_row_aux->file_id()
            });
        }
    }

	return {success => 1, nd_protocol_id => $protocol_id, model_file_md_file_id => $model_file_md_file_id};
}

1;
