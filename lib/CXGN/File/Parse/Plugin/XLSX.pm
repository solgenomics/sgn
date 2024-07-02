package CXGN::File::Parse::Plugin::XLSX;

use Moose;
use CXGN::File::Parse::Plugin::Excel;

sub type {
  return "xlsx";
}

sub parse {
  my $self = shift;
  my $super = shift;
  return CXGN::File::Parse::Plugin::Excel->parse($super);
}

1;
