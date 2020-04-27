
=head1 NAME

SGN::Controller::AJAX::BreedingProgram  
 REST controller for viewing breeding programs and the data associated with them

=head1 DESCRIPTION


=head1 AUTHOR

Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::BreedingProgram;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use Try::Tiny;
use Math::Round;
use CXGN::BreedingProgram;
use CXGN::Phenotypes::PhenotypeMatrix;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


=head2 action program_trials()
    
  Usage:        /breeders/program/<program_id>/datatables/trials
  Desc:         retrieves trials associated with the breeding program
  Ret:          a table in json suitable for datatables
  Args:
    Side Effects:
  Example:
    
=cut


sub ajax_breeding_program : Chained('/')  PathPart('ajax/breeders/program')  CaptureArgs(1) {
    my ($self, $c, $program_id) = @_;
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $program = CXGN::BreedingProgram->new( { schema=> $schema , program_id => $program_id } );
    
    $c->stash->{schema} = $schema;
    $c->stash->{program} = $program;

}




sub program_trials :Chained('ajax_breeding_program') PathPart('trials') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
  
    my $trials = $program->get_trials();

    my @formatted_trials;
    while (my $trial = $trials->next ) {

	my $name = $trial->name;
	my $id = $trial->project_id;
	my $description = $trial->description;
        push @formatted_trials, [ '<a href="/breeders/trial/'.$id.'">'.$name.'</a>', $description ];
    }
    $c->stash->{rest} = { data => \@formatted_trials };
}


sub phenotype_summary : Chained('ajax_breeding_program') PathPart('phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};
    my $round = Math::Round::Var->new(0.01);
    my $dbh = $c->dbc->dbh();

    my $trials = $program->get_trials;
    my @trial_ids;
    while (my $trial = $trials->next() ) {
	my $trial_id = $trial->project_id;
	push @trial_ids , $trial_id;
    }
    my $trial_ids = join ',', map { "?" } @trial_ids;
    my @phenotype_data;
    my @trait_list;

    if ( $trial_ids ) {
	my $h = $dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value),
        to_char(avg(phenotype.value::real), 'FM999990.990'),
        to_char(max(phenotype.value::real), 'FM999990.990'),
        to_char(min(phenotype.value::real), 'FM999990.990'),
        to_char(stddev(phenotype.value::real), 'FM999990.990')
        
        FROM cvterm
            JOIN phenotype ON (cvterm_id=cvalue_id)
            JOIN nd_experiment_phenotype USING(phenotype_id)
            JOIN nd_experiment_project USING(nd_experiment_id)
            JOIN nd_experiment_stock USING(nd_experiment_id)
            JOIN stock as plot USING(stock_id)
            JOIN stock_relationship on (plot.stock_id = stock_relationship.subject_id)
            JOIN stock as accession on (accession.stock_id = stock_relationship.object_id)
            JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE project_id IN ( $trial_ids ) 
            AND phenotype.value~?
           
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id 
        ORDER BY cvterm.name ASC
       ;");
	
	my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
	$h->execute( @trial_ids , $numeric_regex);
	
        while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev) = $h->fetchrow_array()) {
	    push @trait_list, [$trait_id, $trait]; 
	    my $cv = 0;
	    if ($stddev && $average != 0) {
		$cv = ($stddev /  $average) * 100;
		$cv = $round->round($cv) . '%';
	    }
	    if ($average) { $average = $round->round($average); }
	    if ($min) { $min = $round->round($min); }
	    if ($max) { $max = $round->round($max); }
	    if ($stddev) { $stddev = $round->round($stddev); }
	    
	    my @return_array;
	    
	    
	    push @return_array, ( qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $cv, $count, qq{<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change($program_id, $trait_id)"><span class="glyphicon glyphicon-stats"></span></a>} );
	    push @phenotype_data, \@return_array;
	}
    }
    $c->stash->{trait_list} = \@trait_list;
    $c->stash->{rest} = { data => \@phenotype_data };
}


sub traits_assayed : Chained('ajax_breeding_program') PathPart('traits_assayed') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my @traits_assayed  =  $program->get_traits_assayed;
    $c->stash->{rest} = { traits_assayed => \@traits_assayed };
}

sub trait_phenotypes : Chained('ajax_breeding_program') PathPart('trait_phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    #get userinfo from db
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    #my $user = $c->user();
    #if (! $c->user) {
    #  $c->stash->{rest} = {
    #    status => "not logged in"
    #  };
    #  return;
    #}
    my $display = $c->req->param('display') || 'plot' ;
    my $trials = $program->get_trials;
    my @trial_ids;
    while (my $trial = $trials->next() ) {
	my $trial_id = $trial->project_id;
	push @trial_ids , $trial_id;
    }
    my $trait = $c->req->param('trait');
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=> $schema,
        search_type => "MaterializedViewTable",
        data_level => $display,
        trait_list=> [$trait],
        trial_list => \@trial_ids
    );
    my @data = $phenotypes_search->get_phenotype_matrix();
    $c->stash->{rest} = {
      status => "success",
      data => \@data
   };
}


sub accessions : Chained('ajax_breeding_program') PathPart('accessions') Args(0) {
    my ($self, $c) = @_;
    my $program = $c->stash->{program};
    my $accessions = $program->get_accessions;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my @formatted_accessions;
   

    foreach my $id ( @$accessions ) {
	my $acc =  my $row = $schema->resultset("Stock::Stock")->find(  
	    { stock_id => $id , } 
	    );
	
	my $name        = $acc->uniquename;
	my $description = $acc->description;
	push @formatted_accessions, [ '<a href="/stock/' .$id. '/view">'.$name.'</a>', $description ];
    }
    $c->stash->{rest} = { data => \@formatted_accessions };
}

1;


