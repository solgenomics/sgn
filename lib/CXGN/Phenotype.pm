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

has 'observationunit_id' => (
    isa => 'Int',
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

after 'experiment' => sub {
    my $self = shift;
    my $exp = shift;

    if ($exp) { $self->nd_experiment_id($exp->nd_experiment_id()); }

};

has 'nd_experiment_id' => (
    isa => 'Int',
    is => 'rw',
    );

has 'trait_repeat_type' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    default => undef,
    );

has 'trait_format' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

has 'trait_categories' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

has 'trait_format' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

has 'trait_min_value' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );


has 'trait_max_value' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

has 'trait_repeat_type' => (
    isa => 'Maybe[Str]',
    is => 'rw'
    );




#has 'plot_trait_uniquename' => (
#    isa => 'Str|Undef',
#    is => 'rw',
#    );

sub BUILD {
    my $self = shift;

    if ($self->phenotype_id()) { 

	my $q = "SELECT cvalue_id, uniquename, collect_date, value, nd_experiment_phenotype.nd_experiment_id, operator FROM phenotype join nd_experiment_phenotype using(phenotype_id) where phenotype.phenotype_id=?";

	my $h = $self->schema->storage->dbh()->prepare($q);
	$h->execute($self->phenotype_id());
	
	my ($cvterm_id, $uniquename, $collect_date, $value, $nd_experiment_id, $operator) = $h->fetchrow_array();

	$self->cvterm_id($cvterm_id);
	$self->uniquename($uniquename);
	$self->collect_date($collect_date);
	$self->value($value);
	$self->nd_experiment_id($nd_experiment_id);
	$self->operator($operator);
	$self->experiment( $self->schema()->resultset("NaturalDiversity::NdExperiment")->find( { nd_experiment_id => $nd_experiment_id }) );
    }
    else {
	print STDERR "no phenotype_id - creating empty object\n";
    }
}

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
	print STDERR "UPDATING ".$self->phenotype_id()." with new value ".$self->value()."\n";
	my $phenotype_row = $self->schema->resultset('Phenotype::Phenotype')->
	    find( { phenotype_id  => $self->phenotype_id() });
	## should check that unit and variable (also checked here) are conserved in parse step,
	## if not reject before store
	## should also update operator in nd_experimentprops

	$phenotype_row->update({
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
    }
    else { # INSERT
	#print STDERR "INSERTING new value ...\n";
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

	if (!$self->nd_experiment_id()) {
	    die "NEED AN ND_EXPERIMENT ID FOR NEW PHENOTYPES!\n";
	}
	my $experiment = $self->schema->resultset("NaturalDiversity::NdExperiment")->find( { nd_experiment_id => $self->nd_experiment_id() });

	$self->experiment($experiment);

	$self->experiment->create_related('nd_experiment_phenotypes',{
	    phenotype_id => $phenotype_row->phenotype_id });
	
	$experiment_ids{$self->experiment->nd_experiment_id()} = 1;

	if ($self->image_id) {
	    $nd_experiment_md_images{$self->experiment->nd_experiment_id()} = $self->image_id;
	}

	$self->phenotype_id($phenotype_row->phenotype_id());
    }
    return { success => 1, phenotype_id => $self->phenotype_id() };
}

sub store_external_references {
    my $self = shift;
    print STDERR "the CXGN::Phenotype store_external_references function\n";
    my $external_references = shift;

    if (! $self->phenotype_id()) {
	print STDERR "Can't store external references on this phenotype because there is no phenotype_id\n";
    }

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

    if (! $self->phenotype_id()) {
	print STDERR "Can't store additional info on this phenotype because there is no phenotype_id\n";
    }

    my $phenotype_additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'phenotype_additional_info', 'phenotype_property')->cvterm_id();

    my $pheno_additional_info = $self->schema()->resultset("Phenotype::Phenotypeprop")->find_or_create(
	{
	    phenotype_id => $self->phenotype_id,
	    type_id => $phenotype_additional_info_type_id,
	});
    
    $pheno_additional_info = $pheno_additional_info->update(
	{
	    value => encode_json $additional_info,
	});
    
    my $additional_info_stored = $pheno_additional_info->value ? decode_json $pheno_additional_info->value : undef;

    return $additional_info_stored;
}

sub delete_phenotype {
    my $self = shift;

    if ($self->phenotype_id()) {
	print STDERR "Removing phenotype with phenotype_id ".$self->phenotype_id()."\n";
	my $row = $self->schema->resultset("Phenotype::Phenotype")->find( { phenotype_id => $self->phenotype_id() });
	$row->delete();
    }
    else {
	print STDERR "Trying to delete a phenotype without phenotype_id\n";
    }
}

sub check_categories {
    my $self = shift;

    my $error_message;

    my %trait_categories_hash;
    if ($self->trait_format() eq 'Ordinal' || $self->check_trait() eq 'Nominal' || $self->trait_format() eq 'Multicat') {
	# Ordinal looks like <value>=<category>

	my @check_values;

	my @trait_categories = sort(split /\//, $self->check_trait_category());

	# print STDERR "Trait categories: ".Dumper(\@trait_categories)."\n";
	# print STDERR "Trait categories hash: ".Dumper(\%trait_categories_hash)."\n";
	# print STDERR "Check values: ".Dumper(\@check_values)."\n";     
	if ($self->trait_format eq 'Multicat') {
	    @check_values = split /\:/, $self->value();
	}
	else {
	    @check_values = ( $self->value() );
	}

	foreach my $ordinal_category (@{ $self->trait_categories }) {
	    my @split_value = split('=', $ordinal_category);
	    if (scalar(@split_value) >= 1) {
		$trait_categories_hash{$split_value[0]} = 1;
	    }
	    else {
		# Catch everything else
		%trait_categories_hash = map { $_ => 1 } @trait_categories;
	    }
	}
	foreach my $value (@check_values) {
	    if ($value ne '' && !exists($trait_categories_hash{$value})) {
		my $valid_values = join("/", sort keys %trait_categories_hash);  # Sort values for consistent order
		$error_message = "<small> This trait value should be one of $valid_values: <br/>Value: ".$self->value()."</small><hr>";
		print STDERR "The error in the value $error_message \n";
	    }
	    else {
		print STDERR "Trait value ".$self->value()." is valid\n";
	    }
	}
    }
}

=head2 check_measurement()

   Params: $plot_name, $trait_name, $values
   The values parameter may be:
    * a arrayref. In that case, the array is assumed to contain: a trait value, a timestamp
    * a hashref. In that case, the values represent high dimensional data (not checked by this function)

   Returns: a an array containing two arrayrefs, one with warnings and the other with errors.

   Description:

   The function will check:
   * Are the values an arrayref or hashref? It will return
   without further checks if it is a hashref (high dimensionality data).
   * If the trait_name is notes, it skippes any further checks.
   * Are trait formats defined for the trait? If the trait is numeric, the trait numericness is checked, and
     whether the values lies between trait_minimum and trait_maximum.
   * Is the trait an image? The availability of the corresponding image file is checked.
   * If the trait is categorical, the trait categories are retrieved and the value checked against the
     categories
   * The timestamp is checked for format (ISO, YYYY-MM-DD HH:MM::SS).
   * If the trait is multicat, the multiple values are checked against the defined categories.
   * If the trait is defined as a multiple of time_series measurement, the presence of a timestamp is checked.
     Omitted the timestamp for such a trait is considered an error and should break the upload.
   * If the trait is defined as a single trait, the presence of an older measurement is checked.
     Depending on the settings, the old trait is either retained or overwritten with the new trait value.


=cut
   
sub check { 
    my $self = shift;

    my $error_message = "";
    my $warning_message = "";
    
#     print STDERR "check  for trait $trait_name and values ".Dumper($value_array)."\n";
    
#     #print STDERR Dumper $value_array;
#     my ($trait_value, $timestamp);
#     if (ref($value_array) eq 'ARRAY') {
# 	# the entry represents trait + timestamp
# 	#
# 	$trait_value = $value_array->[0];
# 	$timestamp = $value_array->[1];
#     }
#     elsif (ref($value_array) eq "HASH") {
# 	# the trait is a high dimensional trait - we can't check
# 	print STDERR "TRAIT VALUE IS HIGH DIMENSIONAL - skipping.\n";
# 	return (undef, undef);
#     }
#     else {
# 	# it's a scalar. It really shouldn't be I guess?
# 	#
# 	$trait_value = $value_array;
#     }
#     #print STDERR "$plot_name, $trait_name, $trait_value\n";
#     if ( defined($trait_value) && $trait_name ne "notes" ) {
# 	print STDERR "TRAIT NAME = ".Dumper( $trait_name)."\n";
# 	my $trait_cvterm = $self->trait_objs->{$trait_name};
# 	my $trait_cvterm_id = $trait_cvterm->cvterm_id();
#         # print STDERR "the trait cvterm id of this trait is: " . $trait_cvterm_id . "\n";
# 	my $stock_id = $self->bcs_schema->resultset('Stock::Stock')->find({'uniquename' => $plot_name})->stock_id();
	
	
# 	#check that trait value is valid for trait name
# 	if (exists($self->check_trait_format()->{$trait_cvterm_id})) {
#             # print STDERR "Trait minimum value checks if it exists: " . $self->check_trait_min_value->{$trait_cvterm_id} . "\n";
# 	    if ($self->check_trait_format()->{$trait_cvterm_id} eq 'numeric') {
# 		my $trait_format_checked = looks_like_number($trait_value);
# 		if (!$trait_format_checked && $trait_value ne '') {
# 		    $error_message = $error_message."<small>This trait value should be numeric: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
# 		}

#                 my $trait_min = defined $self->check_trait_min_value->{$trait_cvterm_id} ? $self->check_trait_min_value->{$trait_cvterm_id} : undef;
#                 my $trait_max = defined $self->check_trait_max_value->{$trait_cvterm_id} ? $self->check_trait_max_value->{$trait_cvterm_id} : undef;
		
#                 print STDERR "the trait minimum: Trait Minimum for trait $trait_name: ", (defined $trait_min ? $trait_min : undef), "\n";
#                 print STDERR "the trait maximum: Trait Maximum for trait $trait_name: ", (defined $trait_max ? $trait_max : undef), "\n";
		
#                 if (defined $trait_min && $trait_value < $trait_min) {
#                     $error_message .= "<small>For trait '$trait_name' the trait value $trait_value should not be smaller than the defined trait_minimum, $trait_min.</small><hr>";
#                 } else {
#                     print STDERR "the trait min and trait value : No minimum value defined for trait '$trait_name' (cvterm_id: $trait_cvterm_id).\n";
#                 }
		
#                 if (defined $trait_max && $trait_value > $trait_max) {
#                     $error_message .= "<small>For the trait '$trait_name' the trait value $trait_value should not be larger than the defined trait_maximum, $trait_max.</small><hr>";
#                 }else {
#                     print STDERR "the trait max and trait value: No maximum value defined for trait '$trait_name' (cvterm_id: $trait_cvterm_id). \n";
#                 }
# 	    }
		
# 	    #check, if the trait value is an image
# 	    if ($self->check_trait_format->{$trait_cvterm_id} eq 'image') {
# 		$trait_value =~ s/^.*photos\///;
# 		if (!exists($self->image_plot_full_names->{$trait_value})) {
# 		    $error_message = $error_message."<small>For Plot Name: $plot_name there should be a corresponding image named in the zipfile called $trait_value. </small><hr>";
# 		}
# 	    }
	
# 	    my @trait_categories;
# 	    my %trait_categories_hash;
# 	    my @check_values;
	    
# 	    if (exists($self->check_trait_category()->{$trait_cvterm_id})) {
# 	        @trait_categories = sort(split /\//, $self->check_trait_category->{$trait_cvterm_id});
# 		# print STDERR "Trait categories: ".Dumper(\@trait_categories)."\n";
# 		# print STDERR "Trait categories hash: ".Dumper(\%trait_categories_hash)."\n";
# 		my @check_values;
# 		# print STDERR "Check values: ".Dumper(\@check_values)."\n";     
# 		if ($self->check_trait_format->{$trait_cvterm_id} eq 'Multicat') {
# 		    @check_values = split /\:/, $trait_value;
# 		}
# 		else {
# 		    @check_values = ( $trait_value );
# 		}
# 	    }

	    
# 	    #print STDERR "$trait_value, $trait_cvterm_id, $stock_id\n";
#  	    #check if the plot_name, trait_name combination already exists in database.
# 	    # if (exist($self->unique_value_trait_stock()->{$trait_value, $trait_cvterm_id, $stock_id})) {
# 	    # 	my $prev = $self->unique_value_trait_stock()->{$trait_value, $trait_cvterm_id, $stock_id};
# 	    # 	if ( defined($prev) && length($prev) && defined($trait_value) && length($trait_value) ) {
# 	    # 	    $self->same_value_count( $self->same_value_count++ );
# 	    # 	}
# 	    # }
# 	    # elsif (exists($self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp})) {
# 	    # 	my $prev = $self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp};
# 	    # 	if ( defined($prev) ) {
# 	    # 	    $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . (defined($trait_value) && $trait_value ne '' ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name for the timestamp $timestamp.</small><hr>";
# 	    # 	}
# 	    # } elsif (exists($self->unique_trait_stock()->{$trait_cvterm_id, $stock_id})) {
# 	    # 	my $prev = $self->unique_trait_stock()->{$trait_cvterm_id, $stock_id};
# 	    # 	if ( defined($prev) ) {
# 	    # 	    $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . (defined($trait_value) && $trait_value ne '' ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name.</small><hr>";
# 	    # 	}
# 	    # }
	    
# 	    #check if the plot_name, trait_name combination already exists in same file.
# 	    #if (exists($self->file_stock_trait_duplicates()->{$trait_cvterm_id, $stock_id})) {
# 	#	$warning_message = $warning_message."<small>$plot_name already has a value for the trait $trait_name in your file. Possible duplicate in your file?</small><hr>";
# 	 #   }
# 	  #  $self->file_stock_trait_duplicates()->{$trait_cvterm_id, $stock_id} = 1;
	    
	    
# 	    if ($self->has_timestamps()) { #timestamp_included) {
# 		if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
# 		    if ($timestamp) {
# 			if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
# 			    $error_message = $error_message."<small>Bad timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
# 			}
# 		    }
# 		}
# 	    }
# 	    if ($self->check_trait_format->{$trait_cvterm_id} eq 'Ordinal' || $self->check_trait_format->{$trait_cvterm_id} eq 'Nominal' || $self->check_trait_format->{$trait_cvterm_id} eq 'Multicat') {
# 		# Ordinal looks like <value>=<category>
# 		foreach my $ordinal_category (@trait_categories) {
# 		    my @split_value = split('=', $ordinal_category);
# 		    if (scalar(@split_value) >= 1) {
# 			$trait_categories_hash{$split_value[0]} = 1;
# 		    }
# 		}
# 	    } else {
# 		# Catch everything else
# 		%trait_categories_hash = map { $_ => 1 } @trait_categories;
# 	    }
	    
# 	    foreach my $value (@check_values) {
# 		if ($value ne '' && !exists($trait_categories_hash{$value})) {
# 		    my $valid_values = join("/", sort keys %trait_categories_hash);  # Sort values for consistent order
# 		    $error_message = "<small> This trait value should be one of $valid_values: <br/>Plot Name: $plot_name <br/>Trait Name: $trait_name <br/>Value: $trait_value</small><hr>";
# 		    print STDERR "The error in the value $error_message \n";
# 		}
# 		else {
# 		    print STDERR "Trait value $trait_value is valid\n";
# 		}
# 	    }
# 	}
    
# 	my $repeat_type = "single";
	
# 	if (exists($self->check_trait_repeat_type->{$trait_cvterm_id})) {
# 	    if (grep /$repeat_type/, ("single", "multiple", "time_series")) {
# 		$repeat_type = $self->check_trait_repeat_type->{$trait_cvterm_id};
# 		print STDERR "Trait repeat type: $repeat_type\n";
# 	    }else {
# 		print STDERR "the trait repeat type of $self->check_trait_repeat_type->{$trait_cvterm_id} has no meaning. Assuming 'single'.\n";
# 	    }
# 	}
	
# 	if ($repeat_type eq "multiple" or $repeat_type eq "time_series") {
# 	    print STDERR "Trait repeat type: $repeat_type\n";
# 	    if (!$timestamp) {
# 		# print STDERR "trait name : $trait_name is multiple without timestamp \n";
# 		$error_message .= "For trait $trait_name that is defined as a 'multiple' or 'time_series' repeat type trait, a timestamp is required.\n";
# 	    }
# 	    if (exists($self->unique_trait_stock_timestamp()->{$trait_cvterm_id, $stock_id, $timestamp})) {
# 		# print STDERR "trait name : $trait_name  with timestamp \n";
# 		$error_message .= "<small>For the multiple measurement trait $trait_name the observation unit $plot_name already has a value associated with it at exactly the same time";
# 	    }
# 	}
	
    
# 	#print STDERR "$trait_value, $trait_cvterm_id, $stock_id\n";
# 	#check if the plot_name, trait_name combination already exists in database.
# 	if ($repeat_type eq "single") {

# 	    print STDERR "Processing this trait as a single repeat type trait with overwrite_values set to ".$self->overwrite_values()."...\n";
# 	    if (exists($self->unique_value_trait_stock->{$trait_value, $trait_cvterm_id, $stock_id})) {
# 		my $prev = $self->unique_value_trait_stock->{$trait_value, $trait_cvterm_id, $stock_id};

# 		if ( defined($prev) && length($prev) && defined($trait_value) && length($trait_value) ) {
# 		    $self->same_value_count($self->same_value_count() + 1);
# 		}
# 	    }
# 	    elsif (exists($self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp})) {
# 		my $prev = $self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp};
# 		if ( defined($prev) ) {
# 		    $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . ($trait_value ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name for the timestamp $timestamp.</small><hr>";
# 		}
# 	    }
# 	    elsif (exists($self->unique_trait_stock->{$trait_cvterm_id, $stock_id})) {
# 		my $prev = $self->unique_trait_stock->{$trait_cvterm_id, $stock_id};
# 		if ( defined($prev) ) {
# 		    $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . ($trait_value ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name.</small><hr>";
# 		}
# 	    }
	    
# 	    #check if the plot_name, trait_name combination already exists in same file.
# 	    if (exists($self->check_file_stock_trait_duplicates->{$trait_cvterm_id, $stock_id})) {
# 		$warning_message = $warning_message."<small>$plot_name already has a value for the trait $trait_name in your file. Possible duplicate in your file?</small><hr>";
# 	    }
# 	    $self->check_file_stock_trait_duplicates()->{$trait_cvterm_id, $stock_id} = 1;
	    
# 	}else {   ## multiple or time_series - warn only if the timestamp/value are identical
# 	    if (exists($self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp}) && $self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp} eq $trait_value) {
# 		$warning_message .= "For trait 'trait_name', the  timepoint $timestamp for stock  $stock_id already has a measurement with the same value $trait_value associated with it.<hr>";
# 	    }
# 	}
#     }
    
#     #if ($self->has_timestamps()) {
# #	if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
# #	    if ($timestamp) {
# #		if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
# #		    $error_message = $error_message."<small>Bad timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
# #		}
# #	    }
# #	}
#  #   }
#     # combine all warnings about the same values into a summary count
#     if ( defined($self->same_value_count()) && ($self->same_value_count > 0) ) {
#         $warning_message = $warning_message."<small>There are ".$self->same_value_count()." values in your file that are the same as values already stored in the database.</small>";
#     }
    
#     ## Verify metadata
#     if ($self->metadata_hash->{'archived_file'} && (!$self->metadata_hash->{'archived_file_type'} || $self->metadata_hash->{'archived_file_type'} eq "")) {
#         $error_message = "No file type provided for archived file.";
#         return ($warning_message, $error_message);
#     }
#     if (!$self->metadata_hash->{'operator'} || $self->metadata_hash->{'operator'} eq "") {
#         $warning_message = "No operator provided in file upload metadata.";
#         return ($warning_message, $error_message);
#     }
#     if (!$self->metadata_hash->{'date'} || $self->metadata_hash->{'date'} eq "") {
#         $error_message = "No date provided in file upload metadata.";
#         return ($warning_message, $error_message);
#     }
    
#     # print STDERR "warnings : $warning_message, Errors: $error_message\n";
    return ($warning_message, $error_message);
}




sub get_trait_props {
    my $self = shift;
    my $property_name = shift;

    my $sql = "SELECT cvtermprop.value, cvterm.name FROM cvterm join cvtermprop on(cvterm.cvterm_id=cvtermprop.cvterm_id) join cvterm as proptype on(cvtermprop.type_id=proptype.cvterm_id) where proptype.name in ('trait_categories', 'trait_format', 'trait_minimum', 'trait_maximum', 'trait_repeat_type') and cvterm.cvterm_id=? ";
    my $sth= $self->schema()->storage()->dbh()->prepare($sql);
    $sth->execute($self->cvterm_id());

    my %properties;
    while (my ($property_value, $property_name) = $sth->fetchrow_array) {
        if (defined $property_value) {
	    $properties{$property_name} = $property_value;
	}
    }

    $self->trait_categories($properties{trait_categories});
    $self->trait_format($properties{trait_format});
    $self->trait_min_value($properties{trait_minimum});
    $self->trait_max_value($properties{trait_maximum});
    $self->trait_repeat_type($properties{trait_repeat_type});
}

sub check_trait_minimum {
    my $self = shift;

    if (! $self->trait_format() ne "numeric") {
	print STDERR "Format is not numeric, can't check minimum\n";
	return 1;
    }
    if (! defined($self->trait_minimum()) ) {
	print STDERR "Warning. Checking trait minimum but is not set.\n";
	return 1;
    }
    if ($self->trait_minimum() < $self->value()) {
	return 0;
    }
    return 1;
}

sub check_trait_maximum {
    my $self = shift;
    
    if (! $self->trait_format() ne "numeric") {
	print STDERR "Format is not numeric, can't check maximum.";
	return 1;	
    }
    if (! defined($self->trait_maximum())) {
	print STDERR "Warning. Checking trait maximum but is not set\n";
	return 1;
    }
    if ($self->value() > $self->trait_maximum()) {
	return 0;
    }
    return 1;
}

1;
