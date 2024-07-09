package CXGN::File::Parse::Plugin::SSV;

use Moose;
use CXGN::File::Parse::Plugin::Plain;

sub type {
  return "ssv";
}

sub parse {
  my $self = shift;
  my $super = shift;
  return CXGN::File::Parse::Plugin::Plain->parse($super);
}

1;
