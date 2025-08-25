package CXGN::Transformation::LinkTransformationInfo;

=head1 NAME

CXGN::Transformation::LinkTransformationInfo - a module to link existing accession names in the database to transformation identifier.

=head1 USAGE


=head1 DESCRIPTION


=head1 AUTHORS

Titima Tantikanjana (tt15@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
	predicate => 'has_schema',
	required => 1,
);

has 'transformation_stock_id' => (
    isa =>'Int',
    is => 'rw',
    predicate => 'has_transformation_stock_id',
    required => 1,
);

has 'transformant_names' => (
    isa =>'ArrayRef[Str]',
    is => 'rw',
    predicate => 'has_transformant_names',
    required => 1,
);

has 'additional_transformant_info' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    predicate => 'has_additional_transformant_info',
);


sub link_info {

    my $self = shift;
    my $schema = $self->get_schema();
    my $transformation_stock_id = $self->get_transformation_stock_id();
    my @transformant_names = @{$self->get_transformant_names()};
    my $additional_transformant_info = $self->get_additional_transformant_info();
    my $transaction_error;
    my @accession_stock_ids;

    my $coderef = sub {

        my $accession_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
        my $transformant_of_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transformant_of', 'stock_relationship');
        my $transgenic_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transgenic', 'stock_property');
        my $number_of_insertions_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'number_of_insertions', 'stock_property');

        foreach my $name (@transformant_names) {
            my $accession_stock = $schema->resultset("Stock::Stock")->find ({
                uniquename => $name,
                type_id => $accession_cvterm->cvterm_id(),
            });

            $accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $transformant_of_cvterm->cvterm_id(),
                object_id => $transformation_stock_id,
                subject_id => $accession_stock->stock_id(),
            });

            my $previous_transgenic_stockprop_rs = $accession_stock->stockprops({type_id=>$transgenic_cvterm->cvterm_id});
            if (!$previous_transgenic_stockprop_rs) {
                $accession_stock->create_stockprops({$transgenic_cvterm->name() => 1});
            }

            my $previous_number_of_insertions_stockprop_rs = $accession_stock->stockprops({type_id=>$number_of_insertions_cvterm->cvterm_id});
            if (!$previous_transgenic_stockprop_rs) {
                my $number_of_insertions = $additional_transformant_info->{$name}->{'number_of_insertions'};
                if ($number_of_insertions) {
                    $accession_stock->create_stockprops({$number_of_insertions_cvterm->name() => $number_of_insertions});
                }
            }

        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        return { error => $transaction_error };
    } else {
        return { success => 1};
    }


}



#######
1;
#######
