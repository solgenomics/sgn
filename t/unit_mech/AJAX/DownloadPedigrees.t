
use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
use File::Compare;
local $Data::Dumper::Indent = 0;

# for identifying whitespace differences
# use String::Diff;
# use String::Diff qw( diff_fully diff diff_merge diff_regexp );# export functions

my $mech = Test::WWW::Mechanize->new;

# -----------------------------------------------------------------------------
# Download TXT

$mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?file_format=.txt&input_format=accession_ids&ped_format=parents_only&ids=38873,38874,38875,38876,38877");
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

is($response, $expected_response, 'download direct parents pedigree txt');

$mech->get_ok('http://localhost:3010/breeders/download_pedigree_action?file_format=.txt&input_format=accession_ids&ped_format=full&ids=38873,38874,38875,38876,38877');
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

is($response, $expected_response, 'download full pedigree txt');

# -----------------------------------------------------------------------------
# Download HELIUM

$mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?file_format=.helium&input_format=accession_ids&ped_format=parents_only&ids=38873,38874,38875,38876,38877");
$response = $mech->content;
$expected_response = '# Pedigrees of provided Accession IDs: 38873,38874,38875,38876,38877
# Pedigree Format: parents_only
# Include: ancestors
# heliumInput = PEDIGREE
LineName	FemaleParent	MaleParent
test5P001	test_accession4	test_accession5
test5P002	test_accession4	test_accession5
test5P003	test_accession4	test_accession5
test5P004	test_accession4	test_accession5
test5P005	test_accession4	test_accession5
';
is($response, $expected_response, 'download direct parents pedigree helium');

$mech->get_ok('http://localhost:3010/breeders/download_pedigree_action?file_format=.helium&input_format=accession_ids&ped_format=full&ids=38873,38874,38875,38876,38877');
$response = $mech->content;
$expected_response = '# Pedigrees of provided Accession IDs: 38873,38874,38875,38876,38877
# Pedigree Format: full
# Include: ancestors
# heliumInput = PEDIGREE
LineName	FemaleParent	MaleParent
test5P001	test_accession4	test_accession5
test5P002	test_accession4	test_accession5
test5P003	test_accession4	test_accession5
test5P004	test_accession4	test_accession5
test5P005	test_accession4	test_accession5
test_accession1		
test_accession2		
test_accession3		
test_accession4	test_accession1	test_accession2
test_accession5	test_accession3	
';
is($response, $expected_response, 'download full pedigree helium');

# -----------------------------------------------------------------------------
# Download CSV

$mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?file_format=.csv&input_format=accession_ids&ped_format=parents_only&ids=38873,38874,38875,38876,38877");
my $response = $mech->content;
my $expected_response = 'Accession,Female_Parent,Male_Parent,Cross_Type
test5P001,test_accession4,test_accession5,
test5P002,test_accession4,test_accession5,
test5P003,test_accession4,test_accession5,
test5P004,test_accession4,test_accession5,
test5P005,test_accession4,test_accession5,
';
is($response, $expected_response, 'download direct parents pedigree csv');

$mech->get_ok('http://localhost:3010/breeders/download_pedigree_action?file_format=.csv&input_format=accession_ids&ped_format=full&ids=38873,38874,38875,38876,38877');
$response = $mech->content;
$expected_response = 'Accession,Female_Parent,Male_Parent,Cross_Type
test5P001,test_accession4,test_accession5,
test5P002,test_accession4,test_accession5,
test5P003,test_accession4,test_accession5,
test5P004,test_accession4,test_accession5,
test5P005,test_accession4,test_accession5,
test_accession1,,,
test_accession2,,,
test_accession3,,,
test_accession4,test_accession1,test_accession2,biparental
test_accession5,test_accession3,,open
';
is($response, $expected_response, 'download full pedigree csv');

# -----------------------------------------------------------------------------
# Download Excel

$mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?file_format=.xlsx&input_format=accession_ids&ped_format=parents_only&ids=38873,38874,38875,38876,38877");
my $response = $mech->content;

my $expected = "t/data/download/pedigree_parents_only.xlsx";
my $observed = "/tmp/download_pedigree_parents_only.xlsx";
open my $fh, '>', $observed or die "Could not open '$observed': $!";
binmode $fh;
print $fh $response;
close $fh;

ok(compare($expected, $observed) eq 1, 'download direct parents pedigree xlsx');

$mech->get_ok("http://localhost:3010/breeders/download_pedigree_action?file_format=.xlsx&input_format=accession_ids&ped_format=full&ids=38873,38874,38875,38876,38877");
my $response = $mech->content;

my $expected = "t/data/download/pedigree_full.xlsx";
my $observed = "/tmp/download_pedigree_full.xlsx";
open my $fh, '>', $observed or die "Could not open '$observed': $!";
binmode $fh;
print $fh $response;
close $fh;

ok(compare($expected, $observed) eq 1, 'download full pedigree xlsx');

done_testing();
