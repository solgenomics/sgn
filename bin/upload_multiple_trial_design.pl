#!/usr/bin/perl

=head1

upload_multiple_trial_design.pl

=head1 SYNOPSIS

upload_multiple_trial_design.pl -H [dbhost] -D [dbname] -P [dbpass] -w [basepath] -U [dbuser] -i infile -un [username] -e [email address]

=head1 COMMAND-LINE OPTIONS
ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username Ex: "postgres"
 -P database userpass Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -i path to infile (required)
 -un username of uploader (required)
 -e email address of the user
if loading trial data from metadata file, phenotypes + layout from infile 

=head2 DESCRIPTION

perl bin/upload_multiple_trial_design.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn/ -un janedoe -i ~/Desktop/test_multi.xlsx -e 'sk2783@cornell.edu' -iw

This script will parse and validate the input file. If there are any warnings or errors during validation it will send a error message to the provided email.  It will print any errors and warnings to the console.
If there are no errors or warnings (or warnings are ignored) during validation it will then store the data.
The input file should be any file supported by the CXGN::File::Parse class.

=head1 AUTHOR

Srikanth (sk2783@cornell.edu)

=cut

use strict;
use Getopt::Long;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Try::Tiny;
use DateTime;
use Pod::Usage;
use CXGN::Trial; # add project metadata
use CXGN::Trial::ParseUpload;
use CXGN::Trial::TrialCreate;
use CXGN::Contact;
use CXGN::TrialStatus;
use File::Temp qw/tempfile/;
use CXGN::Phenotypes::StorePhenotypes;

my ( $help, $dbhost, $dbname, $basepath, $dbuser, $dbpass, $infile, $username, $email_address, $ignore_warnings);
GetOptions(
    'dbhost|H=s'           => \$dbhost,
    'dbname|D=s'           => \$dbname,
    'dbuser|U=s'           => \$dbuser,
    'dbpass|P=s'           => \$dbpass,
    'basepath|w=s'         => \$basepath,
    'i=s'                  => \$infile,
    'user|un=s'            => \$username,
    'email|e=s'            => \$email_address,
    'ignore_warnings|iw!'  => \$ignore_warnings,
    'help'                 => \$help,
);
pod2usage(1) if $help;
if (!$infile || !$username || !$basepath || !$dbname || !$dbhost ) { 
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}

# Lists of encountered errors and warnings
my @errors;
my @warnings;

# Connect to databases
my $dbh;
if ($dbpass && $dbuser) {
    $dbh = DBI->connect(
        "dbi:Pg:database=$dbname;host=$dbhost",
        $dbuser,
        $dbpass,
        {AutoCommit => 1, RaiseError => 1}
    );
}
else {
    $dbh = CXGN::DB::InsertDBH->new({
        dbhost => $dbhost,
        dbname => $dbname,
        dbargs => {AutoCommit => 1, RaiseError => 1}
    });
}
my $chado_schema = Bio::Chado::Schema->connect(sub { $dbh },  { on_connect_do => ['SET search_path TO  public, sgn, metadata, phenome;'] });
print STDOUT "Database connection ok!\n";

my $parsed_data;
my $validation_coderef = sub {
    # Parse uploaded file with appropriate plugin
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $infile);
    $parser->load_plugin('MultipleTrialDesignGeneric');
    $parsed_data = $parser->parse();

    # Parser has errors, print error messages and quit
    if ($parser->has_parse_errors()) {
        my $errors = $parser->get_parse_errors();
        foreach (@{$errors->{'error_messages'}}) {
            push @errors, $_;
        }
        finish();
    }

    # Parser has warnings, print warning messages and quit unless we're ignoring warnings
    if ($parser->has_parse_warnings()) {
        unless ($ignore_warnings) {
            my $warnings = $parser->get_parse_warnings();
            foreach (@{$warnings->{'warning_messages'}}) {
                push @warnings, $_;
            }
            finish();
        }
    }
};

try {
    $chado_schema->txn_do($validation_coderef);
} catch {
    push @errors, $_;
};

# Check for parsed data
finish("There is no parsed data from the input file!") if !$parsed_data;

# Get User ID
my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
finish("User not found in database for username $username!") if !$sp_person_id;

# Create and Save Trials
my %all_designs = %{$parsed_data};
my %saved_trials;
my $coderef = sub {

    my $phenotime = DateTime->now();
    my $phenotimestamp = $phenotime->ymd()."_".$phenotime->hms();
    my $phenotype_metadata = {
        archived_file => $infile,
        archived_file_type => 'multi trial upload',
        operator => $username,
        date => $phenotimestamp
    };
    my $temp_basedir_key = `cat $basepath/sgn.conf $basepath/sgn_local.conf | grep tempfiles_subdir`;
    my (undef, $temp_basedir) = split(/\s+/, $temp_basedir_key);
    $temp_basedir = "$basepath/$temp_basedir";
    if (! -d "$temp_basedir/delete_nd_experiment_ids/"){
        mkdir("$temp_basedir/delete_nd_experiment_ids/");
    }
    my (undef, $tempfile) = tempfile("$temp_basedir/delete_nd_experiment_ids/fileXXXX"); #tempfile

    my @phenostore_stocks;
    my %phenostore_traits;
    my $phenostore_values = {};

    my $metadata_schema = CXGN::Metadata::Schema->connect( 
        sub { $dbh }, 
        { on_connect_do => ['SET search_path TO public,metadata;'] }
    );
    my $phenome_schema = CXGN::Phenome::Schema->connect( 
        sub { $dbh },
        { on_connect_do => ['SET search_path TO public,phenome;'] }
    );

    for my $trial_name ( keys %all_designs ) {
        my $trial_design = $all_designs{$trial_name};
        if ($trial_design->{'design_details'}{'treatments'}) { #construct treatment hash
            foreach my $plot (keys(%{$trial_design->{'design_details'}{'treatments'}})) {
                foreach my $treatment (keys(%{$trial_design->{'design_details'}{'treatments'}->{$plot}})) {
                    push @{$trial_design->{'design_details'}{'treatments'}->{$plot}->{$treatment}}, $phenotimestamp;
                    push @{$trial_design->{'design_details'}{'treatments'}->{$plot}->{$treatment}}, $username;
                    push @{$trial_design->{'design_details'}{'treatments'}->{$plot}->{$treatment}}, '';
                    push @{$trial_design->{'design_details'}{'treatments'}->{$plot}->{$treatment}}, '';
                    $phenostore_traits{$treatment} = 1;
                    $phenostore_values->{$plot}->{$treatment} = $trial_design->{'design_details'}{'treatments'}->{$plot}->{$treatment};
                }
                push @phenostore_stocks, $plot;
            }
        }
        my %trial_info_hash = (
            chado_schema => $chado_schema,
            dbh => $dbh,
            owner_id => $sp_person_id,
            trial_year => $trial_design->{'year'},
            trial_description => $trial_design->{'description'},
            trial_location => $trial_design->{'location'},
            trial_name => $trial_name,
            design_type => $trial_design->{'design_type'},
            trial_stock_type => $trial_design->{'trial_stock_type'},
            design => $trial_design->{'design_details'},
            program => $trial_design->{'breeding_program'},
            upload_trial_file => $infile,
            operator => $username,
            owner_id => $sp_person_id
        );
        my $entry_numbers = $trial_design->{'entry_numbers'};

        if ($trial_design->{'trial_type'}){
            $trial_info_hash{trial_type} = $trial_design->{'trial_type'};
        }
        if ($trial_design->{'plot_width'}){
            $trial_info_hash{plot_width} = $trial_design->{'plot_width'};
        }
        if ($trial_design->{'plot_length'}){
            $trial_info_hash{plot_length} = $trial_design->{'plot_length'};
        }
        if ($trial_design->{'field_size'}){
            $trial_info_hash{field_size} = $trial_design->{'field_size'};
        }
        if ($trial_design->{'planting_date'}){
            $trial_info_hash{planting_date} = $trial_design->{'planting_date'};
        }
        if ($trial_design->{'harvest_date'}){
            $trial_info_hash{harvest_date} = $trial_design->{'harvest_date'};
        }
        if ($trial_design->{'transplanting_date'}){
            $trial_info_hash{transplanting_date} = $trial_design->{'transplanting_date'};
        }
        my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);
        my $current_save = $trial_create->save_trial();

        if ($current_save->{error}){
            $chado_schema->txn_rollback();
            finish($current_save->{'error'});
        } elsif ($current_save->{'trial_id'}) {
            my $trial_id = $current_save->{'trial_id'};
            my $time = DateTime->now();
            my $timestamp = $time->ymd();
            my $calendar_funcs = CXGN::Calendar->new({});
            my $formatted_date = $calendar_funcs->check_value_format($timestamp);
            my $upload_date = $calendar_funcs->display_start_date($formatted_date);
            $saved_trials{$trial_id} = $trial_name;

            my %trial_activity;
            $trial_activity{'Trial Uploaded'}{'user_id'} = $sp_person_id;
            $trial_activity{'Trial Uploaded'}{'activity_date'} = $upload_date;

            my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $chado_schema });
            $trial_activity_obj->trial_activities(\%trial_activity);
            $trial_activity_obj->parent_id($trial_id);
            my $activity_prop_id = $trial_activity_obj->store();
        }

        # save entry numbers, if provided
        if ( $entry_numbers && scalar(keys %$entry_numbers) > 0 && $current_save->{'trial_id'} ) {
            my %entry_numbers_prop;
            my @stock_names = keys %$entry_numbers;

            # Convert stock names from parsed trial template to stock ids for data storage
            my $stocks = $chado_schema->resultset('Stock::Stock')->search({ uniquename=>{-in=>\@stock_names} });
            while (my $s = $stocks->next()) {
                $entry_numbers_prop{$s->stock_id} = $entry_numbers->{$s->uniquename};
            }

            # Lookup synonyms of accession names
            my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'stock_synonym', 'stock_property')->cvterm_id();
            my $acc_synonym_rs = $chado_schema->resultset("Stock::Stock")->search({
                'me.is_obsolete' => { '!=' => 't' },
                'stockprops.value' => { -in => \@stock_names},
                'stockprops.type_id' => $synonym_cvterm_id
            },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
            while (my $r=$acc_synonym_rs->next) {
                if ( exists($entry_numbers->{$r->get_column('synonym')}) ) {
                    $entry_numbers_prop{$r->stock_id} = $entry_numbers->{$r->get_column('synonym')};
                }
            }

            # store entry numbers
            my $trial = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $current_save->{'trial_id'} });
            $trial->set_entry_numbers(\%entry_numbers_prop);
        }
    }

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath => $temp_basedir,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        temp_file_nd_experiment_id => $tempfile,
        bcs_schema => $chado_schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        user_id => $sp_person_id,
        stock_list => \@phenostore_stocks,
        trait_list => [keys(%phenostore_traits)],
        values_hash => $phenostore_values,
        metadata_hash => $phenotype_metadata
    });

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();

    if ($verified_warning) {
        push @warnings, $verified_warning;
    }
    if ($verified_error) {
        push @errors, $verified_error
    }

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

    if ($stored_phenotype_error) {
        push @errors, $verified_error
    }

};

try {
    $chado_schema->txn_do($coderef);
} catch {
    push @errors, $_;
};

finish();

sub finish {
    my $error = shift;
    push @errors, $error if $error;

    # Print errors and warnings to STDERR
    foreach (@errors) {
        print STDERR "ERROR: $_\n";
    }
    foreach (@warnings) {
        print STDERR "WARNING: $_\n";
    }

    # Send email message, if requested
    # Exit the script: 0 = success, 1 = errors, 2 = warnings
    if ( scalar(@errors) > 0 ) {
        if ( $email_address ) {
            my $email_subject = "Multiple Trial Designs upload failed";
            my $email_body    = "Dear $username,\n\nThere were one or more errors in uploading your trials:\n\n";
            foreach my $error (@errors) {
                $error =~ s/<[^>]*>//g;
                $email_body .= "$error\n";
            }
            $email_body .= "\nYou will need to fix the errors and upload the corrected file. Thank you\nHave a nice day\n\n";
            CXGN::Contact::send_email($email_subject, $email_body, $email_address);
        }
        exit(1);
    }
    if ( scalar(@warnings) > 0 ) {
        if ( $email_address ) {
            my $email_subject = "Multiple Trial Designs upload failed";
            my $email_body    = "Dear $username,\n\nThere were one or more warnings in uploading your trials and the option to ignore warnings was not enabled.  The warnings include:\n\n";
            foreach my $warning (@warnings) {
                $warning =~ s/<[^>]*>//g;
                $email_body .= "$warning\n";
            }
            $email_body .= "\nYou will need to either fix the warnings and upload the corrected file or upload the same file with the option to ignore warnings enabled. Thank you\nHave a nice day\n\n";
            CXGN::Contact::send_email($email_subject, $email_body, $email_address);
        }
        exit(2);
    }
    else {
        my $bs = CXGN::BreederSearch->new({ dbh=>$dbh, dbname=>$dbname });
        my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'all_but_genoview', 'concurrent', $basepath);

        if ( $email_address ) {
            my $email_subject = "Multiple Trial Designs upload successful";
            my $email_body    = "Dear $username,\n\nCongratulations, all the multiple trial designs have been successfully uploaded into the database\n\nThank you\nHave a nice day\n\n";
            CXGN::Contact::send_email($email_subject, $email_body, $email_address);
        }

        exit(0);
    }
}

1;