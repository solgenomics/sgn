package AddTrialFieldNumberAndSecondHarvestDate;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => (
    default => 'Add project properties for field number and second harvest date.',
);

has '+prereq' => (default => sub { [] });

sub patch {
    my $self = shift;
    my $schema = Bio::Chado::Schema->connect(sub { $self->dbh->clone });

    for my $name ('field_number', 'project_second_harvest_date') {
        next if SGN::Model::Cvterm->get_cvterm_row($schema, $name, 'project_property');
        $schema->resultset('Cv::Cvterm')->create_with({
            name => $name,
            cv => 'project_property',
        });
    }
}

1;
