package SGN::Controller::AJAX::DeriveTrait;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;
use DBI;
use DBIx::Class;

BEGIN {extends 'Catalyst::Controller::REST'}

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

 has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );


sub get_all_derived_trait : Path('/ajax/breeders/trial/trait_formula') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');;
    my $dbh = $c->dbc->dbh();
    my (@cvterm_ids, @derived_traits, @formulas, @derived_traits_array, @trait_ids, @trait_db_ids, @formulas_array); 

    my $h = $dbh->prepare("select cvterm.name, cvterm.cvterm_id, a.value, dbxref.accession, db.name from cvterm join cvtermprop as a using(cvterm_id) join dbxref using(dbxref_id) join db using(db_id) join cvterm as b on (a.type_id=b.cvterm_id) where b.name='formula';");

    $h->execute();	
	while (my ($cvterm_id, $derived_trait, $derived_trait_formula, $trait_id, $trait_db_id) = $h->fetchrow_array()) { 
		push @cvterm_ids, $cvterm_id;
	        push @derived_traits, $derived_trait;
		push @formulas, $derived_trait_formula;
		push @trait_ids, $trait_id;
		push @trait_db_ids, $trait_db_id;
	}
    
	for (my $n=0; $n<scalar(@formulas); $n++) {
		print STDERR $derived_traits[$n]."\n";
		print STDERR $cvterm_ids[$n]."|".$trait_db_ids[$n].":".$trait_ids[$n]."\n";
		print STDERR $formulas[$n]."\n";
		push @formulas_array, $formulas[$n];
		push @derived_traits_array, $cvterm_ids[$n]."|".$trait_db_ids[$n].":".$trait_ids[$n];

	#print STDERR $derived_trait_cvterm_id."\n";
    }
    print STDERR Dumper (\@derived_traits_array);

    $c->stash->{rest} = { derived_traits => \@derived_traits_array, formula => \@formulas_array };
}


sub compute_derive_traits : Path('/ajax/phenotype/create_derived_trait') Args(0) {

	my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');
    	my $selected_trait = $c->req->param('trait');
	my %parse_result;
	my $trait_found;

	print "TRAIT NAME: $selected_trait\n";
	print "TRIAl ID: $trial_id\n";

	if (!$c->user()) { 
		print STDERR "User not logged in... not computing trait.\n";
		$c->stash->{rest} = {error => "You need to be logged in to compute trait." };
		return;
    	}
	
	if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
		$c->stash->{rest} = {error =>  "You have insufficient privileges to compute trait." };
		return;
    	}
  
   my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $trait_id = shift;
	my $trial = CXGN::Trial->new({ bcs_schema => $schema, 
					trial_id => $trial_id 
				});

	my $triat_name = $trial->get_traits_assayed();
    
	print STDERR Dumper($triat_name);


	if (scalar(@{$triat_name}) == 0)  {
		$c->stash->{rest} = {error => "No trait assayed for this trial." };
		return;
	   } 


	foreach $trait_found (@{$triat_name}) {
	    if  ($selected_trait && ($trait_found->[1] eq $selected_trait)) {
		print "Triat found = $trait_found->[1] with id $trait_found->[0]\n";
		$c->stash->{rest} = {error => "$trait_found->[1] has been computed and uploaded for this trial." };
			return;	
	    }
	
	   elsif ($selected_trait eq '')  {
		$c->stash->{rest} = {error => "Select trait to compute." };
		return;
	   } 
	 } 

	my $dbh = $c->dbc->dbh();
	my @plots;
	my %data;
	my @traits;	
	my @trait_cvterm_id;
	my $trait = 0;
	my $counter_trait = 0;
	

  if ($selected_trait eq 'Specific gravity') {
	
      foreach $trait_found (@{$triat_name}) {
	
	if ($trait_found->[1] eq 'Root weight in air') {
		$trait = 1;
	}

	if ($trait_found->[1] eq 'Root weight in water') {
		$trait = 1;
	}

	if ($trait == 1){
		$counter_trait++;
		push @trait_cvterm_id, $trait_found->[0];
		
		if ( ($trait_found->[1] ne 'Root weight in air') || ($trait_found->[1] ne 'Root weight in water') ){ 
			$trait = 0;
		}
	 }

       }

       if (scalar(@trait_cvterm_id) != 2) {
		$c->stash->{rest} = {error => "Upload phenotypes for 'weight in air' and 'weight in water' to compute 'specific gravity'." };
		return;
	}
      
	my $computing_trait_name = 'specific gravity|CO:0000163';
	push @traits, $computing_trait_name;
	my $wtair = $trait_cvterm_id[0];
	my %hash_wtair;

	my $h = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
nd_experiment_stock nd_experiment_stocks ON nd_experiment_stocks.stock_id =
me.stock_id LEFT JOIN nd_experiment nd_experiment ON nd_experiment.nd_experiment_id = nd_experiment_stocks.nd_experiment_id LEFT JOIN nd_experiment_phenotype nd_experiment_phenotypes ON nd_experiment_phenotypes.nd_experiment_id = nd_experiment.nd_experiment_id LEFT JOIN phenotype phenotype ON phenotype.phenotype_id =
nd_experiment_phenotypes.phenotype_id LEFT JOIN cvterm observable ON
observable.cvterm_id = phenotype.observable_id LEFT JOIN nd_experiment_project
nd_experiment_projects ON nd_experiment_projects.nd_experiment_id =
nd_experiment.nd_experiment_id LEFT JOIN project project ON project.project_id =
nd_experiment_projects.project_id LEFT JOIN stock_relationship
stock_relationship_subjects ON stock_relationship_subjects.subject_id =
me.stock_id LEFT JOIN stock object ON object.stock_id =
stock_relationship_subjects.object_id WHERE ( ( observable.cvterm_id =? AND
project.project_id=? ) );");
		

	$h->execute($wtair, $trial_id);	
	while (my ($stock_name, $stock_id, $plot_name, $value) = $h->fetchrow_array()) { 
		$hash_wtair{$plot_name} = $value;
	}
	
	print STDERR Dumper(\%hash_wtair);

	my $wtwater = $trait_cvterm_id[1];
	my %hash_wtwater;

	my $h1 = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
nd_experiment_stock nd_experiment_stocks ON nd_experiment_stocks.stock_id =
me.stock_id LEFT JOIN nd_experiment nd_experiment ON nd_experiment.nd_experiment_id = nd_experiment_stocks.nd_experiment_id LEFT JOIN nd_experiment_phenotype nd_experiment_phenotypes ON nd_experiment_phenotypes.nd_experiment_id = nd_experiment.nd_experiment_id LEFT JOIN phenotype phenotype ON phenotype.phenotype_id =
nd_experiment_phenotypes.phenotype_id LEFT JOIN cvterm observable ON
observable.cvterm_id = phenotype.observable_id LEFT JOIN nd_experiment_project
nd_experiment_projects ON nd_experiment_projects.nd_experiment_id =
nd_experiment.nd_experiment_id LEFT JOIN project project ON project.project_id =
nd_experiment_projects.project_id LEFT JOIN stock_relationship
stock_relationship_subjects ON stock_relationship_subjects.subject_id =
me.stock_id LEFT JOIN stock object ON object.stock_id =
stock_relationship_subjects.object_id WHERE ( ( observable.cvterm_id =? AND
project.project_id=? ) );");
		
	my ($stock_name, $stock_id, $plot_name, $value);
	$h1->execute($wtwater, $trial_id);
	while ( ($stock_name, $stock_id, $plot_name, $value) = $h1->fetchrow_array()) { 
		$hash_wtwater{$plot_name} = $value;
		
	}
	
	print STDERR Dumper(\%hash_wtwater);
	
	foreach (keys %hash_wtair) {
		
		if ($hash_wtair{$_} && $hash_wtwater{$_}) { 
				push @plots, $_;
			 $data{$_}->{$computing_trait_name} = ( $hash_wtair{$_}/($hash_wtair{$_} - $hash_wtwater{$_}) );
		}
			
	}

	print STDERR Dumper (\%data);
	print STDERR Dumper (\@plots); 
   }


   elsif ($selected_trait eq 'Sprouting') {

      foreach $trait_found (@{$triat_name}) {
	
	if  ($trait_found->[1] eq 'Number of planted stakes') {
		$trait = 1;
	}
	
	if ($trait_found->[1] eq 'Sprout count at one-month') {
		$trait = 1;
	}

       	if ($trait == 1){
		$counter_trait++;
		push @trait_cvterm_id, $trait_found->[0];
		
		if ( ($trait_found->[1] ne 'Number of planted stakes') || ($trait_found->[1] ne 'Sprout count at one-month') ){ 
			$trait = 0;
		}

	 }

     }

	if (scalar(@trait_cvterm_id) != 2) {
		$c->stash->{rest} = {error => "Upload phenotypes for 'stake planted' and 'sprout count' to compute 'sprouting proportion'." };
		return;
	}	

	my $computing_trait_name = 'sprouting proportion|CO:0000008';
	push @traits, $computing_trait_name;
	my $stakes_planted = $trait_cvterm_id[0];
	my %hash_stakes_planted;

	my $h = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
nd_experiment_stock nd_experiment_stocks ON nd_experiment_stocks.stock_id =
me.stock_id LEFT JOIN nd_experiment nd_experiment ON nd_experiment.nd_experiment_id = nd_experiment_stocks.nd_experiment_id LEFT JOIN nd_experiment_phenotype nd_experiment_phenotypes ON nd_experiment_phenotypes.nd_experiment_id = nd_experiment.nd_experiment_id LEFT JOIN phenotype phenotype ON phenotype.phenotype_id =
nd_experiment_phenotypes.phenotype_id LEFT JOIN cvterm observable ON
observable.cvterm_id = phenotype.observable_id LEFT JOIN nd_experiment_project
nd_experiment_projects ON nd_experiment_projects.nd_experiment_id =
nd_experiment.nd_experiment_id LEFT JOIN project project ON project.project_id =
nd_experiment_projects.project_id LEFT JOIN stock_relationship
stock_relationship_subjects ON stock_relationship_subjects.subject_id =
me.stock_id LEFT JOIN stock object ON object.stock_id =
stock_relationship_subjects.object_id WHERE ( ( observable.cvterm_id =? AND
project.project_id=? ) );");
		
	$h->execute($stakes_planted, $trial_id);	
	while (my ($stock_name, $stock_id, $plot_name, $value) = $h->fetchrow_array()) { 
		$hash_stakes_planted{$plot_name} = $value;
	}

	print STDERR Dumper(\%hash_stakes_planted);

	my $sprout_count = $trait_cvterm_id[1];
	my %hash_sprout_count;

	my $h1 = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
nd_experiment_stock nd_experiment_stocks ON nd_experiment_stocks.stock_id =
me.stock_id LEFT JOIN nd_experiment nd_experiment ON nd_experiment.nd_experiment_id = nd_experiment_stocks.nd_experiment_id LEFT JOIN nd_experiment_phenotype nd_experiment_phenotypes ON nd_experiment_phenotypes.nd_experiment_id = nd_experiment.nd_experiment_id LEFT JOIN phenotype phenotype ON phenotype.phenotype_id =
nd_experiment_phenotypes.phenotype_id LEFT JOIN cvterm observable ON
observable.cvterm_id = phenotype.observable_id LEFT JOIN nd_experiment_project
nd_experiment_projects ON nd_experiment_projects.nd_experiment_id =
nd_experiment.nd_experiment_id LEFT JOIN project project ON project.project_id =
nd_experiment_projects.project_id LEFT JOIN stock_relationship
stock_relationship_subjects ON stock_relationship_subjects.subject_id =
me.stock_id LEFT JOIN stock object ON object.stock_id =
stock_relationship_subjects.object_id WHERE ( ( observable.cvterm_id =? AND
project.project_id=? ) );");
		
	my ($stock_name, $stock_id, $plot_name, $value);
	$h1->execute($sprout_count, $trial_id);
	while ( ($stock_name, $stock_id, $plot_name, $value) = $h1->fetchrow_array()) { 
		$hash_sprout_count{$plot_name} = $value;
	}
	
	print STDERR Dumper(\%hash_sprout_count);

	foreach (keys %hash_stakes_planted) {
		
		if ($hash_stakes_planted{$_} && $hash_sprout_count{$_}) { 
				push @plots, $_;
			 $data{$_}->{$computing_trait_name} = ( $hash_sprout_count{$_}/$hash_stakes_planted{$_} );
		
		}
			
	}

  }
	
  elsif ($selected_trait eq 'Dry matter content by specific gravity method') {

     foreach $trait_found (@{$triat_name}) {

	if ($trait_found->[1] eq 'Specific gravity') {
		
		push @trait_cvterm_id, $trait_found->[0];
		print "cvterm_id 1: $trait_cvterm_id[0]\n";	
	 }

     }

     if (scalar(@trait_cvterm_id) != 1) {
		$c->stash->{rest} = {error => "Compute or upload 'specific gravity' before computing 'dry matter content'." };
		return;
	}	

	my $computing_trait_name = 'dry matter content by specific gravity method|CO:0000160';
	push @traits, $computing_trait_name;
	my $specific_gravity = $trait_cvterm_id[0];
	my %hash_specific_gravity;

	my $h = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
nd_experiment_stock nd_experiment_stocks ON nd_experiment_stocks.stock_id =
me.stock_id LEFT JOIN nd_experiment nd_experiment ON nd_experiment.nd_experiment_id = nd_experiment_stocks.nd_experiment_id LEFT JOIN nd_experiment_phenotype nd_experiment_phenotypes ON nd_experiment_phenotypes.nd_experiment_id = nd_experiment.nd_experiment_id LEFT JOIN phenotype phenotype ON phenotype.phenotype_id =
nd_experiment_phenotypes.phenotype_id LEFT JOIN cvterm observable ON
observable.cvterm_id = phenotype.observable_id LEFT JOIN nd_experiment_project
nd_experiment_projects ON nd_experiment_projects.nd_experiment_id =
nd_experiment.nd_experiment_id LEFT JOIN project project ON project.project_id =
nd_experiment_projects.project_id LEFT JOIN stock_relationship
stock_relationship_subjects ON stock_relationship_subjects.subject_id =
me.stock_id LEFT JOIN stock object ON object.stock_id =
stock_relationship_subjects.object_id WHERE ( ( observable.cvterm_id =? AND
project.project_id=? ) );");
	
	$h->execute($specific_gravity, $trial_id);
	
	while (my ($stock_name, $stock_id, $plot_name, $value) = $h->fetchrow_array()) { 
		$hash_specific_gravity{$plot_name} = $value;
	}
	
	print STDERR Dumper(\%hash_specific_gravity);

	foreach (keys %hash_specific_gravity) {		
		
		if ($hash_specific_gravity{$_}) { 
				push @plots, $_;
			 $data{$_}->{$computing_trait_name} = ( (158.3 * $hash_specific_gravity{$_}) - 142 );
				
		}
			
	}
   
     
	print STDERR Dumper (\%data);
	print STDERR Dumper (\@plots);
  }   	

   elsif ($selected_trait eq 'Starch content') {

	foreach $trait_found (@{$triat_name}) {

		if ($trait_found->[1] eq 'Specific gravity') {
			push @trait_cvterm_id, $trait_found->[0];
		}
	}

	if (scalar(@trait_cvterm_id) != 1) {
		$c->stash->{rest} = {error => "Compute or upload 'specific gravity' before computing 'starch content'." };
		return;
	}	

	my $computing_trait_name = 'starch content percentage|CO:0000071';
	push @traits, $computing_trait_name;
	my $specific_gravity = $trait_cvterm_id[0];
	my %hash_specific_gravity;

	my $h = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
nd_experiment_stock nd_experiment_stocks ON nd_experiment_stocks.stock_id =
me.stock_id LEFT JOIN nd_experiment nd_experiment ON nd_experiment.nd_experiment_id = nd_experiment_stocks.nd_experiment_id LEFT JOIN nd_experiment_phenotype nd_experiment_phenotypes ON nd_experiment_phenotypes.nd_experiment_id = nd_experiment.nd_experiment_id LEFT JOIN phenotype phenotype ON phenotype.phenotype_id =
nd_experiment_phenotypes.phenotype_id LEFT JOIN cvterm observable ON
observable.cvterm_id = phenotype.observable_id LEFT JOIN nd_experiment_project
nd_experiment_projects ON nd_experiment_projects.nd_experiment_id =
nd_experiment.nd_experiment_id LEFT JOIN project project ON project.project_id =
nd_experiment_projects.project_id LEFT JOIN stock_relationship
stock_relationship_subjects ON stock_relationship_subjects.subject_id =
me.stock_id LEFT JOIN stock object ON object.stock_id =
stock_relationship_subjects.object_id WHERE ( ( observable.cvterm_id =? AND
project.project_id=? ) );");
		
	$h->execute($specific_gravity, $trial_id);
	
	while (my ($stock_name, $stock_id, $plot_name, $value) = $h->fetchrow_array()) { 
		$hash_specific_gravity{$plot_name} = $value;
	}
	
	print STDERR Dumper(\%hash_specific_gravity);

	foreach (keys %hash_specific_gravity) {		
		
		if ($hash_specific_gravity{$_}) { 
				push @plots, $_;
			 $data{$_}->{$computing_trait_name} = ( (210.8 * $hash_specific_gravity{$_}) - 213.4 );
				
		}	
	}
   
	print STDERR Dumper (\%data);
	print STDERR Dumper (\@plots);
   }   	
	
	$parse_result{'data'} = \%data;
    	$parse_result{'plots'} = \@plots;
    	$parse_result{'traits'} = \@traits;

	my $size = scalar(@plots) * scalar(@traits);
	my $time = DateTime->now();
  	my $timestamp = $time->ymd()."_".$time->hms();
	my %phenotype_metadata;
	$phenotype_metadata{'archived_file'} = 'none';
  	$phenotype_metadata{'archived_file_type'}="generated from derived traits";
  	$phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  	$phenotype_metadata{'date'}="$timestamp";

	my $store = CXGN::Phenotypes::StorePhenotypes->store($c, $size, \@plots, \@traits, \%data, \%phenotype_metadata);
       

	$c->stash->{rest} = {success => 1};
}


1;
