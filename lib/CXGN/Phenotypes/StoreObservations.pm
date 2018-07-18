package CXGN::Phenotypes::StoreObservations;

=head1 NAME

CXGN::Phenotypes::StoreObservations - an object to handle storing observations from BrAPI /observation PUT requests

=head1 USAGE

my $store_observations = CXGN::Phenotypes::StoreObservations->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    user_id=>$user_id,
    unit_list=>\@units,
    variable_list=>\@variables,
    data=>\%parsed_data,
    metadata_hash=>\%phenotype_metadata
);

my ($stored_observation_error, $stored_observation_success, $stored_observation_details) = $store_observations->store();

=head1 DESCRIPTION


=head1 AUTHORS

Jeremy D. Edwards (jde22@cornell.edu)
Naama Menda (nm249@cornell.edu)
Nicolas Morales (nm529@cornell.edu)
Bryan Ellerbrock (bje24@cornell.edu)

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
use SGN::Image;
use CXGN::ZipFile;
use CXGN::UploadFile;
use CXGN::List::Transform;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'metadata_schema' => ( isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => ( isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
);

has 'user_id' => (isa => "Int",
    is => 'rw',
    required => 1
);

has 'unit_list' => (isa => "ArrayRef",
    is => 'rw',
    required => 1
);

has 'variable_list' => (isa => "ArrayRef",
    is => 'rw',
    required => 1
);

has 'data' => (isa => "HashRef",
    is => 'rw',
    required => 1
);

has 'metadata_hash' => (isa => "HashRef",
    is => 'rw',
    required => 1
);

has 'trait_objs' => (isa => "HashRef",
    is => 'rw',
);

#build is used for creating hash lookups in this case
sub create_hash_lookups {
    my $self = shift;
    my $schema = $self->bcs_schema;

    #Find trait cvterm objects and put them in a hash
    my %trait_objs;
    my @variable_list = @{$self->variable_list};
    my @cvterm_ids;

    foreach my $variable (@variable_list) {
        #print STDERR "trait: $variable\n";
        my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, "|".$variable);
        $trait_objs{$variable} = $trait_cvterm;
        push @cvterm_ids, $trait_cvterm->cvterm_id();
    }
    $self->trait_objs(\%trait_objs);

}

sub store {
    my $self = shift;
    $self->create_hash_lookups();
    $self->get_linked_data();
    my @unit_list = @{$self->unit_list};
    my @variable_list = @{$self->variable_list};
    my %data = %{$self->data};
    my %trait_objs = %{$self->trait_objs};
    my $phenotype_metadata = $self->metadata_hash;
    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    my $error_message;
    my $transaction_error;
    my $user_id = $self->user_id;
    my $archived_file = $phenotype_metadata->{'archived_file'};
    my $archived_file_type = $phenotype_metadata->{'archived_file_type'};
    my $upload_date = $phenotype_metadata->{'date'};
    my $success_message;

    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    my %experiment_ids;
    my @stored_details;

    ## Use txn_do with the following coderef so that if any part fails, the entire transaction fails.
    my $coderef = sub {
        my @overwritten_values;

        foreach my $unit_id (@unit_list) {

            my $stock_id = $unit_id;
            my $location_id = $data{$unit_id}{locationDbId};
            my $project_id = $data{$unit_id}{studyDbId};

            foreach my $variable (@variable_list) {

                #print STDERR "trait: $variable\n";
                my $trait_cvterm = $trait_objs{$variable};

                #print STDERR Dumper $value_array;
                my $observation = $data{$unit_id}->{$variable}->{observation};
                my $trait_value = $data{$unit_id}->{$variable}->{value};
                my $timestamp = $data{$unit_id}->{$variable}->{timestamp};
                my $operator =  $data{$unit_id}->{$variable}->{collector};
                if (!$timestamp) {
                    $timestamp = 'NA'.$upload_date;
                }

                if (defined($trait_value) && length($trait_value)) {

                    # Update existing ot add new, depending on whether observationDbIds are supplied and valid
                    my $plot_trait_uniquename = "Stock: " .
                        $stock_id . ", trait: " .
                        $trait_cvterm->name .
                        " date: $timestamp" .
                        "  operator = $operator" ;

                    my $phenotype;

                    if ($observation) {

                            $phenotype = $trait_cvterm
                            ->find_related("phenotype_cvalues", {
                                observable_id => $trait_cvterm->cvterm_id,
                                phenotype_id => $observation
                            });

                            $phenotype->value($trait_value);
                            $phenotype->uniquename($plot_trait_uniquename);
                            $phenotype->update();

                            my $q = "SELECT phenotype_id, nd_experiment_id, file_id
                            FROM phenotype
                            JOIN nd_experiment_phenotype using(phenotype_id)
                            JOIN nd_experiment_stock using(nd_experiment_id)
                            LEFT JOIN phenome.nd_experiment_md_files using(nd_experiment_id)
                            JOIN stock using(stock_id)
                            WHERE stock.stock_id=?
                            AND phenotype.cvalue_id=?";

                            my $h = $self->bcs_schema->storage->dbh()->prepare($q);
                            $h->execute($stock_id, $trait_cvterm->cvterm_id);
                            while (my ($phenotype_id, $nd_experiment_id, $file_id) = $h->fetchrow_array()) {
                                push @overwritten_values, [$file_id, $phenotype_id, $nd_experiment_id];
                                $experiment_ids{$nd_experiment_id}=1;
                            }

                    } else {


                        $phenotype = $trait_cvterm
                            ->create_related("phenotype_cvalues", {
                                observable_id => $trait_cvterm->cvterm_id,
                                value => $trait_value ,
                                uniquename => $plot_trait_uniquename,
                            });

                        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
                            nd_geolocation_id => $location_id,
                            type_id => $phenotyping_experiment_cvterm_id
                        });
                        $experiment->create_nd_experimentprops({date => $upload_date},{autocreate => 1, cv_name => 'local'});
                        $experiment->create_nd_experimentprops({operator => $operator}, {autocreate => 1 ,cv_name => 'local'});

                        ## Link the experiment to the project
                        $experiment->create_related('nd_experiment_projects', {project_id => $project_id});

                        # Link the experiment to the stock
                        $experiment->create_related('nd_experiment_stocks', { stock_id => $stock_id, type_id => $phenotyping_experiment_cvterm_id });

                        ## Link the phenotype to the experiment
                        $experiment->create_related('nd_experiment_phenotypes', {phenotype_id => $phenotype->phenotype_id });
                        #print STDERR "[StorePhenotypes] Linking phenotype: $plot_trait_uniquename to experiment " .$experiment->nd_experiment_id . "Time:".localtime()."\n";

                        $experiment_ids{$experiment->nd_experiment_id()}=1;
                    }

                    my %details = (
                        "germplasmDbId"=> $data{$unit_id}->{germplasmDbId},
                        "germplasmName"=> $data{$unit_id}->{germplasmName},
                        "observationDbId"=> $phenotype->phenotype_id,
                        "observationLevel"=> $data{$unit_id}->{observationLevel},
                        "observationUnitDbId"=> $unit_id,
                        "observationUnitName"=> $data{$unit_id}->{observationUnitName},
                        "observationVariableDbId"=> $variable,
                        "observationVariableName"=> $trait_cvterm->name,
                        "studyDbId"=> $project_id,
                        "uploadedBy"=> $user_id,
                        "value" => $trait_value
                    );

                    if ($timestamp) { $details{'observationTimestamp'} = $timestamp};
                    if ($operator) { $details{'collector'} = $operator};

                    push @stored_details, \%details;

                }
            }
        }

        $success_message = 'All values in your request are now saved in the database!';
        #print STDERR Dumper \@overwritten_values;
        my %files_with_overwritten_values = map {$_->[0] => 1} @overwritten_values;
        my $obsoleted_files = $self->check_overwritten_files_status(keys %files_with_overwritten_values);
        if (scalar (@$obsoleted_files) > 0){
            $success_message .= ' The following previously uploaded files are now obsolete because all values from them were overwritten by your upload: ';
            foreach (@$obsoleted_files){
                $success_message .= " ".$_->[1];
            }
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        $error_message = $transaction_error;
        print STDERR "Transaction error storing phenotypes: $transaction_error\n";
        return ($error_message, $success_message);
    }

    if ($archived_file) {
        print STDERR "Linking archived file $archived_file to experiments".Dumper(%experiment_ids)."\n";
        $self->save_archived_file_metadata($archived_file, $archived_file_type, \%experiment_ids);
    }

    # print STDERR Dumper @stored_details;

    return ($error_message, $success_message, \@stored_details); #add stored details
}

sub get_linked_data {
    my $self = shift;
    my $data = $self->data;
    my %data = %{$data};
    my $unit_list = $self->unit_list;
    my $schema = $self->bcs_schema;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id;

    my $subquery = "
    SELECT cvterm_id
    FROM cvterm
    JOIN cv USING (cv_id)
    WHERE cvterm.name IN ('plot_of', 'plant_of', 'subplot_of') AND cv.name = 'stock_relationship'
    ";

    my $query = "
        SELECT unit.stock_id, unit.uniquename, level.name, accession.stock_id, accession.uniquename, nd_experiment.nd_geolocation_id, nd_experiment_project.project_id
        FROM stock AS unit
        JOIN cvterm AS level ON (unit.type_id = level.cvterm_id)
        JOIN stock_relationship AS rel ON (unit.stock_id = rel.subject_id AND rel.type_id IN ($subquery))
        JOIN stock AS accession ON (rel.object_id = accession.stock_id AND accession.type_id = $accession_cvterm_id)
        JOIN nd_experiment_stock ON (unit.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
        JOIN nd_experiment_project ON (nd_experiment.nd_experiment_id = nd_experiment_project.nd_experiment_id)
        WHERE unit.stock_id = ANY (?)
        ";

        my $h = $self->bcs_schema->storage->dbh()->prepare($query);
        $h->execute($unit_list);
        while (my ($unit_id, $unit_name, $level, $accession_id, $accession_name, $location_id, $project_id) = $h->fetchrow_array()) {
            $data{$unit_id}{observationUnitName} = $unit_name;
            $data{$unit_id}{observationLevel} = $level;
            $data{$unit_id}{germplasmDbId} = $accession_id;
            $data{$unit_id}{germplasmName} = $accession_name;
            $data{$unit_id}{locationDbId} = $location_id;
            $data{$unit_id}{studyDbId} = $project_id;
        }

    return \%data;
}

sub check_overwritten_files_status {
    my $self = shift;
    my @file_ids = shift;
    #print STDERR Dumper \@file_ids;

    my $q = "SELECT count(nd_experiment_md_files_id) FROM metadata.md_files JOIN phenome.nd_experiment_md_files using(file_id) WHERE file_id=?;";
    my $q2 = "UPDATE metadata.md_metadata SET obsolete=1 where metadata_id IN (SELECT metadata_id FROM metadata.md_files where file_id=?);";
    my $q3 = "SELECT basename FROM metadata.md_files where file_id=?;";
    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    my $h2 = $self->bcs_schema->storage->dbh()->prepare($q2);
    my $h3 = $self->bcs_schema->storage->dbh()->prepare($q3);
    my @obsoleted_files;
    foreach (@file_ids){
        if ($_){
            $h->execute($_);
            my $count = $h->fetchrow;
            print STDERR "COUNT $count \n";
            if ($count == 0){
                $h2->execute($_);
                $h3->execute($_);
                my $basename = $h3->fetchrow;
                push @obsoleted_files, [$_, $basename];
                print STDERR "MADE file_id $_ OBSOLETE\n";
            }
        }
    }
    #print STDERR Dumper \@obsoleted_files;
    return \@obsoleted_files;
}

sub save_archived_file_metadata {
    my $self = shift;
    my $archived_file = shift;
    my $archived_file_type = shift;
    my $experiment_ids = shift;
    my $md5checksum;

    if ($archived_file ne 'none'){
        my $upload_file = CXGN::UploadFile->new();
        my $md5 = $upload_file->get_md5($archived_file);
        $md5checksum = $md5->hexdigest();
    }

    my $md_row = $self->metadata_schema->resultset("MdMetadata")->create({create_person_id => $self->user_id,});
    $md_row->insert();
    my $file_row = $self->metadata_schema->resultset("MdFiles")
        ->create({
            basename => basename($archived_file),
            dirname => dirname($archived_file),
            filetype => $archived_file_type,
            md5checksum => $md5checksum,
            metadata_id => $md_row->metadata_id(),
        });
    $file_row->insert();

    foreach my $nd_experiment_id (keys %$experiment_ids) {
        ## Link the file to the experiment
        my $experiment_files = $self->phenome_schema->resultset("NdExperimentMdFiles")
            ->create({
                nd_experiment_id => $nd_experiment_id,
                file_id => $file_row->file_id(),
            });
        $experiment_files->insert();
        #print STDERR "[StorePhenotypes] Linking file: $archived_file \n\t to experiment id " . $nd_experiment_id . "\n";
    }
}


###
1;
###
