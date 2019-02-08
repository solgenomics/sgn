
use strict;

use Test::More;
use Data::Dumper;
use CXGN::MixedModels;


my $mm = CXGN::MixedModels->new( { tempfile => "t/data/mixed_model_testfile.txt" } );

print STDERR Dumper($mm->phenotype_file()->traits());
print STDERR Dumper($mm->phenotype_file()->factors());
print STDERR Dumper($mm->phenotype_file()->levels());


