package CXGN::Transformation::StoreTransgeneExpressionData;

=head1 NAME

CXGN::Transformation::StoreTransgeneExpressionData - a module to store transgene expression data

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
use Data::Dumper;
use JSON;

has 'chado_schema' => (
	    is       => 'rw',
		isa      => 'DBIx::Class::Schema',
		predicate => 'has_chado_schema',
		required => 1,
);

has 'transformant_stock_id' => (
    isa =>'Int',
    is => 'rw',
    predicate => 'has_stock_id',
    required => 1
);

has 'vector_construct_stock_id' => (
    isa =>'Int',
    is => 'rw',
    predicate => 'has_stock_id',
    required => 1
);

has 'tissue_type' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_tissue_type',
    required => 1
);

has 'relative_expression_data' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    predicate => 'has_relative_expression_data',
    required => 1
);

has 'timestamp' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_timestamp',
	required => 1
);



sub store_relative_expression_data {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transaction_error;
	my $transformant_stock_id = $self->get_transformant_stock_id();
	my $vector_construct_stock_id = $self->get_vector_construct_stock_id();
	my $relative_expression_data = $self->relative_expression_data();
	my $tissue_type = $self->tissue_type();
	my $timestamp = $self->timestamp();

    my $coderef = sub {
        $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
        $vector_construct_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type');
        $expression_data_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'expression_data', 'stock_property');
        $analyzed_tissue_types_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'analyzed_tissue_types', 'stock_property');

	    my $transformant_stock = $schema->resultset("Stock::Stock")->find ({
		    stock_id => $transformant_stock_id,
		    type_id => $accession_cvterm->cvterm_id(),
	    });
		if (!$transformant_stock) {
            print STDERR "Transgenic line could not be found\n";
            return;
        }

		my $vector_construct_stock = $schema->resultset("Stock::Stock")->find ({
		    stock_id => $vector_construct_stock_id,
		    type_id => $vector_construct_cvterm->cvterm_id(),
	    });
		if (!$vector_construct_stock) {
            print STDERR "Vector construct could not be found\n";
            return;
        }

        my $expresssion_data_string;
        my $expression_data_hash = {};
		my $updated_expression_data_string;
        my $previous_expression_data_stockprop_rs = $transformant_stock->stockprops({type_id=>$expression_data_cvterm->cvterm_id});
        if ($previous_expression_data_stockprop_rs->count == 1){
            $expression_data_string = $previous_expression_data_stockprop_rs->first->value();
            $expression_data_hash = decode_json $expression_data_string;
			$expression_data_hash->{$tissue_type}->{$timestamp}->{'relative_expression_data'} = $relative_expression_data;
			$updated_expression_data_string = encode_json $expression_data_hash;
            $previous_stockprop_rs->first->update({value=>$updated_expression_data_string});
        } elsif ($previous_stockprop_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
			$expression_data_hash->{$tissue_type}->{$date}->{'relative_expression_data'} = $relative_expression_data;
			$expression_data_string = encode_json $expression_data_hash;
            $cross_stock->create_stockprops({$cross_info_cvterm->name() => $cross_json_string});
        }
    };

    #try to add all cross info in a transaction
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing expression data: $transaction_error\n";
        return;
    }

    return 1;
}


#######
1;
#######
