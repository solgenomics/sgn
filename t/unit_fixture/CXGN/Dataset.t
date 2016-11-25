
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Dataset::Cache;

my $t = SGN::Test::Fixture->new();

my @datasets = ( 
    CXGN::Dataset->new( people_schema => $t->people_schema(), schema => $t->bcs_schema()), 
    CXGN::Dataset::File->new( people_schema => $t->people_schema(), schema => $t->bcs_schema()), 
#x    CXGN::Dataset::Cache->new( people_schema => $t->people_schema(), schema => $t->bcs_schema(), cache_root => '/tmp/dataset_cache_root'), 	
    );

foreach my $ds (@datasets) { 

    $ds->name("test");
    $ds->description("test description");

    $ds->accessions( [ 38913, 38914, 38915 ] );
    
    my $sp_dataset_id = $ds->store();

    print STDERR "Save dataset with id $sp_dataset_id\n";

    my $ds_copy = CXGN::Dataset->new( people_schema => $t->people_schema(), schema => $t->bcs_schema(), sp_dataset_id => $sp_dataset_id);
    
    is_deeply($ds_copy->accessions(), $ds->accessions(), "accession store test");
    is($ds_copy->name(), $ds->name(), "name store test");
    is($ds_copy->description, $ds->description(), "description store test");

    my $trials = $ds->retrieve_trials();

    

    is_deeply($trials, [
                         [
                           139,
                           'Kasese solgs trial'
                         ],
                         [
                           144,
                           'test_t'
                         ],
                         [
                           141,
                           'trial2 NaCRRI'
                         ]
                       ]
	      , "trial retrieve test");
    

    print STDERR Dumper($trials);
    
    my $traits = $ds ->retrieve_traits();
    print STDERR Dumper($traits);

    is_deeply($traits, [
		  [
		   70741,
		   'dry matter content percentage|CO:0000092'
		  ],
		  [
		   70666,
		   'fresh root weight|CO:0000012'
		  ],
		  [
		   70773,
		   'fresh shoot weight measurement in kg|CO:0000016'
		  ],
		  [
		   70668,
		   'harvest index variable|CO:0000015'
		  ]
	      ]
	);
    
    my $phenotypes = $ds->retrieve_phenotypes();
    
   # print STDERR Dumper($phenotypes);
    
    my $genotypes = $ds->retrieve_genotypes(1);
    
    #print STDERR Dumper($genotypes);
    
    my $years = $ds->retrieve_years();

    print STDER Dumper($years);

    my $plots = $ds->retrieve_plots();
    print STDER Dumper($plots);
}

done_testing();
