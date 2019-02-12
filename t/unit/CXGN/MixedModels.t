
use strict;

use Test::More;
use Data::Dumper;
use CXGN::MixedModels;


my $mm = CXGN::MixedModels->new( { tempfile => "t/data/mixed_model_testfile.txt" } );

print STDERR Dumper($mm->phenotype_file()->traits());
print STDERR Dumper($mm->phenotype_file()->factors());
print STDERR Dumper($mm->phenotype_file()->levels());

$mm->dependent_variable('dry matter content percentage|CO_334:0000092');
$mm->fixed_factors(['studyYear', 'replicate']);
$mm->random_factors(['germplasmName']);
$mm->fixed_factors_interaction( [ [ 'studyYear', 'replicate' ] ]);

print STDERR Dumper($mm->generate_model());

