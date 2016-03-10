package CXGN::Phenotypes::StorePhenotypes;

=head1 NAME

CXGN::Phenotypes::StorePhenotypes - an object to handle storing phenotypes for SGN stocks

=head1 USAGE

 my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
 $store_phenotypes->store($c,\@plot_list, \@trait_list, \%plot_trait_value, \%phenotype_metadata);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)
 Naama Menda (nm249@cornell.edu)
 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);


sub verify {
    my $self = shift;
    my $c = shift;
    my $plot_list_ref = shift;
    my $trait_list_ref = shift;
    my $plot_trait_value_hashref = shift;
    my $phenotype_metadata_ref = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $transaction_error;
    my @plot_list = @{$plot_list_ref};
    my @trait_list = @{$trait_list_ref};
    my %phenotype_metadata = %{$phenotype_metadata_ref};
    my %plot_trait_value = %{$plot_trait_value_hashref};
    my $plot_validator = CXGN::List::Validate->new();
    my $trait_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plot_validator->validate($schema,'plots',\@plot_list)->{'missing'}};
    my @traits_missing = @{$trait_validator->validate($schema,'traits',\@trait_list)->{'missing'}};
    my $phenotyping_experiment_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping experiment', 'experiment type');
    my $error_message;
    my $warning_message;

    if (scalar(@plots_missing) > 0 || scalar(@traits_missing) > 0) {
	print STDERR "Plots or traits not valid\n";
	print STDERR "Invalid plots: ".join(", ", map { "'$_'" } @plots_missing)."\n" if (@plots_missing);
	print STDERR "Invalid traits: ".join(", ", map { "'$_'" } @traits_missing)."\n" if (@traits_missing);
	$error_message = "Invalid plots: <br/>".join(", <br/>", map { "'$_'" } @plots_missing) if (@plots_missing);
	$error_message = "Invalid traits: <br/>".join(", <br/>", map { "'$_'" } @traits_missing) if (@traits_missing);
	return ($warning_message, $error_message);
    }

    my %check_unique_db;
    my $sql = "SELECT value, cvalue_id, uniquename FROM phenotype WHERE value is not NULL; ";
    my $sth = $c->dbc->dbh->prepare($sql);
    $sth->execute();

     while (my ($db_value, $db_cvalue_id, $db_uniquename) = $sth->fetchrow_array) {
	my ($stock_string, $rest_of_name) = split( /,/, $db_uniquename);
	$check_unique_db{$db_value, $db_cvalue_id, $stock_string} = 1;
    }

    my %check_trait_category;
    $sql = "SELECT b.value, c.cvterm_id from cvtermprop as b join cvterm as a on (b.type_id = a.cvterm_id) join cvterm as c on (b.cvterm_id=c.cvterm_id) where a.name = 'trait_categories';";
    $sth = $c->dbc->dbh->prepare($sql);
    $sth->execute();
    while (my ($category_value, $cvterm_id) = $sth->fetchrow_array) {
    	$check_trait_category{$cvterm_id} = $category_value;    	
    }

    my %check_trait_format;
    $sql = "SELECT b.value, c.cvterm_id from cvtermprop as b join cvterm as a on (b.type_id = a.cvterm_id) join cvterm as c on (b.cvterm_id=c.cvterm_id) where a.name = 'trait_format';";
    $sth = $c->dbc->dbh->prepare($sql);
    $sth->execute();
    while (my ($format_value, $cvterm_id) = $sth->fetchrow_array) {
    	$check_trait_format{$cvterm_id} = $format_value;    	
    }

    foreach my $plot_name (@plot_list) {
	foreach my $trait_name (@trait_list) {
	    my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};

	    if ($trait_value) {
		my $trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name)->cvterm_id();
		my $stock_id = $schema->resultset('Stock::Stock')->find({'uniquename' => $plot_name})->stock_id();

		#check that trait value is valid for trait name
		if (exists($check_trait_format{$trait_cvterm_id})) {
			if ($check_trait_format{$trait_cvterm_id} eq 'numeric') {
				my $trait_format_checked = looks_like_number($trait_value);
				if (!$trait_format_checked) {
					$error_message = $error_message."<small>This trait value should be numeric: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
				}
			}
		}
		if (exists($check_trait_category{$trait_cvterm_id})) {
			my @trait_categories = split /\//, $check_trait_category{$trait_cvterm_id};
			my %trait_categories_hash = map { $_ => 1 } @trait_categories;
			if (!exists($trait_categories_hash{$trait_value})) {
				$error_message = $error_message."<small>This trait value should be one of ".$check_trait_category{$trait_cvterm_id}.": <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
			}
		}
	
		#check if the plot_name, trait_name, trait_value combination already exists in database.
		if (exists($check_unique_db{$trait_value, $trait_cvterm_id, "Stock: ".$stock_id})) {
		    $warning_message = $warning_message."<small>This combination exists in database: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
		}
	    }
	}
    }


    ## Verify metadata
    if ($phenotype_metadata{'archived_file'} && (!$phenotype_metadata{'archived_file_type'} || $phenotype_metadata{'archived_file_type'} eq "")) {
	$error_message = "No file type provided for archived file.";
	return ($warning_message, $error_message);
    }
    if (!$phenotype_metadata{'operator'} || $phenotype_metadata{'operator'} eq "") {
	$error_message = "No operaror provided in file upload metadata.";
	return ($warning_message, $error_message);
    }
    if (!$phenotype_metadata{'date'} || $phenotype_metadata{'date'} eq "") {
	$error_message = "No date provided in file upload metadata.";
	return ($warning_message, $error_message);
    }
    
    return ($warning_message, $error_message);
}

sub store {
    my $self = shift;
    my $c = shift;
    my $size = shift;
    my $plot_list_ref = shift;

    ####
    #specify a trait list in addition to the hash of plot->trait->value because not all traits need to be present for each plot
    #the parser can decide to set an empty string as a trait value to create a record for missing data,
    #or store nothing in the hash to create no phenotype record for missing data
    my $trait_list_ref = shift;
    my $plot_trait_value_hashref = shift;
    #####

    my $error_message;
    my $phenotype_metadata = shift;
    my $transaction_error;
    my @plot_list = @{$plot_list_ref};
    my @trait_list = @{$trait_list_ref};
    my %plot_trait_value = %{$plot_trait_value_hashref};
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    if (!$user_id) { #For unit_test, SimulateC
	$user_id = $c->sp_person_id();
    }
    my $archived_file = $phenotype_metadata->{'archived_file'};
    my $archived_file_type = $phenotype_metadata->{'archived_file_type'};
    my $operator = $phenotype_metadata->{'operator'};
    my $phenotyping_date = $phenotype_metadata->{'date'};

    my $phenotyping_experiment_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping experiment', 'experiment_type');

    ## Track experiments seen to allow for multiple trials and experiments to exist in an uploaded file.
    ## Used later to attach file metadata.
    my %experiment_ids;##
    ###

    ## Use txn_do with the following coderef so that if any part fails, the entire transaction fails.

    #For storing files where num_plots * num_traits <= 100.
    my $coderef_small_file = sub {

	foreach my $plot_name (@plot_list) {

	    #print STDERR "plot: $plot_name\n";
	    my $plot_stock = $schema->resultset("Stock::Stock")->find( { uniquename => $plot_name});
	    my $plot_stock_id = $plot_stock->stock_id;

	    ###This has to be stored in the database when creating a trial for these plots
	    my $field_layout_experiment = $plot_stock
		->search_related('nd_experiment_stocks')
		    ->search_related('nd_experiment')
			->find({'type.name' => 'field layout' },
			       { join => 'type' });
	    #####

	    my $location_id = $field_layout_experiment->nd_geolocation_id;
	    my $project = $field_layout_experiment
		->nd_experiment_projects->single ; #there should be one project linked with the field experiment
	    my $project_id = $project->project_id;

	    foreach my $trait_name (@trait_list) {

		#print STDERR "trait: $trait_name\n";

		my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name);
		my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};

		if ($trait_value || $trait_value eq '0') {

		    my $plot_trait_uniquename = "Stock: " .
		    $plot_stock_id . ", trait: " .
			$trait_cvterm->name .
			    " date: $phenotyping_date" .
				"  operator = $operator" ;
		    my $phenotype = $trait_cvterm
		    ->find_or_create_related("phenotype_cvalues", {
			observable_id => $trait_cvterm->cvterm_id,
			value => $trait_value ,
			uniquename => $plot_trait_uniquename,
					     });
		
		#print STDERR "\n[StorePhenotypes] Storing plot: $plot_name trait: $trait_name value: $trait_value:\n";
		my $experiment;
		
		## Find the experiment that matches the location, type, operator, and date/timestamp if it exists
		# my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
		#     ->find({
		# 	    nd_geolocation_id => $location_id,
		# 	    type_id => $phenotyping_experiment_cvterm->cvterm_id(),
		# 	    'type.name' => 'operator',
		# 	    'nd_experimentprops.value' => $operator,
		# 	    'type_2.name' => 'date',
		# 	    'nd_experimentprops_2.value' => $phenotyping_date,
		# 	   },
		# 	   {
		# 	    join => [{'nd_experimentprops' => 'type'},{'nd_experimentprops' => 'type'},{'nd_experiment_phenotypes' => 'type'}],
		# 	   });


		    # Create a new experiment, if one does not exist
		    if (!$experiment) {
			$experiment = $schema->resultset('NaturalDiversity::NdExperiment')
			    ->create({nd_geolocation_id => $location_id, type_id => $phenotyping_experiment_cvterm->cvterm_id()});
			$experiment->create_nd_experimentprops({date => $phenotyping_date},{autocreate => 1, cv_name => 'local'});
			$experiment->create_nd_experimentprops({operator => $operator}, {autocreate => 1 ,cv_name => 'local'});
		    }

		    ## Link the experiment to the project
		    $experiment->create_related('nd_experiment_projects', {project_id => $project_id});

		    # Link the experiment to the stock
		    $experiment->create_related('nd_experiment_stocks', 
						{
						 stock_id => $plot_stock_id,
						 type_id => $phenotyping_experiment_cvterm->cvterm_id
						});

		    ## Link the phenotype to the experiment
		    $experiment->create_related('nd_experiment_phenotypes', {phenotype_id => $phenotype->phenotype_id });
		    #print STDERR "[StorePhenotypes] Linking phenotype: $plot_trait_uniquename to experiment " .$experiment->nd_experiment_id . "Time:".localtime()."\n";

		    $experiment_ids{$experiment->nd_experiment_id()}=1;
		}
	    }
	}
    };

    #For storing files where num_plots * num_traits > 100.
    my $coderef_large_file = sub {

	my $rs = $schema->resultset('Stock::Stock')->search(
	    {'type.name' => 'field layout'},
	    {join=> {'nd_experiment_stocks' => {'nd_experiment' => ['type', 'nd_experiment_projects'  ] } } ,
	     '+select'=> ['me.stock_id', 'me.uniquename', 'nd_experiment.nd_geolocation_id', 'nd_experiment_projects.project_id'], 
	     '+as'=> ['stock_id', 'uniquename', 'nd_geolocation_id', 'project_id']
	    }
	);
	my %data;
	while (my $s = $rs->next()) { 
	    $data{$s->get_column('uniquename')} = [$s->get_column('stock_id'), $s->get_column('nd_geolocation_id'), $s->get_column('project_id') ];
	}

	foreach my $plot_name (@plot_list) {

	    my $plot_stock_id = $data{$plot_name}[0];
	    my $location_id = $data{$plot_name}[1];
	    my $project_id = $data{$plot_name}[2];

	    foreach my $trait_name (@trait_list) {

		my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name);
		my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};

		if ($trait_value || $trait_value eq '0') {

		    my $plot_trait_uniquename = "Stock: " .
		    $plot_stock_id . ", trait: " .
			$trait_cvterm->name .
			    " date: $phenotyping_date" .
				"  operator = $operator" ;
		    my $phenotype = $trait_cvterm
		    ->find_or_create_related("phenotype_cvalues", {
								   observable_id => $trait_cvterm->cvterm_id,
								   value => $trait_value ,
								   uniquename => $plot_trait_uniquename,
								  });

		    my $experiment;

		## Find the experiment that matches the location, type, operator, and date/timestamp if it exists
		# my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
		#     ->find({
		# 	    nd_geolocation_id => $location_id,
		# 	    type_id => $phenotyping_experiment_cvterm->cvterm_id(),
		# 	    'type.name' => 'operator',
		# 	    'nd_experimentprops.value' => $operator,
		# 	    'type_2.name' => 'date',
		# 	    'nd_experimentprops_2.value' => $phenotyping_date,
		# 	   },
		# 	   {
		# 	    join => [{'nd_experimentprops' => 'type'},{'nd_experimentprops' => 'type'},{'nd_experiment_phenotypes' => 'type'}],
		# 	   });


		    # Create a new experiment, if one does not exist
		    if (!$experiment) {
			$experiment = $schema->resultset('NaturalDiversity::NdExperiment')
			    ->create({nd_geolocation_id => $location_id, type_id => $phenotyping_experiment_cvterm->cvterm_id()});
			$experiment->create_nd_experimentprops({date => $phenotyping_date},{autocreate => 1, cv_name => 'local'});
			$experiment->create_nd_experimentprops({operator => $operator}, {autocreate => 1 ,cv_name => 'local'});
		    }

		    ## Link the experiment to the project
		    $experiment->create_related('nd_experiment_projects', {project_id => $project_id});

		    # Link the experiment to the stock
		    $experiment->create_related('nd_experiment_stocks', 
						{
						 stock_id => $plot_stock_id,
						 type_id => $phenotyping_experiment_cvterm->cvterm_id
						});

		    ## Link the phenotype to the experiment
		    $experiment->create_related('nd_experiment_phenotypes', {phenotype_id => $phenotype->phenotype_id });
		    #print STDERR "[StorePhenotypes] Linking phenotype: $plot_trait_uniquename to experiment " .$experiment->nd_experiment_id . "Time:".localtime()."\n";

		    $experiment_ids{$experiment->nd_experiment_id()}=1;
		}
	    }
	}
    };

    if ($size <= 100) {
	try {
	    $schema->txn_do($coderef_small_file);
	} catch {
	    $transaction_error =  $_;
	};
    }
    elsif ($size > 100) {
	try {
	    $schema->txn_do($coderef_large_file);
	} catch {
	    $transaction_error =  $_;
	};
    }

    if ($transaction_error) {
	$error_message = $transaction_error;
	print STDERR "Transaction error storing phenotypes: $transaction_error\n";
	return $error_message;
    }

    if ($archived_file) {
	## Insert metadata about the uploaded file only after a successful phenotype data transaction
	my $md5 = Digest::MD5->new();
	my $file_row;
	my $md_row;
	my $file_metadata_transaction_error;
	open(my $F, "<", $archived_file) || die "Can't open file ".$archived_file;
	binmode $F;
	$md5->addfile($F);
	close($F);
	$md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id,});
	$md_row->insert();
	$file_row = $metadata_schema->resultset("MdFiles")
	    ->create({
		      basename => basename($archived_file),
		      dirname => dirname($archived_file),
		      filetype => $archived_file_type,
		      md5checksum => $md5->hexdigest(),
		      metadata_id => $md_row->metadata_id(),
		     });
	$file_row->insert();
	foreach my $nd_experiment_id (keys %experiment_ids) {
	    ## Link the file to the experiment
	   my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")
		->create({
			  nd_experiment_id => $nd_experiment_id,
			  file_id => $file_row->file_id(),
			 });
	    $experiment_files->insert();
	    #print STDERR "[StorePhenotypes] Linking file: $archived_file \n\t to experiment id " . $nd_experiment_id . "\n";
	}
    }

    return $error_message;
}



###
1;
###
