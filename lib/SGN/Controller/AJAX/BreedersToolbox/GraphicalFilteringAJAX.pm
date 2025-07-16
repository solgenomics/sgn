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
    map       => { 'application/json' => 'JSON' },
   );


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);

sub common_traits_by_trial_list : Path('/ajax/plot/common_traits_by/trial_list') : ActionClass('REST') {}
sub common_traits_by_trial_list_GET : Args(0) {
   my $self = shift;
   my $c = shift;

   #get list ID from url param
   my $trial_list_id = $c->request->param('trial_list_id');

   #get userinfo from db
   my $user = $c->user();
   if (! $c->user) {
     $c->stash->{rest} = {
       status => "not logged in"
     };
     return;
   }
   my $user_id = $user->get_object()->get_sp_person_id();
   my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

   #get list contents
   my $dbh = $schema->storage()->dbh();
   my $tl = CXGN::List->new({ dbh => $dbh, list_id => $trial_list_id, owner => $user_id });
   my $trials = $tl->elements();
   my $trial_id_rs = $schema->resultset("Project::Project")->search( { name => { in => [ @$trials ]} });
   my @trial_ids = map { $_->project_id() } $trial_id_rs->all();
   my $trials_string = "\'".join( "\',\'",@trial_ids)."\'";

   #get all common trial traits
   my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
   my @trait_criteria = ['trials','traits'];
   my $trait_dataref = {
      'traits' => {
         'trials' => $trials_string
      }
   };
   my $trait_queryref = {
      'traits' => {
         'trials' => 1
      }
   };
   my $traits_results_ref = $breedersearch->metadata_query(@trait_criteria, $trait_dataref, $trait_queryref);
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
      search_type => "MaterializedViewTable",
      data_level => "plot",
      trait_list=> \@trait_list,
      plot_list=>  \@plot_list
   );
   my @data = $phenotypes_search->get_phenotype_matrix();

   $c->stash->{rest} = {
      traits => $traits_results_ref,
      status => "success",
      data => \@data
   };
}

sub common_traits_by_plot_list : Path('/ajax/plot/common_traits_by/plot_list') : ActionClass('REST') {}
sub common_traits_by_plot_list_GET : Args(0) {
   my $self = shift;
   my $c = shift;

   #get list ID from url param
   my $plot_list_id = $c->request->param('plot_list_id');

   #get userinfo from db
   my $user = $c->user();
   if (! $c->user) {
     $c->stash->{rest} = {
       status => "not logged in"
     };
     return;
   }
   my $user_id = $user->get_object()->get_sp_person_id();
   my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

   #get list contents
   my $dbh = $schema->storage()->dbh();
   my $tl = CXGN::List->new({ dbh => $dbh, list_id => $plot_list_id, owner => $user_id });
   my $plots = $tl->elements();
   my $plot_id_rs = $schema->resultset("Stock::Stock")->search( { uniquename => { in => [ @$plots ]} });
   my @plot_list = map { $_->stock_id() } $plot_id_rs->all();
   my $plots_string = "\'".join( "\',\'",@plot_list)."\'";

   #get all common plot traits
   my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
   my @criteria = ['plots','traits'];
   my $dataref = {
      'traits' => {
         'plots' => $plots_string
      }
   };
   my $queryref = {
      'traits' => {
         'plots' => 1
      }
   };
   my $traits_results_ref = $breedersearch->metadata_query(@criteria, $dataref, $queryref);
   my @trait_list = map { $$_[0] } @{$$traits_results_ref{results}};

   my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
      bcs_schema=> $schema,
      search_type => "MaterializedViewTable",
      data_level => "plot",
      trait_list=> \@trait_list,
      plot_list=>  \@plot_list
   );
   my @data = $phenotypes_search->get_phenotype_matrix();

   $c->stash->{rest} = {
      traits => $traits_results_ref,
      status => "success",
      data => \@data
   };
}

sub common_traits_by_trials : Path('/ajax/plot/common_traits_by/trials') : ActionClass('REST') {}
sub common_traits_by_trials_GET : Args(0) {
   my $self = shift;
   my $c = shift;

   #get schema
   my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
   my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

   #parse trial params
   my $trial_ids = $c->request->parameters->{'trial_id'};
   my $trials_string = "\'".join( "\',\'",@$trial_ids)."\'";

   #get all common trial traits
   my $breedersearch =  CXGN::BreederSearch->new({"dbh"=>$c->dbc->dbh});
   my @trait_criteria = ['trials','traits'];
   my $trait_dataref = {
      'traits' => {
         'trials' => $trials_string
      }
   };
   my $trait_queryref = {
      'traits' => {
         'trials' => 1
      }
   };
   my $traits_results_ref = $breedersearch->metadata_query(@trait_criteria, $trait_dataref, $trait_queryref);
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
      search_type => "MaterializedViewTable",
      data_level => "plot",
      trait_list=> \@trait_list,
      plot_list=>  \@plot_list
   );
   my @data = $phenotypes_search->get_phenotype_matrix();

   $c->stash->{rest} = {
      traits => $traits_results_ref,
      status => "success",
      data => \@data
   };
}


1;
