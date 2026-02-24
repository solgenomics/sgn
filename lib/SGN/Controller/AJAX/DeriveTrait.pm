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
use CXGN::BreedersToolbox::DeriveTrait;
use CXGN::Phenotypes::StorePhenotypes;

BEGIN {extends 'Catalyst::Controller::REST'}

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON'},
   );

 has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );


sub get_all_derived_trait : Path('/ajax/breeders/trial/trait_formula') Args(0) {
    my $self = shift;
    my $c = shift;
	my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
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

    #print STDERR Dumper (@formulas_array);
    $c->stash->{rest} = { derived_traits => \@derived_traits_array, formula => \@formulas_array };
}


sub compute_derive_traits : Path('/ajax/phenotype/create_derived_trait') Args(0) {

	my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');
    	my $selected_trait = $c->req->param('trait');
	my %parse_result;
	my $time = DateTime->now();
  	my $timestamp = $time->ymd()."_".$time->hms();

	print "TRAIT NAME: $selected_trait\n";
	print "TRIAl ID: $trial_id\n";

	my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
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

	#print STDERR Dumper($triat_name);


	if (scalar(@{$triat_name}) == 0)  {
		$c->stash->{rest} = {error => "No trait assayed for this trial." };
		return;
	}


	foreach my $trait_found (@{$triat_name}) {
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
	# Store paired (db_id, accession) tuples to support multi-ontology formulas
	my @db_accession_pairs;
	my (%hash1, %hash2, %hash3, @trait_values1, @trait_values2, @trait_values3);
	while ($msg_formula =~ /(\w*\:\d+)/g){
		push @dependent_trait_ids, [$1];
		($db_id,$accession) = split (/:/, $1);

		$accession =~ s/\s+$//;
		$accession =~ s/^\s+//;
		$db_id =~ s/\s+$//;
		$db_id =~ s/^\s+//;

		push @accessions, $accession;
		push @db_accession_pairs, [$db_id, $accession];
	}
	#print STDERR Dumper (\@dependent_trait_ids);
	# Use correct db_id for each accession (fixes multi-ontology formula bug)
	foreach my $pair (@db_accession_pairs) {
		my ($pair_db_id, $pair_accession) = @$pair;
		my $h1 = $dbh->prepare("select cvterm.cvterm_id from cvterm join dbxref using(dbxref_id) join db using(db_id) where dbxref.accession=? and db.name=?;");

		$h1->execute($pair_accession, $pair_db_id);
		while ($cvterm_id = $h1->fetchrow_array()) {
			push @traits_cvterm_ids, $cvterm_id;
		}
	}
	#print STDERR Dumper (\@traits_cvterm_ids);
	print STDERR "DEBUG: traits_cvterm_ids from formula: " . join(', ', @traits_cvterm_ids) . "\n";
	print STDERR "DEBUG: assayed traits: " . join(', ', map { $_->[0] . '=' . $_->[1] } @{$triat_name}) . "\n";
	for (my $x=0; $x<scalar(@traits_cvterm_ids); $x++){
		foreach my $trait_found (@{$triat_name}) {
			if ($trait_found->[0] eq $traits_cvterm_ids[$x]) {
				push @found_trait_cvterm_ids, $trait_found->[0];
			}
		}
	}

	# Build full trait names from DB instead of fragile regex parsing
	# This handles special chars (/, (, ), %) in trait names reliably
	foreach my $pair (@db_accession_pairs) {
		my ($pair_db_id, $pair_accession) = @$pair;
		my $h_name = $dbh->prepare("SELECT cvterm.name, db.name, dbxref.accession FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) WHERE dbxref.accession=? AND db.name=?;");
		$h_name->execute($pair_accession, $pair_db_id);
		my ($trait_name, $db_name, $acc) = $h_name->fetchrow_array();
		if ($trait_name) {
			push @regres, "$trait_name|$db_name:$acc";
		}
	}
	#print STDERR Dumper (\@regres);
	print STDERR "DEBUG: found_trait_cvterm_ids: " . join(', ', @found_trait_cvterm_ids) . "\n";
	print STDERR "DEBUG: regres: " . join(', ', @regres) . "\n";
	my ($stock_name, $stock_id, $plot_name, $value);
	if (@found_trait_cvterm_ids != @traits_cvterm_ids) {
		print STDERR "DEBUG: MISMATCH! found=" . scalar(@found_trait_cvterm_ids) . " needed=" . scalar(@traits_cvterm_ids) . "\n";
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

		my %cvterm_hash;
		my %plot_hash;
		my %valid_plots;
		foreach (@found_trait_cvterm_ids) {
			$h2->execute($_, $trial_id);
			while ( ($stock_name, $stock_id, $plot_name, $value) = $h2->fetchrow_array()) {
				$cvterm_hash{$_}->{$plot_name} = $value;
				$plot_hash{$plot_name}->{$_} = $value;

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
			#print STDERR Dumper $value_array;
			my %map_hash;
			for( my $i =0; $i<scalar(@regres); $i++) {
				$map_hash{$regres[$i]} = $value_array->[$i];
			}
			#print STDERR Dumper \%map_hash;
			my $msg_formula_sub = $msg_formula;
			foreach my $full_trait (keys %map_hash) {
				$full_trait =~ /([^|]+)\|(\w*\:\d+)/g;
				#print STDERR Dumper $full_trait;
				$msg_formula_sub =~ s/\Q$1\E\|\Q$2\E/$map_hash{$full_trait}/g;
			}
			#print STDERR Dumper $msg_formula_sub;
			$msg_formal_sub =~ s/[{}[];]//g; # possibly untaint variable
			## no critic (BuiltinFunctions::ProhibitStringEval)
			my $calc_value = eval($msg_formula_sub);
			## use critic

			#print STDERR Dumper $calc_value;
			$data{$valid_plot_name}->{$selected_trait} = [$calc_value,$timestamp];
		}

	}

	#print STDERR Dumper (\%data);
	#print STDERR Dumper (\@plots);
	#print STDERR Dumper (\@traits);

    $parse_result{'data'} = \%data;
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = 'none';
    $phenotype_metadata{'archived_file_type'}="generated from derived traits";
    $phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
    $phenotype_metadata{'date'}="$timestamp";
    my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id => $temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots,
        trait_list=>\@traits,
        values_hash=>\%data,
        has_timestamps=>1,
        overwrite_values=>0,
        metadata_hash=>\%phenotype_metadata,
				composable_validation_check_name=>$c->config->{composable_validation_check_name}
    );
    print "DERIVE_DEBUG: plots=" . scalar(@plots) . " traits=" . join(',', @traits) . " data_keys=" . scalar(keys %data) . "\n";

    my ($store_error, $store_success) = $store_phenotypes->store();

    print "DERIVE_DEBUG: store_error=" . ($store_error // 'none') . " store_success=" . ($store_success // 'none') . "\n";

    if ($store_error) {
        $c->stash->{rest} = {error => $store_error};
        return;
    }

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
	my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);

    my @traits;
    if ($trait_name eq 'all') {
        my $trial = CXGN::Trial->new({trial_id=>$trial_id, bcs_schema=>$schema});
        my $traits_assayed = $trial->get_traits_assayed('plant');
        foreach (@$traits_assayed) {
            push @traits, $_->[1];
        }
    } else {
        @traits = ($trait_name);
    }

    my @return_info;
    my @return_plots;
    my @return_traits;
    my @return_store_hash;
    foreach (@traits) {
        my $derive_trait = CXGN::BreedersToolbox::DeriveTrait->new({
            bcs_schema=>$schema,
            trait_name=>$_,
            trial_id=>$trial_id,
            method=>$method,
            rounding=>$rounding
        });
        my ($info, $plots, $traits, $store_hash) = $derive_trait->generate_plot_phenotypes();
        push @return_info, $info;
        push @return_plots, $plots;
        push @return_traits, $traits;
        push @return_store_hash, $store_hash;
    }
    #print STDERR Dumper \%store_hash;
    #print STDERR Dumper \@return;
    $c->stash->{rest} = {
        success => 1,
        info=>\@return_info,
        method=>$method,
        trait_name=>$trait_name,
        rounding=>$rounding,
        store_plots=>encode_json(\@return_plots),
        store_traits=>encode_json(\@return_traits),
        store_data=>encode_json(\@return_store_hash)
    };
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

	my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);

    my $overwrite = 0;
    if ($overwrite_values) {
        $overwrite = 1;
        my $user_type = $c->user()->get_object->get_user_type();
        #print STDERR $user_type."\n";
        if ($user_type ne 'curator') {
            $c->stash->{rest} = {error => 'Must be a curator to overwrite values! Please contact us!'};
            $c->detach;
        }
    }

    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_id = $c->user ? $c->user->get_object->get_sp_person_id : $c->req->param('user_id');
    $phenotype_metadata{'archived_file'} = 'none';
    $phenotype_metadata{'archived_file_type'}="generated from plot from plant phenotypes";
    $phenotype_metadata{'operator'}=$user_id;
    $phenotype_metadata{'date'}="$timestamp";

    for (my $i=0; $i<scalar(@$data); $i++) {
        my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
            basepath=>$c->config->{basepath},
            dbhost=>$c->config->{dbhost},
            dbname=>$c->config->{dbname},
            dbuser=>$c->config->{dbuser},
            dbpass=>$c->config->{dbpass},
            temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
            bcs_schema=>$schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>$plots->[$i],
            trait_list=>$traits->[$i],
            values_hash=>$data->[$i],
            has_timestamps=>0,
            overwrite_values=>$overwrite,
            metadata_hash=>\%phenotype_metadata,
						composable_validation_check_name=>$c->config->{composable_validation_check_name}
        );
        my ($store_error, $store_success) = $store_phenotypes->store();
        if ($store_error) {
            $c->stash->{rest} = {error => $store_error};
        }
    }
    $c->stash->{rest} = {success => 1};
}



1;
