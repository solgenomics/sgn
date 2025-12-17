
=head1

CXGN::Phenotype - a class for handling of individual phenotype values

=head1 DESCRIPTION

CXGN::Phenotype handles individual phentoypic observations and maps to the phenotype table in the database schema.

Phenotypes can have different types:

=over 3

=item * They can contain numbers, strings, dates, or booleans. If they are numbers, a upper and a lower limit can be defined. The date format is enforced to an ISO date format.

=item * Phenotypes can also be associated with categories. In this case, the phenotypic value needs to be one of the defined values in the categories.

=item * Multicat phenotypes can contain more than one value selected from a list of categories. Multiple values are stored in the value field separated by a colon.

=item * the check() function can be used to check the value against all applicable constraints.

=item * the constraints are stored as cvtermprops

=back

=head1 AUTHORS

 Lukas Mueller
 Srikanth Karaikal

=head1 FUNCTIONS

=cut

package CXGN::Phenotype;

use Moose;
use Data::Dumper;
use Bio::Chado::Schema;
use Scalar::Util qw | looks_like_number |;
use JSON qw | encode_json decode_json |;

=head2 Constructor

=head3 new()

Creates a new object; provide any accessor as a parameter in a hashref.
Required parameters: schema

=head2 Accessors

=head3 schema()

Defined the Bio::Chado::Schema object for database access

=cut

has 'schema' => (
    isa => 'Ref',
    is => 'rw',
    required => 1,
    );

=head3 phenotype_id()

Sets the phenotype_id. If present, will update that phenotype
when store() is called. Otherwise, a new row will be inserted into the database.

=cut

has 'phenotype_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    );

=head3 cvterm_id()

Sets the cvterm_id of the phenotype ontology that this phenotype
refers to.

=cut

has 'cvterm_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    );

has 'cvterm_name' => (
    isa => 'Str',
    is => 'rw'
);

=head3 value()

Sets the value of the phenotype. This can be a number, string, date, boolean, or one or more values from predefined categories.

=cut

has 'value' => (
    isa => 'Str|Undef',
    is => 'rw',
    );

has 'stock_id' => (
    isa => 'Int',
    is => 'rw',
    );

=head3 observationunit_id()

Defines the observation unit that was observed in this measurement. It points to an entry in the stock table of the appropriate type.

=cut

has 'observationunit_id' => (
    isa => 'Int',
    is => 'rw',
    );

=head3 operator()

A string with the operator name. This value is read from the fieldbook operator field.

=cut

has 'operator' => (
    isa => 'Str',
    is => 'rw',
    );

=head3 collect_date()

The date and time the observation was collected in ISO format. For example, Fieldbook provides this information.

=cut

has 'collect_date' => (
    isa => 'Str|Undef',
    is => 'rw',
    );

=head3 image_id()

An optional image_id for an associated image.

=cut

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

=head3 uniquename

a construct of different elements containing all the information in a string format that should be unique in the database.

=cut

has 'uniquename' => (
    isa => 'Str',
    is => 'rw',
    );

=head3 experiment

the associated nd_experiment Bio::Chado::Schema object

=cut

has 'experiment' => (
    isa => 'Bio::Chado::Schema::Result::NaturalDiversity::NdExperiment',
    is => 'rw',
    );

after 'experiment' => sub {
    my $self = shift;
    my $exp = shift;

    if ($exp) { $self->nd_experiment_id($exp->nd_experiment_id()); }

};

=head3 nd_experiment_id()

The nd_experiment_id of the associated nd_experiment entry.
Required as a parameter for new phenotypes.

=cut

has 'nd_experiment_id' => (
    isa => 'Int',
    is => 'rw',
    );

=head3 trait_repeat_type()

specifies whether the trait is measured once ("single"), multiple times ("multiple"), or as a time series ("time_series").

=cut

has 'trait_repeat_type' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    default => undef,
    );

=head3 trait_format()

specified the format of the trait, including numeric, date, boolean etc.

=cut

has 'trait_format' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

=head3 trait_categories()

Lists all the trait categories as a string, with the different categories separated by a slash ("/").

=cut

has 'trait_categories' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

=head3 trait_min_value()

The minimal value allowed for the trait, for numeric traits.

=cut

has 'trait_min_value' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

=head3 trait_max_value()

The maximal value allowed for the trait, for numeric traits.

=cut

has 'trait_max_value' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );

=head2 overwrite()

Overwrite the old value if it is different but has the same value and timestamp

If overwrite is not set, the new value is added to the database.

=cut

has 'overwrite' => (
    isa => 'Bool',
    is => 'rw',
    default => sub { return 0; },
    );

=head2 remove_empty_value

Remove a value if the value in the file is undef or '' and another value is already
stored in the database. Requires overwrite(1).

=cut

has 'remove_empty_value' => (
    isa => 'Bool',
    is => 'rw',
    default => sub { return 0; },
    );

=head2 old_value

The old value in the database. Can be set automatically by calling find_matching_phenotype() or set
from a large compound query using this accessor.

=cut

has 'old_value' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );




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
        #print STDERR "no phenotype_id - creating empty object\n";
    }
}

=head3 function store()

    Params: none
    Returns: a hashref with success => $boolean and the
        phenotype_id of the new phenotype, if applicable
    Desc:

=cut

sub store {
    my $self = shift;
    #print STDERR "CXGN::Phenotype store \n";

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

        # check if a value needs to be removed.
        #
        if ($self->remove_empty_value() && (!defined($self->value()) || $self->value() eq '')) {
            #print STDERR "REMOVE VALUES SET. REMOVING THE VALUE ".$self->value()." BECAUSE IT IS NOT DEFINED.\n";
            $self->delete_phenotype();
            return { success => 1, remove_count => 1, reason => "DELETED ENTRY - DELETE VALUES SET ON EMPTY VALUE.\n" };
        }

        # update only if overwrite is set
        #
        if ($self->overwrite()) {
            #print STDERR "OVERWRITE SET (".$self->overwrite()."). OVERWRITING OLD VALUE ".$self->old_value()." WITH NEW VALUE ".$self->value()."\n";

            if (! $self->image_id() && ($self->value() eq "" || ! defined($self->value()) || $self->value() eq ".") || $self->value() eq "NA") {
                #print STDERR "DELETE VALUES NOT SET FOR EMPTY VALUE. IGNORING EMPTY VALUES!\n";
                return { succes => 1, skip_count => 1, reason => "SKIPPING EMPTY VALUE WITHOUT DELETE_VALUES\n" };
            }

            if ($self->old_value() && ($self->old_value() eq $self->value())) {
                #print STDERR "OLD VALUE AND NEW VALUE ARE THE SAME (".$self->value()."). NOT UPDATING\n";
                return { success => 1, skip_count => 1, previously_stored_skip_count => 1, reason => "NEW AND OLD VALUES ARE IDENTICAL.\n" };

            }

            # else {
            #print STDERR "UPDATING ".$self->phenotype_id()." WITH NEW VALUE ".$self->value()."\n";
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
            return { success => 1, overwrite_count => \@overwritten_values, experiment_ids => \%experiment_ids, nd_experiment_md_images => \%nd_experiment_md_images };
        } # if overwrite
        return { success => 1, skip_count => 1, previously_stored_skip_count => 1, reason => "Overwrite not set - skipping" };
    }  # if phenotype-id
    else { # INSERT
        #print STDERR "OLD VALUE = ".$self->old_value()."\n";
        if ($self->old_value() eq $self->value()) {
            #print STDERR "TRYING TO INSERT WITH SAME VALUE ALREADY PRESENT... SKIPPING!\n";
            return { success => 1, skip_count => 1, previously_stored_skip_count => 1, reason => "VALUE ALREADY PRESENT FOR TRAIT, OBS UNIT AND TIMESTAMP.\n" };
        }

        #print STDERR "INSERTING... ".$self->value()."\n";
        if (! $self->image_id() && ($self->value() eq "" || ! defined($self->value()) || $self->value() eq ".") || $self->value() eq "NA") {
            #print STDERR "NOT STORING EMTPY VALUE\n";
            return { success => 1, skip_count => 1, message => "Not storing empty values" };
        }
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
        #print STDERR "INSERTED ROW WITH NEW PHENOTYPE_ID ".$self->phenotype_id()."\n";
    }
    return { success => 1, new_count => 1, phenotype_id => $self->phenotype_id() };
}

=head3 store_external_references()

Params: external references

=cut

sub store_external_references {
    my $self = shift;
    # print STDERR "the CXGN::Phenotype store_external_references function\n";
    my $external_references = shift;

    if (! $self->phenotype_id()) {
        #print STDERR "Can't store external references on this phenotype because there is no phenotype_id\n";
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

=head3 store_additional_info

Params: additional_info

=cut

sub store_additional_info {
    my $self = shift;
    my $additional_info = shift;

    if (! $self->phenotype_id()) {
        print STDERR "Can't store additional info on this phenotype because there is no phenotype_id\n";
    }

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

=head3 delete_phenotype()

Deletes the current phenotype.
Side effect: Removes the database row from the database.

=cut

sub delete_phenotype {
    my $self = shift;

    if ($self->phenotype_id()) {
        #print STDERR "Removing phenotype with phenotype_id ".$self->phenotype_id()."\n";
        my $row = $self->schema->resultset("Phenotype::Phenotype")->find( { phenotype_id => $self->phenotype_id() });
        $row->delete();
    }
    else {
        #print STDERR "Trying to delete a phenotype without phenotype_id\n";
    }
}

=head3 function check_categories()

=cut

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
            if ($value ne '' && defined($value) && !exists($trait_categories_hash{$value})) {
                my $valid_values = join("/", sort keys %trait_categories_hash);  # Sort values for consistent order
                $error_message =  "<small> This trait value should be one of $valid_values: <br/>Value: ".$self->value()."</small><hr>";
            }
            else {
                #print STDERR "Trait value ".$self->value()." is valid\n";
            }
        }
    }
    return $error_message;
}

=head2 check

STATUS: NOT YET IMPLEMENTED.

   Params: $plot_name, $trait_name, $values
   The values parameter may be:
    * a arrayref. In that case, the array is assumed to contain: a trait value, a timestamp
    * a hashref. In that case, the values represent high dimensional data (not checked by this function)

   Returns: a an array containing two arrayrefs, one with warnings and the other with errors.

   Description:

   The function will check:
   * Are trait formats defined for the trait? If the trait is numeric, the trait numericness is checked, and
     whether the values lies between trait_minimum and trait_maximum.
   * Is the trait an image? The availability of the corresponding image file is checked.
   * If the trait is categorical, the trait categories are retrieved and the value checked against the
     categories
   * The timestamp is checked for format (ISO, YYYY-MM-DD HH:MM::SS).
   * If the trait is multicat, the multiple values are checked against the defined categories.
   * If the trait is defined as a multiple of time_series measurement, the presence of a timestamp is checked.
     Omitting the timestamp for a multiple trait is considered an error and should break the upload.
   * (NOT YET)If the trait is defined as a single trait, the presence of an older measurement is checked.
     Depending on the settings, the old trait is either retained or overwritten with the new trait value.\

=cut

sub check {
    my $self = shift;

    my @errors;
    my @warnings;

    my $trait_value = $self->value();

    if (defined($trait_value) && $trait_value ne '' && $trait_value ne 'NA' && $trait_value ne '.' && $self->trait_format() eq 'numeric') { # check only if the trait_value is defined and not NA etc.
        if (! looks_like_number($trait_value)) {
            push @errors, "Trait format is numeric but value is not a number ($trait_value)\n";
        }

        if ($self->check_trait_minimum()) {
            push @errors, "Trait value $trait_value is smaller than defined minimum ".$self->trait_min_value()."\n";
        }

        if ($self->check_trait_maximum()) {
            push @errors, "Trait value $trait_value is larger than defined maximum ".$self->trait_max_value()."\n";
        }
    }

    #check, if the trait value is an image
    if ($self->trait_format eq 'image') {
        $trait_value =~ s/^.*photos\///;
        #if (!exists($self->image_plot_full_names->{$trait_value})) {
        #    $error_message = $error_message."<small>For Plot Name: $plot_name there should be a corresponding image named in the zipfile called $trait_value. </small><hr>";
        #}
    }

    if ($self->trait_format() eq "categorical") {
        my $error = $self->check_categories();
        push @errors, $error;
    }

    if ($self->collect_date()) { #timestamp_included) {
        push @errors, $self->collect_date();
    }

    if ($self->trait_repeat_type() eq "multiple" or $self->trait_repeat_type() eq "time_series") {
        #print STDERR "Trait repeat type: ".$self->trait_repeat_type()."\n";
        if (!$self->collect_date()) {
            # print STDERR "cvterm_id : ".$self->cvterm_id()." is multiple without timestamp \n";
            push @errors, "For trait with cvterm_id ".$self->cvterm_id()." that is defined as a 'multiple' or 'time_series' repeat type trait, a timestamp is required.\n";
        }
    }

    ## Verify metadata
    #    if ($self->metadata_hash->{'archived_file'} && (!$self->metadata_hash->{'archived_file_type'} || $self->metadata_hash->{'archived_file_type'} eq "")) {
    #       push @errors, "No file type provided for archived file.";
    #  }
    if (!$self->operator()) {
        push @warnings, "No operator provided in file upload metadata.";

    }
    #    if (!$self->metadata_hash->{'date'} || $self->metadata_hash->{'date'} eq "") {
    #        push @errors, "No date provided in file upload metadata.";
    #    }

    return @errors;
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

    if ($self->trait_format() ne "numeric") {
        #print STDERR "Format is not numeric, can't check minimum\n";
        return 1;
    }
    if (! defined($self->trait_min_value()) ) {
        #print STDERR "Warning. Checking trait minimum but minimum value is not set.\n";
        return 1;
    }
    elsif ($self->value() < $self->trait_min_value()) {
        return 0;
    }
    return 1;
}

sub check_trait_maximum {
    my $self = shift;

    if ($self->trait_format() ne "numeric") {
    #print STDERR "Format is not numeric, can't check maximum.";
        return 1;
    }
    if (! defined($self->trait_max_value())) {
    #print STDERR "Warning. Checking trait maximum but maximum value is not set\n";
        return 1;
    }
    if ($self->value() > $self->trait_max_value()) {
        return 0;
    }
    return 1;
}

sub check_collect_date {
    my $self = shift;

    my $error_message = "";
    my $timestamp = $self->collect_date();
    my $trait_value = $self->trait_value();
    my $trait_name = $self->trait_name();
    if ( (!$timestamp && !$trait_value) || ($timestamp && !$trait_value) || ($timestamp && $trait_value) ) {
        if ($timestamp) {
            if( !$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                $error_message = $error_message."<small>Bad timestamp for value for observation unit id: ".$self->observationunit_id()."<br/>Trait Name: ".$trait_name."<br/>Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000</small><hr>";
                return 0;
            }
            else {
                return 1;
            }
        }

    }
    return;
}


=head2 find_matching_phenotype()

    Desc: finds matching phenotypes in the database
    Params: cvterm_id, observationunit_id, value
          (if no params are provided, will take object values)
    Returns: an array of matching phenotype ids

=cut

sub find_matching_phenotype {
    my $self = shift;
    my $cvterm_id = shift || $self->cvterm_id();
    my $observationunit_id = shift || $self->observationunit_id();
    my $value = shift || $self->value();

    my $h = $self->schema()->storage()->dbh()->prepare(
    "SELECT phenotype_id, collect_date FROM phenotype
        JOIN nd_experiment_phenotype USING(phenotype_id)
        JOIN nd_experiment_stock USING(nd_experiment_id)
        WHERE cvalue_id=?  AND stock_id=? AND value=?");

    $h->execute($cvterm_id, $observationunit_id, $value);

    my @phenotype_ids;
    while (my ($phenotype_id) = $h->fetchrow_array()) {
        push @phenotype_ids, $phenotype_id;
    }
    return @phenotype_ids;
}

=head2 find_matching_phenotype_with_collect_date()

    Desc: finds matching phenotypes in the database
    Params: cvterm_id, observationunit_id, value, collect_data
          (if no params are provided, will take object values)
    Returns: an array of matching phenotype ids

=cut

sub find_matching_phenotype_with_collect_date {
    my $self = shift;
    my $cvterm_id = shift || $self->cvterm_id();
    my $observationunit_id = shift || $self->observationunit_id();
    my $value = shift || $self->value();
    my $collect_date = shift || $self->collect_date();

    my $h =  $self->schema()->storage()->dbh()->prepare(
    "SELECT phenotype_id, collect_date FROM phenotype
        JOIN nd_experiment_phenotype USING(phenotype_id)
        JOIN nd_experiment_stock USING(nd_experiment_id)
        WHERE cvalue_id=? AND stock_id=? AND collect_date=? AND value=? ");

    $h->execute($cvterm_id, $observationunit_id, $collect_date, $value);

    my @phenotype_ids;
    while (my ($phenotype_id) = $h->fetchrow_array()) {
        push @phenotype_ids, $phenotype_id;
    }
    return @phenotype_ids;
}

1;
