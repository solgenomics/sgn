
# tests for storing phenotypes

# Jeremy 2013

use strict;

use lib 't/lib';
use Test::More qw/no_plan/;
use Data::Dumper;
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new();

$m->while_logged_in( 
    { user_type => 'user' },
    sub {
    });




