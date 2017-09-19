package SGN::View::Trial;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    design_layout_view
    design_info_view
    trial_detail_design_view
/;
our @EXPORT = ();

sub trial_detail_design_view {
  my $design_ref = shift;
  my %design = %{$design_ref};
  my $design_result_html;

  $design_result_html .= '<table border="1">';
  $design_result_html .= qq{<tr><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th></tr>};

  foreach my $key (sort { $a <=> $b} keys %design) {
      $design_result_html .= "<tr>";
      if ($design{$key}->{plot_name}) {
	  $design_result_html .= "<td>".$design{$key}->{plot_name}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{accession_name}) {
	  $design_result_html .= "<td>".$design{$key}->{accession_name}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{check_name}) {
	  $design_result_html .= "<td>".$design{$key}->{check_name}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{row_number}) {
	  $design_result_html .= "<td>".$design{$key}->{row_number}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{col_number}) {
	  $design_result_html .= "<td>".$design{$key}->{col_number}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{block_number}) {
	  $design_result_html .= "<td>".$design{$key}->{block_number}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{block_row_number}) {
	  $design_result_html .= "<td>".$design{$key}->{block_row_number}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{block_col_number}) {
	  $design_result_html .= "<td>".$design{$key}->{block_col_number}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      if ($design{key}->{rep_number}) {
	  $design_result_html .= "<td>".$design{$key}->{rep_number}."</td>";
      } else {
	  $design_result_html .= "<td></td>";
      }
      $design_result_html .= "</tr>";
  }
  $design_result_html .= "</table>";
  return  "$design_result_html";

}


sub design_layout_view {
    my $design_ref = shift;
    my $design_info_ref = shift;
    my $design_level = shift;
    my %design = %{$design_ref};
    my %design_info = %{$design_info_ref};
    my $design_result_html;

    $design_result_html .= '<table border="1">';

    if ($design_level eq 'plants') {
        $design_result_html .= qq{<tr><th>Plant Name</th><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th></tr>};
    } elsif ($design_level eq 'subplots') {
        $design_result_html .= qq{<tr><th>Plant Name</th><th>Subplot Name</th><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th></tr>};
    } else {
        $design_result_html .= qq{<tr><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th></tr>};
    }

    foreach my $key (sort { $a <=> $b} keys %design) {
        my $plot_name = $design{$key}->{plot_name} || '';
        my $stock_name = $design{$key}->{stock_name} || '';
        my $check_name = $design{$key}->{is_a_control} || '';
        my $row_number = $design{$key}->{row_number} || '';
        my $col_number = $design{$key}->{col_number} || '';
        my $block_number = $design{$key}->{block_number} || '';
        my $block_row_number = $design{$key}->{block_row_number} || '';
        my $block_col_number = $design{$key}->{block_col_number} || '';
        my $rep_number = $design{$key}->{rep_number} || '';
        my $plot_number = $key;

        if ($design{$key}->{subplots_plant_names}) {
            foreach my $subplot_name (sort keys %{$design{$key}->{subplots_plant_names}}) {
                my $plant_names = $design{$key}->{subplots_plant_names}->{$subplot_name};
                foreach my $plant_name (@$plant_names){
                    $design_result_html .= "<tr><td>".$plant_name."</td><td>".$subplot_name."</td><td>".$plot_name."</td><td>".$stock_name."</td><td>".$check_name."</td><td>".$plot_number."</td><td>".$row_number."</td><td>".$col_number."</td><td>".$block_number."</td><td>".$block_row_number."</td><td>".$block_col_number."</td><td>".$rep_number."</td></tr>";
                }
            }
        } elsif ($design{$key}->{plant_names}) {
            foreach my $plant_name (@{$design{$key}->{plant_names}}) {
                $design_result_html .= "<tr><td>".$plant_name."</td><td>".$plot_name."</td><td>".$stock_name."</td><td>".$check_name."</td><td>".$plot_number."</td><td>".$row_number."</td><td>".$col_number."</td><td>".$block_number."</td><td>".$block_row_number."</td><td>".$block_col_number."</td><td>".$rep_number."</td></tr>";
            }
        } else {
            $design_result_html .= "<tr><td>".$plot_name."</td><td>".$stock_name."</td><td>".$check_name."</td><td>".$plot_number."</td><td>".$row_number."</td><td>".$col_number."</td><td>".$block_number."</td><td>".$block_row_number."</td><td>".$block_col_number."</td><td>".$rep_number."</td></tr>";
        }
    }

    $design_result_html .= "</table>";
    return  "$design_result_html";
}

sub design_info_view {
  my $design_ref = shift;
  my $design_info_ref = shift;
  my %design = %{$design_ref};
  my %design_info = %{$design_info_ref};
  my %block_hash;
  my %rep_hash;
  my $design_info_html;
  my $design_description;


  $design_info_html .= "<dl>";

  if ($design_info{'design_type'}) {
    $design_description = $design_info{'design_type'};
    if ($design_info{'design_type'} eq "CRD") {
      $design_description = "Completely Randomized Design";
    }
    if ($design_info{'design_type'} eq "RCBD") {
      $design_description = "Randomized Complete Block Design";
    }
    if ($design_info{'design_type'} eq "Alpha") {
      $design_description = "Alpha Lattice Incomplete Block Design";
    }
    if ($design_info{'design_type'} eq "Augmented") {
      $design_description = "Augmented Incomplete Block Design";
    }
    if ($design_info{'design_type'} eq "MAD") {
      $design_description = "Modified Augmented Design";
    }
    if ($design_info{'design_type'} eq "greenhouse") {
      $design_description = "Greenhouse Design";
    }
#    if ($design_info{'design_type'} eq "MADII") {
#      $design_description = "Modified Augmented Design II";
#    }
#    if ($design_info{'design_type'} eq "MADIII") {
#      $design_description = "Modified Augmented Design III";
#    }
#    if ($design_info{'design_type'} eq "MADIV") {
#      $design_description = "Modified Augmented Design IV";
#    }
    $design_info_html .= "<dt>Design type</dt><dd>".$design_description."</dd>";
  }
  if ($design_info{'number_of_locations'}) {
    $design_info_html .= "<dt>Number of locations</dt><dd>".$design_info{'number_of_locations'}."</dd>";
  }
  if ($design_info{'number_of_stocks'}) {
    $design_info_html .= "<dt>Number of accessions</dt><dd>".$design_info{'number_of_stocks'}."</dd>";
  }
  if ($design_info{'number_of_checks'}) {
    $design_info_html .= "<dt>Number of checks</dt><dd>".$design_info{'number_of_checks'}."</dd>";
  }
  if ($design_info{'number_of_controls'}) {
    $design_info_html .= "<dt>Number of controls</dt><dd>".$design_info{'number_of_controls'}."</dd>";
  }

  my $treatment_info_string = "";
  foreach my $key (sort { $a <=> $b} keys %design) {
    my $current_block_number = $design{$key}->{block_number};
    my $current_rep_number;
    if ($current_block_number) {
        if ($block_hash{$current_block_number}) {
          $block_hash{$current_block_number} += 1;
        } else {
          $block_hash{$current_block_number} = 1;
        }
    }
    if ($design{$key}->{rep_number}) {
      $current_rep_number = $design{$key}->{rep_number};
      if ($rep_hash{$current_rep_number}) {
	$rep_hash{$current_rep_number} += 1;
      } else {
	$rep_hash{$current_rep_number} = 1;
      }
    }

    if($key eq 'treatments'){
        while(my($k,$v) = each %{$design{$key}}){
            my $treatment_units = join ',', @{$v};
            $treatment_info_string .= "<b>$k:</b> $treatment_units<br/>";
        }
    }
  }

  if (%block_hash) {
    $design_info_html .= "<dt>Number of blocks</dt><dd>".scalar(keys %block_hash)."</dd>";
    $design_info_html .= "<dt>Number of accessions per block</dt><dd>";
    foreach my $key (sort { $a <=> $b} keys %block_hash) {
      $design_info_html .= "Block ".$key.": ".$block_hash{$key}." accessions <br>";
    }
    $design_info_html .= "</dt>";
  }


  if (%rep_hash) {
    $design_info_html .= "<dt>Number of reps</dt><dd>".scalar(keys %rep_hash)."</dd>";
  }

  $design_info_html .= "<dt>Treatments:</dt><dd><div id='trial_design_confirm_treatments' >$treatment_info_string</div></dd>";

  $design_info_html .= "</dl>";

  return $design_info_html;

}


######
1;
######
