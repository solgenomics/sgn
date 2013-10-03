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

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;

sub _verify {
    my $self = shift;
    my $c = shift;
    my $plot_list_ref = shift;
    my $trait_list_ref = shift;
    my $plot_trait_value_hashref = shift;
    my $phenotype_metadata = shift;
    my $transaction_error;
    my @plot_list = @{$plot_list_ref};
    my @trait_list = @{$trait_list_ref};
    my %plot_trait_value = %{$plot_trait_value_hashref};
    my $plot_validator = CXGN::List::Validate->new();
    my $trait_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plot_validator->validate($c,'plots',\@plot_list)->{'missing'}};
    my @traits_missing = @{$trait_validator->validate($c,'traits',\@trait_list)->{'missing'}};
    if (scalar(@plots_missing) > 0 || scalar(@traits_missing) > 0) {
	print STDERR "Not validated\n";
	return;
    }
    foreach my $plot_name (@plot_list) {
	foreach my $trait_name (@trait_list) {
	    my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};
	    #check that trait value is valid for trait name
	}
    }
    print STDERR "Validated traits and plots\n";
    return 1;
}


sub store {
    my $self = shift;
    my $c = shift;
    my $plot_list_ref = shift;

    ####
    #specify a trait list in addition to the hash of plot->trait->value because not all traits need to be present for each plot
    #the parser can decide to set an empty string as a trait value to create a record for missing data,
    #or store nothing in the hash to create no phenotype record for missing data
    my $trait_list_ref = shift;
    my $plot_trait_value_hashref = shift;
    #####

    my $phenotype_metadata = shift;
    my $transaction_error;
    my @plot_list = @{$plot_list_ref};
    my @trait_list = @{$trait_list_ref};
    my %plot_trait_value = %{$plot_trait_value_hashref};
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $archived_file = $phenotype_metadata->{'archived_file'};
    my $archived_file_type = $phenotype_metadata->{'archived_file_type'};
    my $operator = $phenotype_metadata->{'operator'};
    my $phenotyping_date = $phenotype_metadata->{'date'};
    my $phenotyping_experiment_cvterm = $schema->resultset('Cv::Cvterm')
	->create_with({
		       name   => 'phenotyping experiment',
		       cv     => 'experiment type',
		       db     => 'null',
		       dbxref => 'phenotyping experiment',
		      });

    ## Track experiments seen to allow for multiple trials and experiments to exist in an uploaded file.
    ## Used later to attach file metadata.
    my %experiment_ids;##
    ###

    ## Use txn_do with the following coderef so that if any part fails, the entire transaction fails
    my $coderef = sub {
	foreach my $plot_name (@plot_list) {
	    print STDERR "plot: $plot_name\n";
	    my $plot_stock = $schema->resultset("Stock::Stock")->find( { uniquename => $plot_name});
	    my $plot_stock_id = $plot_stock->stock_id;

	    ###This has to be stored in the database when creating a trial for these plots
	    my $field_layout_experiment = $plot_stock->search_related('nd_experiment_stocks')->search_related('nd_experiment')->find({'type.name' => 'field layout' },{ join => 'type' });
	    #####

	    my $location_id = $field_layout_experiment->nd_geolocation_id;
	    my $project = $field_layout_experiment->nd_experiment_projects->single ; #there should be one project linked with the field experiment
	    my $project_id = $project->project_id;


	    foreach my $trait_name (@trait_list) {
		print STDERR "trait: $trait_name\n";
		my ($db_name, $ontology_accession) = split (/:/, $trait_name);
		my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};
		my $ontology_db = $schema->resultset("General::Db")->search({'me.name' => $db_name, });
		my $ontology_dbxref = $ontology_db->search_related("dbxrefs", { accession => $ontology_accession, });
		my $trait_cvterm = $ontology_dbxref->search_related("cvterm")->single;
		my $plot_trait_uniquename = "Stock: " . $plot_stock_id . ", trait: " . $trait_cvterm->name . " date: $phenotyping_date" . "  operator = $operator" ;
		my $phenotype = $trait_cvterm->find_or_create_related("phenotype_cvalues", {
											    observable_id => $trait_cvterm->cvterm_id,
											    value => $trait_value ,
											    uniquename => $plot_trait_uniquename,
											   });

		print STDERR "\n[StorePhenotypes] Storing plot: $plot_name trait: $trait_name value: $trait_value:\n";

		## Store a new nd_experiment. One phenotyping experiment per upload
		## find if a phenotyping experiment exists for this location
		my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
		    ->find({
			    nd_geolocation_id => $location_id,
			    type_id => $phenotyping_experiment_cvterm->cvterm_id(),
			   });

		## Find if the experiment has the date and person of this upload, if yes, use the existing one, if no, create a new nd_experiment
		my ($op_prop, $date_prop);
		if ($experiment) {
		    $op_prop = $experiment->search_related('nd_experimentprops',{'type.name' => 'operator', value => $operator},{ join => 'type'})->single;
		    $date_prop = $experiment->search_related('nd_experimentprops',{'type.name' => 'date', value => $phenotyping_date},{ join => 'type'})->single;
		}

		# Create a new experiment, if one does not exist
		# or operator and date are not linked with the existing experiment
		if ( !($op_prop && $date_prop) || !$experiment ) {
		    $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({nd_geolocation_id => $location_id, type_id => $phenotyping_experiment_cvterm->cvterm_id()});
		    $experiment->create_nd_experimentprops({date => $phenotyping_date},{autocreate => 1, cv_name => 'local'});
		    $experiment->create_nd_experimentprops({operator => $operator}, {autocreate => 1 ,cv_name => 'local'});
		    print STDERR "[StorePhenotypes] Created new experiment: " . $experiment->nd_experiment_id . "\n";
		}

		## Link the experiment to the project
		$experiment->find_or_create_related('nd_experiment_projects', {project_id => $project_id});
		print STDERR "[StorePhenotypes] Linking experiment " . $experiment->nd_experiment_id . " with project $project_id \n";

		# Link the experiment to the stock
		$experiment->find_or_create_related('nd_experiment_stocks', {stock_id => $plot_stock_id, type_id => $phenotyping_experiment_cvterm->cvterm_id});
		print STDERR "[StorePhenotypes] Linking experiment " . $experiment->nd_experiment_id . " to stock $plot_stock_id \n";

		## Link the phenotype to the experiment
		$experiment->find_or_create_related('nd_experiment_phenotypes', {phenotype_id => $phenotype->phenotype_id });
		print STDERR "[StorePhenotypes] Linking phenotype:\n\t $plot_trait_uniquename \n\t to experiment " . $experiment->nd_experiment_id . "\n";

		$experiment_ids{$experiment->nd_experiment_id()}=1;
	    }
	}
    };

    ## Verify phenotype data
    if (!$self->_verify($c, $plot_list_ref, $trait_list_ref, $plot_trait_value_hashref, $phenotype_metadata)) {
	return;
    }

    ## Verify metadata
    ####


    try {
	$schema->txn_do($coderef);
    } catch {
	$transaction_error =  $_;
    };

    if ($transaction_error) {
	print STDERR "Transaction error storing phenotypes: $transaction_error\n";
	return;
    }

    if ($archived_file) {
	## Insert metadata about the uploaded file only after a successful phenotype data transaction
	my $md5 = Digest::MD5->new();
	my $file_row;
	my $md_row;
	open(my $F, "<", $archived_file) || die "Can't open file ".$archived_file;
	binmode $F;
	$md5->addfile($F);
	close($F);
	$file_row = $metadata_schema->resultset("MdFiles")
	    ->create({
		      basename => basename($archived_file),
		      dirname => dirname($archived_file),
		      filetype => 'phenotype spreadsheet upload xls',
		      md5checksum => $md5->digest(),
		      metadata_id => $md_row->metadata_id(),
		     });
	$file_row->insert();
	$md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id,});
	$md_row->insert();
	foreach my $nd_experiment_id (keys %experiment_ids) {
	    ## Link the file to the experiment
	    my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")
		->create({
			  nd_experiment_id => $nd_experiment_id,
			  file_id => $file_row->file_id(),
			 });
	    $experiment_files->insert();
	    print STDERR "[StorePhenotypes] Linking file: $archived_file \n\t to experiment id " . $nd_experiment_id . "\n";
	}
    }

    return 1;
}



###
1;
###
