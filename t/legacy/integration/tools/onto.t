use strict;
use warnings;

use lib 't/lib';
use JSON::Any;
use Test::More;
use SGN::Test::WWW::Mechanize;
use Data::Dumper;

my $m = SGN::Test::WWW::Mechanize->new();
my $j = JSON::Any->new();

# test parent terms
my $term = "SP:0000181";
my $root_term = 'SP:0001000';

$m->get_ok("/ajax/onto/parents/?node=$term");
my $contents = $m->content();
my $parsed_content = $j->decode($contents);

my @accession_list  = map ( ${$_}{accession} , @$parsed_content);

ok(  grep(/^$root_term/, @accession_list) ,  'parent accession test');
is( scalar(@accession_list) , 7 , 'number of parents test');
##

#test child terms 
my $new_term = 'SP:0000069';
my $child_accession = 'SP:0000180';

$m->get_ok("/ajax/onto/children/?node=$new_term");
$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);

@accession_list  = map ( ${$_}{accession} , @$parsed_content);

ok(  grep(/^$child_accession/, @accession_list) ,  'child accession test');
is( scalar(@accession_list) , 2 , 'number of children test');
#################

##
$m->get_ok("/ajax/onto/roots");
$contents = $m->content();
my $bp_root = 'GO:0008150';
$parsed_content = $j->jsonToObj($contents);

#roots test

@accession_list  = map ( ${$_}{accession} , @$parsed_content);

ok(  grep(/^$bp_root/, @accession_list) ,  'root accession test');
cmp_ok( scalar(@accession_list), '>=', 2, 'got at least 2 root terms')
    or diag explain $parsed_content;

##

# test the cache 
$m->get_ok("/ajax/onto/cache/?node=$new_term");

$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);


@accession_list  = map ( ${$_}{accession} , @$parsed_content);

ok(  grep(/^$new_term/, @accession_list) ,  'cached parent accession test');
is( scalar(@accession_list) , 24 , 'number of parents test');

##

my $match_string = 'fruit end color';
$m->get_ok("/ajax/onto/match/?db_name=SP&term_name=$match_string");
$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);

@accession_list  = map ( ${$_}{accession} , @$parsed_content);

ok(  grep(/^$term/, @accession_list) ,  'matched accession test');
is( scalar(@accession_list) , 2 , 'number of matches test');

done_testing;

