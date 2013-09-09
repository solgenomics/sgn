package SGN::View::ArrayElements;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    array_elements_simple_view
/;
our @EXPORT = ();

sub array_elements_simple_view {
  my $array_ref = shift;
  my @elements = @{$array_ref};
  my $array_elements_simple_html;
  foreach my $element (@elements) {
    $array_elements_simple_html .= $element."<br>";
  }
  return $array_elements_simple_html;
}

######
1;
######
