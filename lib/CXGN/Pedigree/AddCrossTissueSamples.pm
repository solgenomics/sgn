package CXGN::Pedigree::AddCrossTissueSamples;

=head1 NAME

CXGN::Pedigree::AddCrossTissueSamples - a module to add cross tissue sample ids as stock properties for cross.

=head1 USAGE

my $cross_add_sample = CXGN::Pedigree::AddCrossTissueSamples->new({ chado_schema => $chado_schema, cross_name => $cross_name, key => $sample_type, value => $value} );
$cross_add_info->add_info();

=head1 DESCRIPTION

Adds tissue sample ids in json string format to stock of type cross. The cross must already exist in the database.

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
has 'cross_name' => (isa =>'Str', is => 'rw', predicate => 'has_cross_name', required => 1,);
has 'key' => (isa =>'Str', is => 'rw', predicate => 'has_key',);
has 'value' => (isa =>'ArrayRef[Str]', is => 'rw', predicate => 'has_value',);


sub add_samples {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transaction_error;

    #add all samples in a single transaction
    my $coderef = sub {

        #get cross (stock of type cross)
        my $cross_stock = $self->_get_cross($self->get_cross_name());
        if (!$cross_stock) {
            print STDERR "Cross could not be found\n";
            return;
        }

        my $cross_tissue_samples_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_culture_data_json', 'stock_property');

        my $samples_json_string;
        my $samples_json_hash = {};
        my $previous_stockprop_rs = $cross_stock->stockprops({type_id=>$cross_tissue_samples_cvterm->cvterm_id});
        if ($previous_stockprop_rs->count == 1){
            $samples_json_string = $previous_stockprop_rs->first->value();
            $samples_json_hash = decode_json $samples_json_string;
            $samples_json_string = _generate_property_hash($self->get_key, $self->get_value, $samples_json_hash);
            $previous_stockprop_rs->first->update({value=>$samples_json_string});
        } elsif ($previous_stockprop_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
            $samples_json_string = _generate_property_hash($self->get_key, $self->get_value, $samples_json_hash);
            $cross_stock->create_stockprops({$cross_tissue_samples_cvterm->name() => $samples_json_string});
        }

    };

    #try to add all tissue samples in a transaction
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing tissue samples for cross: $transaction_error\n";
        return;
    }

    return 1;
}


sub _generate_property_hash {
    my $key = shift;
    my $value = shift;
    my $samples_json_hash = shift;
    $samples_json_hash->{$key} = $value;
    #print STDERR Dumper $cross_json_hash;
    my $samples_json_string = encode_json $samples_json_hash;
    return $samples_json_string;
}


sub _get_cross {
    my $self = shift;
    my $cross_name = shift;
    my $schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    my $stock;
    my $cross_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type');

    $stock_lookup->set_stock_name($cross_name);
    $stock = $stock_lookup->get_cross_exact();

    if (!$stock) {
        print STDERR "Cross name does not exist\n";
        return;
    }
    return $stock;
}

#######
1;
#######
