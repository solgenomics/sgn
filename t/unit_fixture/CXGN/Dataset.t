
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Dataset::Cache;

my $t = SGN::Test::Fixture->new();

my $ds = CXGN::Dataset->new( people_schema => $t->people_schema(), schema => $t->bcs_schema());

$ds->accessions( [ 38913, 38914, 38915 ]);
$ds->years(['2012', '2013']);
$ds->traits([ 70666, 70741 ]);
$ds->trials([ 139, 144 ]);
$ds->plots( [ 40034, 40035 ]);
$ds->name("test");
$ds->description("test description");

$ds->name("test");
$ds->description("test description");
$ds->sp_person_id(41);

my $sp_dataset_id = $ds->store();

my $new_ds = CXGN::Dataset->new( people_schema => $t->people_schema(), schema => $t->bcs_schema(), sp_dataset_id => $sp_dataset_id);

is_deeply($new_ds->accessions(), $ds->accessions(), "accession store");
is_deeply($new_ds->years(), $ds->years(), "years store");
is_deeply($new_ds->traits(), $ds->traits(), "traits store");
is_deeply($new_ds->plots(), $ds->plots(), "plots store");

is($new_ds->name(), $ds->name(), "name store");
is($new_ds->description(), $ds->description(), "desc store");
is($new_ds->sp_person_id(), 41, "dataset owner");

my @datasets = ( 
    CXGN::Dataset->new( people_schema => $t->people_schema(), schema => $t->bcs_schema()), 
    CXGN::Dataset::File->new( people_schema => $t->people_schema(), schema => $t->bcs_schema()), 
    CXGN::Dataset::Cache->new( people_schema => $t->people_schema(), schema => $t->bcs_schema(), cache_root => '/tmp/dataset_cache_root'), 	
    );

foreach my $ds (@datasets) { 
    if ($ds->can("cache")) { $ds->cache->clear(); }
    $ds->name("test");
    $ds->description("test description");

    $ds->accessions( [ 38913, 38914, 38915 ] );
    
    my $sp_dataset_id = $ds->store();

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
    
    if ($ds->isa("CXGN::Dataset::File")) { 
	ok(-e $ds->file_name()."_trials.txt", "trial file exists");
    }
	
    my $traits = $ds ->retrieve_traits();

    is_deeply($traits, [
		  [
		   70741,
		   'dry matter content percentage|CO_334:0000092'
		  ],
		  [
		   70666,
		   'fresh root weight|CO_334:0000012'
		  ],
		  [
		   70773,
		   'fresh shoot weight measurement in kg|CO_334:0000016'
		  ],
		  [
		   70668,
		   'harvest index variable|CO_334:0000015'
		  ]
	      ]
	);
    
    my $phenotypes = $ds->retrieve_phenotypes();
    
    my $genotypes = $ds->retrieve_genotypes(1);
    
    my $years = $ds->retrieve_years();

    is_deeply($years, [], "Year retrieve test");

    my $plots = $ds->retrieve_plots();

    is_deeply($plots, [
		  [
		   39299,
		   'KASESE_TP2013_1029'
		  ],
		  [
		   39895,
		   'KASESE_TP2013_1590'
		  ],
		  [
		   39424,
		   'KASESE_TP2013_1717'
		  ],
		  [
		   39607,
		   'KASESE_TP2013_707'
		  ],
		  [
		   39733,
		   'KASESE_TP2013_880'
		  ],
		  [
		   40343,
		   'test_t113'
		  ],
		  [
		   40493,
		   'test_t249'
		  ],
		  [
		   40669,
		   'test_t407'
		  ],
		  [
		   40676,
		   'test_t413'
		  ],
		  [
		   40814,
		   'test_t538'
		  ],
		  [
		   40819,
		   'test_t542'
		  ],
		  [
		   40956,
		   'test_t666'
		  ],
		  [
		   41168,
		   'test_t857'
		  ],
		  [
		   41237,
		   'test_t919'
		  ],
		  [
		   40033,
		   'UG120036_block:2_plot:TP36_2012_NaCRRI'
		  ],
		  [
		   40034,
		   'UG120037_block:2_plot:TP37_2012_NaCRRI'
		  ],
		  [
		   40035,
		   'UG120038_block:2_plot:TP38_2012_NaCRRI'
		  ]
	      ], "plot retrieve test");

}

done_testing();
