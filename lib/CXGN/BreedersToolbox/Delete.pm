
package CXGN::BreedersToolbox::Delete;

use Moose;

has bcs_schema => (is => 'rw');
has metadata_schema => (is=> 'rw');
has phenome_schema => (is => 'rw');

=head2 delete_experiments_by_file

 Usage:        $cpd->delete_experiments_by_file($user_id, $md_file_id);
 Desc:         deletes the phenotype information associated with file $md_file_id
 Ret:          a hash with deletion statistics
 Args:         a user_id (for privilege check), 
               an md_file_id (primary key of metadata.md_files)
 Side Effects: connects to the database and deletes information (be careful!)
 Example:        

=cut

sub delete_experiments_by_file { 
    my $self = shift;
    my $user_id = shift;
    my $md_file_id = shift;

    print STDERR "Get the md_file entry... ";
    my $srs = $self->metadata_schema->resultset("MdFiles")->search( { file_id => $md_file_id } );

    print STDERR "Retrieved ".$srs->count()." entries.\n";
    if ($srs->count() == 0) { 
	return "The file specified does not exist."
    }

    my $file_row = $srs->first();
    my $metadata_id = $file_row->metadata_id()->metadata_id();

    print STDERR "Get the associated md_metadata info... ($metadata_id, $user_id)";

    my $frs = $self->metadata_schema->resultset("MdMetadata")->search( { metadata_id => $metadata_id, create_person_id=>$user_id });

    print STDERR "Retrieved ".$frs->count()." entries.\n";
    if ($frs->count()==0) { 
	return "You don't have the necessary privileges to delete this file";
    }
    
    print STDERR "Get the entries from the linking table... ";
    my $prs = $self->phenome_schema -> resultset("NdExperimentMdFiles")->search( { file_id => $md_file_id });

    print STDERR "Retrieved ".$prs->count()." entries.\n";
    if ($prs->count() == 0) { 
	print STDERR "No experiments have been loaded for file with md_file_id $md_file_id\n";
    }
    else { 
	foreach my $prs_row ($prs->rows()) { 
	    print STDERR "Deleting the MdExperiment entries... ";

	    # first delete the entry in the linking table...
	    #
	    my $nd_experiment_id = $prs_row->nd_experiment_id();
	    $prs_row->delete();

	    $self->_delete_nd_experiments($nd_experiment_id);
	}
    }
    
    # set md_files and/or metadata to obsolote
    print STDERR "Update the md_file table to obsolete... ";
    my $mdmd_row = $self->metadata_schema->resultset("MdMetadata")->find( { metadata_id => $metadata_id } );
    if ($mdmd_row) { 
	$mdmd_row -> update( { obsolete => 1 });
    }
    print STDERR "Done.\n";
    print STDERR "Delete complete.\n";

}

sub delete_experiments_by_trial { 
    my $self = shift;
    my $user_id = shift;
    my $trial_id = shift;


}


sub _delete_nd_experiments { 
    my $self = shift;
    my @nd_experiment_ids = @_;

    my $ids_str = join ",", @nd_experiment_ids;
    print STDERR "Deleting the MdExperiment entries... ";

    # retrieve the associated phenotype ids (they won't be deleted by the cascade)
    #
    my $phenotypes_deleted = 0;
    my $nd_experiments_deleted = 0;

    my $phenotype_rs = $self->bcs_schema()->resultset("MdExperimentPhenotype")->search( { nd_experiment_id=> { -in => $ids_str }}, { join => 'phenotype' });
    if ($phenotype_rs->count() > 0) { 
	foreach my $p ($phenotype_rs->rows()) { 
	    $p->delete();
	    $phenotypes_deleted++;
	}
    }
    
    # delete the experiments
    #
    my $delete_rs = $self->bcs_schema()->resultset("NdExperiment")->search({ md_experiment_id => { -in => $ids_str }});
    $nd_experiments_deleted = $delete_rs->count();
    $delete_rs->delete_all();
    print STDERR "Done.\n";

    return { phenotypes_deleted => $phenotypes_deleted, 
	     nd_experiments_deleted => $nd_experiments_deleted
    };
}


sub delete_location { 
    my $self = shift;
    my $location_id = shift;
    my $rs = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->search({ nd_geolocation_id=>$location_id });

    if ($rs->count ==1) { 
	# the location exists, but we can only delete it if nothing is associated with it
	if ($self->can_delete_location()) { 
	    $rs->first->delete();
	    return 1;
	}
    }
    return 0;
}
	

sub can_delete_location { 
    my $self = shift;
    my $location_id = shift;

    my $rs = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->search({ nd_geolocation_id=>$location_id});
    if ($rs->count() > 0) { 
	my @experiments = $rs->first()->nd_experiments;
	if (@experiments) { 
	    print STDERR "Location $location_id cannot be deleted because there are @experiments exp assoc with it.\n";
	    return 0 ;
	}
    }
    return 1;
}


1;

    
    
