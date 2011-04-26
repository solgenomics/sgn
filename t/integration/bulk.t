
=head1 NAME

bulk.t - a website-level test of the bulk download

=head1 DESCRIPTION

Tests all bulk download.

=head1 AUTHORS

Lukas Mueller, Jonathan "Duke" Leto

=cut

use Modern::Perl;
use Test::More tests => 26;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    for my $input_type (qw/microarray clone_search bac bac_end ftp unigene_convert unigene/) {
        $mech->get_ok("/bulk/input.pl?mode=$input_type");
    }

    $mech->content_contains("Download unigene information");

    my $params = {
               form_name => "bulkform",
               fields    => {
                   ids          => 'SGN-U444444
                                    SGN-U555555' ,
               },
    };

    $mech->submit_form_ok($params, "Submit to bulkform on input.pl");
    $mech->content_contains("Bulk download summary", "Result page title check");
    $mech->content_like(qr/The query you submitted contained .*2.*/, "input.pl returns correct data");
    $mech->content_like(qr/Your query resulted in .*2.* lines/, "input.pl returns correct data");
}
{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get_ok("/bulk/download.pl?idType=bac");
    $mech->content_contains("Bulk download error");
}
{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get("/bulk/input.pl?mode=unigene");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   ids          => "SGN-U444444\nSGN-U555555\n",
                   seq_mode => "longest6frame_seq",
               },
    };
    $mech->submit_form_ok($params, "Submit to Unigene bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get("/bulk/input.pl?mode=bac");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   ids          => 'LE_HBa0033F11',
               },
    };
    $mech->submit_form_ok($params, "Submit to BAC bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get("/bulk/input.pl?mode=clone_search");
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
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get("/bulk/input.pl?mode=microarray");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   build_id     => 'all',
                   ids          => '1-1-1.2.3.4',
               },
    };
    $mech->submit_form_ok($params, "Submit to microarray bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get("/bulk/input.pl?mode=bac_end");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   ids          => 'LE_HBa0011C24_SP6_121022',
               },
    };
    $mech->submit_form_ok($params, "Submit to bac_end bulkform from input.pl");
    $mech->content_contains("download summary");
}
{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get("/bulk/input.pl?mode=unigene_convert");
    my $params =  {
               form_name => "bulkform",
               fields    => {
                   ids          => 'SGN-U268057',
               },
    };
    $mech->submit_form_ok($params, "Submit to unigene_convert bulkform from input.pl");
    $mech->content_contains("download summary");
}
