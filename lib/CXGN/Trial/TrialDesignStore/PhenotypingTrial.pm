
package CXGN::Trial::TrialDesignStore::PhenotypingTrial;

use Moose;
use Try::Tiny;

extends 'CXGN::Trial::TrialDesignStore::AbstractTrial';

sub BUILD {   # adjust the cvterm ids for phenotyping trials
    my $self = shift;

    #print STDERR "PhenotypingTrial BUILD setting stock type id etc....\n";
    my @source_stock_types;
    $self->set_nd_experiment_type_id(SGN::Model::Cvterm->get_cvterm_row($self->get_bcs_schema(), 'field_layout', 'experiment_type')->cvterm_id());
    $self->set_stock_type_id($self->get_plot_cvterm_id);
    $self->set_stock_relationship_type_id($self->get_plot_of_cvterm_id);
    @source_stock_types = ($self->get_accession_cvterm_id);
    $self->set_source_stock_types(\@source_stock_types);
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
	]);
    
}

sub validate_design {
    my $self = shift;
    
    #print STDERR "validating design\n";
    my $chado_schema = $self->get_bcs_schema;
    my $design_type = $self->get_design_type;
    my %design = %{$self->get_design}; 
    my $error = '';
    
    if ($design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type ne 'MAD' && $design_type ne 'Lattice' && $design_type ne 'Augmented' && $design_type ne 'RCBD' && $design_type ne 'p-rep' && $design_type ne 'splitplot' && $design_type ne 'greenhouse' && $design_type ne 'Westcott' && $design_type ne 'Analysis'){
        $error .= "Design $design_type type must be either: genotyping_plate, CRD, Alpha, Augmented, Lattice, RCBD, MAD, p-rep, greenhouse, Westcott or splitplot";
        return $error;
    }
    my @valid_properties;
    
    if ($design_type eq 'CRD' || $design_type eq 'Alpha' || $design_type eq 'Augmented' || $design_type eq 'RCBD' || $design_type eq 'p-rep' || $design_type eq 'splitplot' || $design_type eq 'Lattice' || $design_type eq 'MAD' || $design_type eq 'greenhouse' || $design_type eq 'Westcott' || $design_type eq 'Analysis'){
        # valid plot's properties
        @valid_properties = @{$self->get_valid_properties()};
    }
    my %allowed_properties = map {$_ => 1} @valid_properties;
    
    my %seen_stock_names;
    my %seen_source_names;
    my %seen_accession_names;
    
    foreach my $stock (keys %design){
        if ($stock eq 'treatments'){
            next;
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
    my $accession_type_id = $self->get_accession_cvterm_id();  #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_type_id = $self->get_plot_cvterm_id();            #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = $self->get_plant_cvterm_id();          #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_type_id = $self->get_tissue_sample_cvterm_id(); #SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $stocks = $chado_schema->resultset('Stock::Stock')->search({
        type_id=>[$subplot_type_id, $plot_type_id, $plant_type_id, $tissue_type_id],
        uniquename=>{-in=>\@stock_names}
    });
    while (my $s = $stocks->next()) {
        $error .= "Name $s->uniquename already exists in the database.";
    }

    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($chado_schema,'seedlots',\@source_names)->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        $error .=  "The following seedlots are not in the database as uniquenames or synonyms: ".join(',',@seedlots_missing);
    }

#    my @source_stock_types;
#    if ($self->get_is_genotyping) {
#        @source_stock_types = ($accession_type_id, $plot_type_id, $plant_type_id, $tissue_type_id);
#    } else {
    my @source_stock_types = @{$self->get_source_stock_types()};
#    }
    my $rs = $chado_schema->resultset('Stock::Stock')->search({
        'is_obsolete' => { '!=' => 't' },
        'type_id' => {-in=>\@source_stock_types},
        'uniquename' => {-in=>\@accession_names}
    });
    my %found_data;
    while (my $s = $rs->next()) {
        $found_data{$s->uniquename} = 1;
    }
    foreach (@accession_names){
        if (!$found_data{$_}){
            $error .= "The following name is not in the database: $_ .";
        }
    }

    return $error;
}



1;
