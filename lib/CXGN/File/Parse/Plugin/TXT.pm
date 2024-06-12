package CXGN::File::Parse::Plugin::TXT;

use Moose;
use CXGN::File::Parse::Plugin::Plain;

sub type {
  return "txt";
}

sub parse {
  my $self = shift;
  my $file = shift;
  my $type = shift;
  return CXGN::File::Parse::Plugin::Plain->parse($file, $type);
}

1;
