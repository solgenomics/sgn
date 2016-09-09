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
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

sub verify {
    my $self = shift;
    my $c = shift;
    my $plot_list_ref = shift;
    my $trait_list_ref = shift;
    my $plot_trait_value_hashref = shift;
    my $phenotype_metadata_ref = shift;
    my $timestamp_included = shift;
    my $archived_image_zipfile_with_path = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $transaction_error;
    my @plot_list = @{$plot_list_ref};
    my @trait_list = @{$trait_list_ref};
    my %phenotype_metadata = %{$phenotype_metadata_ref};
    my %plot_trait_value = %{$plot_trait_value_hashref};
    #print STDERR Dumper \%plot_trait_value;
    my $plot_validator = CXGN::List::Validate->new();
    my $trait_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plot_validator->validate($schema,'plots_or_plants',\@plot_list)->{'missing'}};
    my @traits_missing = @{$trait_validator->validate($schema,'traits',\@trait_list)->{'missing'}};
    my $phenotyping_experiment_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type');
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

    my %check_unique_value_trait_stock;
    my %check_unique_trait_stock;
    my $sql = "SELECT value, cvalue_id, uniquename FROM phenotype WHERE value is not NULL; ";
    my $sth = $c->dbc->dbh->prepare($sql);
    $sth->execute();

    while (my ($db_value, $db_cvalue_id, $db_uniquename) = $sth->fetchrow_array) {
        my ($stock_string, $rest_of_name) = split( /,/, $db_uniquename);
        $check_unique_value_trait_stock{$db_value, $db_cvalue_id, $stock_string} = 1;
        $check_unique_trait_stock{$db_cvalue_id, $stock_string} = $db_value;
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

    my %zip_members;
    my %image_plot_full_names;
    if ($archived_image_zipfile_with_path) {
        print STDERR $archived_image_zipfile_with_path."\n";
        my $archived_zip = Archive::Zip->new();
        unless ( $archived_zip->read( $archived_image_zipfile_with_path ) == AZ_OK ) {
            $error_message = $error_message."<small>Image zipfile cannot be read!</small><hr>";
        }
        my @file_names = $archived_zip->memberNames();
        my @image_plot_names;
        foreach (@file_names) {
            my @zip_names_split = split(/\//, $_);
            if ($zip_names_split[1] ne '' && $zip_names_split[1] ne '.DS_Store') {
                my @zip_names_split_ext = split(/\./, $zip_names_split[1]);
                $zip_members{$zip_names_split_ext[0]} = 1;
                if ($zip_names_split_ext[1] ne 'jpg' && $zip_names_split_ext[1] ne 'png') {
                    $error_message = $error_message."<small>Image ".$zip_names_split[1]." in images zip file should be .jpg or .png!</small><hr>";
                }
                push @image_plot_names, $zip_names_split_ext[0];
                $image_plot_full_names{$zip_names_split[1]} = 1;
            }
        }

        my %plot_name_check;
        foreach (@plot_list) {
            $plot_name_check{$_} = 1;
        }
        foreach (@image_plot_names) {
            if (!exists($plot_name_check{$_})) {
                $error_message = $error_message."<small>Image ".$_." in images zip file does not reference a plot or plant_name!</small><hr>";
            }
        }
    }

    print STDERR Dumper \%zip_members;


    #print STDERR Dumper \@trait_list;
    my %check_file_stock_trait_duplicates;

    foreach my $plot_name (@plot_list) {
        foreach my $trait_name (@trait_list) {
            my $value_array = $plot_trait_value{$plot_name}->{$trait_name};
            #print STDERR Dumper $value_array;
            my $trait_value = $value_array->[0];
            my $timestamp = $value_array->[1];

            if ($trait_value) {
                my $trait_cvterm_id;
                #For multiterm traits of the form trait1|CO:0000001||trait2|CO:00000002
                if ($trait_name =~ /\|\|/ ) {
                    $trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $trait_name, 'cassava_trait')->cvterm_id();
                } else {
                    $trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name)->cvterm_id();
                }
                my $stock_id = $schema->resultset('Stock::Stock')->find({'uniquename' => $plot_name})->stock_id();

                #check that trait value is valid for trait name
                if (exists($check_trait_format{$trait_cvterm_id})) {
                    if ($check_trait_format{$trait_cvterm_id} eq 'numeric') {
                        my $trait_format_checked = looks_like_number($trait_value);
                        if (!$trait_format_checked) {
                            $error_message = $error_message."<small>This trait value should be numeric: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
                        }
                    }
                    if ($check_trait_format{$trait_cvterm_id} eq 'image') {
                        if (!exists($image_plot_full_names{$trait_value})) {
                            $error_message = $error_message."<small>For Plot Name: $plot_name there should be a corresponding image named in the zipfile as $plot_name.jpg. </small><hr>";
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

                #check if the plot_name, trait_name combination already exists in database.
                if (exists($check_unique_value_trait_stock{$trait_value, $trait_cvterm_id, "Stock: ".$stock_id})) {
                    $warning_message = $warning_message."<small>$plot_name already has the same value as in your file ($trait_value) stored for the trait $trait_name.</small><hr>";
                } elsif (exists($check_unique_trait_stock{$trait_cvterm_id, "Stock: ".$stock_id})) {
                    $warning_message = $warning_message."<small>$plot_name already has a different value ($check_unique_trait_stock{$trait_cvterm_id, 'Stock: '.$stock_id}) than in your file ($trait_value) stored in the database for the trait $trait_name.</small><hr>";
                }

                #check if the plot_name, trait_name combination already exists in same file.
                if (exists($check_file_stock_trait_duplicates{$trait_cvterm_id, $stock_id})) {
                    $warning_message = $warning_message."<small>$plot_name already has a value for the trait $trait_name in your file. Possible duplicate in your file?</small><hr>";
                }
                $check_file_stock_trait_duplicates{$trait_cvterm_id, $stock_id} = 1;
            }

            if ($timestamp_included) {
                if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
                    if ($timestamp) {
                        if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                            $error_message = $error_message."<small>Bad timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
                        }
                    }
                } else {
                    $error_message = $error_message."<small>'Timestamps Included' is selected, but no timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."</small><hr>";
                }
            } else {
                if ($timestamp) {
                    $error_message = $error_message."<small>Timestamps found in file, but 'Timestamps Included' is not selected.</small><hr>";
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

    my $phenotype_metadata = shift;
    my $data_level = shift;
    my $overwrite_values = shift;
    my $error_message;
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
    my $upload_date = $phenotype_metadata->{'date'};

    my $phenotyping_experiment_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type');
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();

    ## Track experiments seen to allow for multiple trials and experiments to exist in an uploaded file.
    ## Used later to attach file metadata.
    my %experiment_ids;##
    ###

    my %check_unique_trait_stock;
    if ($overwrite_values) {
        my $sql = "SELECT cvalue_id, uniquename FROM phenotype WHERE value is not NULL; ";
        my $sth = $c->dbc->dbh->prepare($sql);
        $sth->execute();

        while (my ($db_cvalue_id, $db_uniquename) = $sth->fetchrow_array) {
            my ($stock_string, $rest_of_name) = split( /,/, $db_uniquename);
            $check_unique_trait_stock{$db_cvalue_id, $stock_string} = 1;
        }
    }

    ## Use txn_do with the following coderef so that if any part fails, the entire transaction fails.

    #For storing files where num_plots * num_traits <= 100.
    my $coderef_small_file = sub {

        foreach my $plot_name (@plot_list) {

            #print STDERR "plot: $plot_name\n";
            my $stock = $schema->resultset("Stock::Stock")->find( { uniquename => $plot_name, 'me.type_id' => [$plot_cvterm_id, $plant_cvterm_id] } );
            my $stock_id = $stock->stock_id;

            my $field_layout_experiment = $stock
                ->search_related('nd_experiment_stocks')
                ->search_related('nd_experiment')
                ->find({'type.name' => 'field_layout' },
                { join => 'type' });

            my $location_id = $field_layout_experiment->nd_geolocation_id;
            my $project = $field_layout_experiment->nd_experiment_projects->single ; #there should be one project linked with the field experiment
            my $project_id = $project->project_id;

            foreach my $trait_name (@trait_list) {

                #print STDERR "trait: $trait_name\n";
                my $trait_cvterm;
                #For multiterm traits of the form trait1|CO:0000001||trait2|CO:00000002
                if ($trait_name =~ /\|\|/ ) {
                    $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, $trait_name, 'cassava_trait');
                } else {
                    $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name);
                }
                my $value_array = $plot_trait_value{$plot_name}->{$trait_name};
                #print STDERR Dumper $value_array;
                my $trait_value = $value_array->[0];
                my $timestamp = $value_array->[1];
                if (!$timestamp) {
                    $timestamp = 'NA'.$upload_date;
                }

                if ($trait_value || $trait_value eq '0') {

                    #Remove previous phenotype values for a given stock and trait, if $overwrite values is checked
                    if ($overwrite_values) {
                        if (exists($check_unique_trait_stock{$trait_cvterm->cvterm_id(), "Stock: ".$stock_id})) {
                            my $overwrite_phenotypes_rs = $schema->resultset("Phenotype::Phenotype")->search({uniquename=>{'like' => 'Stock: '.$stock_id.'%'}, cvalue_id=>$trait_cvterm->cvterm_id() });
                            while (my $previous_phenotype = $overwrite_phenotypes_rs->next()) {
                                #print STDERR "removing phenotype: ".$previous_phenotype->uniquename()."\n";
                                $previous_phenotype->delete();
                            }
                        }
                        $check_unique_trait_stock{$trait_cvterm->cvterm_id(), "Stock: ".$stock_id} = 1;
                    }

		    my $plot_trait_uniquename = "Stock: " .
		    $stock_id . ", trait: " .
			$trait_cvterm->name .
			    " date: $timestamp" .
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
		# 	    'nd_experimentprops_2.value' => $upload_date,
		# 	   },
		# 	   {
		# 	    join => [{'nd_experimentprops' => 'type'},{'nd_experimentprops' => 'type'},{'nd_experiment_phenotypes' => 'type'}],
		# 	   });


                    # Create a new experiment, if one does not exist
                    if (!$experiment) {
                        $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
                        ->create({nd_geolocation_id => $location_id, type_id => $phenotyping_experiment_cvterm->cvterm_id()});
                        $experiment->create_nd_experimentprops({date => $upload_date},{autocreate => 1, cv_name => 'local'});
                        $experiment->create_nd_experimentprops({operator => $operator}, {autocreate => 1 ,cv_name => 'local'});
                    }

                    ## Link the experiment to the project
                    $experiment->create_related('nd_experiment_projects', {project_id => $project_id});

                    # Link the experiment to the stock
                    $experiment->create_related('nd_experiment_stocks', {stock_id => $stock_id, type_id => $phenotyping_experiment_cvterm->cvterm_id});

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

        my $rs;
        my %data;

        $rs = $schema->resultset('Stock::Stock')->search(
            {'type.name' => 'field_layout', 'me.type_id' => [$plot_cvterm_id, $plant_cvterm_id] },
            {join=> {'nd_experiment_stocks' => {'nd_experiment' => ['type', 'nd_experiment_projects'  ] } } ,
                '+select'=> ['me.stock_id', 'me.uniquename', 'nd_experiment.nd_geolocation_id', 'nd_experiment_projects.project_id'],
                '+as'=> ['stock_id', 'uniquename', 'nd_geolocation_id', 'project_id']
            }
        );
        while (my $s = $rs->next()) {
            $data{$s->get_column('uniquename')} = [$s->get_column('stock_id'), $s->get_column('nd_geolocation_id'), $s->get_column('project_id') ];
        }

        foreach my $plot_name (@plot_list) {

            my $stock_id = $data{$plot_name}[0];
            my $location_id = $data{$plot_name}[1];
            my $project_id = $data{$plot_name}[2];

            foreach my $trait_name (@trait_list) {

                #print STDERR "trait: $trait_name\n";
                my $trait_cvterm;
                #For multiterm traits of the form trait1|CO:0000001||trait2|CO:00000002
                if ($trait_name =~ /\|\|/ ) {
                    $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, $trait_name, 'cassava_trait');
                } else {
                    $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name);
                }

                my $value_array = $plot_trait_value{$plot_name}->{$trait_name};
                #print STDERR Dumper $value_array;
                my $trait_value = $value_array->[0];
                my $timestamp = $value_array->[1];
                if (!$timestamp) {
                    $timestamp = 'NA';
                }

		if ($trait_value || $trait_value eq '0') {

            #Remove previous phenotype values for a given stock and trait, if $overwrite values is checked
            if ($overwrite_values) {
                if (exists($check_unique_trait_stock{$trait_cvterm->cvterm_id(), "Stock: ".$stock_id})) {
                    my $overwrite_phenotypes_rs = $schema->resultset("Phenotype::Phenotype")->search({uniquename=>{'like' => 'Stock: '.$stock_id.'%'}, cvalue_id=>$trait_cvterm->cvterm_id() });
                    while (my $previous_phenotype = $overwrite_phenotypes_rs->next()) {
                        #print STDERR "removing phenotype: ".$previous_phenotype->uniquename()."\n";
                        $previous_phenotype->delete();
                    }
                }
                $check_unique_trait_stock{$trait_cvterm->cvterm_id(), "Stock: ".$stock_id} = 1;
            }

		    my $plot_trait_uniquename = "Stock: " .
		    $stock_id . ", trait: " .
			$trait_cvterm->name .
			    " date: $timestamp" .
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
		# 	    'nd_experimentprops_2.value' => $upload_date,
		# 	   },
		# 	   {
		# 	    join => [{'nd_experimentprops' => 'type'},{'nd_experimentprops' => 'type'},{'nd_experiment_phenotypes' => 'type'}],
		# 	   });


		    # Create a new experiment, if one does not exist
		    if (!$experiment) {
                $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
                    ->create({nd_geolocation_id => $location_id, type_id => $phenotyping_experiment_cvterm->cvterm_id()});
                $experiment->create_nd_experimentprops({date => $upload_date},{autocreate => 1, cv_name => 'local'});
                $experiment->create_nd_experimentprops({operator => $operator}, {autocreate => 1 ,cv_name => 'local'});
            }

            ## Link the experiment to the project
            $experiment->create_related('nd_experiment_projects', {project_id => $project_id});

            # Link the experiment to the stock
            $experiment->create_related('nd_experiment_stocks', { stock_id => $stock_id, type_id => $phenotyping_experiment_cvterm->cvterm_id });

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
	if ($archived_file ne 'none') {
		open(my $F, "<", $archived_file) || die "Can't open file ".$archived_file;
		binmode $F;
		$md5->addfile($F);
		close($F);
	}
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
