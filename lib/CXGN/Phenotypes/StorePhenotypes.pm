package CXGN::Phenotypes::StorePhenotypes;

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

has 'ignore_new_values' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

has 'metadata_hash' => (
    isa => "HashRef",
    is => 'rw',
    required => 1
);

has 'image_zipfile_path' => (
    isa => "Str | Undef",
    is => 'rw',
    required => 0
);

has 'trait_objs' => (
    isa => "HashRef",
    is => 'rw',
);

has 'unique_value_trait_stock' => (
    isa => "HashRef",
    is => 'rw',
);

has 'unique_trait_stock' => (
    isa => "HashRef",
    is => 'rw',
);

has 'unique_trait_stock_timestamp' => (
    isa => "HashRef",
    is => 'rw',
);

#build is used for creating hash lookups in this case
sub create_hash_lookups {
    my $self = shift;
    my $schema = $self->bcs_schema;

    #Find trait cvterm objects and put them in a hash
    my %trait_objs;
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
        $trait_objs{$trait_name} = $trait_cvterm;
        push @cvterm_ids, $trait_cvterm->cvterm_id();
    }
    $self->trait_objs(\%trait_objs);

    #for checking if values in the file are already stored in the database or in the same file
    my %check_unique_trait_stock;
    my %check_unique_trait_stock_timestamp;
    my %check_unique_value_trait_stock;

    my $stock_ids_sql = join ("," , @{$self->stock_id_list});
    #print STDERR "Cvterm ids are @cvterm_ids";
    if (scalar @cvterm_ids > 0) {
        my $cvterm_ids_sql = join ("," , @cvterm_ids);
        my $previous_phenotype_q = "SELECT phenotype.value, phenotype.cvalue_id, phenotype.collect_date, stock.stock_id FROM phenotype LEFT JOIN nd_experiment_phenotype USING(phenotype_id) LEFT JOIN nd_experiment USING(nd_experiment_id) LEFT JOIN nd_experiment_stock USING(nd_experiment_id) LEFT JOIN stock USING(stock_id) WHERE stock.stock_id IN ($stock_ids_sql) AND phenotype.cvalue_id IN ($cvterm_ids_sql);";
        my $h = $schema->storage->dbh()->prepare($previous_phenotype_q);
        $h->execute();

        #my $previous_phenotype_rs = $schema->resultset('Phenotype::Phenotype')->search({'me.cvalue_id'=>{-in=>\@cvterm_ids}, 'stock.stock_id'=>{-in=>$self->stock_id_list}}, {'join'=>{'nd_experiment_phenotypes'=>{'nd_experiment'=>{'nd_experiment_stocks'=>'stock'}}}, 'select' => ['me.value', 'me.cvalue_id', 'stock.stock_id'], 'as' => ['value', 'cvterm_id', 'stock_id']});
        while (my ($previous_value, $cvterm_id, $collect_timestamp, $stock_id) = $h->fetchrow_array()) {
        #while (my $previous_phenotype_cvterm = $previous_phenotype_rs->next() ) {
            #my $cvterm_id = $previous_phenotype_cvterm->get_column('cvterm_id');
            #my $stock_id = $previous_phenotype_cvterm->get_column('stock_id');
            if ($stock_id){
                #my $previous_value = $previous_phenotype_cvterm->get_column('value') || ' ';
                $collect_timestamp = $collect_timestamp || 'NA';
                $check_unique_trait_stock{$cvterm_id, $stock_id} = $previous_value;
                $check_unique_trait_stock_timestamp{$cvterm_id, $stock_id, $collect_timestamp} = $previous_value;
                $check_unique_value_trait_stock{$previous_value, $cvterm_id, $stock_id} = 1;
            }
        }

    }
    $self->unique_value_trait_stock(\%check_unique_value_trait_stock);
    $self->unique_trait_stock(\%check_unique_trait_stock);
    $self->unique_trait_stock_timestamp(\%check_unique_trait_stock_timestamp);

}

sub verify {
    my $self = shift;
    print STDERR "CXGN::Phenotypes::StorePhenotypes verify\n";

    my @plot_list = @{$self->stock_list};
    my @trait_list = @{$self->trait_list};
    @trait_list = map { $_ eq 'notes' ? () : ($_) } @trait_list; # omit notes from trait validation
    print STDERR Dumper \@trait_list;
    my %plot_trait_value = %{$self->values_hash};
    my %phenotype_metadata = %{$self->metadata_hash};
    my $timestamp_included = $self->has_timestamps;
    my $archived_image_zipfile_with_path = $self->image_zipfile_path;
    my $schema = $self->bcs_schema;
    my $transaction_error;
    # print STDERR Dumper \@plot_list;
    # print STDERR Dumper \%plot_trait_value;
    my $plot_validator = CXGN::List::Validate->new();
    my $trait_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plot_validator->validate($schema,'plots_or_subplots_or_plants_or_tissue_samples_or_analysis_instances',\@plot_list)->{'missing'}};
    my @traits_missing = @{$trait_validator->validate($schema,'traits',\@trait_list)->{'missing'}};
    my $error_message = '';
    my $warning_message = '';

    if (scalar(@plots_missing) > 0 || scalar(@traits_missing) > 0) {
        print STDERR "Plots or traits not valid\n";
        print STDERR "Invalid plots: ".join(", ", map { "'$_'" } @plots_missing)."\n" if (@plots_missing);
        print STDERR "Invalid traits: ".join(", ", map { "'$_'" } @traits_missing)."\n" if (@traits_missing);
        $error_message = "Invalid plots: <br/>".join(", <br/>", map { "'$_'" } @plots_missing) if (@plots_missing);
        $error_message = "Invalid traits: <br/>".join(", <br/>", map { "'$_'" } @traits_missing) if (@traits_missing);
        return ($warning_message, $error_message);
    }

    $self->create_hash_lookups();
    my %trait_objs = %{$self->trait_objs};
    my %check_unique_value_trait_stock = %{$self->unique_value_trait_stock};
    my %check_unique_trait_stock = %{$self->unique_trait_stock};
    my %check_unique_trait_stock_timestamp = %{$self->unique_trait_stock_timestamp};

    my %check_trait_category;
    my $sql = "SELECT b.value, c.cvterm_id from cvtermprop as b join cvterm as a on (b.type_id = a.cvterm_id) join cvterm as c on (b.cvterm_id=c.cvterm_id) where a.name = 'trait_categories';";
    my $sth = $schema->storage->dbh->prepare($sql);
    $sth->execute();
    while (my ($category_value, $cvterm_id) = $sth->fetchrow_array) {
        $check_trait_category{$cvterm_id} = $category_value;
    }

    my %check_trait_format;
    $sql = "SELECT b.value, c.cvterm_id from cvtermprop as b join cvterm as a on (b.type_id = a.cvterm_id) join cvterm as c on (b.cvterm_id=c.cvterm_id) where a.name = 'trait_format';";
    $sth = $schema->storage->dbh->prepare($sql);
    $sth->execute();
    while (my ($format_value, $cvterm_id) = $sth->fetchrow_array) {
        $check_trait_format{$cvterm_id} = $format_value;
    }

    my %image_plot_full_names;
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
                $image_plot_full_names{$_} = 1;
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

    my %check_file_stock_trait_duplicates;

    foreach my $plot_name (@plot_list) {
        foreach my $trait_name (@trait_list) {
            my $value_array = $plot_trait_value{$plot_name}->{$trait_name};
            #print STDERR Dumper $value_array;
            my $trait_value = $value_array->[0];
            my $timestamp = $value_array->[1];
            #print STDERR "$plot_name, $trait_name, $trait_value\n";
            if ($trait_value || (defined($trait_value) && $trait_value eq '0')) {
                my $trait_cvterm = $trait_objs{$trait_name};
                my $trait_cvterm_id = $trait_cvterm->cvterm_id();
                my $stock_id = $schema->resultset('Stock::Stock')->find({'uniquename' => $plot_name})->stock_id();

                if ($trait_value eq '.' || ($trait_value =~ m/[^a-zA-Z0-9,.\-\/\_]/ && $trait_value ne '.')){
                    $error_message = $error_message."<small>Trait values must be alphanumeric with no spaces: <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
                }

                #check that trait value is valid for trait name
                if (exists($check_trait_format{$trait_cvterm_id})) {
                    if ($check_trait_format{$trait_cvterm_id} eq 'numeric') {
                        my $trait_format_checked = looks_like_number($trait_value);
                        if (!$trait_format_checked) {
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
                    my @trait_categories = split /\//, $check_trait_category{$trait_cvterm_id};
                    my %trait_categories_hash = map { $_ => 1 } @trait_categories;
                    if (!exists($trait_categories_hash{$trait_value})) {
                        $error_message = $error_message."<small>This trait value should be one of ".$check_trait_category{$trait_cvterm_id}.": <br/>Plot Name: ".$plot_name."<br/>Trait Name: ".$trait_name."<br/>Value: ".$trait_value."</small><hr>";
                    }
                }

                #print STDERR "$trait_value, $trait_cvterm_id, $stock_id\n";
                #check if the plot_name, trait_name combination already exists in database.
                if (exists($check_unique_value_trait_stock{$trait_value, $trait_cvterm_id, $stock_id})) {
                    $warning_message = $warning_message."<small>$plot_name already has the same value as in your file ($trait_value) stored for the trait $trait_name.</small><hr>";
                } elsif (exists($check_unique_trait_stock_timestamp{$trait_cvterm_id, $stock_id, $timestamp})) {
                    $warning_message = $warning_message."<small>$plot_name already has a different value ($check_unique_trait_stock_timestamp{$trait_cvterm_id, $stock_id, $timestamp}) than in your file ($trait_value) stored in the database for the trait $trait_name for the timestamp $timestamp.</small><hr>";
                } elsif (exists($check_unique_trait_stock{$trait_cvterm_id, $stock_id})) {
                    $warning_message = $warning_message."<small>$plot_name already has a different value ($check_unique_trait_stock{$trait_cvterm_id, $stock_id}) than in your file ($trait_value) stored in the database for the trait $trait_name.</small><hr>";
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
    print STDERR "CXGN::Phenotypes::StorePhenotypes store\n";

    $self->create_hash_lookups();
    my %linked_data = %{$self->get_linked_data()};
    my @plot_list = @{$self->stock_list};
    my @trait_list = @{$self->trait_list};
    @trait_list = map { $_ eq 'notes' ? () : ($_) } @trait_list; # omit notes so they can be handled separately
    my %trait_objs = %{$self->trait_objs};
    my %plot_trait_value = %{$self->values_hash};
    my %phenotype_metadata = %{$self->metadata_hash};
    my $timestamp_included = $self->has_timestamps;
    my $archived_image_zipfile_with_path = $self->image_zipfile_path;
    my $phenotype_metadata = $self->metadata_hash;
    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    my $overwrite_values = $self->overwrite_values;
    my $ignore_new_values = $self->ignore_new_values;
    my $error_message;
    my $transaction_error;
    my $user_id = $self->user_id;
    my $archived_file = $phenotype_metadata->{'archived_file'};
    my $archived_file_type = $phenotype_metadata->{'archived_file_type'};
    my $operator = $phenotype_metadata->{'operator'};
    my $upload_date = $phenotype_metadata->{'date'};
    my $success_message;

    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $local_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'date', 'local')->cvterm_id();
    my $local_operator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'operator', 'local')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $analysis_instance_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_instance', 'stock_type')->cvterm_id();
    my %experiment_ids;
    my @stored_details;
    my %nd_experiment_md_images;

    my %check_unique_trait_stock = %{$self->unique_trait_stock};

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
            my $note_array = $plot_trait_value{$plot_name}->{'notes'};
            if (defined $note_array) {
                $self->store_stock_note($stock_id, $note_array, $operator);
            }

            # Check if there is nirs data for this plot
            my $nirs_hashref = $plot_trait_value{$plot_name}->{'nirs'};
            if (defined $nirs_hashref) {
                $self->store_high_dimensional_data($nirs_hashref, $experiment->nd_experiment_id(), 'nirs_spectra');
            }

            # Check if there is transcriptomics data for this plot
            my $transcriptomics_hashref = $plot_trait_value{$plot_name}->{'transcriptomics'};
            if (defined $transcriptomics_hashref) {
                $self->store_high_dimensional_data($transcriptomics_hashref, $experiment->nd_experiment_id(), 'transcriptomics');
            }

            # Check if there is metabolomics data for this plot
            my $metabolomics_hashref = $plot_trait_value{$plot_name}->{'metabolomics'};
            if (defined $metabolomics_hashref) {
                $self->store_high_dimensional_data($metabolomics_hashref, $experiment->nd_experiment_id(), 'metabolomics');
            }

            foreach my $trait_name (@trait_list) {

                #print STDERR "trait: $trait_name\n";
                my $trait_cvterm = $trait_objs{$trait_name};

                my $value_array = $plot_trait_value{$plot_name}->{$trait_name};
                #print STDERR Dumper $value_array;
                my $trait_value = $value_array->[0];
                my $timestamp = $value_array->[1];
                $operator = $value_array->[2] ? $value_array->[2] : $operator;
                my $observation = $value_array->[3];
                my $image_id = $value_array->[4];
                my $unique_time = $timestamp && defined($timestamp) ? $timestamp : 'NA'.$upload_date;

                if (defined($trait_value) && length($trait_value)) {

                    #Remove previous phenotype values for a given stock and trait, if $overwrite values is checked
                    if ($overwrite_values) {
                        if (exists($check_unique_trait_stock{$trait_cvterm->cvterm_id(), $stock_id})) {
                            push @{$trait_and_stock_to_overwrite{traits}}, $trait_cvterm->cvterm_id();
                            push @{$trait_and_stock_to_overwrite{stocks}}, $stock_id;
                        }
                        $check_unique_trait_stock{$trait_cvterm->cvterm_id(), $stock_id} = 1;
                    }
                    if ($ignore_new_values) {
                        if (exists($check_unique_trait_stock{$trait_cvterm->cvterm_id(), $stock_id})) {
                            next;
                        }
                    }

                    my $plot_trait_uniquename = "Stock: " .
                        $stock_id . ", trait: " .
                        $trait_cvterm->name .
                        " date: $unique_time" .
                        "  operator = $operator" ;

                    my $phenotype;
                    if ($observation) {
                        $phenotype = $trait_cvterm->find_related("phenotype_cvalues", {
                            observable_id => $trait_cvterm->cvterm_id,
                            phenotype_id => $observation,
                        });

                        ## should check that unit and variable (also checked here) are conserved in parse step, if not reject before store
                        ## should also update operator in nd_experimentprops

                        $phenotype->update({
                            value => $trait_value,
                            uniquename => $plot_trait_uniquename,
                        });

                        $self->handle_timestamp($timestamp, $observation);
                        $self->handle_operator($operator, $observation);

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
                            if ($image_id) {
                                $nd_experiment_md_images{$nd_experiment_id} = $image_id;
                            }
                        }

                    } else {

                        $phenotype = $trait_cvterm->create_related("phenotype_cvalues", {
                            observable_id => $trait_cvterm->cvterm_id,
                            value => $trait_value ,
                            uniquename => $plot_trait_uniquename,
                        });

                        $self->handle_timestamp($timestamp, $phenotype->phenotype_id);
                        $self->handle_operator($operator, $phenotype->phenotype_id);

                        $experiment->create_related('nd_experiment_phenotypes', {
                            phenotype_id => $phenotype->phenotype_id
                        });

                        # $experiment->find_or_create_related({
                        #     nd_experiment_phenotypes => [{phenotype_id => $phenotype->phenotype_id}]
                        # });

                        $experiment_ids{$experiment->nd_experiment_id()}=1;
                        if ($image_id) {
                            $nd_experiment_md_images{$experiment->nd_experiment_id()} = $image_id;
                        }
                    }
                    my $observationVariableDbId = $trait_cvterm->cvterm_id;
                    my %details = (
                        "germplasmDbId"=> $linked_data{$plot_name}->{germplasmDbId},
                        "germplasmName"=> $linked_data{$plot_name}->{germplasmName},
                        "observationDbId"=> $phenotype->phenotype_id,
                        "observationLevel"=> $linked_data{$plot_name}->{observationLevel},
                        "observationUnitDbId"=> $linked_data{$plot_name}->{observationUnitDbId},
                        "observationUnitName"=> $linked_data{$plot_name}->{observationUnitName},
                        "observationVariableDbId"=> qq|$observationVariableDbId|,
                        "observationVariableName"=> $trait_cvterm->name,
                        "studyDbId"=> $project_id,
                        "uploadedBy"=> $user_id,
                        "value" => $trait_value
                    );

                    if ($timestamp) { $details{'observationTimeStamp'} = $timestamp};
                    if ($operator) { $details{'collector'} = $operator};

                    push @stored_details, \%details;
                }
            }
        }

        if (scalar(keys %trait_and_stock_to_overwrite) > 0) {
            my @saved_nd_experiment_ids = keys %experiment_ids;
            push @overwritten_values, $self->delete_previous_phenotypes(\%trait_and_stock_to_overwrite, \@saved_nd_experiment_ids);
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
    my $delete_phenotype_values_error = CXGN::Project::delete_phenotype_values_and_nd_experiment_md_values($self->dbhost, $self->dbname, $self->dbuser, $self->dbpass, $self->temp_file_nd_experiment_id, $self->basepath, $self->bcs_schema, \%phenotype_ids_and_nd_experiment_ids_to_delete);
    if ($delete_phenotype_values_error) {
        die "Error deleting phenotype values ".$delete_phenotype_values_error."\n";
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

###
1;
###
