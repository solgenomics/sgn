
use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

# for identifying whitespace differences
# use String::Diff;
# use String::Diff qw( diff_fully diff diff_merge diff_regexp );# export functions

my $mech = SGN::Test::WWW::Mechanize->new;

my $expected_response1 = 'Accession	Female_Parent	Male_Parent	Cross_Type
test5P001	test_accession4	test_accession5	
test5P002	test_accession4	test_accession5	
test5P003	test_accession4	test_accession5	
test5P004	test_accession4	test_accession5	
test5P005	test_accession4	test_accession5	
';

my $expected_response2 = 'Accession	Female_Parent	Male_Parent	Cross_Type
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

my $forbidden_response = "You do not have the permissions to view pedigrees";


check_pedigrees($forbidden_response, $forbidden_response);

$mech->get_ok("http://localhost:3010/");

print STDERR "COMPLETED WITHOUT LOGIN!\n";


foreach my $data ( [ "freddy", "atgc" ], [ "johndoe", "secretpw" ], [ "janedoe", "secretpw" ]) {

    $mech->login_ok($data->[0], $data->[1]);
    
    check_pedigrees($expected_response1, $expected_response2);

    $mech->logout_ok();
}





sub check_pedigrees {
    my $expected_response1 = shift;
    my $expected_response2 = shift;
    $mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?input_format=accession_ids&ped_format=parents_only&ids=38873,38874,38875,38876,38877");
    my $response = $mech->content;
    
#    my $expected_response = 'Accession	Female_Parent	Male_Parent	Cross_Type
#test5P001	test_accession4	test_accession5	
#test5P002	test_accession4	test_accession5	
#test5P003	test_accession4	test_accession5	
#test5P004	test_accession4	test_accession5	
#test5P005	test_accession4	test_accession5	
#';
    
    # for identifying whitespace differences
    # my($old, $new) = String::Diff::diff($expected_response, $response);
    # print STDERR "expected: $old\n";
    # print STDERR "got: $new\n";
    
    is($response, $expected_response1, 'download direct parents pedigree');
    
    $mech->get_ok('http://localhost:3010/breeders/download_pedigree_action?input_format=accession_ids&ped_format=full&ids=38873,38874,38875,38876,38877');
    $response = $mech->content;
    
#     $expected_response = 'Accession	Female_Parent	Male_Parent	Cross_Type
# test5P001	test_accession4	test_accession5	
# test5P002	test_accession4	test_accession5	
# test5P003	test_accession4	test_accession5	
# test5P004	test_accession4	test_accession5	
# test5P005	test_accession4	test_accession5	
# test_accession1			
# test_accession2			
# test_accession3			
# test_accession4	test_accession1	test_accession2	biparental
# test_accession5	test_accession3		open
# ';

    # for identifying whitespace differences
    # ($old, $new) = String::Diff::diff($expected_response, $response);
    # print STDERR "expected: $old\n";
    # print STDERR "got: $new\n";
    
    is($response, $expected_response2, 'download full pedigree');
}


done_testing();
