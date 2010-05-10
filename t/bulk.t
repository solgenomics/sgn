

=head1 NAME 

bulk.t - a website-level test of the bulk download

=head1 DESCRIPTION

Tests the unigene bulk download. Needs to be expanded to the other downloads.

Currently gives a weird error at the end of a test on a line that does not exist in the test... ???? :-(

=head1 AUTHOR

Lukas Mueller

=cut

use strict;

use Test::More 'no_plan';
use Test::WWW::Mechanize;

my $b = Test::WWW::Mechanize->new();

die "Need to set the CXGN_SERVER environment variable" if (!defined($ENV{SGN_TEST_SERVER}));

$b->get_ok($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=unigene");

$b->content_contains("Download unigene information");

#my $form = $b->form_name('bulkform');

my %params = ( form_name => "bulkform",
	       fields    => {  
		   ids          => 'SGN-U444444
                                    SGN-U555555' ,
		       
		       
	       },
	       
    );

$b->submit_form_ok(\%params, "Form submit test");

$b->content_contains("Bulk download summary", "Result page title check");
$b->content_like(qr/The query you submitted contained .*2.*/, "Result check 1");
$b->content_like(qr/Your query resulted in .*2.* lines/, "Result check 2");


$b->submit_form_ok( \%params, "Submit unigene bulk download");

$b->content_like("Your query resulted in 3 lines being read from the database");

