package SGN::Controller::AJAX::TrialAllocation;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use File::Path qw(rmtree);
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use Text::CSV;
use JSON;


BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );


sub list_accessions :Path('/ajax/trialallocation/accession_lists') Args(0) {
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;

    # Get cvterm_id for 'accessions' in 'list_types'
    my $accession_type_id = $schema->resultset('Cv::Cvterm')->find({ name => 'accessions' })->cvterm_id;

    # Use CXGN::List::all_lists
    my $lists = CXGN::List::all_lists($dbh, $sp_person_id, 'accessions');

    my @formatted = map {
        {
            list_id   => $_->[0],
            name      => $_->[1],
            desc      => $_->[2],
            count     => $_->[3],
            type_id   => $_->[4],
            type_name => $_->[5],
            is_public => $_->[6]
        }
    } @$lists;
    
    print Dumper \@formatted;

    $c->stash->{rest} = { success => 1, lists => \@formatted };
}

sub generate_design :Path('/ajax/trialallocation/generate_design') :Args(0) {
    my ($self, $c) = @_;

    my $json_string = $c->req->param('trial');

    unless ($json_string) {
        $c->stash->{rest} = { success => 0, error => "Missing 'trial' parameter" };
        return;
    }

    my $trial;
    eval {
        $trial = decode_json($json_string);
    };
    if ($@ || !$trial) {
        $c->stash->{rest} = { success => 0, error => "Invalid JSON in 'trial'" };
        return;
    }

    my $dbh = $c->dbc->dbh;

    # Use trial data
    my $name       = $trial->{name};
    my $design     = $trial->{design};
    my $description = $trial->{description};
    my $treatments = $trial->{treatment_list_id};
    my $controls   = $trial->{control_list_id};
    my $rows_per_block = $trial->{rows};       # corresponds to tblockrows
    my $blocks         = $trial->{blocks};     # corresponds to trepsblocks
    my $trial_design;
    
    ## Retrieving elements
    my $treatment_list = CXGN::List->new({ dbh => $dbh, list_id => $treatments });
    my $control_list   = CXGN::List->new({ dbh => $dbh, list_id => $controls });

    my $treatment_names = $treatment_list->elements;
    my $control_names   = $control_list->elements;

    my $treatment_string = join(', ', map { qq("$_") } @$treatment_names);
    my $control_string   = join(', ', map { qq("$_") } @$control_names);


    my $n_trt = scalar(@$treatment_names);
    my $n_ctl = scalar(@$control_names);
    
    # Send paramenter to a temp file
    $c->tempfiles_subdir("trial_allocation");

    # Create base temp file (no extension yet)
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE => "trial_allocation/trial_XXXXX");

    # Full base path (no extension)
    my $temppath = $c->config->{basepath} . "/" . $tempfile;
    print STDERR "***** temppath = $temppath\n";
    
    
    
    ## Call for rrc

    ## Call for DRRC

    ## Call for URDD
    

    # Define specific file names with extensions
    my $paramfile = $temppath . ".params";  # for R input
    my $outfile   = $temppath . ".out";     # for R output
    my $message_file = $temppath . ".message";
    my $design_file = "$temppath" . ".design";

    # Write trial.params (for R)
    open(my $F, ">", $paramfile) or die "Can't open $paramfile for writing.";

    print $F "treatments <- c($treatment_string)\n";
    print $F "controls <- c($control_string)\n";
    print $F "n_rep <- nRep <- " . ($trial->{reps} // '') . "\n";
    print $F "n_row <- nRow <- " . ($trial->{rows} // '') . "\n";
    print $F "n_col <- nCol <- " . ($trial->{cols} // '') . "\n";
    print $F "n_blocks <- nBlocks <- " . ($trial->{blocks} // '') . "\n";
    print $F "serie <- " . ($trial->{serie} // 1) . "\n";  # optional
    close($F);

    # Run R if needed
    if ($trial->{design} eq "RCBD") {
        my $cmd = "R CMD BATCH '--args paramfile=\"$paramfile\"' R/RCBD.R $outfile";
        print STDERR "Running: $cmd\n";
        system($cmd);
    }
    
    ## Handelling with error messages
    
    if (-e $message_file) {
        open(my $fh, '<', $message_file) or die "Could not open $message_file: $!";
        my $error_text = do { local $/; <$fh> };
        close($fh);
        die "Trial allocation error: $error_text";
    }



    ## Adjusting variables for RCBD
    my $json_desing;
    if ($design eq 'RCBD') {
        my ($n_row, $n_col, $error, $trial_design) = create_rcbd($rows_per_block, $blocks, $n_trt, $n_ctl, $design_file);
        $trial->{n_row} = $n_row;
        $trial->{n_col} = $n_col;
        $json_desing = encode_json($trial_design);
    }

    # Return filenames
    $c->stash->{rest} = {
        success     => 1,
        message     => "Files created and R script triggered.",
        n_row   => $trial->{n_row},
        n_col   => $trial->{n_col},
        design  => $json_desing,
        rows_per_block => $rows_per_block,
        param_file  => $paramfile,
        design_file => $design_file,
        r_output    => $outfile
    };

}



sub save_coordinates :Path('/ajax/trialallocation/save_coordinates') :Args(0) {
    my ($self, $c) = @_;

    my $json_string = $c->req->param('trial');
    my $data = eval { decode_json($json_string) };

    if (!$data) {
    $c->stash->{rest} = {
        success => 0,
        error   => "Invalid JSON in 'trial' param: $@"
    };
        return;
    }

    my $trial_name  = $data->{trial_name};
    my $trial_id    = $data->{trial_id};
    my $coords      = $data->{coordinates};
    my $design_file = $data->{design_file};
    # Log or process
    $c->log->debug("Got trial $trial_name with coords:");
    $c->log->debug(" → $_->[0], $_->[1]") for @$coords;


    ## Adding coordinates to the trial
    # Open original file
    open my $in, '<', $design_file or die "Can't open $design_file: $!";

    my $csv_in = Text::CSV->new({ sep_char => "\t", binary => 1, auto_diag => 1 });

    # Read header
    my $header = $csv_in->getline($in);
    push @$header, 'row_number', 'col_number';

    # Read data rows and filter out empty ones
    my @rows;
    while (my $row = $csv_in->getline($in)) {
      # Skip completely empty rows
      next if scalar(grep { defined && /\S/ } @$row) == 0;
      push @rows, $row;
    }
    close $in;

    # Validate row count
    if (@rows != @$coords) {
      die "Mismatch: design file has ".scalar(@rows)." valid rows but got ".scalar(@$coords)." coordinates";
    }

    # Add coordinates
    for my $i (0 .. $#rows) {
      my ($r, $c) = @{ $coords->[$i] };
      push @{ $rows[$i] }, $r, $c;
    }

    # Write to same file
    open my $out, '>', $design_file or die "Can't write to $design_file: $!";

    my $csv_out = Text::CSV->new({ sep_char => "\t", binary => 1, eol => "\n" });
    $csv_out->print($out, $header);
    $csv_out->print($out, $_) for @rows;

    close $out;

    $c->stash->{rest} = {
        success => 1,
        message => "Trial saved!"
    };
}

sub get_design :Path('/ajax/trialallocation/get_design') :Args(0) {
    my $self = shift;
    my $c    = shift;

    my $trial_path = $c->req->param('trial_path');

    unless ($trial_path && -e $trial_path) {
        $c->res->status(400);
        $c->res->body("Design file not found or path not provided.");
        return;
    }

    eval {
        open(my $fh, '<', $trial_path) or die "Cannot open $trial_path: $!";
        local $/;
        my $content = <$fh>;
        close($fh);

        $c->res->content_type('text/plain');
        $c->res->body($content);
    };
    if ($@) {
        $c->res->status(500);
        $c->res->body("Error reading design file: $@");
    }
}



sub create_rcbd {
  my ($rows_per_block, $blocks, $n_trt, $n_ctl, $design_file) = @_;

  my $n_row = $rows_per_block * $blocks;
  my $total_entries = $n_trt + $n_ctl;
  my $n_col = ($total_entries * $blocks) / $n_row;

  if ($n_col != int($n_col)) {
    return ($n_row, $n_col, "Invalid dimensions", []);
  }

  open my $fh, "<", $design_file or return ($n_row, $n_col, "Cannot open $design_file", []);

  my $header_line = <$fh>;
  chomp $header_line;
  my @columns = split /\t/, $header_line;

  my %col_index;
  for my $i (0 .. $#columns) {
    $col_index{$columns[$i]} = $i;
  }

  my @design;
  while (my $line = <$fh>) {
      chomp $line;
      next unless $line =~ /\S/;  # skip blank lines
      my @fields = split /\t/, $line;

      push @design, {
        plot_number    => $fields[ $col_index{plots} ],
        block          => $fields[ $col_index{block} ],
        accession_name => $fields[ $col_index{all_entries} ],
        rep            => $fields[ $col_index{rep} ],
        is_control     => $fields[ $col_index{is_control} ]
      };
    }


  close $fh;

  return ($n_row, $n_col, undef, \@design);
}


1;