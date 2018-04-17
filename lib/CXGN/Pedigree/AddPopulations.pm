package CXGN::Pedigree::AddPopulations;

=head1 NAME

CXGN::Pedigree::AddPopulations - a module to add populations.

=head1 USAGE

 my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, name => $name, members =>  \@members} );
 $population_add->add_population();

=head1 DESCRIPTION

=head1 AUTHORS

Bryan Ellerbrock (bje24@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
		);
has 'name' => (isa => 'Str', is => 'rw', predicate => 'has_name', required => 1,);
has 'members' => (isa =>'ArrayRef[Str]', is => 'rw', predicate => 'has_members', required => 1,);

sub add_population {
	my $self = shift;
	my $schema = $self->get_schema();
	my $population_name = $self->get_name();
	my @members = @{$self->get_members()};
	my $error;

    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $population_id;

    my $previous_pop_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $population_name,
        type_id => $population_cvterm_id,
    });
    if ($previous_pop_rs->count() > 0){
        return { error => "$population_name already used in the database! Use another name or use the existing population entry." };
    }

	# create population stock entry
	try {
	my $pop_rs = $schema->resultset("Stock::Stock")->create(
{
		name => $population_name,
		uniquename => $population_name,
		type_id => $population_cvterm_id,
});
    $population_id = $pop_rs->stock_id();

	 # generate population connections to the members
	foreach my $m (@members) {
my $m_row = $schema->resultset("Stock::Stock")->find({ uniquename => $m });
my $connection = $schema->resultset("Stock::StockRelationship")->create(
		{
	subject_id => $m_row->stock_id,
	object_id => $pop_rs->stock_id,
	type_id => $member_of_cvterm_id,
		});
	}
}
catch {
	$error =  $_;
};
if ($error) {
	print STDERR "Error creating population $population_name: $error\n";
	return { error => "Error creating population $population_name: $error" };
} else {
	print STDERR "population $population_name added successfully\n";
	return { success => "Success! Population $population_name created", population_id=>$population_id };
}
}

sub add_accessions {
    my $self = shift;
    my $schema = $self->get_schema();
    my $population_name = $self->get_name();
    my @members = @{$self->get_members()};
    my $error;

    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();

    try {
        my $population = $schema->resultset("Stock::Stock")->find({
            uniquename => $population_name,
            type_id => $population_cvterm_id,
        });

        foreach my $m (@members) {
            my $m_row = $schema->resultset("Stock::Stock")->find({ uniquename => $m });
            my $connection = $schema->resultset("Stock::StockRelationship")->find_or_create({
                subject_id => $m_row->stock_id,
                object_id => $population->stock_id,
                type_id => $member_of_cvterm_id,
            });
        }
    }
    catch {
        $error =  $_;
    };
    if ($error) {
        print STDERR "Error adding accessions to population $population_name: $error\n";
        return { error => "Error adding accessions to population $population_name: $error" };
    } else {
        print STDERR "Accession added to population $population_name successfully\n";
        return { success => "Accession added to population $population_name successfully!" };
    }
}


#######
1;
#######
