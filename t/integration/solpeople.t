=head1 NAME

t/integration/solpeople.t - tests for solpeople URLs

=head1 DESCRIPTION

Tests for solpeople URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use Test::JSON;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->while_logged_in_all( sub {
    my ($user_info) = @_;
    $mech->get_ok('/solpeople/top-level.pl');
    $mech->content_contains('My SGN' );
    $mech->content_contains('[log out]');
    $mech->content_contains('BLAST Watch');
    $mech->content_contains('User Status');
    $mech->content_contains('General Tools');
    $mech->content_like(qr{Your current user status is\s+<b>$user_info->{user_type}</b>});
});

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

done_testing;
