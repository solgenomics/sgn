
=head1 NAME

bulk.t - a website-level test of the bulk download

=head1 DESCRIPTION

Tests the unigene bulk download. Needs to be expanded to the other downloads.

Currently gives a weird error at the end of a test on a line that does not exist in the test... ???? :-(

=head1 AUTHOR

Lukas Mueller

=cut

use strict;
use Test::More tests => 22;
use Test::WWW::Mechanize;
die "Need to set the CXGN_SERVER environment variable" if (!defined($ENV{SGN_TEST_SERVER}));

{
    my $b = Test::WWW::Mechanize->new;

    for my $input_type (qw/microarray clone_search bac bac_end ftp unigene_convert unigene/) { 
        $b->get_ok($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=$input_type");
    }

    $b->content_contains("Download unigene information");

    my $params = { 
               form_name => "bulkform",
               fields    => {  
                   ids          => 'SGN-U444444
                                    SGN-U555555' ,
               },
    };

    $b->submit_form_ok($params, "Submit to bulkform on input.pl");
    $b->content_contains("Bulk download summary", "Result page title check");
    $b->content_like(qr/The query you submitted contained .*2.*/, "input.pl returns correct data");
    $b->content_like(qr/Your query resulted in .*2.* lines/, "input.pl returns correct data");
}
{
    my $mech = Test::WWW::Mechanize->new;
    $mech->get_ok($ENV{SGN_TEST_SERVER}."/bulk/download.pl?idType=bac");
    $mech->content_contains("Bulk download error");
}
{
    my $mech = Test::WWW::Mechanize->new;
    $mech->get($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=bac");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   ids          => 'LE_HBa0033F11',
                   idType       => 'bac',
               },
    };
    $mech->submit_form_ok($params, "Submit to BAC bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = Test::WWW::Mechanize->new;
    $mech->get($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=clone_search");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   build_id     => 'all',
                   ids          => 'cLEB-1-A2', 
                   idType       => 'clone',
               },
    };
    $mech->submit_form_ok($params, "Submit to clone_search bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = Test::WWW::Mechanize->new;
    $mech->get($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=microarray");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   build_id     => 'all',
                   ids          => '1-1-1.2.3.4',
                   idType       => 'microarray',
               },
    };
    $mech->submit_form_ok($params, "Submit to microarray bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = Test::WWW::Mechanize->new;
    $mech->get($ENV{SGN_TEST_SERVER}."/bulk/input.pl?mode=bac_end");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   ids          => 'LE_HBa0011C24_SP6_121022', 
                   idType       => 'bac_end',
               },
    };
    $mech->submit_form_ok($params, "Submit to bac_end bulkform from input.pl");
    $mech->content_contains("download summary");
}
