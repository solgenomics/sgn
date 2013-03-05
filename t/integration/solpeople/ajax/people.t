##tests for people ajax functions 
## Naama Medna, Feb 2011

use Modern::Perl;

use lib 't/lib';
use Test::More ;


BEGIN { $ENV{SGN_SKIP_CGI} = 1 } #< can skip compiling cgis, not using them here
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;


my $mech = SGN::Test::WWW::Mechanize->new();

my $dbh = $mech->context->dbc->dbh;

my $person = $mech->create_test_user(
    first_name => 'testfirstname',
    last_name  => 'testlastname',
    user_name  => 'testusername',
    password   => 'testpassword',
    user_type  => 'submitter',
    );
my $sp_person_id = $person->{id};

my $term = 'tes';
$mech->get_ok("/ajax/people/autocomplete?term=$term");


$mech->content_contains($term);
$mech->content_contains($person->{first_name});
$mech->content_contains($person->{last_name});

done_testing;


