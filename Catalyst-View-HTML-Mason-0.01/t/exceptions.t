use strict;
use warnings;
use Test::More;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestAppErrors';

is(get('/'), "tiger\n" x 2, 'Basic rendering' );

dies_ok {
  get('/invalid_template');
} 'Rendering nonexistent template dies as expected';

done_testing;
