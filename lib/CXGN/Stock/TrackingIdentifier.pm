
=head1 NAME

CXGN::Stock::TrackingIdentifier - a class to represent tracking identifiers in the database

=head1 DESCRIPTION

CXGN::Stock::TrackingIdentifier inherits from CXGN::Stock.


=head1 AUTHOR


=head1 ACCESSORS & METHODS

=cut

package CXGN::Stock::TrackingIdentifier;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use Try::Tiny;

=head2 Accessor tracking_identifier_id()


=cut

has 'tracking_identifier_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);


=head2 Accessor data_type()

tissue_culture or trial_treatments

=cut

has 'data_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor material_type()

accessions, seedlots or trials

=cut

has 'material_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor get_material()

Returns an ArrayRef of [$stock_id, $uniquename] or [$project_id, $project_name]

=cut

has 'get_material' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_material',
);

after 'stock_id' => sub {
    my $self = shift;
    my $id = shift;
    return $self->tracking_identifier_id($id);
};

sub BUILDARGS {
    my $orig = shift;
    my %args = @_;
    $args{stock_id} = $args{tracking_identifier_id};
    return \%args;
}


sub BUILD {
    my $self = shift;
    if ($self->stock_id()) {
        $self->tracking_identifier_id($self->stock_id);
        $self->data_type($self->_retrieve_stockprop('data_type'));
        $self->material_type($self->_retrieve_stockprop('material_type'));
    }
}


sub _retrieve_material {
    my $self = shift;
    my $schema = $self->schema;
    my $tracking_identifier_id = $self->stock_id();
    my $material_type = $self->material_type();
    print STDERR "TRACKING ID =".Dumper($tracking_identifier_id)."\n";
    print STDERR "MATERIAL TYPE =".Dumper($material_type)."\n";

    my $project_tracking_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'project_tracking_identifier', 'experiment_type')->cvterm_id;
    my $material_of_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id;

    my $material;
    my @data = ();

    if ($material_type eq 'trials') {
        my $q = "SELECT project.project_id, project.name
            FROM nd_experiment_stock
            JOIN nd_experiment_project ON (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id) and nd_experiment_stock.type_id = ?
            JOIN project ON (project.project_id = nd_experiment_project.project_id)
            WHERE nd_experiment_stock.stock_id = ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($project_tracking_type_id, $tracking_identifier_id);

        while(my($project_id, $project_name) = $h->fetchrow_array()){
            push @data, [$project_id, $project_name];
        }
    } else {
        my $q = "SELECT stock.stock_id, stock.uniquename
            FROM stock_relationship
            JOIN stock ON (stock_relationship.subject_id = stock.stock_id) AND stock_relationship.type_id = ?
            WHERE stock_relationship.object_id = ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($material_of_type_id, $tracking_identifier_id);

        while(my($stock_id, $stock_name) = $h->fetchrow_array()){
            push @data, [$stock_id, $stock_name];
        }
    }

    print STDERR "MATERIAL DATA =".Dumper(\@data)."\n";
    if (scalar @data != 1){
        print "Error: There is more than one associated material!\n";
    } else {
        $self->get_material([$data[0][0], $data[0][1]]);
    }

}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
