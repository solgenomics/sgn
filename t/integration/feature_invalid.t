=head1 NAME

t/integration/feature_invalid.t - integration tests for invalid feature URLs

=head1 DESCRIPTION

Tests for feature URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("/feature/view/name/JUNK.fasta");
$mech->content_contains("feature with name = 'JUNK' not found");

$mech->get_ok("/feature/view/id/-1.fasta");
$mech->content_contains("feature with feature_id = '-1' not found");

$mech->get_ok("/feature/view/name/JUNK");
$mech->content_contains("feature with name = 'JUNK' not found");

$mech->get_ok("/feature/view/id/-1");
$mech->content_contains("feature with feature_id = '-1' not found");

$mech->get_ok("/feature/view/id/JUNK.fasta");
$mech->content_contains("JUNK is not a valid value for feature_id");

$mech->get_ok("/feature/view/id/JUNK");
$mech->content_contains("JUNK is not a valid value for feature_id");

done_testing;
