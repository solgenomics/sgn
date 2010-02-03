use strict;

use CXGN::MasonFactory;
use CXGN::DB::DBICFactory;

my %args = (
    schema => CXGN::DB::DBICFactory->open_schema('SGN::Schema', search_path => ['sgn']),
);
my $m = CXGN::MasonFactory->new();
$m->exec("/index.mas", %args);
