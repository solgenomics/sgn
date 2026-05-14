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
use SGN::Controller::AJAX::Locations;
use SGN::Model::Cvterm;
use Text::CSV;
use JSON;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial::ParseUpload;
use CXGN::Trial::TrialCreate;
use CXGN::Trial;
use CXGN::Trial::Search;
use CXGN::TrialStatus;
use CXGN::Calendar;
use CXGN::List;
use List::MoreUtils qw(any);


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

    @formatted = sort { lc($a->{name}) cmp lc($b->{name}) } @formatted;

    $c->stash->{rest} = { success => 1, lists => \@formatted };
}

sub accession_autocomplete :Path('/ajax/trialallocation/accession_autocomplete') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $term = $c->req->param('q') || $c->req->param('term') || '';
    $term =~ s/^\s+|\s+$//g;

    if (length($term) < 2) {
        $c->stash->{rest} = { success => 1, results => [] };
        return;
    }

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
    my $like = '%' . $term . '%';

    my $rs = $schema->resultset('Stock::Stock')->search(
        {
            type_id => $accession_type_id,
            is_obsolete => 'false',
            -or => [
                uniquename => { ilike => $like },
                name => { ilike => $like }
            ]
        },
        {
            columns => [qw/stock_id uniquename name/],
            order_by => [{ -asc => 'uniquename' }],
            rows => 25
        }
    );

    my @results;
    while (my $stock = $rs->next) {
        my $uniquename = $stock->uniquename || '';
        my $name = $stock->name || '';
        my $label = $name && $name ne $uniquename ? "$uniquename ($name)" : $uniquename;
        push @results, {
            id => $uniquename,
            text => $label,
            stock_id => $stock->stock_id
        };
    }

    $c->stash->{rest} = { success => 1, results => \@results };
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
    my $design     = _trial_allocation_display_design_type($trial->{design});
    my $description = $trial->{description};
    my $treatments = $trial->{treatment_list_id};
    my $controls   = $trial->{control_list_id};
    
    my $rows = $trial->{rows};
    my $rows_per_block = $trial->{rows_per_block};  
    my $rows_in_field = $trial->{rows_in_field};    
    
    my $cols = $trial->{cols};
    my $cols_per_block = $trial->{cols_per_block};  
    my $cols_in_field = $trial->{cols_in_field};    
    
    my $reps = $trial->{reps};
    my $blocks = $trial->{blocks}; 
    
    my $layout_type = $trial->{layout_type} || 'serpentine';
    my $engine = 'trial_allocation';
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

    print Dumper \$trial;
    
 
    # Define specific file names with extensions
    my $paramfile = $temppath . ".params";  # for R input
    my $outfile   = $temppath . ".out";     # for R output
    my $message_file = $temppath . ".message";
    my $design_file = "$temppath" . ".design";

    # Write trial.params (for R)
    open(my $F, ">", $paramfile) or die "Can't open $paramfile for writing.";

    print $F "treatments <- c($treatment_string)\n";
    print $F "controls <- c($control_string)\n";
    print $F "n_rep <- nRep <- " . $reps . "\n";
    print $F "n_row <- nRow <- " . $rows . "\n";
    print $F "rows_per_block <- " . $rows_per_block . "\n";
    print $F "rows_in_field <- " . $rows_in_field . "\n";
    print $F "n_col <- nCol <- " . $cols . "\n";
    print $F "cols_per_block <- " . $cols_per_block . "\n";
    print $F "cols_in_field <- " . $cols_in_field . "\n";
    print $F "n_blocks <- nBlocks <- " . $blocks . "\n";
    print $F "serie <- " . ($trial->{serie} // 1) . "\n";  # optional
    print $F "plot_type <- layout <- \"$layout_type\"\n";  # optional
    print $F "engine <- \"$engine\"\n";  # optional
    close($F);
    
    print STDERR "***** The design is = $design\n";

    # Run R if needed
    if ($design eq "RCBD") {
        my $cmd = "R CMD BATCH --no-save --no-restore '--args paramfile=\"$paramfile\"' R/RCBD.R $outfile";
        print STDERR "Running: $cmd\n";
        system($cmd);
    }
    
    if ($design eq "Doubly-Resolvable Row-Column") {
        my $cmd = "R CMD BATCH --no-save --no-restore '--args paramfile=\"$paramfile\"' R/DRRC.r $outfile";
        print STDERR "Running: $cmd\n";
        system($cmd);
    }
    
    if ($design eq "Un-Replicated Diagonal") {
        my $cmd = "R CMD BATCH --no-save --no-restore '--args paramfile=\"$paramfile\"' R/urdd_design.R $outfile";
        print STDERR "Running: $cmd\n";
        system($cmd);
    }

    if ($design eq "Row-Column Design") {
        my $cmd = "R CMD BATCH --no-save --no-restore '--args paramfile=\"$paramfile\"' R/rrc_design.R $outfile";
        print STDERR "Running: $cmd\n";
        system($cmd);
    }

    if ($design eq "Augmented Row-Column") {
        my $cmd = "R CMD BATCH --no-save --no-restore '--args paramfile=\"$paramfile\"' R/augmented_row_column.R $outfile";
        print STDERR "Running: $cmd\n";
        my $status = system($cmd);
        if ($status != 0 || !-e $design_file) {
            my $r_output = -e $outfile ? read_file($outfile) : '';
            $c->stash->{rest} = {
                success => 0,
                error => 'Augmented Row-Column design generation failed. ' . ($r_output || 'No R output was produced.')
            };
            return;
        }
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
    if( $design eq "RCBD"){
        my ($n_row, $n_col, $trial_design) = create_rcbd($rows, $blocks, $n_trt, $n_ctl, $design_file);
        $trial->{n_row} = $n_row;
        $trial->{n_col} = $n_col;
        $json_desing = encode_json($trial_design);
    } else {
        my ($trial_design) = arrange_design($design_file, $design);
        $json_desing = encode_json($trial_design);
        my ($n_row, $n_col);
        
        if ($design eq 'Augmented Row-Column'){
            $n_row = $rows_in_field;
            $n_col = $cols_in_field; 
        } else {
            $n_row = $rows;
            $n_col = $cols;
        }

        # print STDERR "***** Rows = $n_row\n";
        # print STDERR "***** Cols = $n_col\n";
        $trial->{n_row} = $n_row;
        $trial->{n_col} = $n_col;
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

sub farms :Path('/ajax/trialallocation/farms') Args(0) {
    my $self = shift;
    my $c = shift;

    my $project_obj = CXGN::BreedersToolbox::Projects->new({ schema => $c->dbic_schema('Bio::Chado::Schema') });
    my $locations = $project_obj->get_location_geojson_data();

    my @farms;
    foreach my $l (@$locations) {
        push @farms, {
            location_id => $l->{properties}->{Id},
            name        => $l->{properties}->{Name}
        };
    }

    @farms = sort { lc($a->{name}) cmp lc($b->{name}) } @farms;
    
    $c->stash->{rest} = {
        success => 1,
        farms   => \@farms
    };
}

sub breeding_programs :Path('/ajax/trialallocation/breeding_programs') Args(0) {
    my ($self, $c) = @_;

    my $project_obj = CXGN::BreedersToolbox::Projects->new({
        schema => $c->dbic_schema('Bio::Chado::Schema')
    });
    my $programs = $project_obj->get_breeding_programs();

    my @formatted = map {
        {
            program_id  => $_->[0],
            name        => $_->[1],
            description => $_->[2],
        }
    } @$programs;

    @formatted = sort { lc($a->{name}) cmp lc($b->{name}) } @formatted;

    $c->stash->{rest} = {
        success  => 1,
        programs => \@formatted
    };
}

sub seasons :Path('/ajax/trialallocation/seasons') Args(0) {
    my ($self, $c) = @_;

    my $configured = $c->config->{available_seasons} || 'summer,winter';
    my @seasons = grep { $_ ne '' } map {
        my $season = $_;
        $season =~ s/^\s+|\s+$//g;
        $season;
    } split /,/, $configured;

    $c->stash->{rest} = {
        success => 1,
        seasons => \@seasons
    };
}

sub trial_types :Path('/ajax/trialallocation/trial_types') Args(0) {
    my ($self, $c) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my @types = map {
        {
            type_id => $_->[0],
            name => $_->[1],
            description => $_->[2]
        }
    } CXGN::Trial::get_all_project_types($schema);

    @types = sort { lc($a->{name}) cmp lc($b->{name}) } @types;

    $c->stash->{rest} = {
        success => 1,
        trial_types => \@types
    };
}

sub trial_designs :Path('/ajax/trialallocation/trial_designs') Args(0) {
    my ($self, $c) = @_;

    my %supported = _trial_allocation_supported_designs();
    my %aliases = _trial_allocation_design_aliases();

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my %designs = %supported;
    eval {
        my $design_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property');
        if ($design_cvterm) {
            my $rs = $schema->resultset('Project::Projectprop')->search(
                { type_id => $design_cvterm->cvterm_id },
                { columns => [qw/value/], distinct => 1 }
            );
            while (my $row = $rs->next) {
                my $value = _clean_optional_value($row->value);
                my $code = $aliases{$value} || $value;
                $designs{$code} = $supported{$code} if $supported{$code};
            }
        }
    };

    my @designs = map {
        {
            value => $_,
            name => $designs{$_}
        }
    } sort { lc($designs{$a}) cmp lc($designs{$b}) } keys %designs;

    $c->stash->{rest} = {
        success => 1,
        trial_designs => \@designs
    };
}

sub _trial_allocation_supported_designs {
    return (
        CRD => 'CRD',
        RCBD => 'RCBD',
        RRC => 'Row-Column Design',
        DRRC => 'Doubly-Resolvable Row-Column',
        URDD => 'Un-Replicated Diagonal',
        Alpha => 'Alpha',
        Lattice => 'Lattice',
        Augmented => 'Augmented',
        'Augmented Row-Column' => 'Augmented Row-Column',
        MAD => 'MAD',
        greenhouse => 'greenhouse',
        'p-rep' => 'p-rep',
        splitplot => 'splitplot',
        Westcott => 'Westcott',
    );
}

sub _trial_allocation_design_aliases {
    return (
        'Row-Column Design' => 'RRC',
        'Doubly-Resolvable Row-Column' => 'DRRC',
        'Un-Replicated Diagonal' => 'URDD',
    );
}

sub existing_trials :Path('/ajax/trialallocation/existing_trials') Args(0) {
    my ($self, $c) = @_;

    my $location_id = $c->req->param('location_id');
    my $year = $c->req->param('year');

    if (!$location_id || !$year || $location_id eq 'null' || $year eq 'null') {
        $c->stash->{rest} = { success => 1, trials => [] };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my %supported_designs = _trial_allocation_supported_designs();
    my %design_aliases = _trial_allocation_design_aliases();
    my $allocated_trial_ids = $self->_allocated_existing_trial_ids($c);
    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema => $schema,
        location_id_list => [int($location_id)],
        year_list => ["$year"],
        field_trials_only => 1,
        sort_by => ' ORDER BY study.name ',
        order_by => '',
        externalReferenceSources => [],
        externalReferenceIds => []
    });
    my ($results) = $trial_search->search();

    my @trials;
    foreach my $trial (@$results) {
        next if $allocated_trial_ids->{ $trial->{trial_id} };

        my $design = _clean_optional_value($trial->{design});
        my $design_code = $design_aliases{$design} || $design;
        next unless $design_code && $supported_designs{$design_code};

        push @trials, {
            trial_id => $trial->{trial_id},
            name => $trial->{trial_name},
            description => $trial->{description} || '',
            year => $trial->{year} || '',
            location_id => $trial->{location_id} || '',
            location_name => $trial->{location_name} || '',
            breeding_program_id => $trial->{breeding_program_id} || '',
            breeding_program_name => $trial->{breeding_program_name} || '',
            design => $design_code,
            design_name => $supported_designs{$design_code},
            type => $trial->{trial_type_name} || $trial->{trial_type_value} || ''
        };
    }

    $c->stash->{rest} = { success => 1, trials => \@trials };
}

sub existing_trial_design :Path('/ajax/trialallocation/existing_trial_design') Args(0) {
    my ($self, $c) = @_;

    my $trial_id = $c->req->param('trial_id');
    if (!$trial_id || $trial_id eq 'null') {
        $c->stash->{rest} = { success => 0, error => 'Missing trial id.' };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $trial = $schema->resultset('Project::Project')->find({ project_id => $trial_id });
    if (!$trial) {
        $c->stash->{rest} = { success => 0, error => 'Trial not found.' };
        return;
    }

    my $stored_design = _trial_layout_json_for_project($schema, $trial_id);
    my $stored_layout = _existing_trial_design_from_projectprop($stored_design);
    if (@{$stored_layout->{design} || []}) {
        $c->stash->{rest} = {
            success => 1,
            trial => {
                trial_id => int($trial_id),
                name => $trial->name,
                description => $trial->description || '',
                n_row => $stored_layout->{n_row} || 1,
                n_col => $stored_layout->{n_col} || scalar(@{$stored_layout->{design}}),
                design => $stored_layout->{design}
            }
        };
        return;
    }

    my $plots = CXGN::Trial->get_sorted_plots(
        $schema,
        [int($trial_id)],
        'by_row_zigzag',
        'top_left',
        { top => 0, right => 0, bottom => 0, left => 0 },
        0
    );

    if (ref($plots) eq 'HASH' && $plots->{error}) {
        $c->stash->{rest} = { success => 0, error => $plots->{error} };
        return;
    }

    my @plots = ref($plots) eq 'HASH' ? @{$plots->{plots} || []} : @$plots;
    if (!@plots) {
        $c->stash->{rest} = { success => 0, error => 'No plots found for selected trial.' };
        return;
    }

    my $stored_design_indexes = _index_trial_layout_design($stored_design);
    my $plot_number_by_plot_id = _plot_number_stockprops_by_plot_id($schema, \@plots);

    my ($min_row, $max_row, $min_col, $max_col);
    foreach my $plot (@plots) {
        my $row = int($plot->{row_number} || 1);
        my $col = int($plot->{col_number} || 1);
        $min_row = $row if !defined($min_row) || $row < $min_row;
        $max_row = $row if !defined($max_row) || $row > $max_row;
        $min_col = $col if !defined($min_col) || $col < $min_col;
        $max_col = $col if !defined($max_col) || $col > $max_col;
    }

    my @design;
    for my $i (0 .. $#plots) {
        my $plot = $plots[$i];
        my $is_control = $plot->{is_a_control} || 0;
        $is_control = ($is_control && $is_control ne 'false') ? 1 : 0;
        my $plot_id = _existing_trial_plot_id($plot);
        my $plot_name = _existing_trial_plot_name($plot);
        my $plot_number = _existing_trial_plot_number(
            $plot,
            $stored_design_indexes,
            $plot_number_by_plot_id
        );
        push @design, {
            plot_id => $plot_id,
            plot_name => $plot_name,
            plot_number => $plot_number || ($i + 1),
            original_plot_number => $plot_number || ($i + 1),
            block => $plot->{block_number} || 1,
            accession_name => $plot->{accession_name} || '',
            is_control => $is_control
        };
    }

    $c->stash->{rest} = {
        success => 1,
        trial => {
            trial_id => int($trial_id),
            name => $trial->name,
            description => $trial->description || '',
            n_row => ($max_row - $min_row + 1),
            n_col => ($max_col - $min_col + 1),
            design => \@design
        }
    };
}

sub _existing_trial_design_from_projectprop {
    my $design = shift || {};
    return { n_row => 0, n_col => 0, design => [] } unless $design && ref($design) eq 'HASH' && keys %$design;

    my @entries;
    foreach my $key (keys %$design) {
        my $entry = $design->{$key};
        next unless $entry && ref($entry) eq 'HASH';

        my $plot_number = _clean_optional_value($entry->{plot_number}) || _clean_optional_value($key);
        next unless $plot_number ne '';

        my $row = _clean_optional_value($entry->{row_number});
        my $col = _clean_optional_value($entry->{col_number});
        push @entries, {
            sort_row => ($row ne '' && $row =~ /^-?\d+$/) ? int($row) : 0,
            sort_col => ($col ne '' && $col =~ /^-?\d+$/) ? int($col) : 0,
            sort_plot => ($plot_number =~ /^\d+$/) ? int($plot_number) : $plot_number,
            plot_id => _clean_optional_value($entry->{plot_id}),
            plot_name => _clean_optional_value($entry->{plot_name}),
            plot_number => $plot_number,
            original_plot_number => $plot_number,
            block => _clean_optional_value($entry->{block_number}) || _clean_optional_value($entry->{block}) || 1,
            accession_name => _clean_optional_value($entry->{accession_name}),
            is_control => _clean_optional_value($entry->{is_a_control}) ? 1 : 0
        };
    }

    return { n_row => 0, n_col => 0, design => [] } unless @entries;

    my @rows = grep { $_ > 0 } map { $_->{sort_row} } @entries;
    my @cols = grep { $_ > 0 } map { $_->{sort_col} } @entries;
    my ($min_row, $max_row, $min_col, $max_col);
    foreach my $row (@rows) {
        $min_row = $row if !defined($min_row) || $row < $min_row;
        $max_row = $row if !defined($max_row) || $row > $max_row;
    }
    foreach my $col (@cols) {
        $min_col = $col if !defined($min_col) || $col < $min_col;
        $max_col = $col if !defined($max_col) || $col > $max_col;
    }

    @entries = sort {
        ($a->{sort_row} || 0) <=> ($b->{sort_row} || 0)
            || ($a->{sort_col} || 0) <=> ($b->{sort_col} || 0)
            || $a->{sort_plot} cmp $b->{sort_plot}
    } @entries;

    my @output = map {
        my %copy = %$_;
        delete @copy{qw/sort_row sort_col sort_plot/};
        \%copy;
    } @entries;

    return {
        n_row => (defined($min_row) && defined($max_row)) ? ($max_row - $min_row + 1) : 1,
        n_col => (defined($min_col) && defined($max_col)) ? ($max_col - $min_col + 1) : scalar(@output),
        design => \@output
    };
}

sub _allocated_existing_trial_ids {
    my ($self, $c) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $type_id = eval { $self->_multi_trial_layout_type_id($c) };
    return {} if $@ || !$type_id;

    my %allocated;
    my $props = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search({ type_id => $type_id });
    while (my $prop = $props->next) {
        next unless $prop->value;
        my $stored = eval { decode_json($prop->value) };
        next unless $stored && ref($stored) eq 'HASH';

        foreach my $layout (@{$stored->{layouts} || []}) {
            foreach my $placed_trial (@{$layout->{placed_trials} || []}) {
                my $project_id = _clean_optional_value($placed_trial->{existing_project_id});
                $allocated{$project_id} = 1 if $project_id && $project_id =~ /^\d+$/;
            }
            foreach my $form (@{$layout->{trial_forms} || []}) {
                my $project_id = _clean_optional_value($form->{existing_project_id}) || _clean_optional_value($form->{project_id});
                $allocated{$project_id} = 1 if $project_id && $project_id =~ /^\d+$/;
            }
        }
    }

    return \%allocated;
}

sub _trial_layout_json_for_project {
    my ($schema, $project_id) = @_;

    my $type_id = eval { SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_layout_json', 'project_property')->cvterm_id() };
    return {} if $@ || !$type_id;

    my $prop = $schema->resultset('Project::Projectprop')->find({
        project_id => $project_id,
        type_id => $type_id
    });
    return {} unless $prop && $prop->value;

    my $decoded = eval { decode_json($prop->value) };
    return ($decoded && ref($decoded) eq 'HASH') ? $decoded : {};
}

sub _index_trial_layout_design {
    my $design = shift || {};
    my %by_plot_id;
    my %by_plot_name;
    my %by_plot_number;

    foreach my $key (keys %$design) {
        my $entry = $design->{$key};
        next unless $entry && ref($entry) eq 'HASH';

        my $plot_id = _clean_optional_value($entry->{plot_id});
        my $plot_name = _clean_optional_value($entry->{plot_name});
        my $plot_number = _clean_optional_value($entry->{plot_number}) || _clean_optional_value($key);
        my %indexed_entry = %$entry;
        $indexed_entry{plot_number} = $plot_number if $plot_number ne '' && _clean_optional_value($indexed_entry{plot_number}) eq '';
        my $indexed_entry_ref = \%indexed_entry;

        $by_plot_id{$plot_id} = $indexed_entry_ref if $plot_id ne '';
        $by_plot_name{$plot_name} = $indexed_entry_ref if $plot_name ne '';
        $by_plot_number{$plot_number} = $indexed_entry_ref if $plot_number ne '';
    }

    return {
        by_plot_id => \%by_plot_id,
        by_plot_name => \%by_plot_name,
        by_plot_number => \%by_plot_number
    };
}

sub _plot_number_stockprops_by_plot_id {
    my ($schema, $plots) = @_;

    my @plot_ids = grep { $_ && /^\d+$/ } map { _existing_trial_plot_id($_) } @$plots;
    return {} unless @plot_ids;

    my $type_id = eval { SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id() };
    return {} if $@ || !$type_id;

    my %plot_numbers;
    my $props = $schema->resultset('Stock::Stockprop')->search({
        stock_id => { -in => \@plot_ids },
        type_id => $type_id
    });
    while (my $prop = $props->next) {
        my $plot_number = _clean_optional_value($prop->value);
        $plot_numbers{$prop->stock_id} = $plot_number if $plot_number ne '';
    }

    return \%plot_numbers;
}

sub _existing_trial_plot_number {
    my ($plot, $stored_design_indexes, $plot_number_by_plot_id) = @_;

    my $plot_id = _existing_trial_plot_id($plot);
    my $plot_name = _existing_trial_plot_name($plot);
    my $reported_plot_number = _reported_existing_plot_number($plot);

    my $stored_entry =
        ($plot_id ne '' && $stored_design_indexes->{by_plot_id}{$plot_id}) ||
        ($plot_name ne '' && $stored_design_indexes->{by_plot_name}{$plot_name}) ||
        ($reported_plot_number ne '' && $stored_design_indexes->{by_plot_number}{$reported_plot_number}) ||
        undef;

    return _clean_optional_value($stored_entry->{plot_number}) if $stored_entry && _clean_optional_value($stored_entry->{plot_number}) ne '';
    return _clean_optional_value($plot_number_by_plot_id->{$plot_id}) if $plot_id ne '' && _clean_optional_value($plot_number_by_plot_id->{$plot_id}) ne '';
    return $reported_plot_number;
}

sub _existing_trial_plot_id {
    my $plot = shift || {};

    return _clean_optional_value($plot->{plot_id})
        || _clean_optional_value($plot->{stock_id})
        || _clean_optional_value($plot->{observationunit_stock_id})
        || _clean_optional_value($plot->{observation_unit_id})
        || _clean_optional_value($plot->{observationUnitDbId});
}

sub _existing_trial_plot_name {
    my $plot = shift || {};

    return _clean_optional_value($plot->{plot_name})
        || _clean_optional_value($plot->{plotname})
        || _clean_optional_value($plot->{uniquename})
        || _clean_optional_value($plot->{observationunit_uniquename})
        || _clean_optional_value($plot->{observation_unit_name})
        || _clean_optional_value($plot->{observationUnitName});
}

sub _reported_existing_plot_number {
    my $plot = shift || {};
    my $plot_name = _existing_trial_plot_name($plot);

    return _clean_optional_value($plot->{plot_number})
        || _clean_optional_value($plot->{'plot number'})
        || _clean_optional_value($plot->{plotn})
        || _clean_optional_value($plot->{plot_no})
        || _clean_optional_value($plot->{plot_No})
        || _clean_optional_value($plot->{plot_num})
        || _clean_optional_value($plot->{plot_num_per_block})
        || _clean_optional_value($plot->{obsunit_plot_number})
        || _clean_optional_value($plot->{observationunit_plot_number})
        || _clean_optional_value($plot->{plot})
        || _plot_number_from_plot_name($plot_name);
}

sub _plot_number_from_plot_name {
    my $plot_name = _clean_optional_value(shift);

    return '' unless $plot_name;
    return $1 if $plot_name =~ /(?:^|[_-])PLOT[_-]?(\d+)\s*$/i;
    return $1 if $plot_name =~ /(?:^|[_-])plot[_-]?(\d+)\s*$/i;
    return '';
}

sub _multi_trial_layout_type_id {
    my ($self, $c) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $cvterm = $schema->resultset('Cv::Cvterm')->find({ name => 'multi_trial_layout_json' });

    die "Cvterm multi_trial_layout_json was not found" unless $cvterm;

    return $cvterm->cvterm_id;
}

sub _layout_key_matches {
    my ($layout, $year, $season) = @_;

    return ($layout->{year} // '') eq ($year // '') &&
           ($layout->{season} // '') eq ($season // '');
}

sub save_layout :Path('/ajax/trialallocation/save_layout') Args(0) {
    my ($self, $c) = @_;

    my $json_string = $c->req->param('layout');
    my $layout = eval { decode_json($json_string) };

    if (!$layout) {
        $c->stash->{rest} = {
            success => 0,
            error   => "Invalid JSON in 'layout' param: $@"
        };
        return;
    }

    my $location_id = $layout->{farm}->{location_id};
    my $year = $layout->{year};
    my $season = $layout->{season};

    $season = '' unless defined $season;

    if (!$location_id || $location_id !~ /^\d+$/ || !$year) {
        $c->stash->{rest} = {
            success => 0,
            error   => 'A valid location and year are required to save layout.'
        };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $type_id = eval { $self->_multi_trial_layout_type_id($c) };
    if ($@) {
        $c->stash->{rest} = { success => 0, error => "$@" };
        return;
    }

    my $location = $schema->resultset('NaturalDiversity::NdGeolocation')->find({
        nd_geolocation_id => $location_id
    });
    if (!$location) {
        $c->stash->{rest} = {
            success => 0,
            error   => "Location $location_id was not found."
        };
        return;
    }

    my $prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
        nd_geolocation_id => $location_id,
        type_id => $type_id
    });

    my $stored = { schema_version => 1, layouts => [] };
    if ($prop && $prop->value) {
        my $decoded = eval { decode_json($prop->value) };
        $stored = $decoded if $decoded && ref($decoded) eq 'HASH';
        $stored->{layouts} ||= [];
    }

    my @remaining = grep { !_layout_key_matches($_, $year, $season) } @{$stored->{layouts}};
    push @remaining, $layout;
    $stored->{layouts} = \@remaining;

    my $encoded = encode_json($stored);
    my $existing_trials_updated = 0;
    my $saved = eval {
        $schema->txn_do(sub {
            if ($prop) {
                $prop->value($encoded);
                $prop->update();
            } else {
                $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({
                    nd_geolocation_id => $location_id,
                    type_id => $type_id,
                    value => $encoded
                });
            }
            $existing_trials_updated = _update_existing_trial_layouts_from_multi_layout($schema, $layout);
        });
        1;
    };

    if (!$saved) {
        $c->stash->{rest} = {
            success => 0,
            error => "Could not save layout: $@"
        };
        return;
    }

    $c->stash->{rest} = {
        success => 1,
        message => 'Layout saved.',
        layout_count => scalar @remaining,
        existing_trials_updated => $existing_trials_updated
    };
}

sub _update_existing_trial_layouts_from_multi_layout {
    my ($schema, $layout) = @_;

    my $trial_layout_json_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_layout_json', 'project_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();

    my $updated_trials = 0;

    foreach my $placed_trial (@{$layout->{placed_trials} || []}) {
        my $project_id = _clean_optional_value($placed_trial->{existing_project_id});
        next unless $project_id && $project_id =~ /^\d+$/;

        my $project = $schema->resultset('Project::Project')->find({ project_id => $project_id });
        die "Existing trial $project_id was not found.\n" unless $project;

        my $layout_prop = $project->projectprops->find({ type_id => $trial_layout_json_type_id });
        my $design = {};
        if ($layout_prop && $layout_prop->value) {
            my $decoded = eval { decode_json($layout_prop->value) };
            die "Could not decode trial_layout_json for trial $project_id: $@\n" if $@;
            $design = $decoded if $decoded && ref($decoded) eq 'HASH';
        }

        foreach my $plot (@{$placed_trial->{plots} || []}) {
            my $row = _clean_optional_value($plot->{row});
            my $col = _clean_optional_value($plot->{col});
            my $plot_id = _clean_optional_value($plot->{plot_id});
            my $plot_name = _clean_optional_value($plot->{plot_name});
            my $plot_number = _clean_optional_value($plot->{plot_number}) || _clean_optional_value($plot->{original_plot_number});

            die "Existing trial $project_id has a placed plot without row or column.\n" unless $row ne '' && $col ne '';

            my $entry_key = _find_trial_layout_entry_key($design, $plot_id, $plot_name, $plot_number);
            $entry_key ||= $plot_number || $plot_id || _clean_optional_value($plot->{design_index});
            next unless defined $entry_key && $entry_key ne '';

            $design->{$entry_key} ||= {};
            $plot_id ||= _clean_optional_value($design->{$entry_key}->{plot_id});

            if ($plot_id && $plot_id =~ /^\d+$/) {
                $schema->resultset("Stock::Stockprop")->update_or_create({
                    type_id => $row_number_type_id,
                    stock_id => $plot_id,
                    rank => 0,
                    value => $row
                }, { key => 'stockprop_c1' });

                $schema->resultset("Stock::Stockprop")->update_or_create({
                    type_id => $col_number_type_id,
                    stock_id => $plot_id,
                    rank => 0,
                    value => $col
                }, { key => 'stockprop_c1' });
            }

            $design->{$entry_key}->{row_number} = $row;
            $design->{$entry_key}->{col_number} = $col;
            $design->{$entry_key}->{plot_id} = $plot_id if $plot_id;
            $design->{$entry_key}->{plot_name} = $plot_name if $plot_name;
            $design->{$entry_key}->{plot_number} = $plot_number if $plot_number;
            $design->{$entry_key}->{block_number} = _clean_optional_value($plot->{block}) if _clean_optional_value($plot->{block}) ne '';
            $design->{$entry_key}->{accession_name} = _clean_optional_value($plot->{accession_name}) if _clean_optional_value($plot->{accession_name}) ne '';
            $design->{$entry_key}->{is_a_control} = $plot->{is_control} ? 1 : 0 if exists $plot->{is_control};
        }

        $schema->resultset('Project::Projectprop')->update_or_create({
            project_id => $project_id,
            type_id => $trial_layout_json_type_id,
            rank => 0,
            value => encode_json($design)
        }, { key => 'projectprop_c1' });

        $updated_trials++;
    }

    return $updated_trials;
}

sub _find_trial_layout_entry_key {
    my ($design, $plot_id, $plot_name, $plot_number) = @_;

    return $plot_number if $plot_number && exists $design->{$plot_number};

    foreach my $key (keys %{$design || {}}) {
        my $entry = $design->{$key} || {};
        return $key if $plot_id && defined $entry->{plot_id} && "$entry->{plot_id}" eq "$plot_id";
        return $key if $plot_name && defined $entry->{plot_name} && "$entry->{plot_name}" eq "$plot_name";
        return $key if $plot_number && defined $entry->{plot_number} && "$entry->{plot_number}" eq "$plot_number";
    }

    return;
}

sub get_layout :Path('/ajax/trialallocation/get_layout') Args(0) {
    my ($self, $c) = @_;

    my $location_id = $c->req->param('location_id');
    my $year = $c->req->param('year');
    my $season = $c->req->param('season');

    $season = '' unless defined $season;

    if (!$location_id || $location_id !~ /^\d+$/ || !$year) {
        $c->stash->{rest} = {
            success => 0,
            error => 'A valid location and year are required to load layout.'
        };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $type_id = eval { $self->_multi_trial_layout_type_id($c) };
    if ($@) {
        $c->stash->{rest} = { success => 0, error => "$@" };
        return;
    }

    my $prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
        nd_geolocation_id => $location_id,
        type_id => $type_id
    });

    if (!$prop || !$prop->value) {
        $c->stash->{rest} = { success => 1, found => 0 };
        return;
    }

    my $stored = eval { decode_json($prop->value) };
    if (!$stored || ref($stored) ne 'HASH') {
        $c->stash->{rest} = {
            success => 0,
            error => 'Stored layout JSON could not be decoded.'
        };
        return;
    }

    my ($layout) = grep { _layout_key_matches($_, $year, $season) } @{$stored->{layouts} || []};

    $c->stash->{rest} = {
        success => 1,
        found => $layout ? 1 : 0,
        layout => $layout
    };
}

sub delete_layout :Path('/ajax/trialallocation/delete_layout') Args(0) {
    my ($self, $c) = @_;

    if (!$c->user || !$c->user->check_roles('curator')) {
        $c->stash->{rest} = { success => 0, error => 'Only curators can delete a saved layout view.' };
        return;
    }

    my $location_id = $c->req->param('location_id');
    my $year = $c->req->param('year');
    my $season = $c->req->param('season');
    $season = '' unless defined $season;

    if (!$location_id || $location_id !~ /^\d+$/ || !$year) {
        $c->stash->{rest} = { success => 0, error => 'A valid location and year are required to delete layout.' };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $type_id = eval { $self->_multi_trial_layout_type_id($c) };
    if ($@) {
        $c->stash->{rest} = { success => 0, error => "$@" };
        return;
    }

    my $prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
        nd_geolocation_id => $location_id,
        type_id => $type_id
    });

    if (!$prop || !$prop->value) {
        $c->stash->{rest} = { success => 0, error => 'No saved layout view was found.' };
        return;
    }

    my $stored = eval { decode_json($prop->value) };
    if (!$stored || ref($stored) ne 'HASH') {
        $c->stash->{rest} = { success => 0, error => 'Stored layout JSON could not be decoded.' };
        return;
    }

    my @remaining = grep { !_layout_key_matches($_, $year, $season) } @{$stored->{layouts} || []};
    if (@remaining == scalar(@{$stored->{layouts} || []})) {
        $c->stash->{rest} = { success => 0, error => 'No matching saved layout view was found.' };
        return;
    }

    $stored->{layouts} = \@remaining;
    $prop->value(encode_json($stored));
    $prop->update();

    $c->stash->{rest} = { success => 1, layout_count => scalar @remaining };
}

sub delete_layout_trial :Path('/ajax/trialallocation/delete_layout_trial') Args(0) {
    my ($self, $c) = @_;

    if (!$c->user || !$c->user->check_roles('curator')) {
        $c->stash->{rest} = { success => 0, error => 'Only curators can remove a trial from a saved layout view.' };
        return;
    }

    my $location_id = $c->req->param('location_id');
    my $year = $c->req->param('year');
    my $season = $c->req->param('season');
    my $root = _clean_optional_value($c->req->param('root'));
    my $trial_index = _clean_optional_value($c->req->param('trial_index'));
    $season = '' unless defined $season;

    if (!$location_id || $location_id !~ /^\d+$/ || !$year) {
        $c->stash->{rest} = { success => 0, error => 'A valid location and year are required to update layout.' };
        return;
    }
    if (!$root && $trial_index eq '') {
        $c->stash->{rest} = { success => 0, error => 'A trial identifier is required.' };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $type_id = eval { $self->_multi_trial_layout_type_id($c) };
    if ($@) {
        $c->stash->{rest} = { success => 0, error => "$@" };
        return;
    }

    my $prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
        nd_geolocation_id => $location_id,
        type_id => $type_id
    });

    if (!$prop || !$prop->value) {
        $c->stash->{rest} = { success => 0, error => 'No saved layout view was found.' };
        return;
    }

    my $stored = eval { decode_json($prop->value) };
    if (!$stored || ref($stored) ne 'HASH') {
        $c->stash->{rest} = { success => 0, error => 'Stored layout JSON could not be decoded.' };
        return;
    }

    my $removed = 0;
    foreach my $layout (@{$stored->{layouts} || []}) {
        next unless _layout_key_matches($layout, $year, $season);

        my @placed = grep {
            my $matches_root = $root && (($_->{root} || '') eq $root);
            my $matches_index = $trial_index ne '' && (($_->{trial_index} // '') eq $trial_index);
            my $remove = $matches_root || (!$root && $matches_index);
            $removed++ if $remove;
            !$remove;
        } @{$layout->{placed_trials} || []};

        my %remaining_indexes = map { $_->{trial_index} => 1 } @placed;
        my @forms = grep { $remaining_indexes{$_->{trial_index}} } @{$layout->{trial_forms} || []};
        $layout->{placed_trials} = \@placed;
        $layout->{trial_forms} = \@forms;
        last;
    }

    if (!$removed) {
        $c->stash->{rest} = { success => 0, error => 'No matching trial was found in the saved layout view.' };
        return;
    }

    $prop->value(encode_json($stored));
    $prop->update();

    $c->stash->{rest} = { success => 1, removed => $removed };
}

sub _trial_allocation_design_type {
    my $design = shift || '';

    my %design_map = (
        'Row-Column Design' => 'RRC',
        'Doubly-Resolvable Row-Column' => 'DRRC',
        'Un-Replicated Diagonal' => 'URDD',
        'Augmented Row-Column' => 'Augmented',
    );

    return $design_map{$design} || $design;
}

sub _trial_allocation_display_design_type {
    my $design = shift || '';

    my %design_map = (
        RRC => 'Row-Column Design',
        DRRC => 'Doubly-Resolvable Row-Column',
        URDD => 'Un-Replicated Diagonal',
    );

    return $design_map{$design} || $design;
}

sub _sanitize_trial_allocation_trial_name {
    my $trial_name = _clean_optional_value(shift);
    $trial_name =~ s/\s+/_/g;
    $trial_name =~ s/[\\\/:,"*?<>|]+/_/g;
    $trial_name =~ s/_+/_/g;
    $trial_name =~ s/^_+|_+$//g;
    return $trial_name;
}

sub _clean_optional_value {
    my $value = shift;
    $value = '' unless defined $value;
    $value =~ s/^\s+|\s+$//g;
    return '' if $value =~ /^Select /i;
    return $value;
}

sub _plot_name_from_trial_and_number {
    my ($trial_name, $plot_number) = @_;
    my $plot_name = ($trial_name || 'trial') . '_PLOT_' . ($plot_number || '');
    $plot_name =~ s/\s+/_/g;
    $plot_name =~ s/[\/\\]+/_/g;
    return $plot_name;
}

sub _layout_to_multiple_trial_rows {
    my ($layout, $schema) = @_;

    my $farm = $layout->{farm} || {};
    my $breeding_program = $layout->{breeding_program} || {};
    my $field = $layout->{field} || {};
    my $location_id = $farm->{location_id};
    my $program_id = $breeding_program->{program_id};
    my $year = $layout->{year};

    die "A valid location and year are required to save trials.\n"
        if !$location_id || $location_id !~ /^\d+$/ || !$year;
    die "A valid breeding program is required to save trials.\n"
        if !$program_id || $program_id !~ /^\d+$/;

    my $location = $schema->resultset('NaturalDiversity::NdGeolocation')->find({
        nd_geolocation_id => $location_id
    });
    die "Location $location_id was not found.\n" unless $location;

    my $program = $schema->resultset('Project::Project')->find({
        project_id => $program_id
    });
    die "Breeding program $program_id was not found.\n" unless $program;

    my %forms_by_index = map { $_->{trial_index} => $_ } @{$layout->{trial_forms} || []};
    my @rows;

    foreach my $placed_trial (sort { ($a->{trial_index} || 0) <=> ($b->{trial_index} || 0) } @{$layout->{placed_trials} || []}) {
        my $trial_index = $placed_trial->{trial_index};
        my $form = $forms_by_index{$trial_index} || {};
        my $trial_name = _sanitize_trial_allocation_trial_name($form->{name});
        my $design_type = _trial_allocation_design_type(_clean_optional_value($form->{design}));

        die "Trial " . ($trial_index + 1) . " is missing a trial name.\n" unless $trial_name;
        die "Trial $trial_name is missing a valid design type.\n" unless $design_type;

        foreach my $plot (sort { ($a->{design_index} || 0) <=> ($b->{design_index} || 0) } @{$placed_trial->{plots} || []}) {
            my $plot_number = _clean_optional_value($plot->{plot_number}) || _clean_optional_value($plot->{original_plot_number});
            my $accession_name = _clean_optional_value($plot->{filler_accession}) || _clean_optional_value($plot->{accession_name});
            my $block_number = _clean_optional_value($plot->{block}) || 1;

            die "Trial $trial_name has a plot without a plot number.\n" unless $plot_number;
            die "Trial $trial_name plot $plot_number has no accession name.\n" unless $accession_name;

            push @rows, {
                trial_name => $trial_name,
                breeding_program => $program->name,
                location => $location->description,
                year => $year,
                design_type => $design_type,
                description => _clean_optional_value($form->{description}) || $trial_name,
                accession_name => $accession_name,
                plot_number => $plot_number,
                block_number => $block_number,
                plot_name => _plot_name_from_trial_and_number($trial_name, $plot_number),
                trial_type => _clean_optional_value($form->{type}),
                trial_stock_type => 'accession',
                plot_width => _clean_optional_value($form->{plot_width}) || _clean_optional_value($field->{plot_width}),
                plot_length => _clean_optional_value($form->{plot_length}) || _clean_optional_value($field->{plot_length}),
                is_a_control => $plot->{filler_accession} ? 0 : ($plot->{is_control} ? 1 : 0),
                row_number => _clean_optional_value($plot->{row}),
                col_number => _clean_optional_value($plot->{col})
            };
        }
    }

    die "There are no placed trial plots to save.\n" unless @rows;

    return \@rows;
}

sub _write_multiple_trial_upload_file {
    my ($self, $c, $rows) = @_;

    my @columns = qw|trial_name breeding_program location year design_type description accession_name plot_number block_number plot_name trial_type trial_stock_type plot_width plot_length is_a_control row_number col_number|;

    $c->tempfiles_subdir("trial_allocation");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE => "trial_allocation/multi_trial_XXXXX");
    my $filepath = $c->config->{basepath} . "/" . $tempfile . ".tsv";
    close($fh);

    open(my $out, ">", $filepath) or die "Could not write multi-trial upload file: $!";
    my $csv = Text::CSV->new({ sep_char => "\t", binary => 1, eol => "\n" });
    $csv->print($out, \@columns);
    foreach my $row (@$rows) {
        $csv->print($out, [ map { defined $row->{$_} ? $row->{$_} : '' } @columns ]);
    }
    close($out);

    return $filepath;
}

sub _parse_multiple_trial_upload_file {
    my ($schema, $filepath) = @_;

    my $parser = CXGN::Trial::ParseUpload->new(
        chado_schema => $schema,
        filename => $filepath
    );
    $parser->load_plugin('MultipleTrialDesignGeneric');
    my $parsed_data = $parser->parse();

    if ($parser->has_parse_errors()) {
        my $errors = $parser->get_parse_errors();
        die join("\n", @{$errors->{error_messages} || []}) . "\n";
    }
    if ($parser->has_parse_warnings()) {
        my $warnings = $parser->get_parse_warnings();
        die join("\n", @{$warnings->{warning_messages} || []}) . "\n";
    }
    die "There is no parsed data from the generated multi-trial file.\n" if !$parsed_data;

    return $parsed_data;
}

sub save_trials_database :Path('/ajax/trialallocation/save_trials_database') Args(0) {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->stash->{rest} = { success => 0, error => "You need to be logged in to save trials." };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)) {
        $c->stash->{rest} = { success => 0, error => "You have insufficient privileges to save trials." };
        return;
    }

    my $json_string = $c->req->param('layout');
    my $layout = eval { decode_json($json_string) };
    if (!$layout) {
        $c->stash->{rest} = {
            success => 0,
            error => "Invalid JSON in 'layout' param: $@"
        };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $username = $c->user()->get_object()->get_username();
    my @saved_trials;
    my $existing_trials_updated = 0;

    eval {
        my $new_trial_layout = _layout_without_existing_trials($layout);
        my $rows = @{$new_trial_layout->{placed_trials} || []} ? _layout_to_multiple_trial_rows($new_trial_layout, $schema) : [];
        my ($filepath, $parsed_data);
        if (@$rows) {
            $filepath = $self->_write_multiple_trial_upload_file($c, $rows);
            $parsed_data = _parse_multiple_trial_upload_file($schema, $filepath);
        }

        $schema->txn_do(sub {
            $existing_trials_updated = _update_existing_trial_layouts_from_multi_layout($schema, $layout);

            foreach my $trial_name (sort keys %{$parsed_data || {}}) {
                my $trial_design = $parsed_data->{$trial_name};
                my %trial_info_hash = (
                    chado_schema => $schema,
                    dbh => $dbh,
                    owner_id => $user_id,
                    trial_year => $trial_design->{year},
                    trial_description => $trial_design->{description},
                    trial_location => $trial_design->{location},
                    trial_name => $trial_name,
                    design_type => $trial_design->{design_type},
                    trial_stock_type => $trial_design->{trial_stock_type},
                    design => $trial_design->{design_details},
                    program => $trial_design->{breeding_program},
                    upload_trial_file => $filepath,
                    operator => $username
                );

                $trial_info_hash{trial_type} = $trial_design->{trial_type} if $trial_design->{trial_type};
                $trial_info_hash{plot_width} = $trial_design->{plot_width} if $trial_design->{plot_width};
                $trial_info_hash{plot_length} = $trial_design->{plot_length} if $trial_design->{plot_length};
                $trial_info_hash{field_size} = $trial_design->{field_size} if $trial_design->{field_size};

                my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);
                die "Trial name \"" . $trial_create->get_trial_name() . "\" already exists.\n"
                    if $trial_create->trial_name_already_exists();

                my $save = $trial_create->save_trial();
                die $save->{error} . "\n" if $save->{error};

                my $trial_id = $save->{trial_id};
                die "Trial $trial_name could not be saved.\n" unless $trial_id;

                my $time = DateTime->now();
                my $timestamp = $time->ymd();
                my $calendar_funcs = CXGN::Calendar->new({});
                my $formatted_date = $calendar_funcs->check_value_format($timestamp);
                my $upload_date = $calendar_funcs->display_start_date($formatted_date);

                my %trial_activity;
                $trial_activity{'Trial Uploaded'}{'user_id'} = $user_id;
                $trial_activity{'Trial Uploaded'}{'activity_date'} = $upload_date;

                my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $schema });
                $trial_activity_obj->trial_activities(\%trial_activity);
                $trial_activity_obj->parent_id($trial_id);
                $trial_activity_obj->store();

                push @saved_trials, {
                    trial_id => $trial_id,
                    name => $trial_name
                };
            }
        });

        die "There are no new trials or existing-trial coordinate updates to save.\n"
            unless @saved_trials || $existing_trials_updated;
    };
    if ($@) {
        my $error = "$@";
        $error =~ s/\s+$//;
        $c->stash->{rest} = { success => 0, error => $error };
        return;
    }

    $c->stash->{rest} = {
        success => 1,
        trials => \@saved_trials,
        existing_trials_updated => $existing_trials_updated
    };
}

sub _layout_without_existing_trials {
    my $layout = shift;

    my @placed_trials = grep {
        !_clean_optional_value($_->{existing_project_id})
    } @{$layout->{placed_trials} || []};
    my %trial_indexes = map { $_->{trial_index} => 1 } @placed_trials;
    my @trial_forms = grep {
        $trial_indexes{$_->{trial_index}}
    } @{$layout->{trial_forms} || []};

    my %copy = %$layout;
    $copy{placed_trials} = \@placed_trials;
    $copy{trial_forms} = \@trial_forms;

    return \%copy;
}





sub save_coordinates :Path('/ajax/trialallocation/save_coordinates') :Args(0) {
    my ($self, $c) = @_;

    my $json_string = $c->req->param('trial');
    my $data = eval { decode_json($json_string) };

    # print STDERR Dumper \$data;

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
    my $breeding_program_id = $data->{breeding_program_id};
    # Log or process
    $c->log->debug("Got trial $trial_name with coords:");
    # $c->log->debug(" -> $_->[0], $_->[1]") for @$coords;


    ## Adding coordinates to the trial
    # Open original file
    open my $in, '<', $design_file or die "Can't open $design_file: $!";

    my $csv_in = Text::CSV->new({ sep_char => "\t", binary => 1, auto_diag => 1 });

    # Read header
    my $header = $csv_in->getline($in);
    my %col_index = map { $header->[$_] => $_ } 0 .. $#$header;
    my $plot_col = exists $col_index{plots} ? $col_index{plots} : undef;

    if (!exists $col_index{row_number}) {
      push @$header, 'row_number';
      $col_index{row_number} = $#$header;
    }
    if (!exists $col_index{col_number}) {
      push @$header, 'col_number';
      $col_index{col_number} = $#$header;
    }
    if (!exists $col_index{breeding_program_id}) {
      push @$header, 'breeding_program_id';
      $col_index{breeding_program_id} = $#$header;
    }

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
      my $coord = $coords->[$i];
      my ($r, $c, $plot_number);

      if (ref($coord) eq 'HASH') {
        $r = $coord->{row};
        $c = $coord->{col};
        $plot_number = $coord->{plot_number};
      } else {
        ($r, $c) = @$coord;
      }

      $rows[$i]->[ $col_index{row_number} ] = $r;
      $rows[$i]->[ $col_index{col_number} ] = $c;
      $rows[$i]->[ $col_index{breeding_program_id} ] = $breeding_program_id if defined $breeding_program_id;
      $rows[$i]->[ $plot_col ] = $plot_number if defined $plot_col && defined $plot_number && $plot_number ne '';
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

  return ($n_row, $n_col, \@design);
}

sub arrange_design {
  my ($design_file, $design_type) = @_;

  open my $fh, "<", $design_file or return ("Cannot open $design_file", []);
  my @lines = <$fh>;
  chomp @lines;
  close $fh;

  my @design;

  if ($design_type eq 'Row-Column Design') {
      # Transpose matrix
      my @matrix = map { [split /\t/] } @lines;
      my $n_rows = scalar @matrix;
      my $n_cols = scalar @{$matrix[0]};
      my @transposed;

      for my $col (0 .. $n_cols - 1) {
        my @new_row;
        for my $row (0 .. $n_rows - 1) {
          $new_row[$row] = $matrix[$row][$col];
        }
        push @transposed, \@new_row;
      }

      # Prepare output with ONLY the required columns
      my @output_lines;
      push @output_lines, join("\t", qw(block plots all_entries rep is_control));

      for my $i (0 .. $#transposed) {  # skip header row
        my $row = $transposed[$i];
        next unless @$row >= 7;  # must have at least up to V6

        my $block          = $row->[1];  # V1
        my $plot_number    = $row->[4];  # V4
        my $accession_name = $row->[5];  # V5
        my $rep            = $row->[1];  # same as block
        my $is_control     = $row->[6];  # V6

        push @output_lines, join("\t", $block, $plot_number, $accession_name, $rep, $is_control);

        push @design, {
          block          => $block,
          plot_number    => $plot_number,
          accession_name => $accession_name,
          rep            => $rep,
          is_control     => $is_control,
        };
      }

      # Overwrite original file with the selected columns
      open my $outfh, ">", $design_file or return ("Cannot write to $design_file", []);
      print $outfh "$_\n" for @output_lines;
      close $outfh;
    }


  else {
    # Standard design based on column headers
    my @columns = split /\t/, shift @lines;

    my %col_index;
    for my $i (0 .. $#columns) {
      $col_index{$columns[$i]} = $i;
    }

    for my $line (@lines) {
      next unless $line =~ /\S/;
      my @fields = split /\t/, $line;

      push @design, {
        plot_number    => $fields[ $col_index{plots} ],
        block          => $fields[ $col_index{block} ],
        accession_name => $fields[ $col_index{all_entries} ],
        rep            => $fields[ $col_index{rep} ],
        is_control     => $fields[ $col_index{is_control} ],
      };
    }
  }



  return (\@design);
}


1;
