=head1 NAME

t/integration/solpeople.t - tests for solpeople URLs

=head1 DESCRIPTION

Tests for solpeople URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More tests => 8;
use Test::JSON;
use Test::WWW::Mechanize;
use lib 't/lib';
use SGN::Test;

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = Test::WWW::Mechanize->new;

{
    my $url = "/solpeople/account-confirm.pl";
    $mech->get_ok("$base_url/$url?username=fiddlestix");
    $mech->content_like(qr/.*Sorry, we are unable to process this confirmation request\..*No confirmation is required for user .*fiddlestix/ms);
}

{
    my $url = "/solpeople/personal-info.pl";
    $mech->get_ok("$base_url/$url?action=edit&sp_person_id=42");
    $mech->content_like(qr/You do not have rights to modify this database entry because you do not own it/ms);
}

{
    my $url = "/solpeople/personal-info.pl";
    $mech->get_ok("$base_url/$url?action=store&sp_person_id=42");
    $mech->content_like(qr/You do not have rights to modify this database entry because you do not own it/ms);
}

{
    my $url = '/solpeople/login.pl';
    $mech->get_ok("$base_url/$url?logout=yes");
    $mech->content_like(qr/You have successfully logged out\. Thanks for using SGN\./ms);
}
