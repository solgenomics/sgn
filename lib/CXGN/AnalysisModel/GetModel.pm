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

1;
