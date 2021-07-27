
package CXGN::BreedersToolbox::Delete;

use Moose;

use Data::Dumper;

has bcs_schema => (is => 'rw');
has metadata_schema => (is=> 'rw');
has phenome_schema => (is => 'rw');

=head2 delete_experiments_by_file
 SEEMS TO BE DEPRECATED BECAUSE CRUCIAL FUNCTIONS WITHIN THIS CALL ARE COMMENTED OUT
 
 Currently using SGN::Controller::AJAX::BreedersToolbox->delete_uploaded_phenotype_files to delete phenotype files from manage phenotype page
 
 Usage:        $cpd->delete_experiments_by_file($user_id, $md_file_id);
 Desc:         deletes the phenotype information associated with file $md_file_id
 Ret:          a hash with deletion statistics
 Args:         a user_id (for privilege check),
               an md_file_id (primary key of metadata.md_files)
 Side Effects: connects to the database and deletes information (be careful!)
 Example:

=cut

# sub delete_experiments_by_file {
#     my $self = shift;
#     my $user_id = shift;
#     my $md_file_id = shift;
# 
#     print STDERR "Get the md_file entry... ";
#     my $srs = $self->metadata_schema->resultset("MdFiles")->search( { file_id => $md_file_id } );
# 
#     print STDERR "Retrieved ".$srs->count()." entries.\n";
#     if ($srs->count() == 0) {
# 	return "The file specified does not exist."
#     }
# 
#     my $file_row = $srs->first();
#     my $metadata_id = $file_row->metadata_id()->metadata_id();
# 
#     print STDERR "Get the associated md_metadata info... ($metadata_id, $user_id)";
# 
#     my $frs = $self->metadata_schema->resultset("MdMetadata")->search( { metadata_id => $metadata_id, create_person_id=>$user_id });
# 
#     print STDERR "Retrieved ".$frs->count()." entries.\n";
#     if ($frs->count()==0) {
# 	return "You don't have the necessary privileges to delete this file";
#     }
# 
#     print STDERR "Get the entries from the linking table... ";
#     my $prs = $self->phenome_schema -> resultset("NdExperimentMdFiles")->search( { file_id => $md_file_id });
# 
#     print STDERR "Retrieved ".$prs->count()." entries.\n";
#     if ($prs->count() == 0) {
# 	print STDERR "No experiments have been loaded for file with md_file_id $md_file_id\n";
#     }
#     else {
# 	foreach my $prs_row ($prs->rows()) {
# 	    print STDERR "Deleting the MdExperiment entries... ";
# 
# 	    # first delete the entry in the linking table...
# 	    #
# 	    my $nd_experiment_id = $prs_row->nd_experiment_id();
# 	    $prs_row->delete();
# 
# 	    $self->_delete_phenotype_experiments($nd_experiment_id);
# 	}
#     }
# 
#     # set md_files and/or metadata to obsolote
#     print STDERR "Update the md_file table to obsolete... ";
#     my $mdmd_row = $self->metadata_schema->resultset("MdMetadata")->find( { metadata_id => $metadata_id } );
#     if ($mdmd_row) {
# 	$mdmd_row -> update( { obsolete => 1 });
#     }
#     print STDERR "Done.\n";
#     print STDERR "Delete complete.\n";
# 
# }

# sub delete_phenotype_data_by_trial {
#     my $self = shift;
#     my $trial_id = shift;


#     $self->bcs_schema->txn_do(
# 	sub {
# 	    # first, delete metadata entries
# 	    #
# 	    $self->delete_metadata_by_trial($trial_id);

# 	    # delete phenotype data associated with trial
# 	    #
# 	    my $trial = $self->bcs_schema()->resultset("Project::Project")->search( { project_id => $trial_id });

# 	    my $nd_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search( { project_id => $trial_id });
# 	    my @nd_experiment_ids = map { $_->nd_experiment_id } $nd_experiment_rs->all();

# 	    $self->_delete_phenotype_experiments(@nd_experiment_ids); # cascading deletes should take care of everything (IT DOESNT????)

# 	});

# }

# sub delete_field_layout_by_trial {
#     my $self = shift;
#     my $trial_id = shift;

#     # first, delete metadata entries
#     #
#     $self->bcs_schema()->txn_do(
# 	sub {
# 	    $self->delete_metadata_by_trial($trial_id);

# 	    my $trial = $self->bcs_schema()->resultset("Project::Project")->search( { project_id => $trial_id });

# 	    my $nd_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search( { project_id => $trial_id });
# 	    my @nd_experiment_ids = map { $_->nd_experiment_id } $nd_experiment_rs->all();

# 	    print STDERR "ND EXPERIMENTS: ".(join ",", @nd_experiment_ids)."\n";

# 	    print STDERR "DELETING trial layout for trial id $trial_id...\n";
# 	    return $self->_delete_field_layout_experiment($trial_id);
# 	}
# 	);
# }

# sub delete_metadata_by_trial {
#     my $self = shift;
#     my $trial_id = shift;


#     # first, deal with entries in the md_metadata table, which may reference nd_experiment (through linking table)
#     my $q = "SELECT distinct(metadata_id) FROM nd_experiment_project JOIN phenome.nd_experiment_md_files using(nd_experiment_id) JOIN metadata.md_files using(file_id) JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
#     my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
#     $h->execute($trial_id);

#     while (my ($md_id) = $h->fetchrow_array()) {
# 	my $mdmd_row = $self->metadata_schema->resultset("MdMetadata")->find( { metadata_id => $md_id } );
# 	if ($mdmd_row) {
# 	    print STDERR "Update the md_metadata table to obsolete... for $md_id";
# 	    $mdmd_row -> update( { obsolete => 1 });
# 	}
#     }

#     # delete the entries from the linking table...
#     $q = "SELECT distinct(file_id) FROM nd_experiment_project JOIN phenome.nd_experiment_md_files using(nd_experiment_id) JOIN metadata.md_files using(file_id) JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
#     $h = $self->bcs_schema->storage()->dbh()->prepare($q);
#     $h->execute($trial_id);

#     while (my ($file_id) = $h->fetchrow_array()) {
# 	my $ndemdf_rs = $self->phenome_schema->resultset("NdExperimentMdFiles")->search( { file_id=>$file_id });
# 	print STDERR "Delete phenome.nd_experiment_md_files row for file_id $file_id...\n";
# 	foreach my $row ($ndemdf_rs->all()) {
# 	    $row->delete();
# 	}
#     }
# }


# sub _delete_phenotype_experiments {
#     my $self = shift;
#     my @nd_experiment_ids = @_;


#     print STDERR "Deleting the MdExperiment entries... ";

#     # retrieve the associated phenotype ids (they won't be deleted by the cascade)
#     #
#     my $phenotypes_deleted = 0;
#     my $nd_experiments_deleted = 0;

#     my $phenotype_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentPhenotype")->search( { nd_experiment_id=> { -in => [ @nd_experiment_ids ] }}, { join => 'phenotype' });
#     if ($phenotype_rs->count() > 0) {
# 	foreach my $p ($phenotype_rs->all()) {
# 	    print STDERR "Deleting phenotype_id ".$p->phenotype_id()."\n";
# 	    $p->delete();
# 	    $phenotypes_deleted++;
# 	}
#     }

#     # delete the experiments
#     #
#     my $delete_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->search({ nd_experiment_id => { -in => [ @nd_experiment_ids] }});
#     $nd_experiments_deleted = $delete_rs->count();
#     $delete_rs->delete_all();
#     print STDERR "Done.\n";

#     return { phenotypes_deleted => $phenotypes_deleted,
# 	     nd_experiments_deleted => $nd_experiments_deleted
#     };
# }

# =head2 _delete_field_layout_experiment

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub _delete_field_layout_experiment {
#     my $self = shift;
#     my $trial_id = shift;

#     # check if there are still associated phenotypes...
#     #
#     if ($self->trial_has_phenotype_data()) {
# 	print STDERR "Attempt to delete field layout that still has associated phenotype data.\n";
# 	return { error => "Trial still has associated phenotyping experiment, cannot delete." };
#     }

#     my $field_layout_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => "field_layout" })->cvterm_id();
#     print STDERR "Field layout type id = $field_layout_type_id\n";

#     my $plot_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'plot' })->cvterm_id();
#     print STDERR "Plot type id = $plot_type_id\n";

#     my $q = "SELECT stock_id FROM nd_experiment_project JOIN nd_experiment USING (nd_experiment_id) JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id) JOIN stock USING(stock_id) WHERE nd_experiment.type_id=? AND project_id=? AND stock.type_id=?";
#     my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
#     $h->execute($field_layout_type_id, $trial_id, $plot_type_id);

#     my $plots_deleted = 0;
#     while (my ($plot_id) = $h->fetchrow_array()) {
# 	my $plot = $self->bcs_schema()->resultset("Stock::Stock")->find( { stock_id => $plot_id });
# 	print STDERR "Deleting associated plot ".$plot->name()." (".$plot->stock_id().") \n";
# 	$plots_deleted++;
# 	$plot->delete();
#     }

#     $q = "SELECT nd_experiment_id FROM nd_experiment JOIN nd_experiment_project USING(nd_experiment_id) WHERE nd_experiment.type_id=? AND project_id=?";
#     $h = $self->bcs_schema->storage()->dbh()->prepare($q);
#     $h->execute($field_layout_type_id, $trial_id);

#     my ($nd_experiment_id) = $h->fetchrow_array();
#     if ($nd_experiment_id) {
# 	print STDERR "Delete corresponding nd_experiment entry  ($nd_experiment_id)...\n";
# 	my $nde = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->find( { nd_experiment_id => $nd_experiment_id });
# 	$nde->delete();
#     }


#     #return { success => $plots_deleted };
#     return { success => 1 };
# }

# sub trial_has_phenotype_data {
#     my $self = shift;
#     my $trial_id = shift;

#     my $phenotyping_experiment_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'phenotyping_experiment' })->cvterm_id();

#     my $phenotype_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search(
# 	{
# 	    project_id => $trial_id, 'nd_experiment.type_id' => $phenotyping_experiment_type_id},
# 	{
# 	    join => 'nd_experiment'
# 	}
# 	);

#     return $phenotype_experiment_rs->count();

# }

sub plot_has_phenotype_data {
    my $self = shift;
    my $plot_id = shift;

    my $phenotype_rs = $self->bcs_schema->resultset("Stock::Stock")->search( { stock_id => $plot_id }, { join => { 'phenotypes' }});

    if ($phenotype_rs->count() > 0) {
	return 1;
    }
    return 0;
}

1;
