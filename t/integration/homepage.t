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
  for( @stuff ) {
      $mech->get_ok( $_ );
      $mech->back;
  }
}

$mech->get_ok( '/' );

# test for any broken local links
{ my @links = grep !m|^https?://|, uniq map $_->attr('href'), $mech->findnodes('//a[@href]');
  for( @links ) {
      $mech->get_ok( $_ );
      $mech->back;
  }
}



done_testing;
