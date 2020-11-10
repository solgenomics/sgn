package CXGN::Pedigree::AddFamilyNames;

=head1 NAME

CXGN::Pedigree::AddFamilyNames - a module to add family names.

=head1 USAGE

 my $family_name_add = CXGN::Pedigree::AddFamilyNames->new({ chado_schema => $chado_schema, cross_name => $cross_name, family_name => $family_name} );
 $family_name_add->add_family_name();

=head1 DESCRIPTION

Adds family name and creates corresponding new stock of type family_name if the family_name does not exist in the database. The cross must already exist in the database.

=head1 AUTHORS

Titima Tantikanjana <tt15@cornell.edu>

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;


has 'chado_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_chado_schema',
		 required => 1,
		);
has 'phenome_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_phenome_schema',
		 required => 1,
		);
has 'dbh' => (is  => 'rw',predicate => 'has_dbh', required => 1,);
has 'cross_name' => (isa =>'Str', is => 'rw', predicate => 'has_cross_name', required => 1,);
has 'family_name' => (isa =>'Str', is => 'rw', predicate => 'has_family_name', required => 1,);
has 'owner_name' => (isa => 'Str', is => 'rw', predicate => 'has_owner_name', required => 1,);

sub add_family_name {
    my $self = shift;
    my $chado_schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $family_name = $self->get_family_name();
	my $cross_name = $self->get_cross_name();
    my $cross_stock;
    my $organism_id;
    my $family_name_id;
    my $new_family_name_id;
    my $transaction_error;
    my %return;

    #lookup user by name
    my $owner_name = $self->get_owner_name();;
    my $dbh = $self->get_dbh();
    my $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $owner_name); #add person id as an option.


    #add family name and associate with cross
    my $coderef = sub {

        my $family_name_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'family_name', 'stock_type')->cvterm_id();
        my $cross_member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross_member_of', 'stock_relationship')->cvterm_id();
		my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema,  'male_parent', 'stock_relationship')->cvterm_id();
		my $family_female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema,  'family_female_parent_of', 'stock_relationship')->cvterm_id();
		my $family_male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema,  'family_male_parent_of', 'stock_relationship')->cvterm_id();

       #Get stock of type cross matching cross name
        $cross_stock = $self->_get_cross($cross_name);
        if (!$cross_stock) {
			push @{$return{error}},"Cross: $cross_name are not in database";
			return \%return;
        }

		my $cross_female_parent = $chado_schema->resultset("Stock::StockRelationship")
            ->find ({
                object_id => $cross_stock->stock_id(),
                type_id => $female_parent_cvterm_id,
            });

        my $cross_male_parent = $chado_schema->resultset("Stock::StockRelationship")
            ->find ({
                object_id => $cross_stock->stock_id(),
                type_id => $male_parent_cvterm_id,
            });

        my $cross_female_id = $cross_female_parent->subject_id();
        my $cross_male_id;
        if ($cross_male_parent){
		    $cross_male_id = $cross_male_parent->subject_id();
        }

        #Get organism id from cross
        $organism_id = $cross_stock->organism_id();

        #check if family_name already exists
        my $family_name_rs = $chado_schema->resultset("Stock::Stock")->find({
            uniquename => $family_name,
            type_id => $family_name_cvterm_id,
        });

        if ($family_name_rs){
			my $family_female_parent = $chado_schema->resultset("Stock::StockRelationship")->find ({
                object_id => $family_name_rs->stock_id(),
                type_id => $family_female_parent_cvterm_id,
            });

            my $family_male_parent = $chado_schema->resultset("Stock::StockRelationship")->find ({
                object_id => $family_name_rs->stock_id(),
                type_id => $family_male_parent_cvterm_id,
            });

            my $family_male_id;
			my $family_female_id = $family_female_parent->subject_id();
            if ($family_male_parent){
			    $family_male_id = $family_male_parent->subject_id();
            }

			my $previous_linkage = $chado_schema->resultset("Stock::StockRelationship")->find ({
                object_id => $family_name_rs->stock_id(),
				subject_id => $cross_stock->stock_id(),
				type_id => $cross_member_of_cvterm_id,
            });

#           print STDERR "CROSS FEMALE ID =".Dumper($cross_female_id)."\n";
#			print STDERR "CROSS MALE ID =".Dumper($cross_male_id)."\n";
#			print STDERR "FAMILY FEMALE ID =".Dumper($family_female_id)."\n";
#			print STDERR "FAMILY MALE ID =".Dumper($family_male_id)."\n";

            if (($cross_female_id != $family_female_id) || ($cross_male_id != $family_male_id)) {
				push @{$return{error}},"Parents of cross: $cross_name are not the same as parents of family: $family_name";
				return \%return;
            } elsif (!$previous_linkage) {
				$family_name_rs->find_or_create_related('stock_relationship_objects', {
	                type_id => $cross_member_of_cvterm_id,
	                object_id => $family_name_rs->stock_id(),
	                subject_id => $cross_stock->stock_id(),
	            });
            }
        } else {
            my $new_family_name_rs;
            $new_family_name_rs = $chado_schema->resultset("Stock::Stock")->create({
                organism_id => $organism_id,
                name       => $family_name,
                uniquename => $family_name,
                type_id    => $family_name_cvterm_id,
            });

            #create relationship between new family_name and cross
            $new_family_name_rs->find_or_create_related('stock_relationship_objects', {
                type_id => $cross_member_of_cvterm_id,
                object_id => $new_family_name_rs->stock_id(),
                subject_id => $cross_stock->stock_id(),
            });

			#create relationship between new family_name and female parent name
            $new_family_name_rs->find_or_create_related('stock_relationship_objects', {
				type_id => $family_female_parent_cvterm_id,
                object_id => $new_family_name_rs->stock_id(),
                subject_id => $cross_female_parent->subject_id(),
            });

			#create relationship between new family_name and male parent name
            if ($cross_male_parent){
                $new_family_name_rs->find_or_create_related('stock_relationship_objects', {
				    type_id => $family_male_parent_cvterm_id,
                    object_id => $new_family_name_rs->stock_id(),
                    subject_id => $cross_male_parent->subject_id(),
                });
            }

			$new_family_name_id = $new_family_name_rs->stock_id();
        }
    };

    #try to add all family names in a transaction
    try {
        $chado_schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
		$return{error} = "Error creating family $family_name: $transaction_error";
		return \%return;
    }

	#add the owner for this family name
    if (defined $new_family_name_id){
	    $phenome_schema->resultset("StockOwner")->find_or_create({
		    stock_id     => $new_family_name_id,
		    sp_person_id =>  $owner_sp_person_id,
	    });
    }

	return \%return;

}


sub _get_cross {
    my $self = shift;
    my $cross_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;
    my $cross_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross', 'stock_type');

    $stock_lookup->set_stock_name($cross_name);
    $stock = $stock_lookup->get_cross_exact();

    if (!$stock) {
        print STDERR "Cross unique id does not exist\n";
        return;
    }

    return $stock;
}

#######
1;
#######
