=head1 NAME

t/integration/solpeople/sequencer.t - tests for sequencer users on solpeople URLs

=head1 DESCRIPTION

Tests for sequencer user_types on solpeople URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More tests => 12;
use Test::JSON;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->while_logged_in({ user_type => 'sequencer' }, sub {
    $mech->get_ok('/solpeople/attribute_bacs.pl');
    $mech->content_contains('How to attribute a BAC to a sequencing project');

    $mech->get_ok('/maps/physical/clone_reg.pl');
    $mech->content_contains('BAC Registry Viewer/Editor');

    $mech->get_ok('/maps/physical/clone_il_view.pl');
    $mech->content_contains('Clone IL Mapping Assignments');
});
