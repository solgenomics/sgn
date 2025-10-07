package CXGN::File::Parse::Plugin::XLS;

use Moose;
use CXGN::File::Parse::Plugin::Spreadsheet;

sub type {
  return "xls";
}

sub parse {
  my $self = shift;
  my $super = shift;
  return CXGN::File::Parse::Plugin::Spreadsheet->parse($super);
}

1;
