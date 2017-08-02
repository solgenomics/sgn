use strict;

package SGN::Controller::AJAX::BreedersToolbox::GraphicalFiltering;

use Data::Dumper;
use Moose;
use Cwd qw(cwd);
use CXGN::List;
use CXGN::BreederSearch;
use CXGN::Phenotypes::PhenotypeMatrix;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);

sub common_plot_traits : Path('/ajax/trial/common_plot_traits') : ActionClass('REST') {}
sub common_plot_traits_GET : Args(0) {
   my $self = shift;
   my $c = shift;

   #get list ID from url param
   my $trial_list_id = $c->request->param('trial_list_id');

   #get userinfo from db
   my $schema = $c->dbic_schema("Bio::Chado::Schema");
   my $user = $c->user();
   my $user_id = $user->get_object()->get_sp_person_id();

   #get list contents
   my $dbh = $schema->storage()->dbh();
   my $tl = CXGN::List->new({ dbh => $dbh, list_id => $trial_list_id, owner => $user_id });
   my $trials = $tl->elements();
   my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ @$trials ]} });
   my @trial_ids = map { $_->project_id() } $trial_id_rs->all();
   my $trials_string = "\'".join( "\',\'",@trial_ids)."\'";

   #get all common trial traits
   my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
   my @criteria2 = ['trials','traits'];
   my $dataref2 = {
      'traits' => {
         'trials' => $trials_string
      }
   };
   my $queryref2 = {
      'traits' => {
         'trials' => 1
      }
   };
   my $traits_results_ref = $breedersearch->metadata_query(@criteria2, $dataref2, $queryref2);
   my @trait_list = map { $$_[0] } @{$$traits_results_ref{results}};
   my $traits_string = "\'".join( "\',\'",@trait_list)."\'";

   #get all plots with every trait of each trial
   my @criteria = ['trials','traits','plots'];
   my $dataref = {
      'plots' => {
         'trials' => $trials_string,
         'traits' => $traits_string
      }
   };
   my $queryref = {
      'plots' => {
         'trials' => 0,
         'traits' => 1
      }
   };
   my $plots_results_ref = $breedersearch->metadata_query(@criteria, $dataref, $queryref);

   my @plot_list = map { $$_[0] } @{$$plots_results_ref{results}};


   my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
      bcs_schema=> $schema,
      search_type => "Native",
      data_level => "plot",
      trait_list=> \@trait_list,
      plot_list=>  \@plot_list
   );
   my @data = $phenotypes_search->get_phenotype_matrix();

   $c->stash->{rest} = {
      traits => $traits_results_ref,
      data => \@data
   };
}


1;
