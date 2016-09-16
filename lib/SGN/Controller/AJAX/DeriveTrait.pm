package SGN::Controller::AJAX::DeriveTrait;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any sum |;
use DBI;
use DBIx::Class;
use SGN::Model::Cvterm;
use JSON;
use POSIX;
use URI::Encode qw(uri_encode uri_decode);

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
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();
    my (@cvterm_ids, @derived_traits, @formulas, @derived_traits_array, @trait_ids, @trait_db_ids, @formulas_array, @formulas_array_msg, $formula_json_array); 

    my $h = $dbh->prepare("select cvterm.name, cvterm.cvterm_id, a.value, dbxref.accession, db.name from cvterm join cvtermprop as a using(cvterm_id) join dbxref using(dbxref_id) join db using(db_id) join cvterm as b on (a.type_id=b.cvterm_id) where b.name='formula';");

    $h->execute();	
    while (my ($cvterm_id, $derived_trait, $derived_trait_formula, $trait_id, $trait_db_id) = $h->fetchrow_array()) { 
		push @cvterm_ids, $cvterm_id;
	        push @derived_traits, $derived_trait;
		push @formulas, $derived_trait_formula;
		push @trait_ids, $trait_id;
		push @trait_db_ids, $trait_db_id;
		
    }
	for (my $n=0; $n<scalar(@derived_traits); $n++) {
		push @formulas_array, $formulas[$n];
		push @derived_traits_array, $cvterm_ids[$n]."|".$trait_db_ids[$n].":".$trait_ids[$n];
    	}

    print STDERR Dumper (@formulas_array);
    $c->stash->{rest} = { derived_traits => \@derived_traits_array, formula => \@formulas_array };
}


sub compute_derive_traits : Path('/ajax/phenotype/create_derived_trait') Args(0) {

	my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');
    	my $selected_trait = $c->req->param('trait');
	my %parse_result;
	my $trait_found;
	my $time = DateTime->now();
  	my $timestamp = $time->ymd()."_".$time->hms();

	print "TRAIT NAME: $selected_trait\n";
	print "TRIAl ID: $trial_id\n";

	my $schema = $c->dbic_schema('Bio::Chado::Schema');
	my $selected_trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $selected_trait);
	if (!$selected_trait_cvterm) {
		print STDERR "The trait $selected_trait is not in the database.\n";
	}

	my $selected_trait_cvterm_id = $selected_trait_cvterm->cvterm_id();
	print "Selected Trait Cvterm_id: $selected_trait_cvterm_id\n";

	if (!$c->user()) { 
		print STDERR "User not logged in... not computing trait.\n";
		$c->stash->{rest} = {error => "You need to be logged in to compute trait." };
		return;
    	}
	
	if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
		$c->stash->{rest} = {error =>  "You have insufficient privileges to compute trait." };
		return;
    	}
  
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
	    	if  ($selected_trait_cvterm_id && ($trait_found->[0] eq $selected_trait_cvterm_id)) {
			print "Trait found = $trait_found->[1] with id $trait_found->[0]\n";
			$c->stash->{rest} = {error => "$trait_found->[1] has been computed and uploaded for this trial." };
			return;	
	    	}
	
	   	elsif ($selected_trait_cvterm_id eq '')  {
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
	push @traits, $selected_trait;	
	
	my (@cvterm_ids,  @formulas, @regres, $formula_json_array, @formulas_array_msg, $eval_formula, $msg_formula);

	my $h = $dbh->prepare("select cvterm.cvterm_id, a.value from cvterm join cvtermprop as a using(cvterm_id) join cvterm as b on (a.type_id=b.cvterm_id) where b.name='formula';");

    	$h->execute();
    	while (my ($cvterm_id, $derived_trait_formula ) = $h->fetchrow_array()) { 
		push @cvterm_ids, $cvterm_id;  
		push @formulas, $derived_trait_formula;	
		
	}	
   
    	for (my $n=0; $n<scalar(@formulas); $n++) {
  		if ($selected_trait_cvterm_id eq $cvterm_ids[$n]) {
			print "formula_msg: $formulas[$n]\n";
			$msg_formula = $formulas[$n];
	
		}
	}
	
	my @dependent_trait_ids;
	my ($db_id, $accession, @traits_cvterm_ids, $cvterm_id, @found_trait_cvterm_ids, @accessions, @trait_values);
	my (%hash1, %hash2, %hash3, @trait_values1, @trait_values2, @trait_values3);
	while ($msg_formula =~ /(\w{2}\:\d+)/g){
		push @dependent_trait_ids, [$1]; 
		($db_id,$accession) = split (/:/, $1);
		push @accessions, $accession;
	}
	print "DB ID: $db_id\n";
	#print STDERR Dumper (\@dependent_trait_ids);
	foreach my $accession (@accessions) {
		my $h1 = $dbh->prepare("select cvterm.cvterm_id from cvterm join dbxref using(dbxref_id) join db using(db_id) where dbxref.accession=? and db.name=?;");

    		$h1->execute($accession, $db_id);
    		while ($cvterm_id = $h1->fetchrow_array()) { 
			push @traits_cvterm_ids, $cvterm_id;
		}
	}
	#print STDERR Dumper (\@traits_cvterm_ids);
	for (my $x=0; $x<scalar(@traits_cvterm_ids); $x++){
		foreach $trait_found (@{$triat_name}) {
			if ($trait_found->[0] eq $traits_cvterm_ids[$x]) {
				push @found_trait_cvterm_ids, $trait_found->[0];
			}
		}
	}

	while ($msg_formula =~ /([\w\s-]+\|\w{2}\:\d+)/g){
		my $full_name = $1;
		if ($full_name =~ m/\s-\s/g){
			$full_name =~ s/-\s//g;
		}
		push @regres, $full_name;
	}
	print STDERR Dumper (\@regres);
	my ($stock_name, $stock_id, $plot_name, $value);
	if (@found_trait_cvterm_ids != @traits_cvterm_ids) {
		$c->stash->{rest} = {error => "Upload or compute trait(s) required for computing \n\n$selected_trait = $msg_formula." };
		return;
	}
	else {
			
		print Dumper (\@found_trait_cvterm_ids);
		my $h2 = $dbh->prepare("SELECT object.uniquename AS stock_name, object.stock_id AS stock_id, me.uniquename AS plot_name, phenotype.value FROM stock me LEFT JOIN
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

		my @array;
		my %cvterm_hash;
		my %plot_hash;
		my %valid_plots;
		foreach (@found_trait_cvterm_ids) {
			$h2->execute($_, $trial_id);
			while ( ($stock_name, $stock_id, $plot_name, $value) = $h2->fetchrow_array()) { 
				$cvterm_hash{$_}->{$plot_name} = $value;
				$plot_hash{$plot_name}->{$_} = $value;

				@array, $cvterm_hash{$_}->{$plot_name};
			}
		}
		
		foreach my $plot_name (keys %plot_hash) {
			my $valid_plot_check = 1;
			my @value_array;
			foreach (@found_trait_cvterm_ids) {
				if (!exists ($plot_hash{$plot_name}->{$_})) {
					$valid_plot_check = 0;
				}
				push @value_array, $plot_hash{$plot_name}->{$_};

			}
			if ($valid_plot_check) {
				$valid_plots{$plot_name} = \@value_array;
				push @plots, $plot_name;
			}
		}

		foreach my $valid_plot_name (keys %valid_plots){
			my $value_array = $valid_plots{$valid_plot_name};
			print STDERR Dumper $value_array;
			my %map_hash;
			for( my $i =0; $i<scalar(@regres); $i++) {
				$map_hash{$regres[$i]} = $value_array->[$i];
			}
			print STDERR Dumper \%map_hash;
			my $msg_formula_sub = $msg_formula;
			foreach my $full_trait (keys %map_hash) {
				$full_trait =~ /([\w\s-]+)\|(\w{2}\:\d+)/g;
				print STDERR Dumper $full_trait;
				$msg_formula_sub =~ s/($1\|$2)/$map_hash{$full_trait}/g;
			}
			print STDERR Dumper $msg_formula_sub;
			my $calc_value = eval "$msg_formula_sub";
			print STDERR Dumper $calc_value;
			$data{$valid_plot_name}->{$selected_trait} = [$calc_value,$timestamp];
		}

	}
	
	print STDERR Dumper (\%data);
	print STDERR Dumper (\@plots);
	print STDERR Dumper (\@traits);	
   
	$parse_result{'data'} = \%data;
    	$parse_result{'plots'} = \@plots;
    	$parse_result{'traits'} = \@traits;

	my $size = scalar(@plots) * scalar(@traits);
	my %phenotype_metadata;
	$phenotype_metadata{'archived_file'} = 'none';
  	$phenotype_metadata{'archived_file_type'}="generated from derived traits";
  	$phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  	$phenotype_metadata{'date'}="$timestamp";

	my $store = CXGN::Phenotypes::StorePhenotypes->store($c, $size, \@plots, \@traits, \%data, \%phenotype_metadata);
       

	$c->stash->{rest} = {success => 1};
}


sub generate_plot_phenotypes : Path('/ajax/breeders/trial/generate_plot_phenotypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = $c->req->param('trial_id');
    my $trait_name = uri_decode($c->req->param('trait_name'));
    my $method = $c->req->param('method');
    my $rounding = $c->req->param('rounding');
    #print STDERR "Trial: $trial_id\n";
    #print STDERR "Trait: $trait_name\n";
    #print STDERR "Method: $method\n";
    #print STDERR "Round: $rounding\n";
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $trait_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name)->cvterm_id();
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $plant_phenotypes_for_trait = $trial->get_stock_phenotypes_for_trait($trait_id, 'plant', 'plant_of', 'plot');

    my %plot_plant_values;
    foreach (@$plant_phenotypes_for_trait) {
        my @value_array;
        my $plot_id = $_->[5];
        if (exists($plot_plant_values{$plot_id})) {
            @value_array = @{$plot_plant_values{$plot_id}};
        }
        push @value_array, $_->[4];
        $plot_plant_values{$plot_id} = \@value_array;
    }
    
    my @return;
    my %store_hash;
    my @plots;
    my @traits;
    push @traits, $trait_name;

    foreach my $plot_id (keys %plot_plant_values) {
        my %info;
        my $plot_name = $schema->resultset("Stock::Stock")->find({stock_id=>$plot_id})->uniquename();
        push @plots, $plot_name;
        $info{'method'} = $method;
        $info{'plant_values'} = encode_json($plot_plant_values{$plot_id});
        if ($method eq 'arithmetic_mean') {
            my $average = $self->_get_mean($plot_plant_values{$plot_id});
            $info{'output'} = $average;
            $info{'value_to_store'} = $average;
            $info{'notes'} = '';
        }
        if ($method eq 'mode') {
            my $modes = $self->_get_mode($plot_plant_values{$plot_id});
            $info{'output'} = encode_json($modes);
            if (scalar(@$modes > 1)) {
                $info{'notes'} = 'More than one mode!';
                $info{'value_to_store'} = '';
            } else {
                $info{'notes'} = 'A single mode was found!';
                $info{'value_to_store'} = $modes->[0];
            }
        }
        if ($method eq 'maximum') {
            my $maximum = $self->_get_max($plot_plant_values{$plot_id});
            $info{'output'} = $maximum;
            $info{'value_to_store'} = $maximum;
            $info{'notes'} = '';
        }
        if ($method eq 'minimum') {
            my $minimum = $self->_get_min($plot_plant_values{$plot_id});
            $info{'output'} = $minimum;
            $info{'value_to_store'} = $minimum;
            $info{'notes'} = '';
        }
        if ($method eq 'median') {
            my $median = $self->_get_median(@{$plot_plant_values{$plot_id}});
            $info{'output'} = $median;
            $info{'value_to_store'} = $median;
            $info{'notes'} = '';
        }

        if ($rounding eq 'round') {
            $info{'value_to_store'} = ceil($info{'value_to_store'});
        } elsif ($rounding eq 'round_up') {
            my $n = $info{'value_to_store'};
            my $ceiling = ($n == int $n) ? $n : int($n + 1);
            $info{'value_to_store'} = $ceiling;
        } elsif ($rounding eq 'round_down') {
            $info{'value_to_store'} = floor($info{'value_to_store'});
        }

        $store_hash{$plot_name}->{$trait_name} = [$info{'value_to_store'}, ''];
        $store_hash{$plot_name}->{$trait_name} = [$info{'value_to_store'}, ''];
        push @return, \%info;
    }
    #print STDERR Dumper \%store_hash;
    #print STDERR Dumper \@return;
    $c->stash->{rest} = {success => 1, info=>\@return, store_plots=>encode_json(\@plots), store_traits=>encode_json(\@traits), store_data=>encode_json(\%store_hash)};
}



sub store_generated_plot_phenotypes : Path('/ajax/breeders/trial/store_generated_plot_phenotypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    my %parse_result;
    my $data = decode_json($c->req->param('store_data'));
    my $plots = decode_json($c->req->param('store_plots'));
    my $traits = decode_json($c->req->param('store_traits'));
    my $overwrite_values = $c->req->param('overwrite_values');
    #print STDERR Dumper $data;
    #print STDERR Dumper $plots;
    #print STDERR Dumper $traits;
    #print STDERR $overwrite_values;
    
    $parse_result{'data'} = $data;
    $parse_result{'plots'} = $plots;
    $parse_result{'traits'} = $traits;

    my $size = scalar(@$plots) * scalar(@$traits);
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    $phenotype_metadata{'archived_file'} = 'none';
  	$phenotype_metadata{'archived_file_type'}="generated from plot from plant phenotypes";
  	$phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  	$phenotype_metadata{'date'}="$timestamp";

    my $store_error = CXGN::Phenotypes::StorePhenotypes->store($c, $size, $plots, $traits, $data, \%phenotype_metadata, 'plot', $overwrite_values );
    if ($store_error) {
        $c->stash->{rest} = {error => $store_error}
    }
    $c->stash->{rest} = {success => 1};
}


sub _get_mean {
    my $self = shift;
    my $array = shift;
    my $sum = 0;
    foreach (@$array) {
        $sum += $_;
    }
    my $average = $sum/scalar(@$array);
    return $average;
}

sub _get_max {
    my $self = shift;
    my $array = shift;
    my @sorted = sort {$b <=> $a} @$array; 
    my $max = $sorted[0];
    return $max;
}

sub _get_min {
    my $self = shift;
    my $array = shift;
    my @sorted = sort {$a <=> $b} @$array; 
    my $min = $sorted[0];
    return $min;
}

sub _get_mode {
    my $self = shift;
    my $array = shift;
    my %count;
    my @modes;
    map{ $count{$_}++ } @$array;
    my @values;
    my $top=0;
    for my $k ( sort {$count{$b} <=> $count{$a}} keys %count ) {
        #first element has highest count
        if ($count{$k} >= $top) {
            $top = $count{$k};
            push @modes, $k;
        }
    }
    return \@modes;
}

sub _get_median {
    my $self = shift;
    my $median = sum( ( sort { $a <=> $b } @_ )[ int( $#_/2 ), ceil( $#_/2 ) ] )/2;

    return $median;
}

1;
