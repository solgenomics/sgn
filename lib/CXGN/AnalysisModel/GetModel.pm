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

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, basename, dirname, metadata.md_files.file_id, metadata.md_files.filetype, nd_protocol.type_id, nd_experiment.type_id, property.type_id, property.value
        FROM metadata.md_files
        JOIN phenome.nd_experiment_md_files using(file_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_protocol using(nd_experiment_id)
        JOIN nd_protocol using(nd_protocol_id)
        JOIN nd_protocolprop AS property ON(nd_protocol.nd_protocol_id=property.nd_protocol_id)
        WHERE nd_protocol.nd_protocol_id=?;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute($nd_protocol_id);
    my %result;
    while (my ($model_id, $model_name, $model_description, $basename, $filename, $file_id, $filetype, $model_type_id, $experiment_type_id, $property_type_id, $property_value) = $model_h->fetchrow_array()) {
        $result{model_id} = $model_id;
        $result{model_name} = $model_name;
        $result{model_description} = $model_description;
        $result{model_type_id} = $model_type_id;
        $result{model_type_name} = $schema->resultset("Cv::Cvterm")->find({cvterm_id => $model_type_id })->name();
        $result{model_experiment_type_id} = $experiment_type_id;
        $result{model_properties} = decode_json $property_value;
        $result{model_files}->{$filetype} = $filename."/".$basename;
        $result{model_file_ids}->{$file_id} = $basename;
    }
    return \%result;
}

sub get_models_by_user {
    my $schema = shift;
    my $sp_person_id = shift;

    my $analysis_model_experiment_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, basename, dirname, md.file_id, md.filetype, nd_protocol.type_id, nd_experiment.type_id, property.type_id, property.value
        FROM metadata.md_files AS md
        JOIN metadata.md_metadata AS meta ON (md.metadata_id=meta.metadata_id)
        JOIN sgn_people.sp_person AS sp ON (meta.create_person_id = sp.sp_person_id)
        JOIN phenome.nd_experiment_md_files using(file_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_protocol using(nd_experiment_id)
        JOIN nd_protocol using(nd_protocol_id)
        JOIN nd_protocolprop AS property ON(nd_protocol.nd_protocol_id=property.nd_protocol_id)
        WHERE sp.sp_person_id=? AND nd_experiment.type_id=$analysis_model_experiment_id;";
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
