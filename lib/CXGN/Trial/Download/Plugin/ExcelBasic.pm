package CXGN::Trial::Download::Plugin::ExcelBasic;

use Moose::Role;
use JSON;

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

    my $json = JSON->new();
    my @predefined_columns;
    foreach (keys %{$self->predefined_columns}) {
        if ($self->predefined_columns->{$_}) {
            push @predefined_columns, $_;
        }
    }
    my $predefined_columns_json = $json->encode(\@predefined_columns);

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    $ws->write(0, 0, 'Spreadsheet ID'); $ws->write('0', '1', 'ID'.$$.time());
    $ws->write(0, 2, 'Spreadsheet format'); $ws->write(0, 3, "BasicExcel");
    $ws->write(1, 0, 'Trial name'); $ws->write(1, 1, $trial->get_name(), $bold);
    $ws->write(2, 0, 'Description'); $ws->write(2, 1, $trial->get_description(), $bold);
    $ws->write(3, 0, "Trial location");  $ws->write(3, 1, $trial->get_location()->[1], $bold);
    $ws->write(4, 0, "Predefined Columns");  $ws->write(4, 1, $predefined_columns_json, $bold);
    $ws->write(1, 2, 'Operator');       $ws->write(1, 3, "Enter operator here");
    $ws->write(2, 2, 'Date');           $ws->write(2, 3, "Enter date here");
    $ws->data_validation(2,3, { validate => "date", criteria => '>', value=>'1000-01-01' });
    

    my $num_col_before_traits;
    if ($self->data_level eq 'plots') {
        $num_col_before_traits = 6;
        my @column_headers = qw | plot_name accession_name plot_number block_number is_a_control rep_number |;
        for(my $n=0; $n<@column_headers; $n++) { 
            $ws->write(6, $n, $column_headers[$n]);
        }
        
        my @ordered_plots = sort { $a <=> $b} keys(%design);
        for(my $n=0; $n<@ordered_plots; $n++) { 
            my %design_info = %{$design{$ordered_plots[$n]}};

            $ws->write($n+7, 0, $design_info{plot_name});
            $ws->write($n+7, 1, $design_info{accession_name});
            $ws->write($n+7, 2, $design_info{plot_number});
            $ws->write($n+7, 3, $design_info{block_number});
            $ws->write($n+7, 4, $design_info{is_a_control});
            $ws->write($n+7, 5, $design_info{rep_number});
        }
        
    } elsif ($self->data_level eq 'plants') {
        $num_col_before_traits = 7;
        my $pre_col = $self->predefined_columns;
        if ($pre_col) {
            my $num_predefined_col = scalar keys %$pre_col;
            my @column_headers = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number |;
            foreach (keys %$pre_col) {
                if ($pre_col->{$_}) {
                    push @column_headers, $_;
                    $num_col_before_traits++;
                }
            }
            for(my $n=0; $n<scalar(@column_headers); $n++) { 
                $ws->write(6, $n, $column_headers[$n]);
            }
        } else {
            my @column_headers = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number |;
            for(my $n=0; $n<@column_headers; $n++) { 
                $ws->write(6, $n, $column_headers[$n]);
            }
        }
        
        my @ordered_plots = sort { $a <=> $b} keys(%design);
        my $line = 7;
        for(my $n=0; $n<@ordered_plots; $n++) { 
            my %design_info = %{$design{$ordered_plots[$n]}};
            my $plant_names = $design_info{plant_names};
            
            my $sampled_plant_names;
            if ($self->sample_number) {
                my $sample_number = $self->sample_number;
                foreach (@$plant_names) {
                    if ( $_ =~ m/_plant_(\d+)/) {
                        if ($1 <= $sample_number) {
                            push @$sampled_plant_names, $_;
                        }
                    }
                }
            } else {
                $sampled_plant_names = $plant_names;
            }

            foreach (@$sampled_plant_names) {
                $ws->write($line, 0, $_);
                $ws->write($line, 1, $design_info{plot_name});
                $ws->write($line, 2, $design_info{accession_name});
                $ws->write($line, 3, $design_info{plot_number});
                $ws->write($line, 4, $design_info{block_number});
                $ws->write($line, 5, $design_info{is_a_control});
                $ws->write($line, 6, $design_info{rep_number});
                
                if ($pre_col) {
                    my $pre_col_ind = 7;
                    foreach (keys %$pre_col) {
                        if ($pre_col->{$_}) {
                            $ws->write($line, $pre_col_ind, $pre_col->{$_});
                            $pre_col_ind++;
                        }
                    }
                }
                
                $line++;
            }
        }
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
        #if (exists($cvinfo{$trait_list[$i]})) { 
            #$ws->write(5, $i+6, $cvinfo{$trait_list[$i]}->display_name());
            $ws->write(6, $i+$num_col_before_traits, $trait_list[$i]);
        #}
        #else { 
        #    print STDERR "Skipping output of trait $trait_list[$i] because it does not exist\n";
        #    next;
        #}
    
        my $plot_count = scalar(keys(%design));

        for (my $n = 0; $n < $plot_count; $n++) { 
            if ($cvinfo{$trait_list[$i]}) {
                my $format = $cvinfo{$trait_list[$i]}->format();
                if ($format eq "numeric") { 
                    $ws->data_validation($n+7, $i+$num_col_before_traits, { validate => "any" });
                }
                elsif ($format =~ /\,/) {  # is a list
                    $ws->data_validation($n+7, $i+$num_col_before_traits, {
                        validate => 'list',
                        value    => [ split ",", $format ]
                    });
                }
            }
        }
    }
    
    $workbook->close();
    
}
    
1;
