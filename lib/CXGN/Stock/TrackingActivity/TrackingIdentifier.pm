package CXGN::Stock::TrackingActivity::TrackingIdentifier;

=head1 NAME

CXGN::Stock::TrackingActivity::TrackingIdentifier - a module to handle tracking identifier.

=head1 USAGE


=head1 DESCRIPTION

=head1 AUTHORS

Titima Tantikanjana (tt15@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    predicate => 'has_schema',
    required => 1,
);

has 'tracking_identifier' => (
    isa => 'Str',
    is => 'rw',
);

has 'material' => (
    isa =>'Str',
    is => 'rw',
);

has 'project_id' => (
    isa => 'Int',
    is => 'rw',
);


sub store {
    my $self = shift;
    my $schema = $self->get_schema();
    my $tracking_identifier = $self->get_tracking_identifier();
    my $material_name = $self->get_material();
    my $error;

    my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
    my $material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id();
    my $tracking_id;

    my $check_id_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $tracking_identifier,
    });
    if ($check_id_rs->count() > 0){
        return { error => "$tracking_identifier already used in the database! " };
    }


    my $coderef = sub {
        my $tracking_id_rs = $schema->resultset("Stock::Stock")->create({
            name => $tracking_identifier,
            uniquename => $tracking_identifier,
            type_id => $tracking_identifier_cvterm_id,
        });
        $tracking_id = $tracking_id_rs->stock_id();

        my $material_rs = $schema->resultset("Stock::Stock")->find({ uniquename => $material_name});
        my $tracking_material = $schema->resultset("Stock::StockRelationship")->find_or_create({
                subject_id => $material_rs->stock_id,
                object_id => $tracking_id,
                type_id => $material_of_cvterm_id,
            });
    };


    my $error;
	try {
		$self->get_schema->txn_do($coderef);
	} catch {
		print STDERR "Error: $_\n";
		$error =  $_;
	};
	if ($error){
        return { error=>$error };
    } else {
        return { success=>1, tracking_id=>$tracking_id };
    }

}



#######
1;
#######
