use strict;
use warnings;

use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

my $stock_id = $schema->resultset("Stock::Stock")->find({ uniquename => 'UG120180' })->stock_id();
my $protocol_id = $schema->resultset("NaturalDiversity::NdProtocol")->find({ name => 'GBS ApeKI genotyping v4' })->nd_protocol_id();

# follow the download link from the genotype table on the stock page
$mech->get_ok('http://localhost:3010/stock/'.$stock_id.'/datatables/genotype_data');
my $response = decode_json $mech->content;
# pick the row for this protocol by name (column 2), rather than assuming row order,
# so this test does not depend on what other genotype protocols earlier tests left behind
my ($row) = grep { $_->[2] eq 'GBS ApeKI genotyping v4' } @{$response->{data}};
ok($row, 'genotype table has a row for the GBS ApeKI genotyping v4 protocol')
    or diag(explain($response->{data}));
my ($download_link) = $row->[4] =~ /href="([^"]+)"/;
like($download_link, qr/^\/stock\/$stock_id\/genotypes\?genotype_id=\d+$/, 'genotype table has a download link');
my ($genotype_id) = $download_link =~ /genotype_id=(\d+)/;

$mech->get_ok('http://localhost:3010'.$download_link, 'download genotypes from the stock page');
my $vcf = $mech->content;
like($vcf, qr/^##Genotyping protocol id\(s\)=$protocol_id$/m, 'VCF header has the genotyping protocol id');
like($vcf, qr/^##Genotyping protocol name\(s\)=GBS ApeKI genotyping v4$/m, 'VCF header has the genotyping protocol name');
like($vcf, qr/^#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tUG120180/m, 'VCF has the stock genotype column');

# genotype_id must be numeric
$mech->get('http://localhost:3010/stock/'.$stock_id.'/genotypes?genotype_id=abc');
is($mech->status, 200, 'non-numeric genotype_id does not cause a server error');
$mech->content_contains('missing an associated genotype id', 'non-numeric genotype_id gets the missing genotype id message');

# a trailing newline or a non-ASCII decimal digit must not slip past the numeric check either
# (both reach a SQL bound parameter and give a 500 if they do)
$mech->get('http://localhost:3010/stock/'.$stock_id.'/genotypes?genotype_id='.$genotype_id.'%0A');
is($mech->status, 200, 'a trailing newline on genotype_id does not cause a server error');
$mech->content_contains('missing an associated genotype id', 'a trailing newline on genotype_id gets the missing genotype id message');

$mech->get('http://localhost:3010/stock/'.$stock_id.'/genotypes?genotype_id=%D9%A1'); # Arabic-Indic digit one, \d{Nd} but not [0-9]
is($mech->status, 200, 'a non-ASCII decimal digit does not cause a server error');
$mech->content_contains('missing an associated genotype id', 'a non-ASCII decimal digit gets the missing genotype id message');

done_testing();
