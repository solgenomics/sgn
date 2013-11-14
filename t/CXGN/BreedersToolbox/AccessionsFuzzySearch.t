use strict;
use warnings;

use Test::More tests=>3;

BEGIN {use_ok('CXGN::BreedersToolbox::AccessionsFuzzySearch');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {require_ok('Moose');}

#my $dbh = CXGN::DB::Connection->new();
#my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
