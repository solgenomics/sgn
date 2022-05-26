package CXGN::Pedigree::AddCrossInfo;

=head1 NAME

CXGN::Pedigree::AddCrossInfo - a module to add cross information such as date of pollination, number of flowers pollinated, number of fruits set as stock properties for cross.

=head1 USAGE

my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ chado_schema => $chado_schema, cross_name => $cross_name, key => $info_type, value => $value} );
$cross_add_info->add_info();

=head1 DESCRIPTION

Adds cross properties in json string format to stock of type cross. The cross must already exist in the database. This module is intended to be used in independent loading scripts and interactive dialogs.

=head1 AUTHORS

Jeremy D. Edwards (jde22@cornell.edu)
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
has 'value' => (isa =>'Str', is => 'rw', predicate => 'has_value',);
has 'data_type' => (isa =>'Str', is => 'rw', predicate => 'has_type', required => 1,);

sub add_info {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transaction_error;

    #add all cross info in a single transaction
    my $coderef = sub {

        #get cross (stock of type cross)
        my $cross_stock = $self->_get_cross($self->get_cross_name());
        if (!$cross_stock) {
            print STDERR "Cross could not be found\n";
            return;
        }

        # get cvterm of cross info type (crossing_metadata_json or cross_additional_info)
        my $cross_info_type = $self->get_data_type();
#        print STDERR "DATA TYPE =".Dumper($cross_info_type)."\n";
        my $cross_info_cvterm;
        if (($cross_info_type eq 'crossing_metadata_json') || ($cross_info_type eq 'cross_additional_info')) {
			$cross_info_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, $cross_info_type, 'stock_property');
        } else {
			print STDERR "Invalid type"."\n";
            return;
        }

        my $cross_json_string;
        my $cross_json_hash = {};
        my $previous_stockprop_rs = $cross_stock->stockprops({type_id=>$cross_info_cvterm->cvterm_id});
        if ($previous_stockprop_rs->count == 1){
            $cross_json_string = $previous_stockprop_rs->first->value();
            $cross_json_hash = decode_json $cross_json_string;
            $cross_json_string = _generate_property_hash($self->get_key, $self->get_value, $cross_json_hash);
            $previous_stockprop_rs->first->update({value=>$cross_json_string});
        } elsif ($previous_stockprop_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
            $cross_json_string = _generate_property_hash($self->get_key, $self->get_value, $cross_json_hash);
            $cross_stock->create_stockprops({$cross_info_cvterm->name() => $cross_json_string});
        }
#        print STDERR "CROSS JSON STRING =".Dumper($cross_json_string)."\n";
    };

    #try to add all cross info in a transaction
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing information for cross: $transaction_error\n";
        return;
    }

    return 1;
}

sub _generate_property_hash {
    my $key = shift;
    my $value = shift;
    my $cross_json_hash = shift;
    $cross_json_hash->{$key} = $value;
    #print STDERR Dumper $cross_json_hash;
    my $cross_json_string = encode_json $cross_json_hash;
    return $cross_json_string;
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
