
=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for uploading phenotype spreadsheets

=head1 DESCRIPTION

Uploading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Naama Menda <nm249@cornell.edu>
Alex Ogbonna <aco46@cornell.edu>
Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesUpload;

use Moose;
use Try::Tiny;
use DateTime;
use Date::Parse;
use HTML::Entities qw(encode_entities);
use File::Slurp;
use File::Spec;
use File::Copy;
use Data::Dumper;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::BreedersToolbox::Projects;
use CXGN::Phenotype;
use CXGN::Trial;
use CXGN::Project;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );


sub upload_phenotype_verify :  Path('/ajax/phenotype/upload_verify') : ActionClass('REST') { }
sub upload_phenotype_verify_POST : Args(1) {
    my ($self, $c, $file_type, $is_treatment) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $overwrite_values, $remove_values, $image_zip, $user_id, $validate_type) = _prep_upload($c, $file_type, $is_treatment, $schema);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }

    my $timestamp = 0;
    if ($timestamp_included) {
        $timestamp = 1;
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>$plots,
        trait_list=>$traits,
        values_hash=>$parsed_data,
        has_timestamps=>$timestamp,
        metadata_hash=>$phenotype_metadata,
        image_zipfile_path=>$image_zip,
        composable_validation_check_name=>$c->config->{composable_validation_check_name}
    );

    my ($warning_status, $verified_warning, $verified_error);
    try {
        ($verified_warning, $verified_error) = $store_phenotypes->verify();
    }
    catch {
        $verified_error = $_;
	print STDERR "ERROR DURING UPLOAD: $verified_error\n";
    };

    if ($verified_error) {
        my $localized = _localized_verification_errors($c, $store_phenotypes->verification_errors());
        push @$error_status, defined($localized) ? $localized : $verified_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }
    if ($verified_warning) {
        my $details = $store_phenotypes->verification_warnings();
        my $localized = _localized_verification_warnings($c, $details);
        push @$warning_status, defined($localized) ? $localized : $verified_warning;
    }
    push @$success_status, encode_entities($c->i18n->p('phenotype_upload.server.verified', 'File data verified. Plot names and trait names are valid.'), q{&<>"'});

    $c->stash->{rest} = {success => $success_status, warning => $warning_status, error => $error_status};
}

sub upload_phenotype_store :  Path('/ajax/phenotype/upload_store') : ActionClass('REST') { }
sub upload_phenotype_store_POST : Args(1) {
    my ($self, $c, $file_type, $is_treatment) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $overwrite_values, $remove_values, $image_zip, $user_id, $validate_type) = _prep_upload($c, $file_type, $is_treatment, $schema);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }
    my $overwrite = 0;
    if ($overwrite_values) {
        $overwrite = 1;
    }
    my $remove = 0;
    if ($remove_values) {
        $remove = 1;
    }
    my $timestamp = 0;
    if ($timestamp_included) {
        $timestamp = 1;
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>$plots,
        trait_list=>$traits,
        values_hash=>$parsed_data,
        has_timestamps=>$timestamp,
        overwrite_values=>$overwrite,
        remove_values=>$remove,
        metadata_hash=>$phenotype_metadata,
        image_zipfile_path=>$image_zip,
        composable_validation_check_name=>$c->config->{composable_validation_check_name},
        allow_repeat_measures=>$c->config->{allow_repeat_measures}
    );

    #upload_phenotype_store function redoes the same verification that upload_phenotype_verify does before actually uploading. maybe this should be commented out.
    #my ($verified_warning, $verified_error) = $store_phenotypes->verify($c,$plots,$traits, $parsed_data, $phenotype_metadata);
    #if ($verified_error) {
	#push @$error_status, $verified_error;
	#$c->stash->{rest} = {success => $success_status, error => $error_status };
	#return;
    #}
    #push @$success_status, "File data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success);
    try {
        ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    }
    catch {
        $stored_phenotype_error = $_;
    };

    if ($stored_phenotype_error) {
        push @$error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status};
        return;
    }
    if ($stored_phenotype_success) {
        my $summary = $store_phenotypes->upload_summary();
        push @$success_status, $summary
            ? _localized_upload_summary($c, $summary)
            : $stored_phenotype_success;
    }

    if ($validate_type eq 'field book' && $image_zip) {
        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $image_error = $image->upload_fieldbook_zipfile($image_zip, $user_id);
        if ($image_error) {
            push @$error_status, $image_error;
        }
    }

    push @$success_status, encode_entities($c->i18n->p('phenotype_upload.server.metadata_saved', 'Metadata saved for archived file.'), q{&<>"'});
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => $success_status, error => $error_status};
}

# Completed typed errors are rendered only at the request boundary.
# Any unknown or malformed record retains the original complete library error.
sub _localized_verification_errors {
    my ($c, $records) = @_;
    return unless ref($records) eq 'ARRAY' && @$records;
    my @rendered;
    for my $record (@$records) {
        return unless ref($record) eq 'HASH' && defined($record->{code})
            && !ref($record->{code}) && ref($record->{variables}) eq 'HASH';
        my $code = $record->{code};
        my $v = { %{$record->{variables}} };
        my ($message, $wrapper);
        if ($code eq 'invalid_plots') {
            return unless ref($v->{plots}) eq 'ARRAY' && @{$v->{plots}};
            my @names;
            for my $raw (@{$v->{plots}}) {
                return unless defined($raw) && !ref($raw);
                my $name = $raw;
                push @names, "'$name'";
            }
            $v->{plots} = join(', ', @names);
            $message = $c->i18n->p('phenotype_upload.verify_error.invalid_plots', 'Invalid plots: %{plots}', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'invalid_traits') {
            return unless ref($v->{traits}) eq 'ARRAY' && @{$v->{traits}};
            my @names;
            for my $raw (@{$v->{traits}}) {
                return unless defined($raw) && !ref($raw);
                my $name = $raw;
                push @names, "'$name'";
            }
            $v->{traits} = join(', ', @names);
            $message = $c->i18n->p('phenotype_upload.verify_error.invalid_traits', 'Invalid traits: %{traits}', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'possible_matches_heading') {
            $message = $c->i18n->p('phenotype_upload.verify_error.possible_matches_heading', 'Possible Trait Matches:');
            $wrapper = 'heading';
        }
        elsif ($code eq 'possible_matches_explanation') {
            $message = $c->i18n->p('phenotype_upload.verify_error.possible_matches_explanation', 'The following traits have names and ontology identifiers that do not match in this database.  The following suggestions have the correct ontology identifier for the name used in your data.');
            $wrapper = 'explanation';
        }
        elsif ($code eq 'possible_match') {
            return unless defined($v->{original}) && !ref($v->{original});
            return unless defined($v->{matching}) && !ref($v->{matching});
            $message = $c->i18n->p('phenotype_upload.verify_error.possible_match', '%{original} should be %{matching}', $v);
            $wrapper = 'pair';
        }
        elsif ($code eq 'not_variables_heading') {
            $message = $c->i18n->p('phenotype_upload.verify_error.not_variables_heading', 'Traits That Are Not Ontology Variables:');
            $wrapper = 'heading';
        }
        elsif ($code eq 'not_variables_explanation') {
            $message = $c->i18n->p('phenotype_upload.verify_error.not_variables_explanation', 'The following traits are not ontology variables (they do not have associated method and scale information).  Use the Search > Traits page to find the proper Trait Name and Trait ID to use.  The following suggestions include related ontology variables to the terms used in your data.');
            $wrapper = 'explanation';
        }
        elsif ($code eq 'related_variable') {
            return unless defined($v->{original}) && !ref($v->{original});
            return unless defined($v->{matching}) && !ref($v->{matching});
            $message = $c->i18n->p('phenotype_upload.verify_error.related_variable', '%{original} could be %{matching}', $v);
            $wrapper = 'pair';
        }
        elsif ($code eq 'image_zip_unreadable') {
            $message = $c->i18n->p('phenotype_upload.verify_error.image_zip_unreadable', 'Image zipfile could not be read. Is it .zip format?');
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'bad_timestamp') {
            return unless defined($v->{plot}) && !ref($v->{plot});
            return unless defined($v->{trait}) && !ref($v->{trait});
            $message = $c->i18n->p('phenotype_upload.verify_error.bad_timestamp', 'Bad timestamp for value for Plot Name: %{plot}. Trait Name: %{trait}. Should be YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'numeric_required') {
            return unless defined($v->{plot}) && !ref($v->{plot});
            return unless defined($v->{trait}) && !ref($v->{trait});
            return unless defined($v->{value}) && !ref($v->{value});
            $message = $c->i18n->p('phenotype_upload.verify_error.numeric_required', 'This trait value should be numeric. Plot Name: %{plot}. Trait Name: %{trait}. Value: %{value}', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'minimum') {
            return unless defined($v->{trait}) && !ref($v->{trait});
            return unless defined($v->{value}) && !ref($v->{value});
            return unless defined($v->{minimum}) && !ref($v->{minimum});
            $message = $c->i18n->p('phenotype_upload.verify_error.minimum', 'For trait \'%{trait}\' the trait value %{value} should not be smaller than the defined trait_minimum, %{minimum}.', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'maximum') {
            return unless defined($v->{trait}) && !ref($v->{trait});
            return unless defined($v->{value}) && !ref($v->{value});
            return unless defined($v->{maximum}) && !ref($v->{maximum});
            $message = $c->i18n->p('phenotype_upload.verify_error.maximum', 'For the trait \'%{trait}\' the trait value %{value} should not be larger than the defined trait_maximum, %{maximum}.', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'image_missing') {
            return unless defined($v->{plot}) && !ref($v->{plot});
            return unless defined($v->{image}) && !ref($v->{image});
            $message = $c->i18n->p('phenotype_upload.verify_error.image_missing', 'For Plot Name: %{plot} there should be a corresponding image named in the zipfile called %{image}.', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'category') {
            return unless defined($v->{valid_values}) && !ref($v->{valid_values});
            return unless defined($v->{plot}) && !ref($v->{plot});
            return unless defined($v->{trait}) && !ref($v->{trait});
            return unless defined($v->{value}) && !ref($v->{value});
            $message = $c->i18n->p('phenotype_upload.verify_error.category', 'This trait value should be one of %{valid_values}: %{valid_values}. Plot Name: %{plot}. Trait Name: %{trait}. Value: %{value}', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'timestamp_required') {
            return unless defined($v->{trait}) && !ref($v->{trait});
            $message = $c->i18n->p('phenotype_upload.verify_error.timestamp_required', 'For trait %{trait} that is defined as a \'multiple\' or \'time_series\' repeat type trait, a timestamp is required.', $v);
            $wrapper = 'newline';
        }
        elsif ($code eq 'metadata_type_missing') {
            $message = $c->i18n->p('phenotype_upload.verify_error.metadata_type_missing', 'No file type provided for archived file.');
            $wrapper = 'plain';
        }
        elsif ($code eq 'metadata_date_missing') {
            $message = $c->i18n->p('phenotype_upload.verify_error.metadata_date_missing', 'No date provided in file upload metadata.');
            $wrapper = 'plain';
        }
        else { return; }
        my $safe = encode_entities($message, q{&<>"'});
        push @rendered, $wrapper eq 'small_hr' ? '<small>' . $safe . '</small><hr>'
            : $wrapper eq 'heading' ? '<strong>' . $safe . '</strong><br>'
            : $wrapper eq 'explanation' || $wrapper eq 'pair' ? '<small>' . $safe . '</small><br>'
            : $wrapper eq 'newline' ? $safe . "\n" : $safe;
    }
    return join('', @rendered);
}

# Translate only typed complete Verify records, never parse legacy HTML.
# Unknown/incomplete records fall back atomically to the original warning.
sub _localized_verification_warnings {
    my ($c, $records) = @_;
    return unless ref($records) eq 'ARRAY' && @$records;
    my @rendered;
    for my $record (@$records) {
        return unless ref($record) eq 'HASH' && defined($record->{code})
            && !ref($record->{code}) && ref($record->{variables}) eq 'HASH';
        my $code = $record->{code};
        my $v = { %{$record->{variables}} };
        my $legacy_blank = $record->{legacy_blank};
        my ($message, $wrapper);
        if ($code eq 'conflict' || $code eq 'conflict_at_time') {
            return unless defined($legacy_blank) && !ref($legacy_blank)
                && ($legacy_blank eq '0' || $legacy_blank eq '1');
            for my $key (qw(plot trait previous)) {
                return unless defined($v->{$key}) && !ref($v->{$key});
            }
            return if !$legacy_blank && (!defined($v->{incoming}) || ref($v->{incoming}));
            return if $code eq 'conflict_at_time' && (!defined($v->{timestamp}) || ref($v->{timestamp}));
            if ($code eq 'conflict' && !$legacy_blank) {
                $message = $c->i18n->p('phenotype_upload.warning.conflict_value', '%{plot} already has a different value stored in the database (%{previous}) than in your file (%{incoming}) for the trait %{trait}.', $v);
            }
            elsif ($code eq 'conflict' && $legacy_blank) {
                $message = $c->i18n->p('phenotype_upload.warning.conflict_blank', '%{plot} already has a different value stored in the database (%{previous}) than in your file (blank) for the trait %{trait}.', $v);
            }
            elsif ($code eq 'conflict_at_time' && !$legacy_blank) {
                $message = $c->i18n->p('phenotype_upload.warning.conflict_value_at_time', '%{plot} already has a different value stored in the database (%{previous}) than in your file (%{incoming}) for the trait %{trait} on %{timestamp}.', $v);
            }
            elsif ($code eq 'conflict_at_time' && $legacy_blank) {
                $message = $c->i18n->p('phenotype_upload.warning.conflict_blank_at_time', '%{plot} already has a different value stored in the database (%{previous}) than in your file (blank) for the trait %{trait} on %{timestamp}.', $v);
            }
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'multiple_single') {
            return unless defined($v->{trait}) && !ref($v->{trait});
            $message = $c->i18n->p('phenotype_upload.warning.multiple_single', 'Multiple values present in file for single repeat_type term %{trait}', $v);
            $wrapper = 'newline';
        }
        elsif ($code eq 'duplicate_file') {
            return unless defined($v->{plot}) && !ref($v->{plot});
            return unless defined($v->{trait}) && !ref($v->{trait});
            $message = $c->i18n->p('phenotype_upload.warning.duplicate_file', '%{plot} has a duplicate value for trait %{trait} in your file', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'operator_missing') {
            $message = $c->i18n->p('phenotype_upload.warning.operator_missing', 'No operator provided in file upload metadata.');
            $wrapper = 'plain';
        }
        elsif ($code eq 'image_plot_missing') {
            return unless defined($v->{image}) && !ref($v->{image});
            $message = $c->i18n->p('phenotype_upload.warning.image_plot_missing', 'Image %{image} in images zip file does not reference a plot or plant_name (e.g. the image filename does not have a plot or plant name in it)!', $v);
            $wrapper = 'small_hr';
        }
        elsif ($code eq 'same_values') {
            return unless defined($v->{count}) && !ref($v->{count});
            return unless $v->{count} =~ /\A[0-9]+\z/;
            $message = $c->i18n->np('phenotype_upload.warning.same_values', 'There is %{count} value in your file that is the same as a value already stored in the database.', 'There are %{count} values in your file that are the same as values already stored in the database.', $v->{count}, $v);
            $wrapper = 'plain';
        }
        else { return; }
        my $safe = encode_entities($message, q{&<>"'});
        push @rendered, $wrapper eq 'small_hr' ? '<small>' . $safe . '</small><hr>'
            : $wrapper eq 'newline' ? $safe . "\n" : $safe;
    }
    return join('', @rendered);
}

# Only the request presentation layer knows the negotiated language or HTML.
# Counts and filenames come from the completed native Store call, never from
# parsing its legacy English success HTML.
sub _localized_upload_summary {
    my ($c, $summary) = @_;
    my @lines = (
        encode_entities($c->i18n->p('phenotype_upload.server.processed', 'All values in your file have been successfully processed!'), q{&<>"'}),
        '',
        encode_entities($c->i18n->np('phenotype_upload.server.stored_count', '%{count} new value stored', '%{count} new values stored', $summary->{new_count}, { count => $summary->{new_count} }), q{&<>"'}),
        encode_entities($c->i18n->np('phenotype_upload.server.skipped_count', '%{count} previously stored value skipped', '%{count} previously stored values skipped', $summary->{skip_count}, { count => $summary->{skip_count} }), q{&<>"'}),
        encode_entities($c->i18n->np('phenotype_upload.server.overwritten_count', '%{count} previously stored value overwritten', '%{count} previously stored values overwritten', $summary->{overwrite_count}, { count => $summary->{overwrite_count} }), q{&<>"'}),
        encode_entities($c->i18n->np('phenotype_upload.server.removed_count', '%{count} previously stored value removed', '%{count} previously stored values removed', $summary->{remove_count}, { count => $summary->{remove_count} }), q{&<>"'}),
    );
    my $html = join('<br>', @lines) . '<br><br>';
    if (@{$summary->{obsolete_filenames}}) {
        $html .= encode_entities($c->i18n->p('phenotype_upload.server.obsolete_files', 'Previously uploaded files made obsolete by this upload: %{filenames}', { filenames => join(' ', @{$summary->{obsolete_filenames}}) }), q{&<>"'});
    }
    return $html;
}

# Typed diagnostics are optional metadata from the FieldBook parser. Legacy
# English errors remain available to every existing library caller. Translate
# only explicit owned codes here; opaque external/plugin errors keep their path.
sub _localized_fieldbook_error {
    my ($c, $result) = @_;
    my $detail = $result->{error_detail};
    return $result->{error} unless ref($detail) eq 'HASH'
        && defined($detail->{code}) && !ref($detail->{code})
        && ref($detail->{variables}) eq 'HASH';
    my $code = $detail->{code};
    my $variables = $detail->{variables};
    my $message;
    if ($code eq 'unreadable') {
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.unreadable', 'Could not read file.');
    }
    elsif ($code eq 'too_short') {
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.too_short', 'File has less than 2 lines.');
    }
    elsif ($code eq 'no_header') {
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.no_header', 'File has no header row.');
    }
    elsif ($code eq 'missing_trait_value') {
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.missing_trait_value', 'trait or value column not found. Make sure to use the database Fieldbook format.');
    }
    elsif ($code eq 'undefined_fields') {
        return $result->{error} unless defined($variables->{line}) && !ref($variables->{line});
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.undefined_fields', 'Error parsing line %{line}: unit, trait, or value is undefined.', { line => $variables->{line} });
    }
    elsif ($code eq 'timestamp_format') {
        return $result->{error} unless defined($variables->{line}) && !ref($variables->{line});
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.timestamp_format', 'Error parsing line %{line}: timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000', { line => $variables->{line} });
    }
    elsif ($code eq 'missing_stock') {
        return $result->{error} unless defined($variables->{stock_id}) && !ref($variables->{stock_id});
        $message = $c->i18n->p('phenotype_upload.fieldbook_error.missing_stock', 'Error: stock id %{stock_id} does not exist in the database.', { stock_id => $variables->{stock_id} });
    }
    else {
        return $result->{error};
    }
    return encode_entities($message, q{&<>"'});
}

# Optional owned DataCollector diagnostics mirror the FieldBook request boundary.
# Legacy strings and opaque vendor parser errors retain their existing fallback.
sub _localized_datacollector_error {
    my ($c, $result) = @_;
    my $detail = $result->{error_detail};
    return $result->{error} unless ref($detail) eq 'HASH'
        && keys(%$detail) == 2
        && defined($detail->{code}) && !ref($detail->{code})
        && ref($detail->{variables}) eq 'HASH';
    my $code = $detail->{code};
    my $variables = $detail->{variables};
    my $message;
    if ($code eq 'missing_tab') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{number})
            && !ref($variables->{number})
            && $variables->{number} eq '7';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_tab', 'No %{number}th tab found in your Excel file.', { number => 7 });
    }
    elsif ($code eq 'missing_header') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{column})
            && !ref($variables->{column})
            && $variables->{column} eq 'plot_name';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_header', 'Spreadsheet is missing %{column} and atleast one trait in header.', { column => 'plot_name' });
    }
    elsif ($code eq 'missing_plot_name') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{column})
            && !ref($variables->{column})
            && $variables->{column} eq 'plot_name';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_plot_name', 'No %{column} in header.', { column => 'plot_name' });
    }
    elsif ($code eq 'missing_stock_name') {
        return $result->{error} unless keys(%$variables) == 3
            && defined($variables->{accession})
            && !ref($variables->{accession})
            && $variables->{accession} eq 'accession_name'
            && defined($variables->{family})
            && !ref($variables->{family})
            && $variables->{family} eq 'family_name'
            && defined($variables->{cross})
            && !ref($variables->{cross})
            && $variables->{cross} eq 'cross_unique_id';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_stock_name', 'No %{accession} or %{family} or %{cross} in header.', { accession => 'accession_name', family => 'family_name', cross => 'cross_unique_id' });
    }
    elsif ($code eq 'missing_plot_number') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{column})
            && !ref($variables->{column})
            && $variables->{column} eq 'plot_number';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_plot_number', 'No %{column} in header.', { column => 'plot_number' });
    }
    elsif ($code eq 'missing_block_number') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{column})
            && !ref($variables->{column})
            && $variables->{column} eq 'block_number';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_block_number', 'No %{column} in header.', { column => 'block_number' });
    }
    elsif ($code eq 'missing_control') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{column})
            && !ref($variables->{column})
            && $variables->{column} eq 'is_a_control';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_control', 'No %{column} in header.', { column => 'is_a_control' });
    }
    elsif ($code eq 'missing_rep_number') {
        return $result->{error} unless keys(%$variables) == 1
            && defined($variables->{column})
            && !ref($variables->{column})
            && $variables->{column} eq 'rep_number';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.missing_rep_number', 'No %{column} in header.', { column => 'rep_number' });
    }
    elsif ($code eq 'timestamp_format') {
        return $result->{error} unless keys(%$variables) == 2
            && defined($variables->{negative})
            && !ref($variables->{negative})
            && $variables->{negative} eq 'YYYY-MM-DD HH:MM:SS-0000'
            && defined($variables->{positive})
            && !ref($variables->{positive})
            && $variables->{positive} eq 'YYYY-MM-DD HH:MM:SS+0000';
        $message = $c->i18n->p('phenotype_upload.datacollector_error.timestamp_format', 'Timestamp needs to be of form %{negative} or %{positive}', { negative => 'YYYY-MM-DD HH:MM:SS-0000', positive => 'YYYY-MM-DD HH:MM:SS+0000' });
    }
    elsif ($code eq 'value_timestamp_missing') {
        return $result->{error} unless keys(%$variables) == 0;
        $message = $c->i18n->p('phenotype_upload.datacollector_error.value_timestamp_missing', 'Value or timestamp missing.');
    }
    else {
        return $result->{error};
    }
    return encode_entities($message, q{&<>"'});
}

sub _prep_upload {
    my ($c, $file_type, $is_treatment, $schema) = @_;
	my @success_status;
	my @error_status;

	my $user = $c->user();

	if (!$user) {# only checks for login, ask whether this needs to be changed...
		push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.login_required', 'You do not have permission to upload data to this trial!'), q{&<>"'});
		return (\@success_status, \@error_status);
	}

    my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;
    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $timestamp_included;
    my $upload;
    my $subdirectory;
    my $validate_type;
    my $metadata_file_type;
    my $data_level;
    my $image_zip;
    if ($file_type eq "spreadsheet") {
        my $spreadsheet_format;
        if ($is_treatment eq "treatment") {
            $spreadsheet_format = $c->req->param("upload_spreadsheet_treatment_file_format");
            $timestamp_included = $c->req->param('upload_spreadsheet_treatment_timestamp_checkbox');
            $data_level = $c->req->param('upload_spreadsheet_treatment_data_level') || 'plots';
            $upload = $c->req->upload('upload_spreadsheet_treatment_file_input');
            $image_zip = $c->req->upload('upload_spreadsheet_treatment_associated_images_file_input');
        } else {
            $spreadsheet_format = $c->req->param("upload_spreadsheet_phenotype_file_format"); #simple or detailed or nirs or scio or associated_images
            $timestamp_included = $c->req->param('upload_spreadsheet_phenotype_timestamp_checkbox');
            $data_level = $c->req->param('upload_spreadsheet_phenotype_data_level') || 'plots';
            $upload = $c->req->upload('upload_spreadsheet_phenotype_file_input');
            $image_zip = $c->req->upload('upload_spreadsheet_phenotype_associated_images_file_input');
        }
        # print STDERR "File type is Spreadsheet and format is $spreadsheet_format\n";
        $metadata_file_type = "spreadsheet phenotype file";

        if ($spreadsheet_format eq 'detailed'){
            $validate_type = "phenotype spreadsheet";
        } elsif ($spreadsheet_format eq 'simple'){
            $validate_type = "phenotype spreadsheet simple generic";
        } elsif ($spreadsheet_format eq 'associated_images'){
            $validate_type = "phenotype spreadsheet associated_images";
        } else {
            die "Spreadsheet format not supported! Only simple, detailed, nirs, scio, or associated_images\n";
        }
        $subdirectory = "spreadsheet_phenotype_upload";
    }
    elsif ($file_type eq "fieldbook") {
        # print STDERR "Fieldbook \n";
        $subdirectory = "tablet_phenotype_upload";
        $validate_type = "field book";
        $metadata_file_type = "tablet phenotype file";
        $timestamp_included = 1;
        $upload = $c->req->upload('upload_fieldbook_phenotype_file_input');
        $image_zip = $c->req->upload('upload_fieldbook_phenotype_images_zipfile');
        $data_level = $c->req->param('upload_fieldbook_phenotype_data_level') || 'plots';
    }
    elsif ($file_type eq "datacollector") {
        # print STDERR "Datacollector \n";
        $subdirectory = "data_collector_phenotype_upload";
        $validate_type = "datacollector spreadsheet";
        $metadata_file_type = "data collector phenotype file";
        $timestamp_included = $c->req->param('upload_datacollector_phenotype_timestamp_checkbox');
        $upload = $c->req->upload('upload_datacollector_phenotype_file_input');
    }

    my $user_type = $user->get_object->get_user_type();
    if ($user_type ne 'submitter' && $user_type ne 'curator') {
        push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.submitter_required', 'Must have submitter privileges to upload phenotypes! Please contact us!'), q{&<>"'});
        return (\@success_status, \@error_status);
    }

    my $overwrite_values = $c->req->param('phenotype_upload_overwrite_values');
    if ($overwrite_values) {
        #print STDERR $user_type."\n";
        if ($user_type ne 'curator') {
            push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.overwrite_curator', 'Must be a curator to overwrite values! Please contact us!'), q{&<>"'});
            return (\@success_status, \@error_status);
        }
    }
    my $remove_values = $overwrite_values && $c->req->param('phenotype_upload_remove_values');
    if ( $remove_values ) {
        if ($user_type ne 'curator') {
            push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.remove_curator', 'Must be a curator to remove values! Please contact us!'), q{&<>"'});
            return (\@success_status, \@error_status);
        }
    }

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.archive_failed', 'Could not save file %{filename} in archive.', { filename => $upload_original_name }), q{&<>"'});
        return (\@success_status, \@error_status);
    } else {
        push @success_status, encode_entities($c->i18n->p('phenotype_upload.server.archived', 'File %{filename} saved in archive.', { filename => $upload_original_name }), q{&<>"'});
    }
    unlink $upload_tempfile;
    #print STDERR "Archived Phenotype File: $archived_filename_with_path\n";

    my $archived_image_zipfile_with_path;
    if ($image_zip) {
        my $upload_original_name = $image_zip->filename();
        my $upload_tempfile = $image_zip->tempname;
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory."_images",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_type
        });
        $archived_image_zipfile_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_image_zipfile_with_path);
        if (!$archived_image_zipfile_with_path) {
            push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.images_archive_failed', 'Could not save images zipfile %{filename} in archive.', { filename => $upload_original_name }), q{&<>"'});
            return (\@success_status, \@error_status);
        } else {
            push @success_status, encode_entities($c->i18n->p('phenotype_upload.server.images_archived', 'Images Zip File %{filename} saved in archive.', { filename => $upload_original_name }), q{&<>"'});
        }
        unlink $upload_tempfile;
        #print STDERR "Archived Zipfile: $archived_image_zipfile_with_path\n";
    }

    ## Validate and parse uploaded file
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, undef);
    if (!$validate_file) {
        push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.invalid', 'Archived file not valid: %{filename}.', { filename => $upload_original_name }), q{&<>"'});
        return (\@success_status, \@error_status);
    }
    if ($validate_file == 1){
        push @success_status, encode_entities($c->i18n->p('phenotype_upload.server.valid', 'File valid: %{filename}.', { filename => $upload_original_name }), q{&<>"'});
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_type eq 'field book'
                ? _localized_fieldbook_error($c, $validate_file)
                : $validate_type eq 'datacollector spreadsheet'
                    ? _localized_datacollector_error($c, $validate_file)
                    : $validate_file->{'error'};
        }
        return (\@success_status, \@error_status);
    }

    ## Set metadata
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    my $operator = $user->get_object()->get_username();
    $phenotype_metadata{'operator'} = $operator;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, undef);
    if (!$parsed_file) {
        push @error_status, encode_entities($c->i18n->p('phenotype_upload.server.parse_failed', 'Error parsing file %{filename}.', { filename => $upload_original_name }), q{&<>"'});
        return (\@success_status, \@error_status);
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $validate_type eq 'field book'
                ? _localized_fieldbook_error($c, $parsed_file)
                : $validate_type eq 'datacollector spreadsheet'
                    ? _localized_datacollector_error($c, $parsed_file)
                    : $parsed_file->{'error'};
    }
    my %parsed_data;
    my @plots;
    my @traits;

    if (scalar(@error_status) == 0) { #TODO: check for treatment and propagate values to child stocks
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @traits = @{$parsed_file->{'variables'}};
            push @success_status, encode_entities($c->i18n->p('phenotype_upload.server.parsed', 'File data successfully parsed.'), q{&<>"'});
        }
        if ($is_treatment eq "treatment") {
            foreach my $plot (@plots) {
                my $plot_obj = CXGN::Stock->new({
                    schema => $schema,
                    uniquename => $plot
                });
                my $child_stocks = $plot_obj->get_child_stocks_flat_list();
                foreach my $child (@{$child_stocks}) {
                    next if ($child->{type} eq "accession");
                    push @plots, $child->{name};
                    foreach my $trait (@traits) {
                        $parsed_data{$child->{name}}->{$trait} = $parsed_data{$plot}->{$trait};
                    }
                }
            }
        }
    }

    return (\@success_status, \@error_status, \%parsed_data, \@plots, \@traits, \%phenotype_metadata, $timestamp_included, $overwrite_values, $remove_values, $archived_image_zipfile_with_path, $user_id, $validate_type);
}

sub update_plot_phenotype :  Path('/ajax/phenotype/plot_phenotype_upload') : ActionClass('REST') { }
sub update_plot_phenotype_POST : Args(0) {
  my $self = shift;
  my $c = shift;
  print STDERR Dumper $c->req->params();
  my $plot_name = $c->req->param("plot_name");
  my $trait_id = $c->req->param("trait");
  my $trait_value = $c->req->param("trait_value");
  my $trait_list_option = $c->req->param("trait_list_option");
  my $trial_id = $c->req->param("trial_id");
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $dbh = $c->dbc->dbh();
  my $schema = $c->dbic_schema("Bio::Chado::Schema");
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my (@plots, @traits, %data, $trait);
  my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type' )->cvterm_id();
  print "MY LIST OPTION:  $trait_list_option\n";
  my $plot = $schema->resultset("Stock::Stock")->find( { uniquename=>$plot_name });
  my $plot_type_id = $plot->type_id();

  if (!$c->user()) {
    print STDERR "User not logged in... not recording phenotype.\n";
    $c->stash->{rest} = {error => "You need to be logged in to record phenotype." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to record phenotype." };
    return;
  }

  my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
  my $program_ref = $program_object->get_breeding_programs_by_trial($trial_id);

  my $program_array = @$program_ref[0];
  my $breeding_program_name = @$program_array[1];
  my @user_roles = $c->user->roles();
  my %has_roles = ();
  map { $has_roles{$_} = 1; } @user_roles;

  if (! ( (exists($has_roles{$breeding_program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
    $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $breeding_program_name to record phenotype." };
    return;
  }

  if ($plot_type_id == $accession_cvterm_id) {
    print "You are using accessions\n";
    $c->stash->{rest} = {error => "Used only for Plot Phenotyping."};
    return;
  }

  if (!$trait_list_option){
      $trait = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');
  }
  else {
      $trait = $trait_list_option;
  }
  push @plots, $plot_name;
  push @traits, $trait;

  $data{$plot_name}->{$trait} = [$trait_value,$timestamp];

  my %phenotype_metadata;
  $phenotype_metadata{'archived_file'} = 'none';
  $phenotype_metadata{'archived_file_type'}="direct phenotyping";
  $phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  $phenotype_metadata{'date'}="$timestamp";
  my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;

  my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
  my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

  my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
      basepath=>$c->config->{basepath},
      dbhost=>$c->config->{dbhost},
      dbname=>$c->config->{dbname},
      dbuser=>$c->config->{dbuser},
      dbpass=>$c->config->{dbpass},
      temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
      bcs_schema=>$schema,
      metadata_schema=>$metadata_schema,
      phenome_schema=>$phenome_schema,
      user_id=>$user_id,
      stock_list=>\@plots,
      trait_list=>\@traits,
      values_hash=>\%data,
      has_timestamps=> 1,
      overwrite_values=> 1,
      metadata_hash=>\%phenotype_metadata,
      composable_validation_check_name=>$c->config->{composable_validation_check_name},
      allow_repeat_measures=>$c->config->{allow_repeat_measures}
  );

  my ($verified_warning, $verified_error) = $store_phenotypes->verify();
  if ($verified_error){
    my $localized = _localized_verification_errors($c, $store_phenotypes->verification_errors());
    $c->stash->{rest} = {error => defined($localized) ? $localized : $verified_error};
    $c->detach;
  }

  my ($store_error, $store_success) = $store_phenotypes->store();
  if ($store_error) {
      $c->stash->{rest} = {error => $store_error};
      $c->detach;
  }

  $c->stash->{rest} = {success => 1};
}

sub retrieve_plot_phenotype :  Path('/ajax/phenotype/plot_phenotype_retrieve') : ActionClass('REST') { }
sub retrieve_plot_phenotype_POST : Args(0) {
  my $self = shift;
  my $c = shift;
  my $dbh = $c->dbc->dbh();
  my $schema = $c->dbic_schema("Bio::Chado::Schema");
  my $plot_name = $c->req->param("plot_name");
  my $trait_id = $c->req->param("trait");
  my $trait_list_option = $c->req->param("trait_list_option");
  my $trait_value;
  my $stock = $schema->resultset("Stock::Stock")->find( { uniquename=>$plot_name });
  my $stock_id = $stock->stock_id();

  if ($trait_list_option){
      my $h = $dbh->prepare("SELECT cvterm.cvterm_id AS trait_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id WHERE db.db_id = (( SELECT dbxref_1.db_id FROM stock JOIN nd_experiment_stock USING (stock_id) JOIN nd_experiment_phenotype USING (nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm cvterm_1 ON phenotype.cvalue_id = cvterm_1.cvterm_id JOIN dbxref dbxref_1 ON cvterm_1.dbxref_id = dbxref_1.dbxref_id LIMIT 1)) AND (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text =? GROUP BY cvterm.cvterm_id, ((((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text);");
      $h->execute($trait_id);
      while (my ($id, $trait_name) = $h->fetchrow_array()) {
        $trait_id = $id;
      }
  }

    if ($trait_id) {
        my $q = "SELECT phenotype.value FROM stock
            JOIN nd_experiment_stock USING(stock_id)
            JOIN nd_experiment_phenotype USING(nd_experiment_id)
            JOIN phenotype USING(phenotype_id)
            WHERE cvalue_id =? and stock_id=?";

        my $h = $dbh->prepare ($q);
        $h->execute($trait_id,$stock_id);

        while (my ($plot_value) = $h->fetchrow_array()) {
            $trait_value = $plot_value;
        }
    }

    $c->stash->{rest} = {trait_value => $trait_value};

}

sub view_all_uploads :Path('/ajax/phenotype/view_uploads') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file_list = CXGN::Project->get_all_phenotype_metadata($c->dbic_schema("Bio::Chado::Schema"), 100);
    $c->stash->{rest} = $file_list;
}

sub update_single_observation :Path('/ajax/phenotype/edit/') Args(1) {
    my $self = shift;
    my $c = shift;
    my $observationID = shift;

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to record a phenotype." };
        return;
    }

    my $user = $c->user();
    my $sp_person_id = $user->get_object()->get_sp_person_id();

    my $user_type = $user->get_object->get_user_type();
    my $username = $user->get_username();

    my $new_value = $c->req->param('new_observation_value');
    my $new_timestamp = $c->req->param('new_observation_timestamp');
    my $trial_id = $c->req->param('trial_id');

    if (!$trial_id) {
        $c->stash->{rest} = {error => "This observation can only be edited in relation to a trial."};
        return;
    }

    if (!$observationID) {
        $c->stash->{rest} = {error => "You must supply an observation ID!"};
        return;
    }

    if (!defined($new_value) || $new_value eq '') {
        $c->stash->{rest} = {error => "This function can edit existing phenotype entries, but not delete them. Please enter a value."};
        return;
    }

    #check for user permissions on this trial
    my $this_trial = CXGN::Trial->new({
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        trial_id => $trial_id
    });

    my $owners = $this_trial->_get_trial_owners();

    if ( ! $user->check_roles("curator") && !defined($owners->{$sp_person_id}) ) {
        $c->stash->{rest} = {error => "You do not have permission to make edits on this trial - only curators and trial owners can modify raw phenotype values."};
        return;
    }

    if ($new_timestamp) {
        my $epoch = str2time($new_timestamp);
        my $dt = DateTime->from_epoch(epoch => $epoch);
        $new_timestamp = $dt->strftime('%Y-%m-%d %H:%M:%S%z');
    }

    my $phenotype = CXGN::Phenotype->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        overwrite => 1,
        phenotype_id => $observationID,
    });

    my $pheno_uniquename = $phenotype->uniquename();
    $pheno_uniquename =~ s/observation: [\w]*/observation: $new_value/;
    if ($new_timestamp) {
        $pheno_uniquename =~ s/date: [^,]*,/date: $new_timestamp,/;
    }
    if (!$phenotype->operator()) {
        $pheno_uniquename =~ s/operator: [\w]*,/operator: $username,/;
    }

    try {
        $phenotype->value($new_value);
        if ($new_timestamp) {
            $phenotype->collect_date($new_timestamp);
        }
        if (!$phenotype->operator()) {
            $phenotype->operator($username);
        }
        $phenotype->uniquename($pheno_uniquename);
        $phenotype->store();
    } catch {
        $c->stash->{rest} = {error => "An error occurred trying to store phenotype: $_"};
        return;
    };

    $c->stash->{rest} = {success => 1};
    return;

}

######### 
1;
#########
