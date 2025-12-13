=head1 NAME

CXGN::Stock::AddDerivedAccession - a module for adding new accession derived from another stock type

=cut


package CXGN::Stock::AddDerivedAccession;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Stock;

has 'chado_schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'phenome_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_phenome_schema',
    required => 1,
);

has 'derived_accession_name' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'derived_from_stock_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'description' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);


sub existing_accession_name {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $derived_accession_name = $self->get_derived_accession_name();

    if ($schema->resultset('Stock::Stock')->find({ 'uniquename' => $derived_accession_name, 'is_obsolete' => { '!=' => 't' }})){
        return 1;
    } else {
        return;
    }
}


sub add_derived_accession {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $derived_accession_name = $self->get_derived_accession_name();
    my $description = $self->get_description();
    my $derived_from_stock_id = $self->get_derived_from_stock_id();
    my $owner_id = $self->get_owner_id();
    my $derived_accession_stock_id;
    my %return;

    if ($self->existing_accession_name()){
        return {error => "Error: Accession name: $derived_accession_name already exists in the database."};
    }

    my $coderef = sub {
        my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
        my $offspring_of_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id();
        my $derived_from_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'derived_from', 'stock_relationship')->cvterm_id();

        my $original_stock_info = $self->_get_original_stock_info($derived_from_stock_id);

        my $derived_from_stock_type_name = $original_stock_info->{'derived_from_stock_type_name'};
        my $derived_from_organism_id = $original_stock_info->{'derived_from_organism_id'};
        my $original_stock_id = $original_stock_info->{'original_stock_id'};
        my $original_stock_type = $original_stock_info->{'original_stock_type'};
        my $female_parent_stock_id = $original_stock_info->{'female_parent_stock_id'};
        my $male_parent_stock_id = $original_stock_info->{'male_parent_stock_id'};
        my $cross_type = $original_stock_info->{'cross_type'};

        my $derived_accession_stock = $schema->resultset("Stock::Stock")->create({
            organism_id => $derived_from_organism_id,
            name => $derived_accession_name,
            uniquename => $derived_accession_name,
            type_id => $accession_cvterm_id,
            description => $description,
        });

        $derived_accession_stock_id = $derived_accession_stock->stock_id();

        if ($derived_accession_stock_id) {
            $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $derived_from_cvterm_id,
                object_id => $derived_from_stock_id,
                subject_id => $derived_accession_stock_id,
                value => $derived_from_stock_type_name
			});

            if (($original_stock_type eq 'cross') || ($original_stock_type eq 'family_name')) {
                if ($female_parent_stock_id) {
                    $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                        type_id => $female_parent_cvterm_id,
                        object_id => $derived_accession_stock_id,
                        subject_id => $female_parent_stock_id,
                        value => $cross_type,
                    });
                }

                if ($male_parent_stock_id) {
                    $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                        type_id => $male_parent_cvterm_id,
                        object_id => $derived_accession_stock_id,
                        subject_id => $male_parent_stock_id,
                    });
                }

                if ($original_stock_type eq 'cross') {
                    $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                        type_id => $offspring_of_cvterm_id,
                        object_id => $original_stock_id,
                        subject_id => $derived_accession_stock_id,
                    });
                }
            } elsif ($original_stock_type eq 'accession') {
                $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $female_parent_cvterm_id,
                    object_id => $derived_accession_stock_id,
                    subject_id => $original_stock_id,
                    value => 'derived',
                });

                $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $male_parent_cvterm_id,
                    object_id => $derived_accession_stock_id,
                    subject_id => $original_stock_id,
                });
            }
        }

    };

    my $transaction_error;
    try {
        $schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $transaction_error =  $_;
    };

    if ($transaction_error){
        return { error=>$transaction_error };
    } else {
        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id => $derived_accession_stock_id,
            sp_person_id =>  $owner_id,
        });
    }

    return { success=>1 };

}

sub _get_original_stock_info {
    my $self = shift;
    my $derived_from_stock_id = shift;
    my $schema = $self->get_chado_schema();
    my %original_stock_info;

    my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $family_name_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $plant_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $family_female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'family_female_parent_of', 'stock_relationship')->cvterm_id();
    my $family_male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'family_male_parent_of', 'stock_relationship')->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $offspring_of_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id();

    my $derived_from_stock = $schema->resultset('Stock::Stock')->find({ 'stock_id' => $derived_from_stock_id});
    my $derived_from_stock_type_id = $derived_from_stock->type_id();
    my $derived_from_organism_id = $derived_from_stock->organism_id();

    my $original_stock_id;
    my $original_stock_type;
    my $cross_type;
    my $female_parent_stock_id;
    my $male_parent_stock_id;
    my $derived_from_stock_type_name;
    my $relationship_type_id;
    if ($derived_from_stock_type_id == $accession_cvterm_id) {
        $original_stock_id = $derived_from_stock_id;
        $original_stock_type = 'accession';
        $derived_from_stock_type_name = 'accession';
    } elsif ($derived_from_stock_type_id == $plant_cvterm_id) {
        $relationship_type_id = $plant_of_cvterm_id;
        $derived_from_stock_type_name = 'plant';
    } elsif ($derived_from_stock_type_id == $tissue_sample_cvterm_id) {
        $relationship_type_id = $tissue_sample_of_cvterm_id;
        $derived_from_stock_type_name = 'tissue_sample';
    }

    if ($derived_from_stock_type_id == $accession_cvterm_id) {
        my $q1 = "SELECT female_parent.subject_id, female_parent.value, male_parent.subject_id
            FROM stock
            LEFT JOIN stock_relationship AS female_parent ON (stock.stock_id = female_parent.object_id) AND female_parent.type_id = ?
            LEFT JOIN stock_relationship AS male_parent ON (stock.stock_id = male_parent.object_id) AND male_parent.type_id = ?
            WHERE stock.stock_id = ?";
        my $h1 = $schema->storage->dbh()->prepare($q1);
        $h1->execute($female_parent_cvterm_id, $male_parent_cvterm_id, $original_stock_id);
        ($female_parent_stock_id, $cross_type, $male_parent_stock_id) = $h1->fetchrow_array();

    } elsif (($derived_from_stock_type_id == $plant_cvterm_id) || ($derived_from_stock_type_id == $tissue_sample_cvterm_id)) {
        my $q2 = "SELECT stock.stock_id, cvterm.name, female_parent.subject_id, female_parent.value, male_parent.subject_id
            FROM stock
            JOIN stock_relationship ON (stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
            JOIN cvterm on (stock.type_id = cvterm.cvterm_id)
            LEFT JOIN stock_relationship AS female_parent ON (stock.stock_id = female_parent.object_id) AND female_parent.type_id IN (?,?)
            LEFT JOIN stock_relationship AS male_parent ON (stock.stock_id = male_parent.object_id) AND male_parent.type_id IN (?,?)
            WHERE stock_relationship.subject_id = ? and stock.type_id IN (?,?,?)";

        my $h2 = $schema->storage->dbh()->prepare($q2);
        $h2->execute($relationship_type_id, $female_parent_cvterm_id, $family_female_parent_cvterm_id, $male_parent_cvterm_id, $family_male_parent_cvterm_id, $derived_from_stock_id, $accession_cvterm_id, $cross_cvterm_id, $family_name_cvterm_id);
        ($original_stock_id, $original_stock_type, $female_parent_stock_id, $cross_type, $male_parent_stock_id) = $h2->fetchrow_array();
    }

    $original_stock_info{'derived_from_stock_type_name'} = $derived_from_stock_type_name;
    $original_stock_info{'derived_from_organism_id'} = $derived_from_organism_id;
    $original_stock_info{'original_stock_id'} = $original_stock_id;
    $original_stock_info{'original_stock_type'} = $original_stock_type;
    $original_stock_info{'female_parent_stock_id'} = $female_parent_stock_id;
    $original_stock_info{'male_parent_stock_id'} = $male_parent_stock_id;
    $original_stock_info{'cross_type'} = $cross_type;

    return \%original_stock_info;
}




#########
1;
#########
