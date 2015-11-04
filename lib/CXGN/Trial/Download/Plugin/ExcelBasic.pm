package CXGN::Trial::Download::Plugin::ExcelBasic;

use Moose::Role;

sub verify { 
    my $self = shift;
    return 1;
}


sub download { 
    my $self = shift;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my @trait_list = @{$self->trait_list()};
    my $spreadsheet_metadata = $self->file_metadata();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );

    my $design = $trial_layout->get_design();

    if (! $design) {
	return "No design found for this trial.";
    }
	
    my %design = %{$trial_layout->get_design()};
    my @plot_names = @{$trial_layout->get_plot_names};

    my $workbook = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $workbook->add_worksheet();
	
    # generate worksheet headers
    #
    my $bold = $workbook->add_format();
    $bold->set_bold();

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    $ws->write(0, 0, 'Spreadsheet ID'); $ws->write('0', '1', 'ID'.$$.time());
    $ws->write(0, 2, 'Spreadsheet format'); $ws->write(0, 3, "BasicExcel");
    $ws->write(1, 0, 'Trial name'); $ws->write(1, 1, $trial->get_name(), $bold);
    $ws->write(2, 0, 'Description'); $ws->write(2, 1, $trial->get_description(), $bold);
    $ws->write(3, 0, "Trial location");  $ws->write(3, 1, $trial->get_location()->[1], $bold);
    $ws->write(1, 2, 'Operator');       $ws->write(1, 3, "Enter operator here");
    $ws->write(2, 2, 'Date');           $ws->write(2, 3, "Enter date here");
    $ws->data_validation(2,3, { validate => "date" });
    

    my @column_headers = qw | plot_name accession_name plot_number block_number is_a_control rep_number |;
    for(my $n=0; $n<@column_headers; $n++) { 
	$ws->write(5, $n, $column_headers[$n]);
    }
    my @ordered_plots = sort { $a <=> $b} keys(%design);
    for(my $n=0; $n<@ordered_plots; $n++) { 
	my %design_info = %{$design{$ordered_plots[$n]}};
	    
	$ws->write($n+6, 0, $design_info{plot_name});
	$ws->write($n+6, 1, $design_info{accession_name});
	$ws->write($n+6, 2, $design_info{plot_number});
	$ws->write($n+6, 3, $design_info{block_number});
	$ws->write($n+6, 4, $design_info{is_a_control});
	$ws->write($n+6, 5, $design_info{rep_number});
    }

    # write traits and format trait columns
    #
    my $lt = CXGN::List::Transform->new();
    
    my $transform = $lt->transform($schema, "traits_2_trait_ids", \@trait_list);

    if (@{$transform->{missing}}>0) { 
    	print STDERR "Warning: Some traits could not be found. ".join(",",@{$transform->{missing}})."\n";
    }
    my @trait_ids = @{$transform->{transform}};

    my %cvinfo = ();
    foreach my $t (@trait_ids) { 
	my $trait = CXGN::Trait->new( { bcs_schema=> $schema, cvterm_id => $t });
	$cvinfo{$trait->display_name()} = $trait;
	print STDERR "**** Trait = " . $trait->display_name . "\n\n";
    }
									       
    for (my $i = 0; $i < @trait_list; $i++) { 
	if (exists($cvinfo{$trait_list[$i]})) { 
	    $ws->write(5, $i+6, $cvinfo{$trait_list[$i]}->display_name());
	}
	else { 
	    print STDERR "Skipping output of trait $trait_list[$i] because it does not exist\n";
	    next;
	}
    
	my $plot_count = scalar(keys(%design));

	for (my $n = 0; $n < $plot_count; $n++) { 
	    my $format = $cvinfo{$trait_list[$i]}->format();
	    if ($format eq "numeric") { 
		$ws->data_validation($n+6, $i+6, { validate => "any" });
	    }
	    elsif ($format =~ /\,/) {  # is a list
		$ws->data_validation($n+6, $i+6, 
				     { 
					 validate => 'list',
					 value    => [ split ",", $format ]
				     });
	    }
	}
    }
    $workbook->close();
    
}
    
1;
