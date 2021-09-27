
use strict;

use lib 't/lib';

use Test::More qw| no_plan|;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Stock;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

$schema->txn_begin();

eval {
    my $this_stock_id = 39041;
    my $other_stock_id = 38844;
    
    my $stock = CXGN::Stock->new( { schema => $schema, stock_id => $this_stock_id } );
    
    my $initial_counts = get_counts($this_stock_id);
    
    # try self merge, should fail:
    my $error = $stock->merge($this_stock_id);
    is($error, "Error: cannot merge stock into itself", "merge stock into itself test");
    
    my $initial_counts_other = get_counts($other_stock_id);
    
    $error = $stock->merge(38844);
    is($error, 1, "merge stock should give no error");
    
    # all data should be transferred, so these need to add up
    my $combined_counts = get_counts($this_stock_id);
	
    $initial_counts_other->{prop_count}++; # take added synonym into account
    
    foreach my $k (keys %$combined_counts) {
	print STDERR "Checking key $k...\n";
	is($combined_counts->{$k}, ($initial_counts->{$k} + $initial_counts_other->{$k}), "$k test");
    }  
};

print STDERR "ERROR = $@\n";
$schema->txn_rollback();
    
done_testing();


sub get_counts {
    my $stock_id = shift;
    my $stock_rel_object_id_count = $schema->resultset("Stock::StockRelationship")->search( { object_id => $stock_id })->count();
    my $stock_rel_subject_id_count = $schema->resultset("Stock::StockRelationship")->search( { subject_id => $stock_id })->count();
    my $stock_nd_experiment_count = $schema->resultset("NaturalDiversity::NdExperimentStock")->search( { stock_id => $stock_id })->count();
    my $stock_prop_count = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id })->count();

    my $data =  {
	object_id_count => $stock_rel_object_id_count,
	subject_id_count => $stock_rel_subject_id_count,
	nd_experiment_count => $stock_nd_experiment_count,
	prop_count => $stock_prop_count,
    };

    print STDERR Dumper($data);

    return $data;
}
