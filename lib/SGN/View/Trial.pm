package SGN::View::Trial;
use base 'Exporter';
use List::MoreUtils ':all';
use Data::Dumper;
use strict;
use warnings;

our @EXPORT_OK = qw/
    design_layout_view
    design_info_view
    trial_detail_design_view
    design_layout_map_view
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

sub design_layout_map_view {
    my $design_ref = shift;
    my $design_type = shift;
    my $result;
    my %design = %{$design_ref};
    my @layout_info;
    my @row_numbers = ();
    my @col_numbers = ();
    my @rep_numbers = ();
    my @block_numbers = ();
    my @check_names = ();

    foreach my $key (sort { $a <=> $b} keys %design) {
        my $plot_name = $design{$key}->{plot_name} || '';
        my $stock_name = $design{$key}->{stock_name} || '';
        my $check_name = $design{$key}->{is_a_control} || '';
        my $row_number = $design{$key}->{row_number} || '';
        my $col_number = $design{$key}->{col_number} || '';
        my $block_number = $design{$key}->{block_number} || '';
        my $rep_number = $design{$key}->{rep_number} || '';
        my $plot_number = $key;

        if ($col_number) {
            push @col_numbers, $col_number;
        }
        if ($row_number) {
            push @row_numbers, $row_number;
        }elsif (!$row_number){
			if ($block_number && $design_type ne 'splitplot'){
				$row_number = $block_number;
				push @row_numbers, $row_number;
			}elsif ($rep_number && !$block_number && $design_type ne 'splitplot'){
				$row_number = $rep_number;
				push @row_numbers, $row_number;
			}elsif ($design_type eq 'splitplot'){
                $row_number = $rep_number;
				push @row_numbers, $row_number;
            }
		}
        if ($rep_number) {
            push @rep_numbers, $rep_number;
        }
        if ($block_number) {
            push @block_numbers, $block_number;
        }
        if ($check_name){
            push @check_names, $stock_name;
        }

        push @layout_info, {
            plot_number => $plot_number,
            row_number => $row_number,
            col_number => $col_number,
            block_number=> $block_number,
            rep_number =>  $rep_number,
            plot_name => $plot_name,
            accession_name => $stock_name,
        };
    }

    @layout_info = sort { $a->{plot_number} <=> $b->{plot_number}} @layout_info;
    my $false_coord;
	if (scalar(@col_numbers) < 1){
        @col_numbers = ();
        $false_coord = 'false_coord';
		my @row_instances = uniq @row_numbers;
		my %unique_row_counts;
		$unique_row_counts{$_}++ for @row_numbers;
        my @col_number2;
        for my $key (keys %unique_row_counts){
            push @col_number2, (1..$unique_row_counts{$key});
        }
        for (my $i=0; $i < scalar(@layout_info); $i++){
			$layout_info[$i]->{'col_number'} = $col_number2[$i];
            push @col_numbers, $col_number2[$i];
        }
	}

    my $plot_popUp;
	foreach my $hash (@layout_info){
		$plot_popUp = $hash->{'plot_name'}."\nplot_No:".$hash->{'plot_number'}."\nblock_No:".$hash->{'block_number'}."\nrep_No:".$hash->{'rep_number'}."\nstock:".$hash->{'accession_name'};
        push @$result,  {plotname => $hash->{'plot_name'}, stock => $hash->{'accession_name'}, plotn => $hash->{'plot_number'}, blkn=>$hash->{'block_number'}, rep=>$hash->{'rep_number'}, row=>$hash->{'row_number'}, col=>$hash->{'col_number'}, plot_msg=>$plot_popUp} ;
    }

    my @sorted_block = sort@block_numbers;
	my @uniq_block = uniq(@sorted_block);
    @check_names = uniq(@check_names);
    #print STDERR Dumper(\@check_names);
	my ($min_rep, $max_rep) = minmax @rep_numbers;
	my ($min_block, $max_block) = minmax @block_numbers;
	my ($min_col, $max_col) = minmax @col_numbers;
	my ($min_row, $max_row) = minmax @row_numbers;
	my (@unique_col,@unique_row);
	for my $x (1..$max_col){
		push @unique_col, $x;
	}
	for my $y (1..$max_row){
		push @unique_row, $y;
	}

    my %return = (
		coord_row =>  \@row_numbers,
		coord_col =>  \@col_numbers,
		max_row => $max_row,
		max_col => $max_col,
		max_rep => $max_rep,
		max_block => $max_block,
		controls => \@check_names,
		unique_col => \@unique_col,
		unique_row => \@unique_row,
		false_coord => $false_coord,
		result => $result,
	);

    return  \%return;
}

#For printing the table view of the generated design, splitplot design is different from the others:
# The splitplot generates plots, subplots, and plant entries, so the table should reflect that.

sub design_layout_view {
    my $design_ref = shift;
    my $design_info_ref = shift;
    my $design_type = shift;
    my $trial_stock_type = shift;
    my %design = %{$design_ref};
    my %design_info = %{$design_info_ref};
    my $design_result_html;

    $design_result_html .= '<table class="table table-bordered table-hover">';

    if ($trial_stock_type eq 'family_name') {
        if ($design_type eq 'greenhouse') {
            $design_result_html .= qq{<tr><th>Plant Name</th><th>Plot Name</th><th>Family Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        } elsif ($design_type eq 'splitplot') {
            $design_result_html .= qq{<tr><th>Plant Name</th><th>Subplot Name</th><th>Plot Name</th><th>Family Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        } else {
            $design_result_html .= qq{<tr><th>Plot Name</th><th>Family Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        }
    } elsif ($trial_stock_type eq 'cross') {
        if ($design_type eq 'greenhouse') {
            $design_result_html .= qq{<tr><th>Plant Name</th><th>Plot Name</th><th>Cross Unique ID</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        } elsif ($design_type eq 'splitplot') {
            $design_result_html .= qq{<tr><th>Plant Name</th><th>Subplot Name</th><th>Plot Name</th><th>Cross Unique ID</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        } else {
            $design_result_html .= qq{<tr><th>Plot Name</th><th>Cross Unique ID</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        }
    } else {
        if ($design_type eq 'greenhouse') {
            $design_result_html .= qq{<tr><th>Plant Name</th><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        } elsif ($design_type eq 'splitplot') {
            $design_result_html .= qq{<tr><th>Plant Name</th><th>Subplot Name</th><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        } else {
            $design_result_html .= qq{<tr><th>Plot Name</th><th>Accession Name</th><th>Check Name</th><th>Plot Number</th><th>Row number</th><th>Col number</th><th>Block Number</th><th>Block Row Number</th><th>Block Col Number</th><th>Rep Number</th><th>Seedlot Name</th><th>Num Seeds Per Plot</th></tr>};
        }
    }

    foreach my $key (sort { $a <=> $b} keys %design) {
        if ($key eq 'treatments'){
            next;
        }
        my $plot_name = $design{$key}->{plot_name} || '';
        my $stock_name = $design{$key}->{stock_name} || '';
        my $seedlot_name = $design{$key}->{seedlot_name} || '';
        my $num_seed_per_plot = $design{$key}->{num_seed_per_plot} || '';
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
                    $design_result_html .= "<tr><td>".$plant_name."</td><td>".$subplot_name."</td><td>".$plot_name."</td><td>".$stock_name."</td><td>".$check_name."</td><td>".$plot_number."</td><td>".$row_number."</td><td>".$col_number."</td><td>".$block_number."</td><td>".$block_row_number."</td><td>".$block_col_number."</td><td>".$rep_number."</td><td>".$seedlot_name."</td><td>".$num_seed_per_plot."</td></tr>";
                }
            }
        } elsif ($design{$key}->{plant_names}) {
            foreach my $plant_name (@{$design{$key}->{plant_names}}) {
                $design_result_html .= "<tr><td>".$plant_name."</td><td>".$plot_name."</td><td>".$stock_name."</td><td>".$check_name."</td><td>".$plot_number."</td><td>".$row_number."</td><td>".$col_number."</td><td>".$block_number."</td><td>".$block_row_number."</td><td>".$block_col_number."</td><td>".$rep_number."</td><td>".$seedlot_name."</td><td>".$num_seed_per_plot."</td></tr>";
            }
        } else {
            $design_result_html .= "<tr><td>".$plot_name."</td><td>".$stock_name."</td><td>".$check_name."</td><td>".$plot_number."</td><td>".$row_number."</td><td>".$col_number."</td><td>".$block_number."</td><td>".$block_row_number."</td><td>".$block_col_number."</td><td>".$rep_number."</td><td>".$seedlot_name."</td><td>".$num_seed_per_plot."</td></tr>";
        }
    }

    $design_result_html .= "</table>";
    return  "$design_result_html";
}

sub design_info_view { #TODO: fix treatments here
    my $design_ref = shift;
    my $design_info_ref = shift;
    my $trial_stock_type = shift;
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
        if ($trial_stock_type eq 'family_name') {
            $design_info_html .= "<dt>Number of family names</dt><dd>".$design_info{'number_of_stocks'}."</dd>";
        } elsif ($trial_stock_type eq 'cross') {
            $design_info_html .= "<dt>Number of cross unique ids</dt><dd>".$design_info{'number_of_stocks'}."</dd>";
        } else {
            $design_info_html .= "<dt>Number of accessions</dt><dd>".$design_info{'number_of_stocks'}."</dd>";
        }
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
        if ($trial_stock_type eq 'family_name') {
            $design_info_html .= "<dt>Number of family names per block</dt><dd>";
            foreach my $key (sort { $a <=> $b} keys %block_hash) {
                $design_info_html .= "Block ".$key.": ".$block_hash{$key}." family names <br>";
            }
        } elsif ($trial_stock_type eq 'cross') {
            $design_info_html .= "<dt>Number of cross unique ids per block</dt><dd>";
            foreach my $key (sort { $a <=> $b} keys %block_hash) {
                $design_info_html .= "Block ".$key.": ".$block_hash{$key}." cross unique ids <br>";
            }
        } else {
            $design_info_html .= "<dt>Number of accessions per block</dt><dd>";
            foreach my $key (sort { $a <=> $b} keys %block_hash) {
                $design_info_html .= "Block ".$key.": ".$block_hash{$key}." accessions <br>";
            }
        }
        $design_info_html .= "</dt>";
    }


    if (%rep_hash) {
        $design_info_html .= "<dt>Number of reps</dt><dd>".scalar(keys %rep_hash)."</dd>";
    }

    if ($treatment_info_string) {
        $design_info_html .= "<dt>Treatments:</dt><dd><div id='trial_design_confirm_treatments' >$treatment_info_string</div></dd>";
    } else {
        $design_info_html .= "<dt>Treatments:</dt><dd><div id='trial_design_confirm_treatments' >None added. Treatments and management regimes can be added on the trial detail page.</div></dd>";
    }

    

    $design_info_html .= "</dl>";

    return $design_info_html;

}


######
1;
######
