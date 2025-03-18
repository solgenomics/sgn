
use strict;

use Test::More;

use lib 't/lib';

use SGN::Test::Fixture;

use CXGN::Phenotype;

my $f = SGN::Test::Fixture->new();

my $p = CXGN::Phenotype->new( { schema => $f->bcs_schema() });


$p->cvterm_name('dry matter content percentage');
$p->value(40);
$p->stock_id('KASESE_TP2013_1016');


$p->operator("Butz");

collect_date
