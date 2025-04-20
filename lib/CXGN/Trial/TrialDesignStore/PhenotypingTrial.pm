
package CXGN::Trial::TrialDesignStore::PhenotypingTrial;

use Moose;
use Try::Tiny;
use JSON;
use Data::Dumper;

extends 'CXGN::Trial::TrialDesignStore::AbstractTrial';

sub BUILD {   # adjust the cvterm ids for phenotyping trials
    my $self = shift;

    #print STDERR "PhenotypingTrial BUILD setting stock type id etc....\n";
    $self->set_nd_experiment_type_id(SGN::Model::Cvterm->get_cvterm_row($self->get_bcs_schema(), 'field_layout', 'experiment_type')->cvterm_id());
    $self->set_stock_type_id($self->get_plot_cvterm_id);
    $self->set_stock_relationship_type_id($self->get_plot_of_cvterm_id);
    $self->set_source_stock_types([$self->get_accession_cvterm_id, $self->get_cross_cvterm_id, $self->get_family_name_cvterm_id]);

    $self->set_valid_properties(
	[
        'seedlot_name',
        'num_seed_per_plot',
        'weight_gram_seed_per_plot',
        'stock_name',
        'plot_name',
        'plot_number',
        'block_number',
        'rep_number',
        'is_a_control',
        'range_number',
        'row_number',
        'col_number',
        'plant_names',
        'plot_num_per_block',
        'subplots_names', #For splotplot
        'treatments', #For splitplot
        'subplots_plant_names', #For splitplot
        'additional_info', # For brapi additional info storage
        'external_refs' # For brapi external reference storage
	]);

}

sub validate_design {
    my $self = shift;

    #print STDERR "validating design\n";
    my $chado_schema = $self->get_bcs_schema;
    my $design_type = $self->get_design_type;
    my %design = %{$self->get_design};
    my $error = '';

    if (defined $design_type){
        if ($design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type ne 'MAD' && $design_type ne 'Lattice' && $design_type ne 'Augmented' && $design_type ne 'RCBD' && $design_type ne 'RRC' && $design_type ne 'DRRC' && $design_type ne 'URDD'&& $design_type ne 'ARC' && $design_type ne 'p-rep' && $design_type ne 'splitplot' && $design_type ne 'stripplot' && $design_type ne 'greenhouse' && $design_type ne 'Westcott' && $design_type ne 'Analysis'){
            $error .= "Design $design_type type must be either: CRD, Alpha, Augmented, Lattice, RCBD, RRC, DRRC, URDD, ARC, MAD, p-rep, greenhouse, Westcott, splitplot or stripplot";
            return $error;
        }
    }

    my @valid_properties = @{$self->get_valid_properties()};
    my %allowed_properties = map {$_ => 1} @valid_properties;

    my %seen_stock_names;
    my %seen_source_names;
    my %seen_accession_names;
    my %seen_plot_numbers;
    my @plot_numbers;

    foreach my $stock (keys %design){
        if ($stock eq 'treatments'){
            next;
        }
        if (!exists($design{$stock}->{plot_number})) {
            $error .= "Property: plot_number is required for stock " . $stock;
        }

        foreach my $property (keys %{$design{$stock}}){
            if (!exists($allowed_properties{$property})) {
                $error .= "Property: $property not allowed! ";
            }
            if ($property eq 'stock_name') {
                my $stock_name = $design{$stock}->{$property};
                $seen_accession_names{$stock_name}++;
            }
            if ($property eq 'seedlot_name') {
                my $stock_name = $design{$stock}->{$property};
                if ($stock_name){
                    $seen_source_names{$stock_name}++;
                }
            }
            if ($property eq 'plot_name') {
                my $plot_name = $design{$stock}->{$property};
                # Check that there are no plant names, if so, this could be a lookup value for an existing plot
                # So, we don't validate that the plot name is unique
                if ($design{$stock}->{plant_names} && scalar $design{$stock}->{plant_names} > 0) { next; }
                $seen_stock_names{$plot_name}++;
            }
            if ($property eq 'plant_names') {
                my $plant_names = $design{$stock}->{$property};
                foreach (@$plant_names) {
                    $seen_stock_names{$_}++;
                }
            }
            if ($property eq 'subplots_names') {
                my $subplot_names = $design{$stock}->{$property};
                foreach (@$subplot_names) {
                    $seen_stock_names{$_}++;
                }
            }

            if ($property eq 'plot_number') {
                my $plot_number = $design{$stock}->{$property};
                if ($design{$stock}->{plant_names} && scalar $design{$stock}->{plant_names} > 0) { next; }
                $seen_plot_numbers{$plot_number}++;
                push @plot_numbers, $plot_number;
            }
        }
    }

    my @stock_names = keys %seen_stock_names;
    my @source_names = keys %seen_source_names;
    my @accession_names = keys %seen_accession_names;
    if(scalar(@stock_names)<1){
        $error .= "You cannot create a trial with less than one plot.";
    }
    #if(scalar(@source_names)<1){
    #	$error .= "You cannot create a trial with less than one seedlot.";
    #}
    if(scalar(@accession_names)<1){
        $error .= "You cannot create a trial with less than one accession.";
    }
    my $subplot_type_id = $self->get_subplot_cvterm_id();      #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type')->cvterm_id();
    my $plot_type_id = $self->get_plot_cvterm_id();            #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = $self->get_plant_cvterm_id();          #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_type_id = $self->get_tissue_sample_cvterm_id(); #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $stocks = $chado_schema->resultset('Stock::Stock')->search({
        type_id=>[$subplot_type_id, $plot_type_id, $plant_type_id, $tissue_type_id],
        uniquename=>{-in=>\@stock_names}
    });
    while (my $s = $stocks->next()) {
        $error .= sprintf("Name %s already exists in the database.", $s->uniquename);
    }

    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($chado_schema,'seedlots',\@source_names)->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        $error .=  "The following seedlots are not in the database as uniquenames or synonyms or are marked as discarded: ".join(',',@seedlots_missing);
    }

    my @source_stock_types = @{$self->get_source_stock_types()};

    print STDERR "Source Stock types = ".join(", ",@source_stock_types)."\n";
    print STDERR "Accession names = ".join(", ", @accession_names)."\n";

    # Run one query to get all stocks matching the accession names
    my $rs = $chado_schema->resultset('Stock::Stock')->search({
        'is_obsolete' => { '!=' => 't' },
        'type_id'     => { -in => \@source_stock_types },
        'uniquename'  => { -in => \@accession_names },
    });

    # Record found names
    my %found_data;
    while (my $s = $rs->next) {
        my $uname = $s->uniquename;
        print STDERR "FOUND $uname\n";
        $found_data{$uname} = 1;
    }

    # Report any missing names
    foreach my $name (@accession_names) {
        if (!$found_data{$name}) {
            $error .= "The following name is not in the database: $name.\n";
        }
    }

    # Check that the plot numbers are unique in the db for the given study
    my $trial_layout_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'trial_layout_json', 'project_property')->cvterm_id();
    my $plot_number_select = "select projectprop.value from project " .
        "join projectprop on projectprop.project_id = project.project_id " .
        "where projectprop.type_id = $trial_layout_cvterm_id and project.project_id = ?";
    my $sth = $chado_schema->storage->dbh->prepare($plot_number_select);
    $sth->execute($self->get_trial_id());
    while (my ($trial_layout_json) = $sth->fetchrow_array()) {
        my $trial_layout_json = decode_json($trial_layout_json);
        foreach my $key (keys %{$trial_layout_json}) {
            if (defined %seen_plot_numbers{$key}) {
                $error .= "Plot number '$key' already exists in the database for that study. Plot number must be unique.";
            }
        }
    }

    return $error;
}



1;
