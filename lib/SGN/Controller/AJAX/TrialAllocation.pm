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
    
    ## Retrieving elements
    my $treatment_list = CXGN::List->new({ dbh => $dbh, list_id => $treatments });
    my $control_list   = CXGN::List->new({ dbh => $dbh, list_id => $controls });

    my $treatment_names = $treatment_list->elements;
    my $control_names   = $control_list->elements;

    my $treatment_string = join(', ', map { qq("$_") } @$treatment_names);
    my $control_string   = join(', ', map { qq("$_") } @$control_names);


    ## Adjusting variables for RCBD
    my ($n_row, $n_col);
    if ($design eq 'RCBD') {
        my $rows_per_block = $trial->{rows};       # corresponds to tblockrows
        my $blocks         = $trial->{blocks};     # corresponds to trepsblocks

        my $n_row = $rows_per_block * $blocks;
        my $total_entries = scalar(@$treatment_names) + scalar(@$control_names);
        my $n_col = ($total_entries * $blocks) / $n_row;

        if ($n_col != int($n_col)) {

            $c->stash->{rest} = {
                success => 0,
                error   => "The number of columns for the RCBD layout is not an integer. Please adjust the number of entries, reps (blocks), or rows per block to fit evenly."
            };
            return;
        };
        
        print STDERR "New total of rows: $rows_per_block \n";
        print STDERR "New total of cols: $n_col \n";

        $trial->{n_row} = $n_row;
        $trial->{n_col} = $n_col;

    }
    
    ## Send paramenter to a temp file
    $c->tempfiles_subdir("trial_allocation");

    # Create base temp file (no extension yet)
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE => "trial_allocation/trial_XXXXX");

    # Full base path (no extension)
    my $temppath = $c->config->{basepath} . "/" . $tempfile;
    print STDERR "***** temppath = $temppath\n";

    # Define specific file names with extensions
    my $paramfile = $temppath . ".params";  # for R input
    my $outfile   = $temppath . ".out";     # for R output

    # Write trial.params (for R)
    open(my $F, ">", $paramfile) or die "Can't open $paramfile for writing.";

    print $F "treatments <- c($treatment_string)\n";
    print $F "controls <- c($control_string)\n";
    print $F "n_rep <- " . ($trial->{reps} // '') . "\n";
    print $F "n_row <- " . ($trial->{rows} // '') . "\n";
    print $F "n_col <- " . ($trial->{cols} // '') . "\n";
    print $F "n_blocks <- " . ($trial->{blocks} // '') . "\n";
    print $F "serie <- " . ($trial->{serie} // 1) . "\n";  # optional
    close($F);

    # Run R if needed
    if ($trial->{design} eq "RCBD") {
        my $cmd = "R CMD BATCH '--args paramfile=\"$paramfile\"' R/RCBD.R $outfile";
        print STDERR "Running: $cmd\n";
        system($cmd);
    }

    # Return filenames
    $c->stash->{rest} = {
        success     => 1,
        message     => "Files created and R script triggered.",
        n_row   => $trial->{n_row},
        n_col   => $trial->{n_col},
        design  => $trial->{design},
        param_file  => $paramfile,
        r_output    => $outfile
    };

}




1;