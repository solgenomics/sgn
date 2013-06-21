package SGN::View::Trial;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    design_view
/;
our @EXPORT = ();

sub design_view {
  my ($design_ref) = @_;
  my %design = %{$design_ref};
  my $design_result_html;
  my $header;
  $header = qq{<tr><th>Plot Name</th><th>Stock Name</th><th>Block Number</th><th>Rep Number</th></tr>};
  $design_result_html .= $header;
  foreach my $key (sort { $a <=> $b} keys %design) {
    $design_result_html .= "<tr><td>".$design{$key}->{plot_name} ."</td><td>".$design{$key}->{stock_name} ."</td><td>".$design{$key}->{block_number}."</td>";
    if ($design{$key}->{rep_number}) {
      $design_result_html .= "<td>".$design{$key}->{rep_number}."</td>";
    }
    $design_result_html .= "</tr>";
  }

  return  "$design_result_html";

}


######
1;
######
