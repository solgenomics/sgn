package CXGN::File::Parse::Plugin::ODS;

use Moose;
use CXGN::File::Parse::Plugin::OpenDocument;

sub type {
  return "ods";
}

sub parse {
  my $self = shift;
  my $super = shift;
  return CXGN::File::Parse::Plugin::OpenDocument->parse($super);
}

1;
