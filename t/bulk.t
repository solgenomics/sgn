

=head1 NAME 

bulk.t - a website-level test of the bulk download

=head1 DESCRIPTION

Tests the unigene bulk download. Needs to be expanded to the other downloads.

Currently gives a weird error at the end of a test on a line that does not exist in the test... ???? :-(

=head1 AUTHOR

Lukas Mueller

=cut

use strict;
use Test::More tests => 12;
use Test::WWW::Mechanize;

my $b = Test::WWW::Mechanize->new;

die "Need to set the CXGN_SERVER environment variable" if (!defined($ENV{SGN_TEST_SERVER}));

for my $input_type (qw/microarray clone_search bac bac_end ftp unigene_convert unigene/) { 
    $b->get_ok($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=$input_type");
}

$b->content_contains("Download unigene information");

my %params = ( 
           form_name => "bulkform",
	       fields    => {  
               ids          => 'SGN-U444444
                                SGN-U555555' ,
	       },
    );

$b->submit_form_ok(\%params, "Form submit test");
$b->content_contains("Bulk download summary", "Result page title check");
$b->content_like(qr/The query you submitted contained .*2.*/, "Result check 1");
$b->content_like(qr/Your query resulted in .*2.* lines/, "Result check 2");

