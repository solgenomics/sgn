use strict;
use warnings;
use Carp;

use File::Spec;
use IPC::Cmd qw/ can_run /;


use Test::More;
use Test::WWW::Mechanize;

use CXGN::DB::Connection;
use CXGN::Page;

unless( can_run('qsub') ) {
    plan skip_all => 'qsub not found in path';
} else {
    plan tests => 4;
}

my $mech = Test::WWW::Mechanize->new;
#my $server = $ENV{SGN_TEST_SERVER}|| "http://sgn-devel.sgn.cornell.edu";
my $server = $ENV{SGN_TEST_SERVER}|| "http://sgn.localhost.localdomain";
diag "Using server $ENV{SGN_TEST_SERVER}\n";

my $new_page = $server."/tools/insilicopcr/index.pl";
$mech->get_ok($new_page);
$mech->content_contains("In Silico PCR");
$mech->content_contains("PCR Primers");
$mech->content_contains("Forward Primer");
$mech->content_contains("Reverse Primer");
$mech->content_contains("Product Maximum Length");
$mech->content_contains("Allowed Mismatches");
$mech->content_contains("BLAST Attributes");
$mech->content_contains("Database");
$mech->content_contains("BLAST Program");
$mech->content_contains("Expectation value");
$mech->content_contains("Substitution Matrix");
$mech->content_contains("Filter query sequence");


my %form = (
    form_name => 'PCRform',
    fields => { fprimer => 'GGCGAGCCTTTAAATTAAAGGATCCCTTTGGAATAAAAAG',
		rprimer => 'TGGCCCTTTTCCCTATTAAGAATTCCATCAGAAAGTTATTC',
		productLength => '5000',
		allowedMismatches => '0',
		output_format => '8',
		database => 34,
		program => 'blastn',
		expect => '1e-10',
		matrix => 'BLOSUM62',
		filterq => 'checked'
    }
    );
    

$mech->submit_form_ok(\%form, "PCR  job submit form" );
$mech->content_contains("Running");

print STDERR "Waiting";

while ($mech->content() != /PCR Results/) { 
    print STDERR ".\n";
    $mech->reload();	
    sleep(3);    

}

$mech->content_contains("PCR Results");
$mech->content_contains("Note:");
$mech->content_contains("PCR Report");
$mech->content_contains("BLAST OUTPUT");

unless ($mech->content()=~/No PCR Product Found/){

    $mech->content_contains("Agarose");
    $mech->content_contains("SGN-U510886");
}
