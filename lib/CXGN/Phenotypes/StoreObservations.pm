package CXGN::Phenotypes::StoreObservations;

=head1 NAME

CXGN::Phenotypes::StoreObservations - an object to handle storing observations from BrAPI /observation PUT requests

=head1 USAGE

my $store_observations = CXGN::Phenotypes::StoreObservations->new(
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    user_id=>$user_id,
    stock_list=>$plots,
    trait_list=>$traits,
    values_hash=>$parsed_data,
    has_timestamps=>$timestamp_included,
    overwrite_values=>$overwrite,
    metadata_hash=>$phenotype_metadata
);
my ($stored_observations_error, $stored_observations_success) = $store_observations->store();

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

has 'unit_id_list' => (isa => "ArrayRef[Int]|Undef",
    is => 'rw',
    required => 0,
);

has 'variable_list' => (isa => "ArrayRef",
    is => 'rw',
    required => 1
);

has 'data' => (isa => "HashRef",
    is => 'rw',
    required => 1
);

has 'has_timestamps' => (isa => "Bool",
    is => 'rw',
    default => 0
);

has 'overwrite_values' => (isa => "Bool",
    is => 'rw',
    default => 0
);

has 'metadata_hash' => (isa => "HashRef",
    is => 'rw',
    required => 1
);

has 'image_zipfile_path' => (isa => "Str | Undef",
    is => 'rw',
    required => 0
);

has 'trait_objs' => (isa => "HashRef",
    is => 'rw',
);

has 'unique_value_trait_stock' => (isa => "HashRef",
    is => 'rw',
);

has 'unique_trait_stock' => (isa => "HashRef",
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

    foreach my $trait_name (@variable_list) {
        #print STDERR "trait: $trait_name\n";
        my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, "|".$trait_name);
        $trait_objs{$trait_name} = $trait_cvterm;
        push @cvterm_ids, $trait_cvterm->cvterm_id();
    }
    $self->trait_objs(\%trait_objs);

    #for checking if values in the file are already stored in the database or in the same file
    # my %check_unique_trait_stock;
    # my %check_unique_value_trait_stock;
    # my $previous_phenotype_rs = $schema->resultset('Phenotype::Phenotype')->search({'me.cvalue_id'=>{-in=>\@cvterm_ids}, 'stock.stock_id'=>{-in=>$self->stock_id_list}}, {'join'=>{'nd_experiment_phenotypes'=>{'nd_experiment'=>{'nd_experiment_stocks'=>'stock'}}}, 'select' => ['me.value', 'me.cvalue_id', 'stock.stock_id'], 'as' => ['value', 'cvterm_id', 'stock_id']});
    # while (my $previous_phenotype_cvterm = $previous_phenotype_rs->next() ) {
    #     my $cvterm_id = $previous_phenotype_cvterm->get_column('cvterm_id');
    #     my $stock_id = $previous_phenotype_cvterm->get_column('stock_id');
    #     if ($stock_id){
    #         my $previous_value = $previous_phenotype_cvterm->get_column('value') || ' ';
    #         $check_unique_trait_stock{$cvterm_id, $stock_id} = $previous_value;
    #         $check_unique_value_trait_stock{$previous_value, $cvterm_id, $stock_id} = 1;
    #     }
    # }
    # $self->unique_value_trait_stock(\%check_unique_value_trait_stock);
    # $self->unique_trait_stock(\%check_unique_trait_stock);

}

sub store {
    my $self = shift;
    # my %phenotype_metadata = %{$self->metadata_hash};

    $self->create_hash_lookups();
    my @unit_list = @{$self->unit_list};
    my @variable_list = @{$self->variable_list};
    my %trait_objs = %{$self->trait_objs};
    my %data = %{$self->data};
    # my %phenotype_metadata = %{$self->metadata_hash};
    # my $timestamp_included = $self->has_timestamps;
    # my $archived_image_zipfile_with_path = $self->image_zipfile_path;
    my $phenotype_metadata = $self->metadata_hash;
    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    # my $overwrite_values = $self->overwrite_values;
    my $error_message;
    my $transaction_error;
    my $user_id = $self->user_id;
    my $archived_file = $phenotype_metadata->{'archived_file'};
    my $archived_file_type = $phenotype_metadata->{'archived_file_type'};
    # my $operator = $phenotype_metadata->{'operator'};
    my $upload_date = $phenotype_metadata->{'date'};
    my $success_message;

    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();

    ## Track experiments seen to allow for multiple trials and experiments to exist in an uploaded file.
    ## Used later to attach file metadata.
    my %experiment_ids;##
    ###

    #For each observation, check for observationId. If exists, update phenotype with that ID>

    #If doesn't exist, load new phenotype


    # my %check_unique_trait_stock = %{$self->unique_trait_stock};

    my $rs;
    my %linked_data;
    $rs = $schema->resultset('Stock::Stock')->search(
        {'type.name' => 'field_layout', 'me.type_id' => [$plot_cvterm_id, $plant_cvterm_id, $subplot_cvterm_id], 'me.stock_id' => {-in=>\@unit_list } },
        {join=> {'nd_experiment_stocks' => {'nd_experiment' => ['type', 'nd_experiment_projects'  ] } } ,
            '+select'=> ['me.stock_id', 'me.uniquename', 'nd_experiment.nd_geolocation_id', 'nd_experiment_projects.project_id'],
            '+as'=> ['stock_id', 'uniquename', 'nd_geolocation_id', 'project_id']
        }
    );
    while (my $s = $rs->next()) {
        print STDERR "Associate stock id ".$s->get_column('stock_id')." with location id ".$s->get_column('nd_geolocation_id')." and project_id ".$s->get_column('project_id')."\n";
        $linked_data{$s->get_column('stock_id')} = [$s->get_column('nd_geolocation_id'), $s->get_column('project_id') ];
    }

    ## Use txn_do with the following coderef so that if any part fails, the entire transaction fails.
    my $coderef = sub {
        my @overwritten_values;

        foreach my $unit_id (@unit_list) {

            my $stock_id = $unit_id;
            my $location_id = $linked_data{$unit_id}[0];
            my $project_id = $linked_data{$unit_id}[1];

            foreach my $trait_name (@variable_list) {

                #print STDERR "trait: $trait_name\n";
                my $trait_cvterm = $trait_objs{$trait_name};

                #print STDERR Dumper $value_array;
                my $trait_value = $data{$unit_id}->{$trait_name}->{value};
                my $timestamp = $data{$unit_id}->{$trait_name}->{timestamp};
                my $operator =  $data{$unit_id}->{$trait_name}->{collector};
                if (!$timestamp) {
                    $timestamp = 'NA'.$upload_date;
                }

                if (defined($trait_value) && length($trait_value)) {

                    # change this to work depending on whether observationDbIds are supplied and valid
                    #Remove previous phenotype values for a given stock and trait, if $overwrite values is checked
                    # if ($overwrite_values) {
                    #     if (exists($check_unique_trait_stock{$trait_cvterm->cvterm_id(), $stock_id})) {
                    #         push @overwritten_values, $self->delete_previous_phenotypes($trait_cvterm->cvterm_id(), $stock_id);
                    #     }
                    #     $check_unique_trait_stock{$trait_cvterm->cvterm_id(), $stock_id} = 1;
                    # }

                    my $plot_trait_uniquename = "Stock: " .
                        $stock_id . ", trait: " .
                        $trait_cvterm->name .
                        " date: $timestamp" .
                        "  operator = $operator" ;

                    my $phenotype = $trait_cvterm
                        ->find_related("phenotype_cvalues", {
                            observable_id => $trait_cvterm->cvterm_id,
                            value => $trait_value ,
                            uniquename => $plot_trait_uniquename,
                        });

                    if (!$phenotype) {

                        my $phenotype = $trait_cvterm
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
                }
            }
        }

        $success_message = 'All values in your file are now saved in the database!';
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
        $self->save_archived_file_metadata($archived_file, $archived_file_type, \%experiment_ids);
    }

    return ($error_message, $success_message);
}


sub delete_previous_phenotypes {
    my $self = shift;
    my $trait_cvterm_id = shift;
    my $stock_id = shift;

    my $q = "
        DROP TABLE IF EXISTS temp_pheno_duplicate_deletion;
        CREATE TEMP TABLE temp_pheno_duplicate_deletion AS
        (SELECT phenotype_id, nd_experiment_id, file_id
        FROM phenotype
        JOIN nd_experiment_phenotype using(phenotype_id)
        JOIN nd_experiment_stock using(nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_files using(nd_experiment_id)
        JOIN stock using(stock_id)
        WHERE stock.stock_id=?
        AND phenotype.cvalue_id=?);
        DELETE FROM phenotype WHERE phenotype_id IN (SELECT phenotype_id FROM temp_pheno_duplicate_deletion);
        DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_pheno_duplicate_deletion);
        DELETE FROM nd_experiment WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_pheno_duplicate_deletion);
        ";
    my $q2 = "SELECT phenotype_id, nd_experiment_id, file_id FROM temp_pheno_duplicate_deletion;";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    my $h2 = $self->bcs_schema->storage->dbh()->prepare($q2);
    $h->execute($stock_id, $trait_cvterm_id);
    $h2->execute();

    my @deleted_phenotypes;
    while (my ($phenotype_id, $nd_experiment_id, $file_id) = $h2->fetchrow_array()) {
        push @deleted_phenotypes, [$file_id, $phenotype_id, $nd_experiment_id];
    }
    return @deleted_phenotypes;
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
