package Bio::Graphics::Browser2::Plugin::test;
# $Id: test.pm,v 1.1 2002-03-25 05:31:45 lstein Exp $
# test plugin
use strict;
use Bio::Graphics::Browser2::Plugin;
use CGI qw(param url header p);

use vars '$VERSION','@ISA';
$VERSION = '0.10';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Test" }
sub description {
  p("This is the Test plugin, used to test that the dump architecture is working properly.");
}
sub dump {
  my $self = shift;
  my $segment = shift;
  print header('text/plain');
  my $dna = $segment->dna;
  $dna =~ s/(.{1,60})/$1\n/g;
  print ">$segment\n";
  print $dna;
}

1;
