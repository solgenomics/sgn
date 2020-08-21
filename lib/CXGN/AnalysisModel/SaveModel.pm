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
    my $application_name = $self->application_name();
    my $application_version = $self->application_version();
    my $dataset_id = $self->dataset_id();
    my $is_public = $self->is_public();
    my $archive_path = $self->archive_path();
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

	return {success => 1, nd_protocol_id => $protocol_id};
}

1;
