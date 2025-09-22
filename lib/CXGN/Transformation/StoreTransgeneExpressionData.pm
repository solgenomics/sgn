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

has 'transformant_name' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_transformant_name',
    required => 1
);

has 'vector_construct_name' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_vector_construct_name',
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

has 'endogenous_control' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_endogenous_control',
    required => 1
);

has 'assay_date' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'assay_date',
    required => 1
);

has 'notes' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_notes',
);

has 'operator_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_operator_id',
	required => 1
);

has 'relative_expression_data_derived_from' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_relative_expression_data_derived_from',
);

sub store_relative_expression_data {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transaction_error;
	my $transformant_name = $self->get_transformant_name();
	my $vector_construct_name = $self->get_vector_construct_name();
	my $relative_expression_data = $self->get_relative_expression_data();
	my $tissue_type = $self->get_tissue_type();
	my $assay_date = $self->get_assay_date();
	my $endogenous_control = $self->get_endogenous_control();
	my $notes = $self->get_notes();
	my $operator_id = $self->get_operator_id();
	my $relative_expression_data_derived_from = $self->get_relative_expression_data_derived_from();

    my $coderef = sub {
        my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
        my $vector_construct_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type');
        my $expression_data_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'transgene_expression_data', 'stock_property');
        my $assay_metadata_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'assay_metadata', 'stock_property');
        my $transformant_stock_id;
		my $vector_construct_stock_id;
	    my $transformant_stock = $schema->resultset("Stock::Stock")->find ({
		    uniquename => $transformant_name,
		    type_id => $accession_cvterm->cvterm_id(),
	    });
		if (!$transformant_stock) {
            print STDERR "Transgenic line could not be found\n";
            return;
        } else {
            $transformant_stock_id = $transformant_stock->stock_id();
		}

		my $vector_construct_stock = $schema->resultset("Stock::Stock")->find ({
		    uniquename => $vector_construct_name,
		    type_id => $vector_construct_cvterm->cvterm_id(),
	    });
		if (!$vector_construct_stock) {
            print STDERR "Vector construct could not be found\n";
            return;
        } else {
			$vector_construct_stock_id = $vector_construct_stock->stock_id();
		}

        my $expression_data_json;
        my $expression_data_hash = {};
        my $updated_expression_data_json;

        my $previous_expression_data_stockprop_rs = $transformant_stock->stockprops({type_id=>$expression_data_cvterm->cvterm_id});
        if ($previous_expression_data_stockprop_rs->count == 1){
            $expression_data_json = $previous_expression_data_stockprop_rs->first->value();
            $expression_data_hash = decode_json $expression_data_json;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'relative_expression_values'} = $relative_expression_data;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'endogenous_control'} = $endogenous_control;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'notes'} = $notes;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'uploaded_by'} = $operator_id;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'relative_expression_data_derived_from'} = $relative_expression_data_derived_from;

            $updated_expression_data_json = encode_json $expression_data_hash;
            $previous_expression_data_stockprop_rs->first->update({value=>$updated_expression_data_json});
        } elsif ($previous_expression_data_stockprop_rs->count > 1) {
            print STDERR "More than one expression data stockprop found!\n";
            return;
        } else {
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'relative_expression_values'} = $relative_expression_data;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'endogenous_control'} = $endogenous_control;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'notes'} = $notes;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'uploaded_by'} = $operator_id;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'}->{'relative_expression_data_derived_from'} = $relative_expression_data_derived_from;
            $expression_data_json = encode_json $expression_data_hash;
            $transformant_stock->create_stockprops({$expression_data_cvterm->name() => $expression_data_json});
        }

        my $previous_assay_metadata_stockprop_rs = $vector_construct_stock->stockprops({type_id=>$assay_metadata_cvterm->cvterm_id});
        if ($previous_assay_metadata_stockprop_rs->count == 1){
            my $previous_assay_metadata_json = $previous_assay_metadata_stockprop_rs->first->value();
            my $previous_assay_metadata_hash = decode_json $previous_assay_metadata_json;
            $previous_assay_metadata_hash->{$tissue_type}->{$assay_date} = 1;
            $previous_assay_metadata_json = encode_json $previous_assay_metadata_hash;
            $previous_assay_metadata_stockprop_rs->first->update({value=>$previous_assay_metadata_json});
        } elsif ($previous_assay_metadata_stockprop_rs->count > 1) {
            print STDERR "More than one assay metadata stockprop found!\n";
            return;
        } else {
            my $assay_metadata = {};
            my $assay_metadata->{$tissue_type}->{$assay_date} = 1;
            my $assay_metadata_json = encode_json $assay_metadata;

            $vector_construct_stock->create_stockprops({$assay_metadata_cvterm->name() => $assay_metadata_json});
        }
    };

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
