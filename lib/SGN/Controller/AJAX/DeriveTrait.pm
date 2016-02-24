package SGN::Controller::AJAX::DeriveTrait;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;
use DBI;
use DBIx::Class;

BEGIN {extends 'Catalyst::Controller::REST'}

 has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );

sub compute_derive_traits : Path('/ajax/phenotype/create_derived_trait') Args(0) {

	my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');
    	my $selected_trait = $c->req->param('trait');
	my %parse_result;

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

	foreach my $trait_found (@{$triat_name}) {
	    if  ($selected_trait && ($trait_found->[0] eq $selected_trait)) {
		print "Triat found = $trait_found->[1] with id $trait_found->[0]\n";
		$c->stash->{rest} = {error => "$trait_found->[1] has been computed and uploaded for this trial." };
			return;	
	    }
	
	   elsif ($selected_trait == '')  {
		$c->stash->{rest} = {error => "Select trait to compute." };
		return;
	   } 
	 } 

	my $dbh = $c->dbc->dbh();
	
	#my @wtair_wtwater = ("76811", "76824");
	#my @pheno_wtair;
	my @container_array;
	
	my $computing_trait_name = 'specific gravity|CO:0000163';
	my @traits;
	push @traits, $computing_trait_name;
	my $wtair = 76811;
	my %hash_wtair;
      #foreach my $wt (@wtair_wtwater){

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
		

	#$h->execute($wt, $trial_id);
	$h->execute($wtair, $trial_id);
	my @array_name;
	
	while (my ($stock_name, $stock_id, $plot_name, $value) = $h->fetchrow_array()) { 
		#push @pheno_wtair, [$stock_name, $stock_id, $plot_name, $value];
		#push @array_name, [$stock_name, $plot_name, $value];
		$hash_wtair{$plot_name} = $value;
	}
	
	print STDERR Dumper(\%hash_wtair);


	my @plot_name_rename;
	my $wtwater = 76824;
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
		push @plot_name_rename, $plot_name;
	}
	
	print STDERR Dumper(\%hash_wtwater);
	
	my @plots;
	my %data;
	my (@keys, @specific_grvty );
	
	foreach (keys %hash_wtair) {
		#if (defined $hash_wtwater{$plot_name}){
		#	print "$plot_name: found in weight in water\n";
		#	next;
		#}
	#	unless ( exists $hash_wtwater{$_} ) {
	#		print "$_: found in weight in water\n";		
	#		next;
	#	}
		
		if ($hash_wtair{$_} && $hash_wtwater{$_}) { 
				push @plots, $_;
			 $data{$_}->{$computing_trait_name} = ( $hash_wtair{$_}/($hash_wtair{$_} - $hash_wtwater{$_}) );
				#my $specific_grvty_entry = ( $hash_wtair{$_}/($hash_wtair{$_} - $hash_wtwater{$_}) );
				#my $specific_grvty_entry2 = sprintf("%.4f", $specific_grvty_entry);				
				#push @specific_grvty, $specific_grvty_entry2;
				
		}
			
	}

	print STDERR Dumper (\%data);
	print STDERR Dumper (\@plots);
      	
	
	$parse_result{'data'} = \%data;
    	$parse_result{'plots'} = \@plots;
    	$parse_result{'traits'} = \@traits;


	my $time = DateTime->now();
  	my $timestamp = $time->ymd()."_".$time->hms();
	my %phenotype_metadata;
	$phenotype_metadata{'archived_file'} = 'none';
  	$phenotype_metadata{'archived_file_type'}="generated from derived traits";
  	$phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  	$phenotype_metadata{'date'}="$timestamp";

	my $store = CXGN::Phenotypes::StorePhenotypes->store($c, \@plots, \@traits, \%data, \%phenotype_metadata);


	$c->stash->{rest} = {success => 1};
}


1;
