#!/usr/bin/perl
use strict;
use warnings;

use List::AllUtils 'uniq';

use Test::More;
use lib 't/lib';

use SGN::Test::WWW::Mechanize;
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok( '/' );
$mech->html_lint_ok;
$mech->dbh_leak_ok;

# test for any broken images or other things that have a
# src attr
{ my @stuff = grep !m|^https?://|, uniq map $_->attr('src'), $mech->findnodes('//*[@src]');
  get_ok( $mech, $_ ) for @stuff;
}

$mech->get_ok( '/' );

# test for any broken local links
{
    my @links = grep !m"^(https?|mailto):", uniq map $_->attr('href'), $mech->findnodes('//a[@href]');

    get_ok( $mech, $_ ) for @links;
}

done_testing;

sub get_ok {
    my ( $mech, $url ) = @_;

    local $TODO = $url =~ m!^/gbrowse/! ? 'gbrowse not installed on all development machines' : undef;
    diag "visiting $_";
    $mech->get_ok( $_ );
    $mech->back;
}
