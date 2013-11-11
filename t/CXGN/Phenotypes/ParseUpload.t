
# test for parsing uploaded phenotype files

# Jeremy, Oct 2013

use strict;

use lib 't/lib';
use Test::More qw/no_plan/;
use JSON::Any;
use Data::Dumper;
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new();

$m->while_logged_in( 
    { user_type => 'user' },
    sub {

    });




