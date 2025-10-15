

use strict;
use Test::More;
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;

use CXGN::Phenotypes::PhenotypeMatrix;

my $f = SGN::Test::Fixture->new();

my $dbh = $f->dbh();

print STDERR "Inserting a duplicate measurement...\n";
#
my $q = "insert into phenotype (cvalue_id, value, uniquename) values (70773, '3.0', 'fresh shoot weight date: 2024-03-01_19:20:56 operator = test_operator_323')";

my $h = $dbh->prepare($q);
$h->execute();

my $q2 = "insert into cvtermprop (cvterm_id, type_id, value) values (70773, (select cvterm_id from cvterm where name='trait_repeat_type'), 'multiple')";

my $h2 = $dbh->prepare($q2);
$h2->execute();

my $q3 = "insert into nd_experiment_phenotype (nd_experiment_id, phenotype_id) values (76184, (select phenotype_id FROM phenotype where uniquename ilike '%test_operator_323%'))";

my $h3= $dbh->prepare($q3);
$h3->execute();

my $q4 = "select phenotype_id, cvalue_id, value from phenotype where value='3.0'";

my $h4 = $dbh->prepare($q4);
$h4->execute();

while (my ($phenotype_id, $cvalue_id, $value) = $h4->fetchrow_array()) {
    print STDERR "PHENOTYPE_ID $phenotype_id CVALUE_ID $cvalue_id VALUE $value\n";

}

my $dbhost = $f->config->{dbhost};
my $dbname = $f->config->{dbname};
my $dbpass = $f->config->{dbpass};

print STDERR "Running matview refresh with -H $dbhost -D $dbname -U postgres -P $dbpass -m phenotypes\n";
system("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U postgres -P $dbpass -m phenotypes");
    


print STDERR "Downloading data...\n";

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
    bcs_schema=>$f->bcs_schema(),
    search_type=> 'MaterializedViewTable',
    data_level=> 'plot',
    trial_list=> [ 139 ],
    trait_list=> [ 70773 ],
    repetitive_measurements => 'average',
#   #  program_list=>$self->program_list,
    # folder_list=>$self->folder_list,
    # year_list=>$year_list,
    # location_list=>$location_list,
    # accession_list=>$accession_list,
    # plot_list=>$plot_list,
    # plant_list=>$plant_list,
    # include_timestamp=>$include_timestamp,
    # include_pedigree_parents=>$include_pedigree_parents,
    # exclude_phenotype_outlier=>0,
    # dataset_excluded_outliers=>$dataset_excluded_outliers,
    # trait_contains=>$trait_contains,
    # phenotype_min_value=>$phenotype_min_value,
    # phenotype_max_value=>$phenotype_max_value,
    # start_date => $start_date,
    # end_date => $end_date,
    # include_dateless_items => $include_dateless_items,
 #   limit=>$limit, offset=>$offset
    );


my @results = ( '2.25', '1.5|3.0', '1.5', '3.0', '4.5' );

my $search_type = 'MaterializedViewTable';
foreach my $repetitive_measurements ('average', 'all_values_single_line', 'first', 'last', 'sum') {
    
    $phenotypes_search->search_type($search_type);
    $phenotypes_search->repetitive_measurements($repetitive_measurements);
    
    my @data = $phenotypes_search->get_phenotype_matrix();
    
    foreach my $d (@data) { 
	    if (my @out = grep( /KASESE_TP2013_1619/, @$d )) {
	        my $result = shift(@results);
	        print STDERR "$search_type, $repetitive_measurements, GOT: $d->[39], EXPECTED: $result\n";
    
	        is( $d->[39], $result, "test $result" );
	        #print STDERR "MATCHED: ".Dumper($d);
	    }
    }  
}


@results = ( '2.25', '1.5|3.0', '1.5', '3.0', '4.5');
$search_type = "Native";

foreach my $repetitive_measurements ('average', 'all_values_single_line', 'first', 'last', 'sum') {
    
    $phenotypes_search->search_type($search_type);
    $phenotypes_search->repetitive_measurements($repetitive_measurements);
    
    
    my @data = $phenotypes_search->get_phenotype_matrix();
    
    foreach my $d (@data) { 
	    if (my @out = grep( /KASESE_TP2013_1619/, @$d )) {
	        my $result = shift(@results);
	        print STDERR "$search_type, $repetitive_measurements, GOT: $d->[30], EXPECTED: $result\n";
    
	        is( $d->[30], $result, "test $result" );
	        #print STDERR "MATCHED: ".Dumper($d);
	    }
    }  
}

$f->clean_up_db();

system("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U postgres -P $dbpass -m phenotypes");
    

done_testing();
