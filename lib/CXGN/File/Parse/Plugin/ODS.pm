package CXGN::File::Parse::Plugin::ODS;

use Moose;
use CXGN::File::Parse::Plugin::Spreadsheet;

sub type {
  return "ods";
}

sub parse {
  my $self = shift;
  my $super = shift;
  return CXGN::File::Parse::Plugin::Spreadsheet->parse($super);
}

1;
