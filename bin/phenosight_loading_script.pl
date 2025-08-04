#!/usr/bin/perl

=head1

phenosight_loading_script.pl - a script to load phenosight experiments as trials

=head1 SYNOPSIS

phenosight_loading_script.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS

 -H host name
 -D database name
 -i infile
 -b breeding program for client-specific permissions

=head1 DESCRIPTION

Script for loading completed Phenosight experiments as Breedbase trials.

=head1 AUTHORS

=cut
use strict;
use warnings;
#use Getopt::Std;
use Getopt::Long;
use Try::Tiny;
use File::Basename;

use DateTime;
use Data::Dumper;
use CXGN::File::Parse;
use CXGN::BreedingProgram ; # the BP object
use CXGN::Metadata::Schema;
use CXGN::Metadata::Metadbdata;
use CXGN::Phenome::Schema;
use SGN::Model::Cvterm; # maybe need this for the projectprop.type_id breeding_program
use URI::FromHash 'uri';
use JSON;


use DateTime;
use Pod::Usage;
use CXGN::Trial; # add project metadata
use CXGN::Trial::TrialCreate;
use CXGN::TrialStatus;


my ( $help, $dbhost, $dbname, $basepath, $dbuser, $dbpass, $infile, $username, $ignore_warnings);
GetOptions(
    'dbhost|H=s'           => \$dbhost,
    'dbname|D=s'           => \$dbname,
    'dbuser|U=s'           => \$dbuser,
    'dbpass|P=s'           => \$dbpass,
    'basepath|w=s'         => \$basepath,
    'i=s'                  => \$infile,
    'user|un=s'            => \$username,
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
my @md_errors;
my @md_warnings;

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
my $metadata_schema = CXGN::Metadata::Schema->connect("dbi:Pg:database=$dbname;host=$dbhost", "postgres", $dbpass, {on_connect_do => "SET search_path TO 'metadata', 'public'", });
my $phenome_schema = CXGN::Phenome::Schema->connect("dbi:Pg:database=$dbname;host=$dbhost", "postgres", $dbpass, {on_connect_do => "SET search_path TO 'phenome', 'public'", });

print STDOUT "Database connection ok!\n";
# my $metadata_schema = CXGN::Metadata::Schema->connect(
#     "dbi:Pg:database=$dbname;host=$opt_H", # DSN Line
#     $opt_U,                    # Username
#     $opt_P           # Password
# );
# my $phenome_schema = CXGN::Phenome::Schema->connect(
#     "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
#     $opt_U,                    # Username
#     $opt_P           # Password
# );

# Lists of encountered errors and warnings
my @errors;

### Get list of all trials
my $program_id = 134;
#my $program = CXGN::BreedingProgram->new( { schema=> $chado_schema , program_id => $program_id } );

#my $trials = $program->get_trials();
#print STDERR "$trials\n";

#my @trials = qw(Exp_010103 Exp_010105 Exp_010104 Exp_010102 Exp_010111);
#### Following line prevents any from being uploaded:
#my @trials = qw(Exp_000089 Exp_010103 Exp_010105 Exp_010104 Exp_010102 Exp_010111);

#our ($opt_i);
#getopts('i');

###### Parse Phenosight Experiment Metadata file:
my $md_parser = CXGN::File::Parse->new(file => $infile, type => 'xlsx');
my $md_parsed = $md_parser->parse();
my $md_parsed_errors = $md_parsed->{errors};


# Parser has errors, print error messages and quit
if ( $md_parsed_errors && scalar(@$md_parsed_errors) > 0 ) {
    print STDERR Dumper(@$md_parsed_errors) . "\n";
    print STDERR "Failed to read metadata file." . "\n";
    foreach (@$md_parsed_errors) {
        push @errors, $_;
    }
    exit();
}

### AFP: the file parser does not do warning (the trial upload does - not used here)
# # Parser has warnings, print warning messages and quit unless we're ignoring warnings
# if ($md_parser->has_parse_warnings()) {
#     unless ($ignore_warnings) {
#         my $md_warnings = $md_parser->get_parse_warnings();
#         foreach (@{$md_warnings->{'warning_messages'}}) {
#             push @md_warnings, $_;
#         }
#         print STDERR Dumper(@md_warnings) . "\n";
#         exit();
#     }
# }
my $md_columns = $md_parsed->{columns};
my $md_data = $md_parsed->{data};
my $md_values = $md_parsed->{values};

#print STDERR "@$md_columns\n";
#print STDERR Dumper($md_data);
#print STDERR Dumper("$md_values\n");
#print STDERR Dumper($md_values);
#my %all_trials_runs = %md_data;
#my $ps_trial_names = $all_trials_runs{'Experiment ID'};
#print STDERR Dumper($ps_trial_names);
my @ps_exp_names;
foreach my $row (@$md_data) {
    my $ps_exp_name = $row->{'Experiment ID'};
    push(@ps_exp_names, $ps_exp_name);

}

#print STDERR "@ps_exp_names\n";
my $q = "SELECT project_id,name FROM project";
my $h = $dbh->prepare($q);
$h->execute();
my @trial_names;
while (my ($trial_id, $trial_name) = $h->fetchrow_array()) {
    # for my $phenosight_trial_name ( keys %all_designs ) {
    push(@trial_names, $trial_name)
    # }
    # if ($trial_name) {
    #     print STDERR "$name\n";
    # }
    # else {
    #     print STDERR "$name\n";
    # }


}

#print STDERR @trial_names;

# Get list of directories - this CR path will be obtained from sgn_local.conf
# Note: don't use basepath here; need to include parameter to point to the 'data dir'
my @CR_exp_dirs = glob("/home/production/CropReporter/Data/*"); 

#print "@CR_exp_dirs\n";

# Check each directory for the PS2 file:
my $curr_exp;
my @content_curr_exp;

my $PS2_path;
my $coderef = sub {
    for my $exp_dir (@CR_exp_dirs) {
        @content_curr_exp = glob($exp_dir . "/*");
        print STDERR "@content_curr_exp\n";
        my $exp_name = basename($exp_dir);
        print STDERR "$exp_name\n";
        # Check if PS2 file is present:
        my $PS2_present = 0;
        for my $curr_exp_content (@content_curr_exp) {
            $PS2_path = $exp_dir . "/PS2_Analysis_new.TXT";

            if ($curr_exp_content eq $PS2_path){
                $PS2_present = 1;
                my $trial_saved = 0;
                ## Check Exp_folder name to see if present as trial in DB
                # foreach (@trial_names) {
                #     if ($exp_name eq $_) {
                #         print STDERR "$exp_name matches $_, check next one;\n";
                #         $trial_saved = 1;
                #         last;
                #     } else {
                #         print STDERR "$exp_name does not match $_, move to the next;\n";
                #     }
                # }
                ### Move on to save the trial if not present:
                if ($trial_saved == 0) {
                    print STDERR "No trial match for $exp_name; proceed to parse and load\n";
                    my $parser = CXGN::File::Parse->new(file => $PS2_path, type => 'txt');
                    my $parsed = $parser->parse();
                    my $parsed_errors = $parsed->{errors};

                    # Parser has errors, print error messages and quit
                    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
#                        print STDERR Dumper(@$parsed_errors) . "\n";
#                        print STDERR "Failed to read metadata file." . "\n";
                        foreach (@$parsed_errors) {
                            push @errors, $_;
                        }
                        exit();
                    }
                    ### AFP: the file parser does not do warning (the trial upload does - not used here)
                    # # Parser has warnings, print warning messages and quit unless we're ignoring warnings
                    # if ($parser->has_parse_warnings()) {
                    #     unless ($ignore_warnings) {
                    #         my $warnings = $parser->get_parse_warnings();
                    #         foreach (@{$warnings->{'warning_messages'}}) {
                    #             push @warnings, $_;
                    #         }
                    #         print STDERR Dumper(@warnings) . "\n";
                    #         exit();
                    #     }
                    # }
                    my $columns = $parsed->{columns};
                    my $data = $parsed->{data};
                    my $values = $parsed->{values};
#                    print STDERR Dumper($columns) . "\n";
#                    print STDERR Dumper($data) . "\n"; # These are the rows w/data
#                    print STDERR Dumper($values) . "\n";
                    #my %values = %{$values};

                    # Question: who should be the owner/sp_person ID?
                    # Get User ID
                    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
                    finish("User not found in database for username $username!") if !$sp_person_id;

                    # Set up the trial design (hash of plot hashes)

                    my $plot_numbers = $values->{'PhenoTray.ID'};
                    my @plot_uniquenames;
                    foreach my $plot_number (@$plot_numbers) {
                        my $current_plot_name = _create_plot_name($exp_name, $plot_number);
                        push @plot_uniquenames, $current_plot_name;
                    }
#                    print STDERR "@$plot_ids are the plots;\n";
                    print STDERR "@plot_uniquenames are the plots;\n";

                    

                    #### Get the Metadata associated with this trial:
                    my @ps_exp_names;
                    my %phenosight_metadata_hash;
                    foreach my $row (@$md_data) {
                        my $ps_exp_name = $row->{'Experiment ID'};
                        print STDERR "$ps_exp_name is from the Excel file; $exp_name is from the folder name;\n";
                        if ($ps_exp_name eq $exp_name) {
                            my $ps_curr_date = $row->{'Date START (D/M/YR)'};
                            my $ps_year = substr($ps_curr_date, -4);
                            %phenosight_metadata_hash = (
                                ps_experiment_name => $ps_exp_name,
                                ps_owner => $row->{'Owner'},
                                ps_date_analyzed => $row->{'Data analyzed'},
                                ps_trial_year => $ps_year
                            );
                            print STDERR "$ps_year is the year;\n";
                            last;
                        }

                    }
                    #print STDERR "The phenosight metadata hash:\n";
                    #print STDERR Dumper(%phenosight_metadata_hash) . "\n";
                    # Need to save the trial:
                    # Some of this info needs to come from external all-experiment metadata file? Not all is in PS2_txt...
                    # First, need to create/extract the design details:
                    my %design_details;
                    for my $row (@$data) {
                        my $accession_name = "accessionPS1";
                        my $plot_number = $row->{'PhenoTray.ID'};
                        my $plot_name = _create_plot_name($exp_name, $plot_number);
                        my $block_number = 1;

                        my $key = $plot_name;
                        $design_details{$key}->{plot_name} = $plot_name;
                        $design_details{$key}->{stock_name} = $accession_name;
                        $design_details{$key}->{plot_number} = $plot_number;
                        $design_details{$key}->{block_number} = $block_number;
                    }
#                    print STDERR "The design details:\n";
#                    print STDERR Dumper(%design_details) . "\n";
                    my $design_details = \%design_details;

#                    if (%phenosight_metadata_hash) {
                    my %trial_info_hash = (
                        chado_schema => $chado_schema,
                        dbh => $dbh,
                        trial_year => $phenosight_metadata_hash{'ps_trial_year'},
                        trial_description => "Placeholder description",
                        trial_location => "Phenosight",
                        trial_name => $phenosight_metadata_hash{'ps_experiment_name'},
                        design_type => "greenhouse",
                        design => $design_details,
                        program => $phenosight_metadata_hash{'ps_owner'},
                        operator => $username,
                        owner_id => $sp_person_id
                    );
#                    print STDERR "The trial info hash:\n";
#                    print STDERR Dumper(%trial_info_hash) . "\n";
#                    }


                    #my $entry_numbers = $trial_design->{'entry_numbers'};

                    # # if ($trial_design->{'trial_type'}){
                    # #     $trial_info_hash{trial_type} = $trial_design->{'trial_type'};
                    # # }
                    # # if ($trial_design->{'plot_width'}){
                    # #     $trial_info_hash{plot_width} = $trial_design->{'plot_width'};
                    # # }
                    # # if ($trial_design->{'plot_length'}){
                    # #     $trial_info_hash{plot_length} = $trial_design->{'plot_length'};
                    # # }
                    # # if ($trial_design->{'field_size'}){
                    # #     $trial_info_hash{field_size} = $trial_design->{'field_size'};
                    # # }
                    # # if ($trial_design->{'planting_date'}){
                    # #     $trial_info_hash{planting_date} = $trial_design->{'planting_date'};
                    # # }
                    # # if ($trial_design->{'harvest_date'}){
                    # #     $trial_info_hash{harvest_date} = $trial_design->{'harvest_date'};
                    # # }
                    # # if ($trial_design->{'transplanting_date'}){
                    # #     $trial_info_hash{transplanting_date} = $trial_design->{'transplanting_date'};
                    # # }



#                    my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);
#                    my $current_save = $trial_create->save_trial();

                    my $bs = CXGN::BreederSearch->new({ dbh=>$dbh, dbname=>$dbname });
                    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'all_but_genoview', 'concurrent', $basepath);


                    # try {
                    #     $trial_create->save_trial();
                    # } catch {
                    #     print STDERR "ERROR SAVING TRIAL!\n";
                    # };
                    # if ($current_save->{error}){
                    #      $chado_schema->txn_rollback();
                    #      finish($current_save->{'error'});
                    # } elsif ($current_save->{'trial_id'}) {
                    #      my $trial_id = $current_save->{'trial_id'};
                    #     my $time = DateTime->now();
                    #     my $timestamp = $time->ymd();
                    #     my $calendar_funcs = CXGN::Calendar->new({});
                    #     my $formatted_date = $calendar_funcs->check_value_format($timestamp);
                    #     my $upload_date = $calendar_funcs->display_start_date($formatted_date);

                    #     my %trial_activity;
                    #     $trial_activity{'Trial Uploaded'}{'user_id'} = $sp_person_id;
                    #     $trial_activity{'Trial Uploaded'}{'activity_date'} = $upload_date;

                    #     my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $chado_schema });
                    #     $trial_activity_obj->trial_activities(\%trial_activity);
                    #     $trial_activity_obj->parent_id($trial_id);
                    #     my $activity_prop_id = $trial_activity_obj->store();
                    # }

                    #my %parsed_data = %{$parsed->{'data'}};
                    # my %values = %{$parsed->{'values'}};                   
                    # my @plots;

                    # foreach ($values{'File'}) {
                    #     print STDERR "ID: $_\n";
                    # } 

                    #### Create the image files as needed for upload: Image file names should consist of the observationUnitName, traitname, number, and timestamp
                    my $new_zip_file = $exp_dir . "/processed.imgs/imagefolder.zip";
                    system("zip $new_zip_file $exp_dir/processed.imgs/*.JPG");
                    print STDERR Dumper($new_zip_file) . "\n";

                    #print STDERR "The parsed contents:" . "\n";
                    #print STDERR Dumper($data) . "\n";

                    # N.B. from Magda, there should only be one phi.npq - the symbol version will not be present in future versions; also still need to add 'qI' trait - not here as not in obo/db yet
                    my @traits = ('qE','F0\'','phi.no','qL','NDVI','qN','npq(t)','NPQ','Fq\'/Fm\'','Fv/Fm','qP','AriIdx','phi.npq','ChlIdx');
                    my @full_traits = ('qE|PHS:0000008','F0\'|PHS:0000004','phi.no|PHS:0000009','qL|PHS:0000007','NDVI|PHS:0000015','qN|PHS:0000006','npq(t)|PHS:0000012','NPQ|PHS:0000003','Fq\'/Fm\'|PHS:0000002','Fv/Fm|PHS:0000001','qP|PHS:0000005','AriIdx|PHS:0000014','phi.npq|PHS:0000010','ChlIdx|PHS:0000013');
                    my %multiple_measures_hash;
                    for my $row (@$data) {
                        my $row_id = $row->{'PhenoTray.ID'};
                        my $plot_number = $row->{'PhenoTray.ID'};
                        my $plot_name = _create_plot_name($exp_name, $plot_number);
                        my $key = $plot_name;
                        foreach my $trait (@traits) {
                            my $current_value = $row->{$trait};
                            # Need YYYY-MM-DD HH:MM:SS-0000
                            my $current_year = substr($row->{'Date'}, 0, 4);
                            my $current_month = $row->{'month'};
                            my $current_day = $row->{'day'};
                            my $current_time = $row->{'Time'};
                            my $current_timestamp = $current_year . '-' . $current_month . '-' . $current_day . ' ' . $current_time . ':00-0000';
                            #print STDERR "The trait:" . "\n"; 
                            #print STDERR Dumper($trait) . "\n";                            
                            #print STDERR "The value:" . "\n"; 
                            #print STDERR Dumper($current_value) . "\n";
                            #print STDERR "The time:" . "\n"; 
                            #print STDERR Dumper($current_timestamp) . "\n";
                            # Matching full trait:
                            my $pattern = "^" .quotemeta( $trait );
                            my @current_trait_match = grep {/$pattern/} @full_traits;
                            my $current_trait = $current_trait_match[0];
#                            print STDERR "Matching trait:" . "\n";                            
#                            print STDERR Dumper($current_trait) . "\n";
#                            print STDERR "PS trait:" . "\n";
#                            print STDERR Dumper($trait) . "\n";
                            my $value_array = [$current_value, $current_timestamp];
                            push @{$multiple_measures_hash{$key}->{$current_trait}}, $value_array; 

                        }
                        #print STDERR "Array of single trait in $exp_name:" . "\n"; 
                        #print STDERR Dumper($multiple_measures_hash{$key}->{'qN'});
                        #print STDERR "Print structure for a given plot in $exp_name:" . "\n"; 
                        #print STDERR Dumper($multiple_measures_hash{key});

                    }
                    print STDERR "Print entire hash for $exp_name:" . "\n"; 
                    print STDERR Dumper(\%multiple_measures_hash);
                    my $time = DateTime->now();
                    my $timestamp = $time->ymd()."_".$time->hms();
                    my %phenotype_metadata;
                    #$phenotype_metadata{'archived_file'} = 'none';
                    #$phenotype_metadata{'archived_file_type'} = 'phenosight_data';
                    $phenotype_metadata{'operator'} = $username;
                    $phenotype_metadata{'date'} = $timestamp;

#                    my @test_plot_ids = qw(53531 53530 53532 53527 53528 53529);
#                    $plot_ids = \@test_plot_ids;
                    print STDERR "Plot IDs:";
#                    print STDERR Dumper($plot_ids);
                    print STDERR "Design Details:";
                    print STDERR Dumper($design_details);

                    ##### Once trial is uploaded, need to upload phenotypes
                    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
                        basepath=>$basepath,
                        dbhost=>$dbhost,
                        dbname=>$dbname,
                        dbuser=>$dbuser,
                        dbpass=>$dbpass,
                        temp_file_nd_experiment_id=>"/tmp/delete_nd_experiment_ids.txt",
                        bcs_schema=>$chado_schema,
                        metadata_schema=>$metadata_schema,
                        phenome_schema=>$phenome_schema,
                        user_id=>$sp_person_id,
                    #     # # need to develop plots list from phenosight data file
                        # Do these need to be uniquenames actually?
                        stock_list=>\@plot_uniquenames,
                    # #     # # need to develop trait list from headers in the phenosight data file
                        trait_list=>\@full_traits,
                        values_hash=>\%multiple_measures_hash,
                        has_timestamps=>1,
                        overwrite_values=>0,
                    #     ## Develop metadata hash from Experiments.xlsx file? + need the image file names?
                        metadata_hash=>\%phenotype_metadata,
                    #     image_zipfile_path=>$new_zip_file,
                    #     #composable_validation_check_name=>$f->config->{composable_validation_check_name}
                    );
                    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
                    if ($verified_error) {
                        die $verified_error."\n";
                    }
                    print STDERR "Print verification for $exp_name:" . "\n"; 
                    print STDERR Dumper($verified_warning, $verified_error);

                   my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
                   if ($stored_phenotype_error) {
                       die $stored_phenotype_error."\n";
                   }

                   print STDERR "Print storage message for $exp_name:" . "\n"; 
                   print STDERR Dumper($stored_phenotype_error, $stored_phenotype_success);



                    ##### Lastly, upload the image files - include with phenotypes above? (image.zip?)
                }
            } else {

            }

        }
        print STDERR "$PS2_present\n";



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

    # Exit the script: 0 = success, 1 = errors
    if ( scalar(@errors) > 0 ) {
        exit(1);
    }
    else {
        my $bs = CXGN::BreederSearch->new({ dbh=>$dbh, dbname=>$dbname });
        my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'all_but_genoview', 'concurrent', $basepath);
        exit(0);
    }
}

sub _create_plot_name {
  my $trial_name = shift;
  my $plot_number = shift;
  return $trial_name . "-PLOT_" . $plot_number;
}

1;

# my $filename = "/home/adrianpowell/phenosight_test_files/CropReporter/Data/Exp_010103/PS2_Analysis.TXT";

# # Open the file for reading
# open(my $fh, "<", $filename) || die "Could not open file '$filename': $!";

# while (my $line = <$fh>) {
#     # Remove trailing newline characters
#     chomp $line;

# #    print "$line\n";

# }

# # Close the file handle
# close $fh;

# print "File processing complete.\n";

