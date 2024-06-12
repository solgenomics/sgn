package CXGN::File::Parse::Plugin::XLS;

use Moose;
use CXGN::File::Parse::Plugin::Excel;

sub type {
  return "xls";
}

sub parse {
  my $self = shift;
  my $file = shift;
  my $type = shift;
  return CXGN::File::Parse::Plugin::Excel->parse($file, $type);
}

1;
