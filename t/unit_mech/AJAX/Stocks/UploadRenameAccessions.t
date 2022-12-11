
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use List::MoreUtils qw | any |;
use LWP::UserAgent;
use CXGN::List;

use Data::Dumper;
use JSON::XS;
use SGN::Model::Cvterm;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;


# Login
#
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = JSON::XS->new->decode($mech->content);
print STDERR "\n\nResponse from token call: ".Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR "\n\nsgn_session_id = $sgn_session_id\n";

my $breeding_program_id = $schema->resultset('Project::Project')->find({name=>'test'})->project_id();


# Upload file with rename - all entries should exist. Not using store synonyms option
#
my $file = $f->config->{basepath}."/t/data/stock/renaming/accession_renaming_1.csv";

my $message = verify_rename_accessions($sgn_session_id, $file);

is_deeply($message->{'success'}, 1, "check verify success");


$message = submit_rename_accessions($sgn_session_id, $message->{archived_filename_with_path}, 0);

is_deeply($message->{'success'}, 1);

my $stock1 = CXGN::Stock->new( { schema => $f->bcs_schema(), uniquename => 'test_accession100' });

my $stock1_synonyms = $stock1->synonyms();

print STDERR "STOCK 1 SYNONYMS: ".Dumper($stock1_synonyms);

is(scalar(@$stock1_synonyms), 1, "no additional synonyms without the old_names_as_synonyms option test; accession had 1 synonym before rename");



# Upload file to rename the previous entries to their original name; using store synonyms option
#
my $file = $f->config->{basepath}."/t/data/stock/renaming/accession_renaming_2.csv";

my $message = verify_rename_accessions($sgn_session_id, $file);

is_deeply($message->{success}, 1, "check verify success of renaming back");

$message = submit_rename_accessions($sgn_session_id, $message->{archived_filename_with_path}, 1);

is_deeply($message->{success}, 1);

my $stock2 = CXGN::Stock->new( { schema => $f->bcs_schema(), uniquename => 'test_accession1' });

my $stock2_synonyms = $stock2->synonyms();

ok(any { $_ eq "test_accession100"} @$stock2_synonyms, "stock synonym test");


# Upload a file with errors
#
my $file = $f->config->{basepath}."/t/data/stock/renaming/accession_renaming_2.csv";

my $message = verify_rename_accessions($sgn_session_id, $file);

is_deeply($message->{success}, 0, "check verify success of bad file");

like($message->{error}, qr/do not exist/, "check the error message for the missing accession");
like($message->{error}, qr/target of renames/, "check the error message for the present ones that should not exist");




# clean up
#
$f->clean_up_db();

done_testing();


sub verify_rename_accessions {
    my $sgn_session_id = shift;
    my $file = shift;
    
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/rename_accessions/upload_verify',
        Content_Type => 'form-data',
        Content => [
            rename_accessions_uploaded_file => [ $file, 'rename_accessions_uploaded_file', Content_Type => 'text/html', ],
            sgn_session_id => $sgn_session_id,
        ]
	);
    
    print STDERR Dumper $response;
    ok($response->is_success);
    
    my $message = $response->decoded_content;
    print STDERR "MESSAGE: $message\n";
    my $message_hash = JSON::XS->new->decode($message);
    return $message_hash;
}

sub submit_rename_accessions {
    my $sgn_session_id = shift;
    my $file = shift;
    my $store_old_name_as_synonym = shift;
    
    my $store_old_name_as_synonym_url = "";
    if ($store_old_name_as_synonym) {
	$store_old_name_as_synonym_url = "&store_old_name_as_synonym=on";
    }
    else {
	$store_old_name_as_synonym_url = "&store_old_name_as_synonym=off";
    }
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
	"http://localhost:3010/ajax/rename_accessions/upload_store?archived_filename=$file&sgn_session_id=$sgn_session_id".$store_old_name_as_synonym_url);
    
    print STDERR Dumper $response;
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = JSON::XS->new()->decode($message);

    return $message_hash;

}
