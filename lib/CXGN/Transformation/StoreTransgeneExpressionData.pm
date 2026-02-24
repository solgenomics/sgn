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
use Statistics::Descriptive;

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

has 'CT_expression_data' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    predicate => 'has_CT_expression_data',
);

has 'relative_expression_data' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    predicate => 'has_relative_expression_data',
);

has 'normalization_method' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_normalization_method',
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


sub store_qPCR_data {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transaction_error;
    my $transformant_name = $self->get_transformant_name();
    my $vector_construct_name = $self->get_vector_construct_name();
    my $CT_expression_data = $self->get_CT_expression_data();
    my $relative_expression_data = $self->get_relative_expression_data();

    my $tissue_type = $self->get_tissue_type();
    my $assay_date = $self->get_assay_date();
    my $endogenous_control = $self->get_endogenous_control();
    my $normalization_method = $self->get_normalization_method();
    my $notes = $self->get_notes();
    my $operator_id = $self->get_operator_id();
    my $normalized_values_derived_from;
    my %return;

    my $coderef = sub {

        if ($CT_expression_data) {
            if ($normalization_method eq "CASS_Delta_Cq") {
                $relative_expression_data = _CASS_normalized_values($CT_expression_data, $endogenous_control);
                $normalized_values_derived_from = 'calculated using CASS normalization method';
            }
        } elsif ((!$CT_expression_data) && $relative_expression_data ) {
            $normalized_values_derived_from = 'provided';
        }

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
            $return{error} = "Transgenic line cound not be found in the database: $transformant_name!";
            return \%return;
        } else {
            $transformant_stock_id = $transformant_stock->stock_id();
		}

		my $vector_construct_stock = $schema->resultset("Stock::Stock")->find ({
		    uniquename => $vector_construct_name,
		    type_id => $vector_construct_cvterm->cvterm_id(),
	    });
        if (!$vector_construct_stock) {
            $return{error} = "Vector construct cound not be found in the database: $vector_construct_name!";
            return \%return;
        } else {
			$vector_construct_stock_id = $vector_construct_stock->stock_id();
		}

        my $expression_data_json;
        my $expression_data_hash = {};
        my $updated_expression_data_json;
        my %CT_expression_data_details;
        my %relative_expression_data_details;

        if ($CT_expression_data) {
            $CT_expression_data_details{'CT_values'} = $CT_expression_data;
            $CT_expression_data_details{'endogenous_control'} = $endogenous_control;
            $CT_expression_data_details{'notes'} = $notes;
            $CT_expression_data_details{'uploaded_by'} = $operator_id;
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'CT_expression_data'} = \%CT_expression_data_details;
        }

        $relative_expression_data_details{'relative_expression_values'} = $relative_expression_data;
        $relative_expression_data_details{'endogenous_control'} = $endogenous_control;
        $relative_expression_data_details{'notes'} = $notes;
        $relative_expression_data_details{'uploaded_by'} = $operator_id;
        $relative_expression_data_details{'normalized_values_derived_from'} = $normalized_values_derived_from;

        my $previous_expression_data_stockprop_rs = $transformant_stock->stockprops({type_id=>$expression_data_cvterm->cvterm_id});
        if ($previous_expression_data_stockprop_rs->count == 1){
            $expression_data_json = $previous_expression_data_stockprop_rs->first->value();
            $expression_data_hash = decode_json $expression_data_json;

            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'} = \%relative_expression_data_details;
            if ($CT_expression_data) {
                $expression_data_hash->{$tissue_type}->{$assay_date}->{'CT_expression_data'} = \%CT_expression_data_details;
            }

            $updated_expression_data_json = encode_json $expression_data_hash;
            $previous_expression_data_stockprop_rs->first->update({value=>$updated_expression_data_json});
        } elsif ($previous_expression_data_stockprop_rs->count > 1) {
            $return{error} = "More than one expression data stockprop found for: $transformant_name!";
            return \%return;
        } else {
            $expression_data_hash->{$tissue_type}->{$assay_date}->{'relative_expression_data'} = \%relative_expression_data_details;
            if ($CT_expression_data) {
                $expression_data_hash->{$tissue_type}->{$assay_date}->{'CT_expression_data'} = \%CT_expression_data_details;
            }

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
            $return{error} = "More than one assay metadata stockprop found for vector construct: $vector_construct_name!";
            return \%return;
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
        $return{error} = "Transaction error storing qPCR data for $transformant_name: $transaction_error\n";
        return \%return;
    } else {
        $return{success} = 1;
        return \%return;
    }
}

sub _CASS_normalized_values {
    my $CT_data = shift;
	my $endogenous_control = shift;

	my %normalized_values_hash;
	my %normalized_data;

	foreach my $gene (keys %$CT_data) {
		my @replicates = ();
		my $number_of_replicates = '';
		my $gene_data = {};
        $gene_data = $CT_data->{$gene};
		@replicates = keys %$gene_data;
		$number_of_replicates = scalar @replicates;
		foreach my $rep (keys %$gene_data) {
            my $CT_values = $gene_data->{$rep};
	        my $endogenous_control_CT = $CT_values->{'endogenous_control'}->{$endogenous_control};
	        my $two_power_control = 2**$endogenous_control_CT;
	        my $CT = $CT_values->{'target'}->{$gene};
	        my $normalized_value;
			my $two_power_target = 2**$CT;
	        $normalized_values_hash{$rep} = $two_power_control / $two_power_target;
		}

		my @all_normalized_values = ();
		@all_normalized_values = values %normalized_values_hash;
		my $stat = Statistics::Descriptive::Full->new();
		$stat->add_data(@all_normalized_values);

		my $mean_value =  sprintf("%.6f", $stat->mean());
		my $stdevp_value;
		if ($number_of_replicates > 1) {
		    my $sum_of_squared_differences;
			foreach my $normalized_value (@all_normalized_values) {
				my $squared_difference;
				$squared_difference = ($normalized_value - $mean_value) ** 2;
				$sum_of_squared_differences += $squared_difference;
			}
			$stdevp_value = sqrt($sum_of_squared_differences/$number_of_replicates);
			$stdevp_value =  sprintf("%.6f", $stdevp_value);
		} else {
			$stdevp_value = "NA";
		}
		$normalized_data{$gene}{'relative_expression'} = $mean_value;
		$normalized_data{$gene}{'number_of_replicates'} = $number_of_replicates;
		$normalized_data{$gene}{'stdevp'} = $stdevp_value;
	}

    return \%normalized_data;
}



#######
1;
#######
