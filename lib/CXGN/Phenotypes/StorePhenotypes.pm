package CXGN::Phenotypes::StorePhenotypes;

use CXGN::Phenotype;

=head1 NAME

CXGN::Phenotypes::StorePhenotypes - an object to handle storing phenotypes for SGN stocks

=head1 USAGE

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>basepath,
    dbhost=>dbhost,
    dbname=>dbname,
    dbuser=>dbuser,
    dbpass=>dbpass,
    temp_file_nd_experiment_id=>$temp_file_nd_experiment_id, #tempfile full name for deleting nd_experiment_ids asynchronously
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    user_id=>$user_id,
    stock_list=>$plots,
    trait_list=>$traits,
    values_hash=>$parsed_data,
    has_timestamps=>$timestamp_included,
    overwrite_values=>$overwrite,
    ignore_new_values=>$ignore_new_values,
    metadata_hash=>$phenotype_metadata,
    image_zipfile_path=>$image_zip
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
my ($stored_phenotype_error, $stored_Phenotype_success) = $store_phenotypes->store();

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
use JSON;
use SGN::Image;
use CXGN::ZipFile;
use CXGN::UploadFile;
use CXGN::List::Transform;
use CXGN::Stock;
use CXGN::Tools::Run;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
);

has 'basepath' => (
    isa => "Str",
    is => 'rw',
    required => 1
);

has 'dbhost' => (
    isa => "Str",
    is => 'rw',
    required => 1
);

has 'dbname' => (
    isa => "Str",
    is => 'rw',
    required => 1
);

has 'dbuser' => (
    isa => "Str",
    is => 'rw',
    required => 1
);

has 'dbpass' => (
    isa => "Str",
    is => 'rw',
    required => 1
);

has 'temp_file_nd_experiment_id' => (
    isa => "Str",
    is => 'rw',
    required => 1
);

has 'user_id' => (
    isa => "Int",
    is => 'rw',
    required => 1
);

has 'stock_list' => (
    isa => "ArrayRef",
    is => 'rw',
    required => 1
);

has 'stock_id_list' => (
    isa => "ArrayRef[Int]|Undef",
    is => 'rw',
    required => 0,
);

has 'trait_list' => (
    isa => "ArrayRef",
    is => 'rw',
    required => 1
);

has 'values_hash' => (
    isa => "HashRef",
    is => 'rw',
    required => 1
);

has 'has_timestamps' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

has 'overwrite_values' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

has 'remove_values' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

has 'ignore_new_values' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

has 'metadata_hash' => (
    isa => "HashRef",
    is => 'rw',
    required => 1,
);

has 'image_zipfile_path' => (
    isa => "Str | Undef",
    is => 'rw',
    required => 0
);

has 'trait_objs' => (
    isa => "HashRef",
    is => 'rw',
    default => sub { {} },
);

has 'unique_value_trait_stock' => (
    isa => "HashRef",
    is => 'rw',
    default => sub { {} },
);

has 'unique_trait_stock' => (
    isa => "HashRef",
    is => 'rw',
    default => sub { {} },
);

has 'unique_trait_stock_timestamp' => (
    isa => "HashRef",
    is => 'rw',
    default => sub { {} },
);

has 'composable_validation_check_name' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

has 'allow_repeat_measures' => (
    isa => "Bool",
    is => 'rw',
    default => 0
    );

has 'check_file_stock_trait_duplicates' => (
    isa => "HashRef",
    is => 'rw',
    default => sub { {} },
    );

has 'same_value_count' => (
    isa => 'Int',
    is => 'rw',
    );

has 'check_trait_category' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

has 'check_trait_format' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

has 'check_trait_min_value' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

has 'check_trait_max_value' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

has 'check_trait_repeat_type' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

has 'image_plot_full_names' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

#build is used for creating hash lookups in this case
sub create_hash_lookups {
    my $self = shift;
    my $schema = $self->bcs_schema;

    #Find trait cvterm objects and put them in a hash
#    $self->trait_objs({}); #initialize with empty list
    my @trait_list = @{$self->trait_list};
    @trait_list = map { $_ eq 'notes' ? () : ($_) } @trait_list; # omit notes from trait validation
    print STDERR "trait list after filtering @trait_list\n";
    my @stock_list = @{$self->stock_list};
    my @cvterm_ids;

    my $t = CXGN::List::Transform->new();
    my $stock_id_list = $t->transform($schema, 'stocks_2_stock_ids', \@stock_list);
    $self->stock_id_list($stock_id_list->{'transform'});

    foreach my $trait_name (@trait_list) {
        print STDERR "trait: $trait_name\n";
        my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name);
        $self->trait_objs->{$trait_name} = $trait_cvterm;
        push @cvterm_ids, $trait_cvterm->cvterm_id();
    }

    # checking if values in the file are already stored in the database or in the same file
    #
    my $stock_ids_sql = join ("," , @{$self->stock_id_list});
    #print STDERR "Cvterm ids are @cvterm_ids";

    if (scalar @cvterm_ids > 0) {
        my $cvterm_ids_sql = join ("," , @cvterm_ids);
        my $previous_phenotype_q = "SELECT phenotype.value, phenotype.cvalue_id, phenotype.collect_date, stock.stock_id FROM phenotype LEFT JOIN nd_experiment_phenotype USING(phenotype_id) LEFT JOIN nd_experiment USING(nd_experiment_id) LEFT JOIN nd_experiment_stock USING(nd_experiment_id) LEFT JOIN stock USING(stock_id) WHERE stock.stock_id IN ($stock_ids_sql) AND phenotype.cvalue_id IN ($cvterm_ids_sql);";
        my $h = $schema->storage->dbh()->prepare($previous_phenotype_q);
        $h->execute();

        while (my ($previous_value, $cvterm_id, $collect_timestamp, $stock_id) = $h->fetchrow_array()) {
	    
            if ($stock_id){
                #my $previous_value = $previous_phenotype_cvterm->get_column('value') || ' ';
                $collect_timestamp = $collect_timestamp || 'NA';
                $self->unique_trait_stock->{$cvterm_id, $stock_id} = $previous_value;
                $self->unique_trait_stock_timestamp->{$cvterm_id, $stock_id, $collect_timestamp} = $previous_value;
                $self->unique_value_trait_stock->{$previous_value, $cvterm_id, $stock_id} = 1;
            }
        }

    }

    $self->check_trait_category($self->get_trait_props('trait_categories'));
    $self->check_trait_format($self->get_trait_props('trait_format'));
    $self->check_trait_min_value($self->get_trait_props('trait_minimum'));
    $self->check_trait_max_value($self->get_trait_props('trait_maximum'));
    $self->check_trait_repeat_type($self->get_trait_props('trait_repeat_type'));


}

sub verify {
    my $self = shift;
    print STDERR "CXGN::Phenotypes::StorePhenotypes verify\n";

    my @plot_list = @{$self->stock_list};
    my @trait_list = @{$self->trait_list};
    @trait_list = map { $_ eq 'notes' ? () : ($_) } @trait_list; # omit notes from trait validation
    print STDERR Dumper \@trait_list;
    # my %plot_trait_value = %{$self->values_hash};
    # my %phenotype_metadata = %{$self->metadata_hash};
    # my $timestamp_included = $self->has_timestamps;
    my $archived_image_zipfile_with_path = $self->image_zipfile_path;
    my $schema = $self->bcs_schema;
    my $transaction_error;
    # print STDERR Dumper \@plot_list;
    # print STDERR Dumper \%plot_trait_value;
    my $plot_validator = CXGN::List::Validate->new();
    my $trait_validator = CXGN::List::Validate->new(
        composable_validation_check_name => $self->{composable_validation_check_name}
    );
    my @plots_missing = @{$plot_validator->validate($schema,'plots_or_subplots_or_plants_or_tissue_samples_or_analysis_instances',\@plot_list)->{'missing'}};
    my $traits_validation = $trait_validator->validate($schema,'traits',\@trait_list);
    my @traits_missing = @{$traits_validation->{'missing'}};
    my @traits_wrong_ids = @{$traits_validation->{'wrong_ids'}};
    my $error_message = '';
    my $warning_message = '';

    if (scalar(@plots_missing) > 0 || scalar(@traits_missing) > 0) {
        print STDERR "Plots or traits not valid\n";
        print STDERR "Invalid plots: ".join(", ", map { "'$_'" } @plots_missing)."\n" if (@plots_missing);
        print STDERR "Invalid traits: ".join(", ", map { "'$_'" } @traits_missing)."\n" if (@traits_missing);
        $error_message = "Invalid plots: <br/>".join(", <br/>", map { "'$_'" } @plots_missing) if (@plots_missing);
        $error_message = "Invalid traits: <br/>".join(", <br/>", map { "'$_'" } @traits_missing) if (@traits_missing);

        # Display matches of traits with the wrong id
        if ( scalar(@traits_wrong_ids) > 0 ) {
            $error_message .= "<br /><br /><strong>Possible Trait Matches:</strong>";
            foreach my $m (@traits_wrong_ids) {
                $error_message .= "<br /><br />" . $m->{'original_term'} . "<br />should be<br />" . $m->{'matching_term'};
            }
        }

        return ($warning_message, $error_message);
    }

    $self->create_hash_lookups();

    ### note: moved these variables below to accessors 
    #my %trait_objs = %{$self->trait_objs};
    #my %check_unique_value_trait_stock = %{$self->unique_value_trait_stock};
    #my %check_unique_trait_stock = %{$self->unique_trait_stock};
    #my %check_unique_trait_stock_timestamp = %{$self->unique_trait_stock_timestamp};

    # my %check_trait_category = $self->get_trait_props('trait_categories');
    # my %check_trait_format = $self->get_trait_props('trait_format');
    # my %check_trait_min_value = $self->get_trait_props('trait_minimum');
    # my %check_trait_max_value = $self->get_trait_props('trait_maximum');
    # my %check_trait_repeat_type = $self->get_trait_props('trait_repeat_type');
    #my %image_plot_full_names;

    
    #This is for saving Fieldbook images, which are only associated to a stock. To save images that are associated to a stock and a trait and a value, use the ExcelAssociatedImages parser
    if ($archived_image_zipfile_with_path) {

        my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_image_zipfile_with_path);
        my @archived_zipfile_return = $archived_zip->file_names();
        if (!@archived_zipfile_return){
            $error_message = $error_message."<small>Image zipfile could not be read. Is it .zip format?</small><hr>";
        } else {
            my $file_names_stripped = $archived_zipfile_return[0];
            my $file_names_full = $archived_zipfile_return[1];
            foreach (@$file_names_full) {
                $self->image_plot_full_names->{$_} = 1;
            }
            my %plot_name_check;
            foreach (@plot_list) {
                $plot_name_check{$_} = 1;
            }
            foreach my $img_name (@$file_names_stripped) {
                $img_name = substr($img_name, 0, -20);
                if ($img_name && !exists($plot_name_check{$img_name})) {
                    $warning_message = $error_message."<small>Image ".$img_name." in images zip file does not reference a plot or plant_name (e.g. the image filename does not have a plot or plant name in it)!</small><hr>";
                }
            }
        }
    }


    # PERFORMS CHECKS in the following way:
    #
    # IMPORTANT: for multiple and time_series trait_repeat_types, the acquisition datetime
    #            must be present!
    #
    # * check that values are of the correct format (numeric vs string vs date etc)
    # * if categorical, check if legal categories
    # * if numerical, check boundaries (trait_minimum, trait_maximum)
    # * if trait_repeat_type = single, check if measurement has already been taken, and
    #    emit warning depending on selected mode (overwrite vs. not)
    # * if trait_repeat_type = multiple, check if measurement already exists, otherwise add
    # * if trait_repeat_type = time_series, check if measurement for time point already exists,
    #   otherwise add
    #
    
    my ($errors, $warnings);
    my ($all_errors, $all_warnings);

    print STDERR "VALUES HASH = ".Dumper($self->values_hash());
    
    foreach my $plot_name (@plot_list) {
        foreach my $trait_name (@trait_list) {
            my $measurements_array = $self->values_hash()->{$plot_name}->{$trait_name};
	    
	        if (ref($measurements_array->[0]) eq 'ARRAY') {   ### we have a list of measurements, not just a trait_value timestamp pair
                foreach my $value_array (@$measurements_array) {
		            ($warnings, $errors) = $self->check_measurement($plot_name, $trait_name, $value_array);
		            $all_errors .= $errors;
		            $all_warnings .= $warnings;
		        }
	        }else {
		        ($warnings, $errors) = $self->check_measurement($plot_name, $trait_name, $measurements_array);
		        $all_errors .= $errors;
		        $all_warnings .= $warnings;
	        }
	    }

        #Trait values can be non alphanumeric 
        #if ($trait_value eq '.' || ($trait_value =~ m/[^a-zA-Z0-9,.\-\/\_]/ && $trait_value ne '.')){
        #    $error_message = $error_message."<small>Trait values must be alphanumeric with no spaces: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
        #}

        #check that trait value is valid for trait name
        if (exists($check_trait_format{$trait_cvterm_id})) {
            if ($check_trait_format{$trait_cvterm_id} eq 'numeric') {
                my $trait_format_checked = looks_like_number($trait_value);
                if (!$trait_format_checked && $trait_value ne '') {
                    $error_message = $error_message."<small>This trait value should be numeric: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
                }
            }
            if ($check_trait_format{$trait_cvterm_id} eq 'image') {
                $trait_value =~ s/^.*photos\///;
                if (!exists($image_plot_full_names{$trait_value})) {
                    $error_message = $error_message."<small>For Plot Name: $plot_name there should be a corresponding image named in the zipfile called $trait_value. </small><hr>";
                }
            }
        }

        if (exists($check_trait_category{$trait_cvterm_id})) {
		    my @check_values;
            my @trait_categories = split /\//, $check_trait_category{$trait_cvterm_id};
            my %trait_categories_hash;

		    if ($check_trait_format{$trait_cvterm_id} eq "Multicat") {
		        @check_values = split /\:/, $trait_value;
		    }else {
			    @check_values = ( $trait_value );
		    }

            if ($check_trait_format{$trait_cvterm_id} eq 'Ordinal' || $check_trait_format{$trait_cvterm_id} eq 'Nominal' || $check_trait_format{$trait_cvterm_id} eq 'Multicat') {
                # Ordinal looks like <value>=<category>

                foreach my $ordinal_category (@trait_categories) {
                    my @split_value = split('=', $ordinal_category);
                    if (scalar(@split_value) >= 1) {
                        $trait_categories_hash{$split_value[0]} = 1;
                    }
                }
            } else {
                # Catch everything else
                %trait_categories_hash = map { $_ => 1 } @trait_categories;
            }

		    foreach my $tw (@check_values) { 
			    if ($tw ne '' && !exists($trait_categories_hash{$tw})) {
			        my $valid_values = join("/", sort keys %trait_categories_hash);  # Sort values for consistent order
			        $error_message = "<small>This trait value should be one of $valid_values: <br/>Plot Name: $plot_name<br/>Trait Name: $trait_name<br/>Value: $trait_value</small><hr>";
			        print STDERR $error_message;
			    } else {
			        print STDERR "Trait value is valid $tw.\n";
			    }
		    }
        }

        #print STDERR "$trait_value, $trait_cvterm_id, $stock_id\n";
        #check if the plot_name, trait_name combination already exists in database.
        if (exists($check_unique_value_trait_stock{$trait_value, $trait_cvterm_id, $stock_id})) {
            my $prev = $check_unique_value_trait_stock{$trait_value, $trait_cvterm_id, $stock_id};
            if ( defined($prev) && length($prev) && defined($trait_value) && length($trait_value) ) {
                $same_value_count++;
            }
        } elsif (exists($check_unique_trait_stock_timestamp{$trait_cvterm_id, $stock_id, $timestamp})) {
            my $prev = $check_unique_trait_stock_timestamp{$trait_cvterm_id, $stock_id, $timestamp};
            if ( defined($prev) ) {
                $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . ($trait_value ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name for the timestamp $timestamp.</small><hr>";
            }
        } elsif (exists($check_unique_trait_stock{$trait_cvterm_id, $stock_id})) {
            my $prev = $check_unique_trait_stock{$trait_cvterm_id, $stock_id};
            if ( defined($prev) ) {
                $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . ($trait_value ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name.</small><hr>";
            }
        }

        #check if the plot_name, trait_name combination already exists in same file.
        if (exists($check_file_stock_trait_duplicates{$trait_cvterm_id, $stock_id})) {
            $warning_message = $warning_message."<small>$plot_name already has a value for the trait $trait_name in your file. Possible duplicate in your file?</small><hr>";
        } else {
            $check_file_stock_trait_duplicates{$trait_cvterm_id, $stock_id} = 1;
        }

        if ($timestamp_included) {
            if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
                if ($timestamp) {
                    if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                        $error_message = $error_message."<small>Bad timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
                    }
                }
            }
        }

        # }
    }
    return ($all_warnings, $all_errors);
}

sub check_measurement {
    my $self = shift;
    my $plot_name = shift;
    my $trait_name = shift;
    my $value_array = shift;
    
    my $error_message = "";
    my $warning_message = "";
    #print STDERR Dumper $value_array;
    my $trait_value = $value_array->[0];
    my $timestamp = $value_array->[1];
    #print STDERR "$plot_name, $trait_name, $trait_value\n";
    if ( defined($trait_value) ) {
	print STDERR "TRAIT NAME = ".Dumper( $trait_name)."\n";
	my $trait_cvterm = $self->trait_objs->{$trait_name};
	my $trait_cvterm_id = $trait_cvterm->cvterm_id();
	my $stock_id = $self->bcs_schema->resultset('Stock::Stock')->find({'uniquename' => $plot_name})->stock_id();
	
	#Trait values can be non alphanumeric 
	#if ($trait_value eq '.' || ($trait_value =~ m/[^a-zA-Z0-9,.\-\/\_]/ && $trait_value ne '.')){
	#    $error_message = $error_message."<small>Trait values must be alphanumeric with no spaces: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
	#}
	
	#check that trait value is valid for trait name
	if (exists($self->check_trait_format->{$trait_cvterm_id})) {
	    if ($self->check_trait_format->{$trait_cvterm_id} eq 'numeric') {
		my $trait_format_checked = looks_like_number($trait_value);
		if (!$trait_format_checked && $trait_value ne '') {
		    $error_message = $error_message."<small>This trait value should be numeric: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
		}
		if ($trait_value < $self->check_trait_min_value->{$trait_cvterm_id}) {
		    $error_message .= "<small>For trait '$trait_name' the trait value ($trait_value) should not be smaller than the defined trait_minimum, ". $self->check_trait_min_value->{$trait_cvterm_id}. "</small><hr />";
		}
		
		if ($trait_value > $self->check_trait_max_value->{$trait_cvterm_id}) {
		    $error_message .= "<small>For the trait '$trait_name' The trait vlue($trait_value) should not be larger than the defined trait_maximum, ".$self->check_trait_max_value->{$trait_cvterm_id}."</small></hr>";
		}
	    }
	    if ($self->check_trait_format->{$trait_cvterm_id} eq 'image') {
		$trait_value =~ s/^.*photos\///;
		if (!exists($self->image_plot_full_names->{$trait_value})) {
		    $error_message = $error_message."<small>For Plot Name: $plot_name there should be a corresponding image named in the zipfile called $trait_value. </small><hr>";
		}
	    }
	}
	
	if ($trait_value ne '' && exists($self->check_trait_category->{$trait_cvterm_id})) {
	    my @trait_categories = sort(split /\//, $self->check_trait_category->{$trait_cvterm_id});
	    my %trait_categories_hash;
	    if ($self->check_trait_format->{$trait_cvterm_id} eq 'Ordinal' || $self->check_trait_format->{$trait_cvterm_id} eq 'Nominal') {
		# Ordinal looks like <value>=<category>
		foreach my $ordinal_category (@trait_categories) {
		    my @split_value = split('=', $ordinal_category);
		    if (scalar(@split_value) >= 1) {
			$trait_categories_hash{$split_value[0]} = 1;
		    }
		}
	    } else {
		# Catch everything else
		%trait_categories_hash = map { $_ => 1 } @trait_categories;
	    }
	    
	    if (!exists($trait_categories_hash{$trait_value})) {
		$error_message .= "<small>This trait value should be one of ".$self->check_trait_category->{$trait_cvterm_id}.": <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
	    }
	    else {
		#print STDERR "Trait value $trait_value is valid\n";
	    }
	}

	if ($self->has_timestamps()) {
	    if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
		if ($timestamp) {
		    if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
			$error_message = $error_message."<small>Bad timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
		    }
		}
	    }
	}
	
	my $repeat_type = "single";
	if (exists($self->check_trait_repeat_type->{$trait_cvterm_id})) {
	    my $repeat_type = $self->check_trait_repeat_type->{$trait_cvterm_id}; 
	    if (grep /$repeat_type/, ("single", "multiple", "time_series")) {
		$repeat_type = $self->check_trait_repeat_type->{$trait_cvterm_id};
	    }
	    else {
		print STDERR "the trait repeat type of $self->check_trait_repeat_type->{$trait_cvterm_id} has no meaning. Assuming 'single'.\n";
	    }
	}
	
	if ($repeat_type eq "multiple" or $repeat_type eq "time_series") {
	    if (!defined($timestamp)) {
		$error_message .= "For trait $trait_name that is defined as a 'multiple' or 'time_series' repeat type trait, a timestamp is required.\n";
	    }
	    if (exists($self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp})) {
		$error_message .= "<small>For the multiple measurement trait $trait_name the observation unit $plot_name already has a value associated with it at exactly the same time";
	    }
	}
	
	#print STDERR "$trait_value, $trait_cvterm_id, $stock_id\n";
	#check if the plot_name, trait_name combination already exists in database.
	
	if ($repeat_type eq "single") { 
	    if (exists($self->unique_value_trait_stock->{$trait_value, $trait_cvterm_id, $stock_id})) {
		my $prev = $self->unique_value_trait_stock->{$trait_value, $trait_cvterm_id, $stock_id};
		if ( defined($prev) && length($prev) && defined($trait_value) && length($trait_value) ) {
		    $self->same_value_count($self->same_value_count() + 1);
		}
	    } elsif (exists($self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp})) {
		my $prev = $self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp};
		if ( defined($prev) ) {
		    $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . ($trait_value ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name for the timestamp $timestamp.</small><hr>";
		}
	    } elsif (exists($self->unique_trait_stock->{$trait_cvterm_id, $stock_id})) {
		my $prev = $self->unique_trait_stock->{$trait_cvterm_id, $stock_id};
		if ( defined($prev) ) {
		    $warning_message = $warning_message."<small>$plot_name already has a <strong>different value</strong> ($prev) than in your file (" . ($trait_value ? $trait_value : "<em>blank</em>") . ") stored in the database for the trait $trait_name.</small><hr>";
		}
	    }
	    
	    #check if the plot_name, trait_name combination already exists in same file.
	    if (exists($self->check_file_stock_trait_duplicates->{$trait_cvterm_id, $stock_id})) {
		$warning_message = $warning_message."<small>$plot_name already has a value for the trait $trait_name in your file. Possible duplicate in your file?</small><hr>";
	    }
	    $self->check_file_stock_trait_duplicates()->{$trait_cvterm_id, $stock_id} = 1;
	    
	}
	else {   ## multiple or time_series - warn only if the timestamp/value are identical
	    if (exists($self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp}) && $self->unique_trait_stock_timestamp->{$trait_cvterm_id, $stock_id, $timestamp} eq $trait_value) {
		$warning_message .= "For trait 'trait_name', the  timepoint $timestamp for stock  $stock_id already has a measurement with the same value $trait_value associated with it.<hr />";
	    }
	}
    }
    
    if ($self->has_timestamps()) {
	if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
	    if ($timestamp) {
		if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
		    $error_message = $error_message."<small>Bad timestamp for value for Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
		}
	    }
	}
    }    
    
    
    
    # combine all warnings about the same values into a summary count
    if ( defined($self->same_value_count()) && ($self->same_value_count > 0) ) {
        $warning_message = $warning_message."<small>There are ".$self->same_value_count()." values in your file that are the same as values already stored in the database.</small>";
    }
    
    ## Verify metadata
    if ($self->metadata_hash->{'archived_file'} && (!$self->metadata_hash->{'archived_file_type'} || $self->metadata_hash->{'archived_file_type'} eq "")) {
        $error_message = "No file type provided for archived file.";
        return ($warning_message, $error_message);
    }
    if (!$self->metadata_hash->{'operator'} || $self->metadata_hash->{'operator'} eq "") {
        $warning_message = "No operator provided in file upload metadata.";
        return ($warning_message, $error_message);
    }
    if (!$self->metadata_hash->{'date'} || $self->metadata_hash->{'date'} eq "") {
        $error_message = "No date provided in file upload metadata.";
        return ($warning_message, $error_message);
    }
    
    print STDERR "WARNINGS: $warning_message, ERRORS: $error_message\n";
    return ($warning_message, $error_message);
}

sub store {
    my $self = shift;
    print STDERR "CXGN::Phenotypes::StorePhenotypes store\n";
    
    $self->create_hash_lookups();
    my %linked_data = %{$self->get_linked_data()};
    my @plot_list = @{$self->stock_list};
    my @trait_list = @{$self->trait_list};
    
    @trait_list = map { $_ eq 'notes' ? () : ($_) } @trait_list; # omit notes so they can be handled separately
    #my %trait_objs = %{$self->trait_objs};
    #    my %plot_trait_value = %{$self->values_hash};
    #my %phenotype_metadata = %{$self->metadata_hash};
    #    my $timestamp_included = $self->has_timestamps;
    my $archived_image_zipfile_with_path = $self->image_zipfile_path;
    #my $phenotype_metadata = $self->metadata_hash;
    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    my $overwrite_values = $self->overwrite_values;
    my $remove_values = $self->remove_values;
    my $ignore_new_values = $self->ignore_new_values;
    my $allow_repeat_measures = $self->allow_repeat_measures;
    my $error_message;
    my $transaction_error;
    my $user_id = $self->user_id;
    my $archived_file = $self->metadata_hash->{'archived_file'};
    my $archived_file_type = $self->metadata_hash->{'archived_file_type'};
    my $operator = $self->metadata_hash->{'operator'};
    my $upload_date = $self->metadata_hash->{'date'};
    my $success_message;
    
    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $local_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'date', 'local')->cvterm_id();
    my $local_operator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'operator', 'local')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $analysis_instance_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_instance', 'stock_type')->cvterm_id();
    my $phenotype_addtional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_additional_info', 'phenotype_property')->cvterm_id();
    my $external_references_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_external_references', 'phenotype_property')->cvterm_id();
    my %experiment_ids;
    my @stored_details;
    my %nd_experiment_md_images;
    
    #    my %check_unique_trait_stock = %{$self->unique_trait_stock};
    
    my $rs;
    my %data;
    $rs = $schema->resultset('Stock::Stock')->search(
        {'type.name' => ['field_layout', 'analysis_experiment', 'sampling_layout'], 'me.type_id' => [$plot_cvterm_id, $plant_cvterm_id, $subplot_cvterm_id, $tissue_sample_cvterm_id, $analysis_instance_cvterm_id], 'me.stock_id' => {-in=>$self->stock_id_list } },
        {join=> {'nd_experiment_stocks' => {'nd_experiment' => ['type', 'nd_experiment_projects'  ] } } ,
	 '+select'=> ['me.stock_id', 'me.uniquename', 'nd_experiment.nd_geolocation_id', 'nd_experiment_projects.project_id'],
	 '+as'=> ['stock_id', 'uniquename', 'nd_geolocation_id', 'project_id']
        }
	);
    while (my $s = $rs->next()) {
        $data{$s->get_column('uniquename')} = [$s->get_column('stock_id'), $s->get_column('nd_geolocation_id'), $s->get_column('project_id') ];
    }
    
    # print STDERR "DATA: ".Dumper(\%data);
    ## Use txn_do with the following coderef so that if any part fails, the entire transaction fails.
    my $coderef = sub {
        my %trait_and_stock_to_overwrite;
        my @overwritten_values;
        my $new_count = 0;
        my $skip_count = 0;
        my $overwrite_count = 0;
        my $remove_count = 0;

	print STDERR "(store) VALUES HASH ".Dumper($self->values_hash());
	
        foreach my $plot_name (@plot_list) {
	    
            my $stock_id = $data{$plot_name}[0];
            my $location_id = $data{$plot_name}[1];
            my $project_id = $data{$plot_name}[2];
	    
            # create plot-wide nd_experiment entry
	    
            my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
                nd_geolocation_id => $location_id,
                type_id => $phenotyping_experiment_cvterm_id,
                nd_experimentprops => [{type_id => $local_date_cvterm_id, value => $upload_date}, {type_id => $local_operator_cvterm_id, value => $operator}],
                nd_experiment_projects => [{project_id => $project_id}],
                nd_experiment_stocks => [{stock_id => $stock_id, type_id => $phenotyping_experiment_cvterm_id}]
			});
	    
            $experiment_ids{$experiment->nd_experiment_id()}=1;
	    
            # Check if there is a note for this plot, If so add it using dedicated function
            my $note_array = $self->values_hash->{$plot_name}->{'notes'};
            if (defined $note_array) {
                $self->store_stock_note($stock_id, $note_array, $operator);
            }
	    
            # Check if there is nirs data for this plot
            my $nirs_hashref = $self->values_hash->{$plot_name}->{'nirs'};
            if (defined $nirs_hashref) {
                $self->store_high_dimensional_data($nirs_hashref, $experiment->nd_experiment_id(), 'nirs_spectra');
                $new_count++;
            }
	    
            # Check if there is transcriptomics data for this plot
            my $transcriptomics_hashref = $self->values_hash->{$plot_name}->{'transcriptomics'};
            if (defined $transcriptomics_hashref) {
                $self->store_high_dimensional_data($transcriptomics_hashref, $experiment->nd_experiment_id(), 'transcriptomics');
                $new_count++;
            }
	    
            # Check if there is metabolomics data for this plot
            my $metabolomics_hashref = $self->values_hash->{$plot_name}->{'metabolomics'};
            if (defined $metabolomics_hashref) {
                $self->store_high_dimensional_data($metabolomics_hashref, $experiment->nd_experiment_id(), 'metabolomics');
                $new_count++;
            }
	    
            foreach my $trait_name (@trait_list) {	
                #print STDERR "trait: $trait_name\n";
                my $trait_cvterm = $self->trait_objs->{$trait_name};
		
                my $measurements_array = $self->values_hash->{$plot_name}->{$trait_name};
		print STDERR "MEASUREMENTS ARRAY 1: ".Dumper($measurements_array);
		print STDERR "REF MEASUREMENT ARRAY = ".ref($measurements_array->[0])."\n";
		if (ref($measurements_array->[0]) ne "ARRAY") {
		    
		    ## multiple measurements, have structure  [ [ value, timestamp ], [ value, timestamp ]... ] instead of just [ value, timestamp ] for single measurements
		    print STDERR "Adding to sub array...\n";
		    
		    $measurements_array = [ $measurements_array ];
		}

		print STDERR "MEASUREMENT ARRAY ".Dumper($measurements_array);

		my $value_count = 0;
		foreach my $value_array(@$measurements_array) { 
		    
		    print STDERR "CHECKING $plot_name, $trait_name, ".Dumper($value_array)."\n";
		    
		    # this should not give any $errors now
		    my ($warnings, $errors) = $self->check_measurement($plot_name, $trait_name, $value_array);
		    
		    if ($errors) { die "Trying to store phenotypes with the following errors: $errors"; }
		    
		    # convert to array or array format for single array values to accept old format inputs without refactoring
		    #if (ref($value_array->[0]) ne 'ARRAY') {
		    #	push @values, $value_array;
		    #   } else {
		    #	@values = @{$value_array};
		    #   }

		    print STDERR "VALUE ARRAY: ".Dumper($value_array);
		    
#		    foreach my $value (@$value_array) {
			
		    my $phenotype_object = CXGN::Phenotype->new( { schema => $schema });
		    # perl doesn't have a problem attempting to access possibly non existing indices
		    my $trait_value = $value_array->[0];
		    $phenotype_object->value($trait_value);
		    my $timestamp = $value_array->[1];
		    if ($timestamp eq "") { $timestamp = undef; }
		    $phenotype_object->collect_date($timestamp);
		    
		    $operator = $value_array->[2] ? $value_array->[2] : $operator;
		    $phenotype_object->operator($operator); 
		    my $observation = $value_array->[3];
		    if ($observation eq "") { $observation = undef; } # special case, not sure where it comes from
		    $phenotype_object->phenotype_id($observation);
		    my $image_id = $value_array->[4];
		    if (defined($image_id) && ($image_id eq "")) { $image_id = undef; }
		    $phenotype_object->image_id($image_id);
		    my $additional_info = $value_array->[5] || undef;
		    my $external_references = $value_array->[6] || undef;
		    my $unique_time = $timestamp && defined($timestamp) ? $timestamp : undef; ####$upload_date;
		    $phenotype_object->unique_time($unique_time);
		    my $existing_trait_value = $self->unique_trait_stock->{$trait_cvterm->cvterm_id(), $stock_id};
		    $phenotype_object->existing_trait_value($existing_trait_value);
		    $phenotype_object->cvterm_name($trait_cvterm->name());
		    $phenotype_object->cvterm_id($trait_cvterm->cvterm_id());
		    $phenotype_object->experiment($experiment);
		    
		    print STDERR "Existing value $existing_trait_value. New value: ".$phenotype_object->value()."\n";
		    
		    if (defined($trait_value) && (length($trait_value) || $remove_values)) {
			
			if ($ignore_new_values) {
			    print STDERR "IGNORING NEW VALUES...\n";
			    if (exists($self->unique_trait_stock->{$trait_cvterm->cvterm_id(), $stock_id})) {
				$skip_count++;
				next;
			    }
			}
			
		    }
		    my $plot_trait_uniquename = "stock: " .
			$stock_id . ", trait: " .
			$trait_cvterm->name .
			", date: $unique_time" .
			", operator: $operator" .
			", count: $value_count";
		    
		    print STDERR "PHENOTYPE UNIQUENAME: $plot_trait_uniquename\n";
		    
		    $phenotype_object->uniquename($plot_trait_uniquename);
		    
		    # Remove previous phenotype values for a given stock and trait if $overwrite values is checked, otherwise skip to next
		    if ($overwrite_values) {
			print STDERR "OVERWRITING VALUES...\n";
			if (exists($self->unique_trait_stock->{$trait_cvterm->cvterm_id(), $stock_id})) {
			    #skip when observation is provided since overwriting doesn't create records it updates observations.
			    if (!$observation) {
				push @{$trait_and_stock_to_overwrite{traits}}, $trait_cvterm->cvterm_id();
				push @{$trait_and_stock_to_overwrite{stocks}}, $stock_id;
			    }
			    $plot_trait_uniquename .= ", overwritten: $upload_date";
			    if ( defined($trait_value) && length($trait_value) ) {
				$overwrite_count++;
			    }
			    elsif ( $existing_trait_value ne "" ) {
				$remove_count++;
			    }
			} elsif ( length($trait_value) ) {
			    $new_count++;
			}
			$self->unique_trait_stock->{$trait_cvterm->cvterm_id(), $stock_id} = 1;
		    } else {
			if (!$allow_repeat_measures && exists($self->unique_trait_stock->{$trait_cvterm->cvterm_id(), $stock_id})) {
			    print STDERR "SKIPPING THIS VALUE... (NO REPEAT MEASURES!)\n";
			    $skip_count++;
			    next;
			} else {
			    $new_count++;
			}
		    }
		
		    
		    if ( !length($trait_value) && !$remove_values && $existing_trait_value ne "" ) {
			$skip_count++;	
		    }
		    
		    $phenotype_object->store();
		    
		    $experiment_ids{$experiment->nd_experiment_id()} = 1;
		    if ($image_id) {
			$nd_experiment_md_images{$experiment->nd_experiment_id()} = $image_id;
		    }
		    
		    
		    my $additional_info_stored;
		    if($additional_info){
			# my $pheno_additional_info = $schema->resultset("Phenotype::Phenotypeprop")->find_or_create({
			#     phenotype_id => $phenotype->phenotype_id,
				#     type_id       => $phenotype_addtional_info_type_id,
			# 											   });
			# $pheno_additional_info = $pheno_additional_info->update({
			#     value => encode_json $additional_info,
			# 							});
			# $additional_info_stored = $pheno_additional_info->value ? decode_json $pheno_additional_info->value : undef;
			$additional_info_stored = $phenotype_object->store_additional_info($additional_info);
		    }
		    my $external_references_stored;
		    
		    print STDERR "EXTERNAL REFERENCES: ".Dumper($external_references);
		    
		    if ($external_references) {
			
			
			# my $phenotype_external_references = $schema->resultset("Phenotype::Phenotypeprop")->find_or_create({
			#     phenotype_id => $phenotype->phenotype_id,
			#     type_id      => $external_references_type_id,
			# 												   });
			# $phenotype_external_references = $phenotype_external_references->update({
			#     value => encode_json $external_references,
			# 									});
			# $external_references_stored = $phenotype_external_references->value ? decode_json $phenotype_external_references->value : undef;
			$external_references_stored = $phenotype_object->store_external_references($external_references);
		    }
		    
		    my $observationVariableDbId = $trait_cvterm->cvterm_id;
		    my $observation_id = $phenotype_object->phenotype_id;
		    my %details = (
			"germplasmDbId"=> qq|$linked_data{$plot_name}->{germplasmDbId}|,
			"germplasmName"=> $linked_data{$plot_name}->{germplasmName},
			"observationDbId"=> qq|$observation_id|,
			"observationLevel"=> $linked_data{$plot_name}->{observationLevel},
			"observationUnitDbId"=> qq|$linked_data{$plot_name}->{observationUnitDbId}|,
			"observationUnitName"=> $linked_data{$plot_name}->{observationUnitName},
			"observationVariableDbId"=> qq|$observationVariableDbId|,
			"observationVariableName"=> $trait_cvterm->name,
			"studyDbId"=> qq|$project_id|,
			"uploadedBy"=> $operator ? $operator : "",
			"additionalInfo" => $additional_info_stored,
			"externalReferences" => $external_references_stored,
			"value" => $trait_value
			);
		    
		    if ($timestamp) { $details{'observationTimeStamp'} = $timestamp};
		    if ($operator) { $details{'collector'} = $operator};
		    
		    push @stored_details, \%details;
		    
		    $value_count++;
		}
	    }
	    
	}
	
	
	
	
	
	print STDERR "TRAIT STOCK\n";
	
	
	if (scalar(keys %trait_and_stock_to_overwrite) > 0) {
	    my @saved_nd_experiment_ids = keys %experiment_ids;
	    push @overwritten_values, $self->delete_previous_phenotypes(\%trait_and_stock_to_overwrite, \@saved_nd_experiment_ids);
	}
	
	$success_message = 'All values in your file have been successfully processed!<br><br>';
	$success_message .= "$new_count new values stored<br>";
	$success_message .= "$skip_count previously stored values skipped<br>";
	$success_message .= "$overwrite_count previously stored values overwritten<br>";
	$success_message .= "$remove_count previously stored values removed<br><br>";
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
    if (scalar(keys %nd_experiment_md_images) > 0) {
        $self->save_archived_images_metadata(\%nd_experiment_md_images);
    }
    
    return ($error_message, $success_message, \@stored_details);
}

sub store_stock_note {
    my $self = shift;
    my $stock_id = shift;
    my $note_array = shift;
    my $operator = shift;
    my $note = $note_array->[0];
    my $timestamp = $note_array->[1];
    $operator = $note_array->[2] ? $note_array->[2] : $operator;

    print STDERR "Stock_id is $stock_id and note in sub is $note, timestamp is $timestamp, operator is $operator\n";

    $note = $note ." (Operator: $operator, Time: $timestamp)";
    my $stock = $self->bcs_schema()->resultset("Stock::Stock")->find( { stock_id => $stock_id } );
    $stock->create_stockprops( { 'notes' => $note } );
}



sub store_high_dimensional_data {
    my $self = shift;
    my $nirs_hashref = shift;
    my $nd_experiment_id = shift;
    my $md_json_type = shift;
    my %nirs_hash = %{$nirs_hashref};

    my $protocol_id = $nirs_hash{protocol_id};
    delete $nirs_hash{protocol_id};

    my $nirs_json = encode_json \%nirs_hash;

    my $insert_query = "INSERT INTO metadata.md_json (json_type, json) VALUES (?,?) RETURNING json_id;";
    my $dbh = $self->bcs_schema->storage->dbh()->prepare($insert_query);
    $dbh->execute($md_json_type, $nirs_json);
    my ($json_id) = $dbh->fetchrow_array();

    my $linking_query = "INSERT INTO phenome.nd_experiment_md_json ( nd_experiment_id, json_id) VALUES (?,?);";
    $dbh = $self->bcs_schema->storage->dbh()->prepare($linking_query);
    $dbh->execute($nd_experiment_id,$json_id);

    my $protocol_query = "INSERT INTO nd_experiment_protocol ( nd_experiment_id, nd_protocol_id) VALUES (?,?);";
    $dbh = $self->bcs_schema->storage->dbh()->prepare($protocol_query);
    $dbh->execute($nd_experiment_id,$protocol_id);

    print STDERR "[StorePhenotypes] Linked $md_json_type json with id $json_id to nd_experiment $nd_experiment_id to protocol $protocol_id\n";
}

sub delete_previous_phenotypes {
    my $self = shift;
    my $trait_and_stock_to_overwrite = shift;
    my $saved_nd_experiment_ids = shift;
    my $stocks_sql = join ("," , @{$trait_and_stock_to_overwrite->{stocks}});
    my $traits_sql = join ("," , @{$trait_and_stock_to_overwrite->{traits}});
    my $saved_nd_experiment_ids_sql = join (",", @$saved_nd_experiment_ids);
    my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    my $q_search = "
        SELECT phenotype_id, nd_experiment_id, file_id
        FROM phenotype
        JOIN nd_experiment_phenotype using(phenotype_id)
        JOIN nd_experiment_stock using(nd_experiment_id)
        JOIN nd_experiment using(nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_files using(nd_experiment_id)
        JOIN stock using(stock_id)
        WHERE stock.stock_id IN ($stocks_sql)
        AND phenotype.cvalue_id IN ($traits_sql)
        AND nd_experiment_id NOT IN ($saved_nd_experiment_ids_sql)
        AND nd_experiment.type_id = $nd_experiment_type_id;
        ";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q_search);
    $h->execute();

    my %phenotype_ids_and_nd_experiment_ids_to_delete;
    my @deleted_phenotypes;
    while (my ($phenotype_id, $nd_experiment_id, $file_id) = $h->fetchrow_array()) {
        push @{$phenotype_ids_and_nd_experiment_ids_to_delete{phenotype_ids}}, $phenotype_id;
        push @{$phenotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}, $nd_experiment_id;
        push @deleted_phenotypes, [$file_id, $phenotype_id, $nd_experiment_id];
    }

    if (scalar(@deleted_phenotypes) > 0) {
        my $delete_phenotype_values_error = CXGN::Project::delete_phenotype_values_and_nd_experiment_md_values($self->dbhost, $self->dbname, $self->dbuser, $self->dbpass, $self->temp_file_nd_experiment_id, $self->basepath, $self->bcs_schema, \%phenotype_ids_and_nd_experiment_ids_to_delete);
        if ($delete_phenotype_values_error) {
            die "Error deleting phenotype values ".$delete_phenotype_values_error."\n";
        }
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

sub save_archived_images_metadata {
    my $self = shift;
    my $nd_experiment_md_images = shift;

    my $q = "INSERT into phenome.nd_experiment_md_images (nd_experiment_id, image_id) VALUES (?, ?);";
    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    # Check for single image id vs array, then handle accordingly
    while (my ($nd_experiment_id, $image_id) = each %$nd_experiment_md_images) {
        $h->execute($nd_experiment_id, $image_id);
    }
}

sub get_linked_data {
    my $self = shift;
    my %data;
    my $unit_list = $self->stock_list;
    my $schema = $self->bcs_schema;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;

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
        WHERE unit.uniquename = ANY (?)
        ";

    my $h = $schema->storage->dbh()->prepare($query);
    $h->execute($unit_list);
    while (my ($unit_id, $unit_name, $level, $accession_id, $accession_name, $location_id, $project_id) = $h->fetchrow_array()) {
        $data{$unit_name}{observationUnitName} = $unit_name;
        $data{$unit_name}{observationUnitDbId} = $unit_id;
        $data{$unit_name}{observationLevel} = $level;
        $data{$unit_name}{germplasmDbId} = $accession_id;
        $data{$unit_name}{germplasmName} = $accession_name;
        $data{$unit_name}{locationDbId} = $location_id;
        $data{$unit_name}{studyDbId} = $project_id;
    }

    return \%data;
}

sub handle_timestamp {
    my $self = shift;
    my $timestamp = shift || undef;
    my $phenotype_id = shift;

    my $q = "
    UPDATE phenotype
    SET collect_date = ?,
        create_date = DEFAULT
    WHERE phenotype_id = ?
    ";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($timestamp, $phenotype_id);
}

sub handle_operator {
    my $self = shift;
    my $operator = shift || undef;
    my $phenotype_id = shift;

    my $q = "
    UPDATE phenotype
    SET operator = ?
    WHERE phenotype_id = ?
    ";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($operator, $phenotype_id);
}

sub get_trait_props {
    my $self = shift;
    my $cvterm_id = shift;
    my $property_name = shift;

    my %property_by_cvterm_id;
    my $sql = "SELECT cvtermprop.value, cvterm.cvterm_id, cvterm.name FROM cvterm join cvtermprop on(cvterm.cvterm_id=cvtermprop.cvterm_id) join cvterm as proptype on(cvtermprop.type_id=proptype.cvterm_id) where proptype.name=? ";
    my $sth= $self->bcs_schema()->storage()->dbh()->prepare($sql);
    $sth->execute($property_name);
    while (my ($property_value, $cvterm_id, $cvterm_name) = $sth->fetchrow_array) {
	$property_by_cvterm_id{$cvterm_id} = $property_value;
    }
    print STDERR "PROPERTIES FROM $property_name: ".Dumper(\%property_by_cvterm_id);
    return %property_by_cvterm_id;
}

###
1;
###
