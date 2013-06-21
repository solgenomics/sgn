package SGN::View::Trial;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    design_view
/;
our @EXPORT = ();

sub design_view {
  my $design_ref = shift;
  my $design_info_ref = shift;
  my %design = %{$design_ref};
  my %design_info = %{$design_info_ref};
  my $design_result_html;

  $design_result_html .= "<dl>";
  if ($design_info{'number_of_stocks'}) {
    $design_result_html .= "<dt>Number of stocks</dt><dd>".$design_info{'number_of_stocks'}."</dd>";
  }
  if ($design_info{'number_of_controls'}) {
    $design_result_html .= "<dt>Number of controls</dt><dd>".$design_info{'number_of_controls'}."</dd>";
  }
  $design_result_html .= "</dl>";
  $design_result_html .= "<table>";
  $design_result_html .= qq{<tr><th>Plot Name</th><th>Stock Name</th><th>Block Number</th><th>Rep Number</th></tr>};
  foreach my $key (sort { $a <=> $b} keys %design) {
    $design_result_html .= "<tr><td>".$design{$key}->{plot_name} ."</td><td>".$design{$key}->{stock_name} ."</td><td>".$design{$key}->{block_number}."</td>";
    if ($design{$key}->{rep_number}) {
      $design_result_html .= "<td>".$design{$key}->{rep_number}."</td>";
    }
    $design_result_html .= "</tr>";
  }
  $design_result_html .= "</table>";
  return  "$design_result_html";

}


######
1;
######
