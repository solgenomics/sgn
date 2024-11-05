package CXGN::Phenotype;

use Moose;
use Data::Dumper;
use Bio::Chado::Schema;
use JSON qw | encode_json decode_json |;

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

has 'collect_date' => (
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
    isa => 'Str|Undef',
    is => 'rw',
    );

has 'uniquename' => (
    isa => 'Str',
    is => 'rw',
    );

has 'experiment' => (
    isa => 'Bio::Chado::Schema::Result::NaturalDiversity::NdExperiment',
    is => 'rw',
    );

#has 'plot_trait_uniquename' => (
#    isa => 'Str|Undef',
#    is => 'rw',
#    );

sub store {
    my $self = shift;
    print STDERR "CXGN::Phenotype store \n";

    my %experiment_ids = ();
    my %nd_experiment_md_images;
    my @overwritten_values;

    if (! $self->cvterm_id()) {
	    my $row = $self->schema->resultset("Cv::Cvterm")->find( { name => $self->cvterm_name() });
	    if ($row) {
	        $self->cvterm_id($row->cvterm_id);
	    }
	    else {
	        die "The cvterm ".$self->cvterm_name()." does not exist. Exiting.\n";
	    }
    }
    
    if ($self->phenotype_id) {   ### UPDATE
	    my $phenotype = $self->schema->resultset('Phenotype::Phenotype')->
	    find( { phenotype_id  => $self->phenotype_id() });
	    ## should check that unit and variable (also checked here) are conserved in parse step,
	    ## if not reject before store
	    ## should also update operator in nd_experimentprops
	
	    $phenotype->update({
	    	value      => $self->value(),
	    	cvalue_id  => $self->cvterm_id(),
	    	observable_id => $self->cvterm_id(),
	    	uniquename => $self->uniquename(),
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

	    my $h = $self->schema->storage->dbh()->prepare($q);
	    $h->execute($self->stock_id, $self->cvterm_id);

	    while (my ($phenotype_id, $nd_experiment_id, $file_id) = $h->fetchrow_array()) {
	        push @overwritten_values, [ $file_id, $phenotype_id, $nd_experiment_id ];
	        $experiment_ids{$nd_experiment_id} = 1;
	        if ($self->image_id) {
	    	    $nd_experiment_md_images{$nd_experiment_id} = $self->image_id;
	        }
	    }
        return { success => 1, overwritten_values => \@overwritten_values, experiment_ids => \%experiment_ids, nd_experiment_md_images => \%nd_experiment_md_images };
    }else { # INSERT
        my $phenotype_row = $self->schema->resultset('Phenotype::Phenotype')->create({
		    cvalue_id     => $self->cvterm_id(),
		    observable_id => $self->cvterm_id(),
		    value         => $self->value(),
		    uniquename    => $self->uniquename(),
		    collect_date  => $self->collect_date(),
		    operator      => $self->operator(),
	    });
	
	    #$self->handle_timestamp($timestamp, $phenotype->phenotype_id);
	    #$self->handle_operator($operator, $phenotype->phenotype_id);

	    $self->experiment->create_related('nd_experiment_phenotypes',{
	        phenotype_id => $phenotype_row->phenotype_id });
	    $experiment_ids{$self->experiment->nd_experiment_id()} = 1;
	    if ($self->image_id) {
	        $nd_experiment_md_images{$self->experiment->nd_experiment_id()} = $self->image_id;
	    }
	    $self->phenotype_id($phenotype_row->phenotype_id());
    }
    return { success => 1 };
}

sub store_external_references {
    my $self = shift;
    print STDERR "the CXGN::Phenotype store_external_references function\n";
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

sub store_additional_info {
    my $self = shift;
    my $additional_info = shift;

    my $phenotype_additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'phenotype_additional_info', 'phenotype_property')->cvterm_id();
    
    my $pheno_additional_info = $self->schema()->resultset("Phenotype::Phenotypeprop")->find_or_create({
	    phenotype_id => $self->phenotype_id,
	    type_id => $phenotype_additional_info_type_id,
    });
    $pheno_additional_info = $pheno_additional_info->update({
	    value => encode_json $additional_info,
	});
    
    my $additional_info_stored = $pheno_additional_info->value ? decode_json $pheno_additional_info->value : undef;
    return $additional_info_stored;
}