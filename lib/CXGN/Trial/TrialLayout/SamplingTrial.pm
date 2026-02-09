
package CXGN::Trial::TrialLayout::SamplingTrial;

use Moose;
use namespace::autoclean;
use Data::Dumper;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';


sub BUILD {
    my $self = shift;

    print STDERR "BUILD CXGN::Trial::TrialLayout::SamplingTrial...\n";

    #    $self->set_source_primary_stock_types( [ "accession" ]);
    $self->set_source_stock_types( [ "accession", "plot", "plant", "tissue_sample", "subplot" ] );
    $self->set_source_stock_types( [ "accession", "subplot" ] );
    $self->set_relationship_types( [ "tissue_sample_of" ] );
    $self->set_target_stock_types( [ "tissue_sample" ] );

    $self->convert_source_stock_types_to_ids();

        # probably better to lazy load the action design...
    #

    $self->_lookup_trial_id();

}



sub retrieve_plot_info {
     my $self = shift;
     my $plot = shift;
     my $design = shift;

     # print STDERR "DESIGN INFO = ".Dumper($design);

     $self->SUPER::retrieve_plot_info($plot, $design);

     my $plot_properties = $plot->search_related('stockprops', { type_id => { -in => [ $self->cvterm_id('plot number') ] }});

     my $plot_number;
     if (my $row = $plot_properties->next()) {
	 $plot_number = $row->value();
     }

     if (! $plot_number) { print STDERR "NO PLOT NUMBER AVAILABLE!!!!\n"; }

     my $project = $self->get_project();

     my $source_rs = $plot->search_related('stock_relationship_subjects')->search(
	 { 'me.type_id' => { -in => $self->get_relationship_type_ids() }, 'object.type_id' => { -in => $self->get_source_stock_type_ids() } },
	 { 'join' => 'object' }
	 )->search_related('object');

	 # was $accession_cvterm_id, $plot_cvterm_id, $plant_cvterm_id, $tissue_cvterm_id, $subplot_cvterm_id


     print STDERR "Now dealing with metadata... [".$source_rs->count()."]\n";
     while (my $r=$source_rs->next){
	 print STDERR "TYPE= ".$r->type_id()."\n";
	 if ($r->type_id == $self->cvterm_id('accession')){
	     print STDERR "Dealing with accession metadata.\n";
	     $design->{$plot_number}->{"source_accession_id"} = $r->stock_id;
	     $design->{$plot_number}->{"source_accession_name"} = $r->uniquename;
	     $design->{$plot_number}->{"source_observation_unit_name"} = $r->uniquename;
	     $design->{$plot_number}->{"source_observation_unit_id"} = $r->stock_id;
	 }
	 if ($r->type_id == $self->cvterm_id('plot')){
	     print STDERR "Dealing with plot metadata.\n";
	     $design->{$plot_number}->{"source_plot_id"} = $r->stock_id;
	     $design->{$plot_number}->{"source_plot_name"} = $r->uniquename;
	     $design->{$plot_number}->{"source_observation_unit_name"} = $r->uniquename;
	     $design->{$plot_number}->{"source_observation_unit_id"} = $r->stock_id;
	 }
	 if ($r->type_id == $self->cvterm_id('plant')){
	     print STDERR "Dealing with plant metadata\n";
	     $design->{$plot_number}->{"source_plant_id"} = $r->stock_id;
	     $design->{$plot_number}->{"source_plant_name"} = $r->uniquename;
	     $design->{$plot_number}->{"source_observation_unit_name"} = $r->uniquename;
	     $design->{$plot_number}->{"source_observation_unit_id"} = $r->stock_id;
	 }
	 if ($r->type_id == $self->cvterm_id('tissue_sample')){
	     print STDERR "Dealing with tieeus metadata\n";
	      $design->{$plot_number}->{"source_tissue_id"} = $r->stock_id;
	      $design->{$plot_number}->{"source_tissue_name"} = $r->uniquename;
	      $design->{$plot_number}->{"source_observation_unit_name"} = $r->uniquename;
	      $design->{$plot_number}->{"source_observation_unit_id"} = $r->stock_id;
	 }
     }
     my $organism_q = "SELECT species, genus FROM organism WHERE organism_id = ?;";
     my $h = $self->get_schema->storage->dbh()->prepare($organism_q);
     $h->execute($plot->organism_id);
     my ($species, $genus) = $h->fetchrow_array;
     $design->{$plot_number}->{"species"} = $species;
     $design->{$plot_number}->{"genus"} = $genus;
 }

###

__PACKAGE__->meta()->make_immutable();

1;
