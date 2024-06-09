
package CXGN::Phenotype;

use Moose;
use Data::Dumper;
use Bio::Chado::Schema;
use JSON::Any;

has 'schema' => (
    isa => 'Ref',
    is => 'rw',
    required => 1,
    );

has 'phenotype_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    );

has 'cvterm_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    );

has 'cvterm_name' => (
    isa => 'Str',
    is => 'rw'
);

has 'value' => (
    isa => 'Str|Undef',
    is => 'rw',
    );

has 'stock_id' => (
    isa => 'Int',
    is => 'rw',
    );

has 'nd_experiment_id' => (
    isa => 'Str',
    is => 'rw',
    );

has 'operator' => (
    isa => 'Str',
    is => 'rw',
    );

has 'collect_timestamp' => (
    isa => 'Str|Undef',
    is => 'rw',
    );

has 'image_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    );

has 'existing_trait_value' => (
    isa => 'Str|Undef',
    is => 'rw',
    );

has 'unique_time' => (
    isa => 'Str',
    is => 'rw',
    );

has 'plot_trait_uniquename' => (
    isa => 'Str|Undef',
    is => 'rw',
    );

sub store {
    my $self = shift;

    my %experiment_ids = ();
    my %nd_experiment_md_images;
    my @overwritten_values;

    my $phenotype_addtional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'phenotype_additional_info', 'phenotype_property')->cvterm_id();

    
    if ($self->phenotype_id) {   ### UPDATE
	my $phenotype = $self->schema->resultset('Phenotype::Phenotype')->
	    find( { phenotype_id  => $self->phenotype_id() });
	
	## should check that unit and variable (also checked here) are conserved in parse step,
	## if not reject before store
	## should also update operator in nd_experimentprops
	
	$phenotype->update(
	    {
		value      => $self->value(),
		cvalue_id  => $self->cvterm_id(),
		observable_id => $self->cvterm_id(),
		uniquename => $self->plot_trait_uniquename(),
		collect_date => $self->collect_date(),
		operator => $self->operator(),
	    });
	
#	$self->handle_timestamp($timestamp, $observation);
#	$self->handle_operator($operator, $observation);
	
	my $q = "SELECT phenotype_id, nd_experiment_id, file_id
                 FROM phenotype
                 JOIN nd_experiment_phenotype using(phenotype_id)
                 JOIN nd_experiment_stock using(nd_experiment_id)
                 LEFT JOIN phenome.nd_experiment_md_files using(nd_experiment_id)
                 JOIN stock using(stock_id)
                 WHERE stock.stock_id=?
                 AND phenotype.cvalue_id=?";

	my $h = $self->bcs_schema->storage->dbh()->prepare($q);
	$h->execute($self->stock_id, $self->cvterm_id);

	while (my ($phenotype_id, $nd_experiment_id, $file_id) = $h->fetchrow_array()) {
	    push @overwritten_values, [ $file_id, $phenotype_id, $nd_experiment_id ];
	    $experiment_ids{$nd_experiment_id} = 1;
	    if ($self->image_id) {
		$nd_experiment_md_images{$nd_experiment_id} = $self->image_id;
	    }
	}
	return { success => 1, overwritten_values => \@overwritten_values, experiment_ids => \%experiment_ids, nd_experiment_md_images => \%nd_experiment_md_images };
    }
    else {   # INSERT
	
	my $phenotype = $self->schema->resultset('Phenotype::Phenotype')->insert(
	    {
		cvalue_id     => $self->cvterm_id(),
		observable_id => $self->cvterm_id(),
		value         => $self->value(),
		uniquename    => $self->plot_trait_uniquename(),
		collect_date  => $self->collect_date(),
		operator      => $self->operator(),
	    });
	
	#$self->handle_timestamp($timestamp, $phenotype->phenotype_id);
	#$self->handle_operator($operator, $phenotype->phenotype_id);
	
	my $experiment->create_related('nd_experiment_phenotypes', {
	    phenotype_id => $phenotype->phenotype_id
				    });
	
	$experiment->find_or_create_related({
	     nd_experiment_phenotypes => [{phenotype_id => $phenotype->phenotype_id}]
	 });
	
	$experiment_ids{$experiment->nd_experiment_id()} = 1;
	if ($self->image_id) {
	    $nd_experiment_md_images{$experiment->nd_experiment_id()} = $self->image_id;
	}
    }
    my $additional_info_stored;
    if($self->additional_info()){
	my $pheno_additional_info = $self->schema()->resultset("Phenotype::Phenotypeprop")->find_or_create(
	    {
		phenotype_id => $self->phenotype_id,
		type_id => $phenotype_addtional_info_type_id,

	    });
	
	$pheno_additional_info = $pheno_additional_info->update({
	    value => encode_json $self->additional_info(),
	    							});
	    
        my $additional_info_stored = $pheno_additional_info->value ? decode_json $pheno_additional_info->value : undef;
    }
    return { success => 1, additional_info_stored => 1 };
}

sub store_external_references {
    my $self = shift;
    my $external_references = shift;

    my $external_references_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'phenotype_external_references', 'phenotype_property')->cvterm_id();
    
    my $external_references_stored;
    my $phenotype_external_references = $self->schema->resultset("Phenotype::Phenotypeprop")->find_or_create({
	phenotype_id => $self->phenotype_id,
	type_id      => $external_references_type_id,
												       });
    $phenotype_external_references = $phenotype_external_references->update({
	value => encode_json $external_references,
									    });
    $external_references_stored = $phenotype_external_references->value ? decode_json $phenotype_external_references->value : undef;

    return $external_references_stored;
}

sub store_high_dimensional_data {
    my $self = shift;
    my $nirs_hashref = shift;
    my $nd_experiment_id = shift;
    my $md_json_type = shift;
    my %nirs_hash = %{$nirs_hashref};

    my $protocol_id = $nirs_hash{protocol_id};
    delete $nirs_hash{protocol_id};

    my $nirs_json = encode_json(\%nirs_hash);

    my $insert_query = "INSERT INTO metadata.md_json (json_type, json) VALUES (?,?) RETURNING json_id;";
    my $dbh = $self->schema->storage->dbh()->prepare($insert_query);
    $dbh->execute($md_json_type, $nirs_json);
    my ($json_id) = $dbh->fetchrow_array();

    my $linking_query = "INSERT INTO phenome.nd_experiment_md_json ( nd_experiment_id, json_id) VALUES (?,?);";
    $dbh = $self->schema->storage->dbh()->prepare($linking_query);
    $dbh->execute($nd_experiment_id,$json_id);

    my $protocol_query = "INSERT INTO nd_experiment_protocol ( nd_experiment_id, nd_protocol_id) VALUES (?,?);";
    $dbh = $self->schema->storage->dbh()->prepare($protocol_query);
    $dbh->execute($nd_experiment_id,$protocol_id);

    print STDERR "[StorePhenotypes] Linked $md_json_type json with id $json_id to nd_experiment $nd_experiment_id to protocol $protocol_id\n";
}


1;
