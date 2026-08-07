
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use File::Temp qw(tempfile);
use CXGN::Genotype::Protocol;
use Data::Dumper;
use JSON;

# This test checks the "update mismatched markers" VCF upload feature: when a
# marker name already exists in a stored protocol but its chrom/pos/ref/alt
# differ from the uploaded file, a curator can either leave the stored marker
# as-is (default) or ask that it be overwritten with the new marker info by
# checking "Update mismatched markers?" (upload_genotype_update_markers).

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_id = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'})->first->nd_geolocation_id;
my $breeding_program_id = $schema->resultset('Project::Project')->search({name => 'test'})->first->project_id;

my $original_file = $f->config->{basepath}."/t/data/genotype_data/testset_GT-AD-DP-GQ-DS-PL.vcf";

sub get_stored_marker {
    my ($protocol_id, $marker_name) = @_;
    my $protocol = CXGN::Genotype::Protocol->new({ bcs_schema => $schema, nd_protocol_id => $protocol_id });
    return $protocol->markers()->{$marker_name};
}

sub get_stored_marker_from_array {
    my ($protocol_id, $marker_name) = @_;
    my $protocol = CXGN::Genotype::Protocol->new({ bcs_schema => $schema, nd_protocol_id => $protocol_id });
    foreach my $m (@{$protocol->markers_array()}) {
        return $m if $m->{name} eq $marker_name;
    }
    return;
}

#Upload the file the first time to establish a protocol with marker S1_21594
#stored at chrom=1 pos=21594 ref=G alt=A.
my $ua = LWP::UserAgent->new;
my $upload_response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_vcf_file_input => [ $original_file, 'genotype_vcf_data_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_vcf_project_name"=>"Modify Markers Test Project A",
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2018",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"accession",
        "upload_genotype_vcf_facility_select"=>"IGD",
        "upload_genotype_vcf_project_description"=>"Modify markers test",
        "upload_genotype_vcf_protocol_name"=>"Modify Markers Test Protocol",
        "upload_genotype_vcf_include_igd_numbers"=>1,
        "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
        "upload_genotype_add_new_accessions"=>1,
    ]
);
sleep(20);
ok($upload_response->is_success, 'initial VCF upload request succeeded at the HTTP level');
my $message_hash = decode_json $upload_response->decoded_content;
print STDERR "post response message_hash\n";
diag(Dumper($message_hash));
is($message_hash->{success}, 1, 'initial upload stored successfully') or diag(Dumper($message_hash));
my $protocol_id = $message_hash->{nd_protocol_id};
diag(Dumper($protocol_id));
ok($protocol_id, 'got a protocol_id from the initial upload');

my $original_marker = get_stored_marker($protocol_id, 'S1_21594');
is($original_marker->{pos}, '21594', 'marker S1_21594 is initially stored with pos 21594');
is($original_marker->{ref}, 'G', 'marker S1_21594 is initially stored with ref G');
is($original_marker->{alt}, 'A', 'marker S1_21594 is initially stored with alt A');

#Build a modified copy of the VCF file where marker S1_21594 has a different
#pos/ref/alt than what is already stored in the protocol above, but keeps the
#same marker name, so that re-uploading it against the same protocol triggers
#the marker-mismatch comparison.
open(my $in_fh, '<', $original_file) or die "Cannot open $original_file: $!";
my @lines = <$in_fh>;
close($in_fh);
my $found_marker_line = 0;
foreach my $line (@lines) {
    if ($line =~ /^1\t21594\tS1_21594\tG\tA\t/) {
        $line =~ s/^1\t21594\tS1_21594\tG\tA\t/1\t21600\tS1_21594\tC\tT\t/;
        $found_marker_line = 1;
    }
}
ok($found_marker_line, 'found the S1_21594 marker line to modify in the source VCF');

my (undef, $modified_file) = tempfile(SUFFIX => '.vcf');
open(my $out_fh, '>', $modified_file) or die "Cannot open $modified_file: $!";
print $out_fh @lines;
close($out_fh);

#Re-upload the modified file against the same protocol, without accepting
#warnings and without requesting the mismatched marker be updated: expect a
#warning describing the mismatch, and the stored marker left unchanged.
$ua = LWP::UserAgent->new;
$upload_response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_vcf_file_input => [ $modified_file, 'genotype_vcf_data_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotype_protocol_id"=>$protocol_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_vcf_project_name"=>"Modify Markers Test Project B",
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2018",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"accession",
        "upload_genotype_vcf_facility_select"=>"IGD",
        "upload_genotype_vcf_project_description"=>"Modify markers test",
        "upload_genotype_vcf_include_igd_numbers"=>1,
        "upload_genotype_add_new_accessions"=>0,
    ]
);
sleep(20);
ok($upload_response->is_success, 'mismatched-marker upload request succeeded at the HTTP level');
$message_hash = decode_json $upload_response->decoded_content;
ok(!$message_hash->{success}, 'upload with a mismatched marker and no accept_warnings is not stored') or diag(Dumper($message_hash));
ok($message_hash->{warning}, 'a warning is returned describing the mismatched marker');
like($message_hash->{warning}, qr/Marker S1_21594 in your file has 21600 for pos, but in the previously stored protocol shows 21594/, 'warning describes the pos mismatch');
like($message_hash->{warning}, qr/Marker S1_21594 in your file has C for ref, but in the previously stored protocol shows G/, 'warning describes the ref mismatch');
like($message_hash->{warning}, qr/Marker S1_21594 in your file has T for alt, but in the previously stored protocol shows A/, 'warning describes the alt mismatch');
is($message_hash->{previous_genotypes_exist}, 1, 'previous_genotypes_exist is set since these accessions already have genotypes stored for this protocol');
is_deeply($message_hash->{mismatched_markers}, ['S1_21594'], 'mismatched_markers lists the one marker with differing info');

$original_marker = get_stored_marker($protocol_id, 'S1_21594');
is($original_marker->{pos}, '21594', 'marker S1_21594 is still stored with pos 21594 after the warning-only upload');
is($original_marker->{ref}, 'G', 'marker S1_21594 is still stored with ref G after the warning-only upload');
is($original_marker->{alt}, 'A', 'marker S1_21594 is still stored with alt A after the warning-only upload');

#Re-upload the same modified file, this time accepting warnings but still not
#requesting the mismatched marker be updated: the upload should succeed, but
#the stored marker info should still be left unchanged.
$ua = LWP::UserAgent->new;
$upload_response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_vcf_file_input => [ $modified_file, 'genotype_vcf_data_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotype_protocol_id"=>$protocol_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_vcf_project_name"=>"Modify Markers Test Project B",
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2018",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"accession",
        "upload_genotype_vcf_facility_select"=>"IGD",
        "upload_genotype_vcf_project_description"=>"Modify markers test",
        "upload_genotype_vcf_include_igd_numbers"=>1,
        "upload_genotype_add_new_accessions"=>0,
        "upload_genotype_accept_warnings"=>1,
    ]
);
sleep(20);
print STDERR "finished upload for protocol $protocol_id\n";
ok($upload_response->is_success, 'accepted-warnings upload request succeeded at the HTTP level');
$message_hash = decode_json $upload_response->decoded_content;
print STDERR "message_hash\n";
diag(Dumper($message_hash));
is($message_hash->{success}, 1, 'upload succeeds once warnings are accepted') or diag(Dumper($message_hash));
diag(Dumper($protocol_id));
ok($message_hash->{project_id}, 'got a project_id for the accepted-warnings upload');

$original_marker = get_stored_marker($protocol_id, 'S1_21594');
is($original_marker->{pos}, '21594', 'marker S1_21594 is still stored with pos 21594 after accepting warnings without requesting an update');
is($original_marker->{ref}, 'G', 'marker S1_21594 is still stored with ref G after accepting warnings without requesting an update');
is($original_marker->{alt}, 'A', 'marker S1_21594 is still stored with alt A after accepting warnings without requesting an update');

#Finally, re-upload the modified file again, this time also checking "Update
#mismatched markers?" (upload_genotype_update_markers): the upload should
#succeed and the stored marker info should now reflect the new file.
$ua = LWP::UserAgent->new;
$upload_response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_vcf_file_input => [ $modified_file, 'genotype_vcf_data_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotype_protocol_id"=>$protocol_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_vcf_project_name"=>"Modify Markers Test Project C",
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2018",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"accession",
        "upload_genotype_vcf_facility_select"=>"IGD",
        "upload_genotype_vcf_project_description"=>"Modify markers test",
        "upload_genotype_vcf_include_igd_numbers"=>1,
        "upload_genotype_add_new_accessions"=>0,
        "upload_genotype_accept_warnings"=>1,
        "upload_genotype_update_markers"=>1,
    ]
);
ok($upload_response->is_success, 'update-markers upload request succeeded at the HTTP level');
$message_hash = decode_json $upload_response->decoded_content;
is($message_hash->{success}, 1, 'upload succeeds when requesting the mismatched marker be updated') or diag(Dumper($message_hash));

my $updated_marker = get_stored_marker($protocol_id, 'S1_21594');
is($updated_marker->{pos}, '21600', 'marker S1_21594 pos is updated to 21600 after requesting an update');
is($updated_marker->{ref}, 'C', 'marker S1_21594 ref is updated to C after requesting an update');
is($updated_marker->{alt}, 'T', 'marker S1_21594 alt is updated to T after requesting an update');

my $updated_marker_in_array = get_stored_marker_from_array($protocol_id, 'S1_21594');
ok($updated_marker_in_array, 'marker S1_21594 is still present in the markers_array after the update');
is($updated_marker_in_array->{pos}, '21600', 'marker S1_21594 pos is updated to 21600 in the markers_array');
is($updated_marker_in_array->{ref}, 'C', 'marker S1_21594 ref is updated to C in the markers_array');
is($updated_marker_in_array->{alt}, 'T', 'marker S1_21594 alt is updated to T in the markers_array');

unlink $modified_file;

done_testing();
