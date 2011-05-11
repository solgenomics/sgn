use strict;
use warnings;

use IPC::Cmd qw/ can_run /;

use List::MoreUtils qw/ all /;
use Test::More;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::BlastDB;

use lib 't/lib';
use aliased 'SGN::Test::WWW::Mechanize';

my $mech = Mechanize->new;

my $new_page = "/tools/insilicopcr/index.pl";
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
		#database => $test_blastdb_id,
		program => 'blastn',
		expect => '1e-10',
		matrix => 'BLOSUM62',
		filterq => 'checked'
    }
    );

$mech->submit_form_ok(\%form, "PCR  job submit form" );

while ( $mech->content =~ /please wait/i && $mech->content !~ /PCR Results/i ) {
    sleep 1;
    $mech->get( $mech->base );
}

$mech->content_contains("PCR Results");
$mech->content_contains("Note:");
$mech->content_contains("PCR Report");
$mech->content_contains("BLAST OUTPUT");

unless ($mech->content() =~ /No PCR Product Found/){

    $mech->content_contains("Agarose");
    $mech->content_contains("SGN-U510886");
}

done_testing;
