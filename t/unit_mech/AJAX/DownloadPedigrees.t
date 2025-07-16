
use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

# for identifying whitespace differences
# use String::Diff;
# use String::Diff qw( diff_fully diff diff_merge diff_regexp );# export functions

my $mech = Test::WWW::Mechanize->new;

$mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?input_format=accession_ids&ped_format=parents_only&ids=38873,38874,38875,38876,38877");
my $response = $mech->content;

my $expected_response = 'Accession	Female_Parent	Male_Parent	Cross_Type
test5P001	test_accession4	test_accession5	
test5P002	test_accession4	test_accession5	
test5P003	test_accession4	test_accession5	
test5P004	test_accession4	test_accession5	
test5P005	test_accession4	test_accession5	
';

# for identifying whitespace differences
# my($old, $new) = String::Diff::diff($expected_response, $response);
# print STDERR "expected: $old\n";
# print STDERR "got: $new\n";

is($response, $expected_response, 'download direct parents pedigree');

$mech->get_ok('http://localhost:3010/breeders/download_pedigree_action?input_format=accession_ids&ped_format=full&ids=38873,38874,38875,38876,38877');
$response = $mech->content;

$expected_response = 'Accession	Female_Parent	Male_Parent	Cross_Type
test5P001	test_accession4	test_accession5	
test5P002	test_accession4	test_accession5	
test5P003	test_accession4	test_accession5	
test5P004	test_accession4	test_accession5	
test5P005	test_accession4	test_accession5	
test_accession1			
test_accession2			
test_accession3			
test_accession4	test_accession1	test_accession2	biparental
test_accession5	test_accession3		open
';

# for identifying whitespace differences
# ($old, $new) = String::Diff::diff($expected_response, $response);
# print STDERR "expected: $old\n";
# print STDERR "got: $new\n";

is($response, $expected_response, 'download full pedigree');

done_testing();
