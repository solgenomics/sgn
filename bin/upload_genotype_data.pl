#!/usr/bin/perl

=head1

upload_genotype_data.pl

=head1 SYNOPSIS

upload_genotype_data.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -tf [tempfiles_subdir] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -ap archive path (required) Ex: /home/production/volume/archive
 -tf tempfiles subdirectory, relative to the basepath (required) Ex: static/documents/tempfiles
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/upload_genotype_data.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -tf static/documents/tempfiles -j 17

Reads an already archived genotype data file and saves the genotypes in it to the database, along
with the project and protocol they belong to.

Whatever happened is reported back to the submitting job, so that it acts the same whether the
upload was sync on or left to run in the background. The job also carries the answer the upload
dialog would have been given, so that waiting on the job and running it in the background produce
the same response.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI;
use File::Basename;
use File::Path qw | make_path |;
use File::Temp qw | tempfile |;
use JSON;
use Try::Tiny;

use Bio::Chado::Schema;
use CXGN::BreederSearch;
use CXGN::DB::InsertDBH;
use CXGN::Genotype::ParseUpload;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;
use CXGN::Genotype::StoreVCFGenotypes;
use CXGN::Job;
use CXGN::Metadata::Schema;
use CXGN::People::Schema;
use CXGN::Phenome::Schema;
use CXGN::Tools::Run;

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $archive_path, $tempfiles_subdir, $sp_job_id );
GetOptions(
    'dbhost|H=s'        => \$dbhost,
    'dbname|D=s'        => \$dbname,
    'dbuser|U=s'        => \$dbuser,
    'dbpass|P=s'        => \$dbpass,
    'basepath|w=s'      => \$basepath,
    'archive_path|ap=s' => \$archive_path,
    'tempfiles|tf=s'    => \$tempfiles_subdir,
    'jobid|j=s'         => \$sp_job_id,
    'help'              => \$help,
);
pod2usage(1) if $help;
if (!$basepath || !$dbname || !$dbhost || !$archive_path || !$tempfiles_subdir || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}

# Connect to databases. 
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

my $chado_schema = Bio::Chado::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, metadata, phenome;'] } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, metadata;'] } );
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, phenome;'] } );
my $people_schema = CXGN::People::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, sgn_people;'] } );

my @success_messages;
my @warning_messages;
my @error_messages;

# The answer the upload dialog is given. Every way out of this script sets it, so that a dialog
# waiting on the job reads exactly what it used to read when the upload ran in the controller.
my $result;

my $params;

# Only SNP type genotypes are uploaded from VCF through the web interface for now.
my $vcf_genotyping_type = 'vcf_snp_genotyping';
my $genotyping_type;
my $genotype_data_type;
if ($vcf_genotyping_type =~ /vcf_phg_genotyping/) {
    $genotyping_type = 'phg genotyping';
    $genotype_data_type = 'PHG';
} else {
    $genotyping_type = 'snp genotyping';
    $genotype_data_type = 'SNP';
}

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    $params = upload_params();
    upload_genotype_data();
} catch {
    push @error_messages, $_;
    $result = { error => $_ };
};

finish();

=head2 upload_params()

Reads what this script is to upload off the submitting job. Dies if it is not there, since there is
nothing to upload without it.

=cut

sub upload_params {
    my $job = CXGN::Job->new({
        sp_job_id => $sp_job_id,
        schema => $chado_schema,
        people_schema => $people_schema
    });

    my $job_args = $job->additional_args() || {};
    my $upload_params = $job_args->{upload_params};
    if (!$upload_params) {
        die "Job $sp_job_id does not describe a genotype upload.\n";
    }

    return $upload_params;
}

=head2 upload_genotype_data()

Reads the uploaded file with the parser it belongs to and saves the genotypes in it.

=cut

sub upload_genotype_data {
    my $file_path = $params->{archived_filename};

    # A Tassel HDF5 file is not something the genotype parsers can read, so it is exported to VCF
    # first and what comes out of that is what gets parsed.
    if ($params->{tassel_hdf5_file}) {
        $file_path = export_tassel_hdf5_to_vcf($params->{tassel_hdf5_file});
    }

    my $parser = build_parser($file_path);
    my $store_args = build_store_args($file_path);

    my $plugin = $params->{parser_plugin};
    my $return;
    if ($plugin eq 'VCF' || $plugin eq 'transposedVCF') {
        $return = store_vcf_genotypes($parser, $store_args);
    }
    elsif ($plugin eq 'IntertekCSV' || $plugin eq 'KASP') {
        $return = store_intertek_or_kasp_genotypes($parser, $store_args);
    }
    elsif ($plugin eq 'SSRExcel') {
        $return = store_ssr_genotypes($parser, $store_args);
    }
    else {
        die "Parser plugin $plugin not recognized!\n";
    }

    # The file was not stored. Whichever function read it has already recorded what was wrong with
    # it, and there is no point refreshing anything over an upload that did not happen.
    if (!$return) {
        return;
    }

    refresh_matviews();

    push @success_messages, "Genotype data stored successfully.";
    $result = $return;
}

=head2 export_tassel_hdf5_to_vcf($hdf5_file)

Exports a Tassel HDF5 file to VCF and transposes it, and returns the file that came out. This is
the slowest part of a Tassel upload

=cut

sub export_tassel_hdf5_to_vcf {
    my $hdf5_file = shift;

    my $exported_vcf = tempfile_in('genotype_upload_tassel_hdf5', 'temp_vcf_XXXX').".vcf";
    my $cmd = "perl ".$params->{rootpath}."/tassel-5-standalone/run_pipeline.pl -Xmx12g -h5 ".$hdf5_file." -export ".$exported_vcf." -exportType VCF";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $transposed_vcf = tempfile_in('genotype_upload_tassel_hdf5', 'fileXXXX');
    transpose_vcf($exported_vcf, $transposed_vcf);

    return $transposed_vcf;
}

=head2 transpose_vcf($vcf_file, $transposed_file)

Writes a VCF out with its rows and columns swapped, so that it can be read a sample at a time
instead of a marker at a time. The header lines are copied through as they are.

=cut

sub transpose_vcf {
    my $vcf_file = shift;
    my $transposed_file = shift;

    open (my $Fout, "> :encoding(UTF-8)", $transposed_file) || die "Can't open file $transposed_file\n";
    open (my $F, "< :encoding(UTF-8)", $vcf_file) or die "Can't open file $vcf_file \n";
    my @outline;
    my $lastcol = -1;
    while (<$F>) {
        $_ =~ s/\r//g;
        if ($_ =~ m/^\##/) {
            print $Fout $_;
        } else {
            chomp;
            my @line = split /\t/;
            my $oldlastcol = $lastcol;
            $lastcol = $#line if $#line > $lastcol;
            for (my $i=$oldlastcol + 1; $i <= $lastcol; $i++) {
                if ($oldlastcol) {
                    $outline[$i] = "\t" x $oldlastcol;
                }
            }
            for (my $i=0; $i <=$lastcol; $i++) {
                $outline[$i] .= "$line[$i]\t"
            }
        }
    }
    for (my $i=0; $i <= $lastcol; $i++) {
        $outline[$i] =~ s/\s*$//g;
        print $Fout $outline[$i]."\n";
    }
    close($F);
    close($Fout);
}

=head2 build_parser($file_path)

Builds the parser for the kind of file that was uploaded.

=cut

sub build_parser {
    my $file_path = shift;

    my $parser = CXGN::Genotype::ParseUpload->new({
        chado_schema => $chado_schema,
        filename => $file_path,
        filename_marker_info => $params->{archived_marker_info_file},
        observation_unit_type_name => $params->{obs_type},
        organism_id => $params->{organism_id},
        create_missing_observation_units_as_accessions => $params->{add_accessions},
        igd_numbers_included => $params->{include_igd_numbers},
        # lab_numbers_included => $params->{include_lab_numbers}
    });
    $parser->load_plugin($params->{parser_plugin});

    return $parser;
}

=head2 build_store_args($file_path)

Builds the arguments the genotype store takes. The project and protocol details are whatever the
uploader filled in; the store creates a project or a protocol from them if the upload did not name
ones that already exist.

=cut

sub build_store_args {
    my $file_path = shift;

    return {
        bcs_schema=>$chado_schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        observation_unit_type_name=>$params->{obs_type},
        project_id=>$params->{project_id},
        protocol_id=>$params->{protocol_id},
        genotyping_facility=>$params->{genotyping_facility}, #projectprop
        breeding_program_id=>$params->{breeding_program_id}, #project_rel
        project_year=>$params->{year}, #projectprop
        project_location_id=>$params->{location_id}, #ndexperiment and projectprop
        project_name=>$params->{project_name}, #project_attr
        project_description=>$params->{description}, #project_attr
        protocol_name=>$params->{protocol_name},
        protocol_description=>$params->{protocol_description},
        organism_id=>$params->{organism_id},
        igd_numbers_included=>$params->{include_igd_numbers},
        lab_numbers_included=>$params->{include_lab_numbers},
        user_id=>$params->{user_id},
        archived_filename=>$file_path,
        archived_file_type=>'genotype_vcf', #can be 'genotype_vcf' or 'genotype_dosage' to disntiguish genotyprop between old dosage only format and more info vcf format
        temp_file_sql_copy=>sql_copy_tempfile(),
        vcf_genotyping_type => $vcf_genotyping_type,
        genotyping_type => $genotyping_type,
        genotyping_data_type=> $genotype_data_type,
    };
}

=head2 store_vcf_genotypes($parser, $store_args)

Reads a VCF or transposed VCF file and saves the genotypes in it. A whole VCF does not fit in
memory, so it is read through an iterator: the first sample is used to work out the protocol and to
check the file, and the rest are stored a sample at a time as they are read.

Returns what was stored, or nothing if the file could not be used.

=cut

sub store_vcf_genotypes {
    my $parser = shift;
    my $store_args = shift;

    my $parser_return = $parser->parse_with_iterator();

    if ($parser->get_parse_errors()) {
        my $return_error = '';
        my $parse_errors = $parser->get_parse_errors();
        print STDERR Dumper $parse_errors;
        foreach my $error_string (@{$parse_errors->{'error_messages'}}){
            $return_error=$return_error.$error_string."<br>";
        }
        push @error_messages, $return_error;
        $result = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
        return;
    }

    my $protocol = $parser->protocol_data();
    my $observation_unit_names_all = $parser->observation_unit_names();
    $store_args->{observation_unit_uniquenames} = $observation_unit_names_all;

    if ($params->{parser_plugin} eq 'VCF') {
        $store_args->{marker_by_marker_storage} = 1;
    }

    $protocol->{'reference_genome_name'} = $params->{reference_genome_name};
    $protocol->{'species_name'} = $params->{organism_species};
    $protocol->{'assay_type'} = $params->{assay_type};
    my $store_genotypes;
    my ($observation_unit_names, $genotype_info) = $parser->next();
    if (scalar(keys %$genotype_info) > 0) {
        #print STDERR Dumper [$observation_unit_names, $genotype_info];
        print STDERR "Parsing first genotype and extracting protocol info... \n";

        $store_args->{protocol_info} = $protocol;
        $store_args->{genotype_info} = $genotype_info;

        $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new($store_args);
        my $verified_errors = $store_genotypes->validate();

        if (scalar(@{$verified_errors->{error_messages}}) > 0){
            my $error_string;
            foreach my $error (@{$verified_errors->{error_messages}}) {
                $error_string .= $error."<br>";
            }
            push @error_messages, $error_string;
            $result = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks}, missing_markers => $verified_errors->{missing_markers} };
            return;
        }

        my @all_warnings;
        my $previous_genotypes_exist;
        if (scalar(@{$verified_errors->{warning_messages}}) > 0){
            my $warning_string;
            foreach my $error_string (@{$verified_errors->{'warning_messages'}}){
                $warning_string .= $error_string."<br>";
            }
            push @warning_messages, $warning_string;
            if (!$params->{accept_warnings}){
                $result = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
                return;
            }
            push @all_warnings, @{$verified_errors->{warning_messages}};
            $previous_genotypes_exist = $verified_errors->{previous_genotypes_exist};
        }

        if ($params->{protocol_id}) {
            my $protocol_match_errors = check_vcf_protocol_markers($store_genotypes, $protocol);
            if (!$protocol_match_errors) {
                return;
            }
            push @all_warnings, @$protocol_match_errors;
        }

        if (scalar(@all_warnings) > 0 && !$params->{accept_warnings}) {
            my $warning_string = join("<br>", @all_warnings);
            $result = { warning => $warning_string, previous_genotypes_exist => $previous_genotypes_exist };
            return;
        }

        $store_genotypes->store_metadata();
        $store_genotypes->store_identifiers();
    }

    print STDERR "Done loading first line, moving on...\n";

    my $continue_iterate = 1;
    while ($continue_iterate == 1) {
        my ($observation_unit_names, $genotype_info) = $parser->next();
        if (scalar(keys %$genotype_info) > 0) {
            $store_genotypes->genotype_info($genotype_info);
            $store_genotypes->observation_unit_uniquenames($observation_unit_names);
            $store_genotypes->store_identifiers();
        } else {
            $continue_iterate = 0;
            last;
        }
    }

    return $store_genotypes->store_genotypeprop_table();
}

=head2 check_vcf_protocol_markers($store_genotypes, $protocol)

Compares the markers in a VCF file against the protocol the upload named. Markers the protocol does
not have are either added to it or reported, depending on what the uploader asked for; markers it
does have but describes differently are reported as warnings.

Returns the differences to be warned about, or nothing if the file cannot be used against this
protocol.

A VCF holds every marker in the assay, so a handful of new ones among them is a protocol that has
grown slightly and anything more is the wrong protocol. That is why the limit here is a proportion
of the file rather than the flat count the Intertek and KASP files are held to.

=cut

sub check_vcf_protocol_markers {
    my $store_genotypes = shift;
    my $protocol = shift;

    my @protocol_match_errors;
    my $new_marker_data = $protocol->{markers};
    my $stored_protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $chado_schema,
        nd_protocol_id => $params->{protocol_id}
    });
    my $stored_markers = $stored_protocol->markers();

    my @all_stored_markers = keys %$stored_markers;
    my %compare_marker_names = map {$_ => 1} @all_stored_markers;
    my $total_marker_count = 0;
    my @mismatch_marker_names;
    my @mismatch_markers;
    while (my ($chrom, $new_marker_data_1) = each %$new_marker_data) {
        while (my ($marker_name, $new_marker_details) = each %$new_marker_data_1) {
            $total_marker_count++;
            if (exists($compare_marker_names{$marker_name})) {
                for my $key (qw(chrom pos name ref alt)) {
                    my $value = $new_marker_details->{$key};
                    if ($value ne ($stored_markers->{$marker_name}->{$key})) {
                        push @protocol_match_errors, "Marker $marker_name in your file has $value for $key, but in the previously stored protocol shows ".$stored_markers->{$marker_name}->{$key};
                    }
                }
            } else {
                push @mismatch_marker_names, $marker_name;
                push @mismatch_markers, [$chrom, $marker_name];
            }
        }
    }

    if (scalar(@mismatch_marker_names)) {
        if ($params->{add_markers}) {
            if ($total_marker_count && (scalar(@mismatch_marker_names) / $total_marker_count) < 0.1) {
                print STDERR "Adding new markers\n";
                $store_genotypes->store_new_markers_in_protocolprop(\@mismatch_markers);
            } else {
                push @error_messages, "Too many new markers";
                $result = { error => "Too many new markers"};
                return;
            }
        } else {
            my $marker_name_error = "<br>";
            foreach my $error ( sort @mismatch_marker_names) {
                $marker_name_error .= $error."<br>";
            }
            push @error_messages, "These marker names in your file are not in the selected protocol. $marker_name_error";
            $result = { error => "These marker names in your file are not in the selected protocol. $marker_name_error", missing_markers => \@mismatch_marker_names };
            return;
        }
    }

    if (scalar(@protocol_match_errors) > 0){
        my $protocol_warning;
        foreach my $match_error (@protocol_match_errors) {
            $protocol_warning .= $match_error."<br>";
        }
        push @warning_messages, $protocol_warning;
        if (!$params->{accept_warnings}){
            $result = { warning => $protocol_warning };
            return;
        }
    }

    return \@protocol_match_errors;
}

=head2 store_intertek_or_kasp_genotypes($parser, $store_args)

Reads an Intertek or KASP file and saves the genotypes in it. These files are small enough to read
in one go, so unlike a VCF the whole file is parsed and checked before anything is stored.

Returns what was stored, or nothing if the file could not be used.

=cut

sub store_intertek_or_kasp_genotypes {
    my $parser = shift;
    my $store_args = shift;

    if (defined $params->{protocol_id}) {
        $parser->{nd_protocol_id} = $params->{protocol_id};
    }
    my $parsed_data = $parser->parse();
    my $parse_errors;
    if (!$parsed_data) {
        my $return_error = '';
        if (!$parser->has_parse_errors() ){
            $return_error = "Could not get parsing errors";
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."<br>";
            }
        }
        push @error_messages, $return_error;
        $result = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
        return;
    }
    #print STDERR Dumper $parsed_data;
    my $observation_unit_uniquenames = $parsed_data->{observation_unit_uniquenames};
    my $genotype_info = $parsed_data->{genotypes_info};
    my $protocol_info = $parsed_data->{protocol_info};
    my $marker_info_keys = $parsed_data->{marker_info_keys};
    $protocol_info->{'reference_genome_name'} = $params->{reference_genome_name};
    $protocol_info->{'species_name'} = $params->{organism_species};
    $protocol_info->{'marker_info_keys'} = $marker_info_keys;
    $protocol_info->{'assay_type'} = $params->{assay_type};

    $store_args->{protocol_info} = $protocol_info;
    $store_args->{genotype_info} = $genotype_info;
    $store_args->{observation_unit_uniquenames} = $observation_unit_uniquenames;

    my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new($store_args);
    my $verified_errors = $store_genotypes->validate();

    if (scalar(@{$verified_errors->{error_messages}}) > 0){
        my $error_string;
        foreach my $error (@{$verified_errors->{error_messages}}) {
            $error_string .= $error."<br>";
        }
        push @error_messages, $error_string;
        $result = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks}, missing_markers => $verified_errors->{missing_markers} };
        return;
    }

    my @all_warnings;
    my $previous_genotypes_exist;
    if (scalar(@{$verified_errors->{warning_messages}}) > 0){
        my $warning_string;
        foreach my $error_string (@{$verified_errors->{'warning_messages'}}) {
            $warning_string .= $error_string."<br>";
        }
        push @warning_messages, $warning_string;
        if (!$params->{accept_warnings}){
            $result = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
            return;
        }
        push @all_warnings, @{$verified_errors->{warning_messages}};
        $previous_genotypes_exist = $verified_errors->{previous_genotypes_exist};
    }

    if ($params->{protocol_id}) {
        my $protocol_match_errors = check_intertek_or_kasp_protocol_markers($store_genotypes, $protocol_info);
        if (!$protocol_match_errors) {
            return;
        }
        push @all_warnings, @$protocol_match_errors;
    }

    if (scalar(@all_warnings) > 0 && !$params->{accept_warnings}) {
        my $warning_string = join("<br>", @all_warnings);
        $result = { warning => $warning_string, previous_genotypes_exist => $previous_genotypes_exist };
        return;
    }

    $store_genotypes->store_metadata();
    $store_genotypes->store_identifiers();

    return $store_genotypes->store_genotypeprop_table();
}

=head2 check_intertek_or_kasp_protocol_markers($store_genotypes, $protocol_info)

Compares the markers in an Intertek or KASP file against the protocol the upload named, the same
way the VCF check does.

Returns the differences to be warned about, or nothing if the file cannot be used against this
protocol.

These files hold a chosen panel of markers rather than a whole assay, so new markers among them are
counted rather than measured against the size of the file.

=cut

sub check_intertek_or_kasp_protocol_markers {
    my $store_genotypes = shift;
    my $protocol_info = shift;

    my @protocol_match_errors;
    my $new_marker_data = $protocol_info->{markers};
    my $stored_protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $chado_schema,
        nd_protocol_id => $params->{protocol_id}
    });
    my $stored_markers = $stored_protocol->markers();
    my @all_stored_markers = keys %$stored_markers;
    my %compare_marker_names = map {$_ => 1} @all_stored_markers;
    my $total_marker_count = 0;
    my @mismatch_marker_names;
    my @mismatch_markers;
    while (my ($chrom, $new_marker_data_1) = each %$new_marker_data) {
        while (my ($marker_name, $new_marker_details) = each %$new_marker_data_1) {
            $total_marker_count++;
            if (exists($compare_marker_names{$marker_name})) {
                for my $key (qw(chrom pos name ref alt)) {
                    my $value = $new_marker_details->{$key};
                    if ($value ne ($stored_markers->{$marker_name}->{$key})) {
                        push @protocol_match_errors, "Marker $marker_name in your file has $value for $key, but in the previously stored protocol shows ".$stored_markers->{$marker_name}->{$key};
                    }
                }
            } else {
                push @mismatch_marker_names, $marker_name;
                push @mismatch_markers, [$chrom, $marker_name];
            }
        }
    }

    if (scalar(@mismatch_marker_names)){
        if ($params->{add_markers}) {
            if (scalar(@mismatch_marker_names) < 20) {
                print STDERR "Adding new markers\n";
                $store_genotypes->store_new_markers_in_protocolprop(\@mismatch_markers);
            } else {
                print STDERR "Too many new markers, should be less than 20\n";
                push @error_messages, "Too many new markers, should be less than 20";
                $result = { error => "Too many new markers, should be less than 20"};
                return;
            }
        } else {
            my $marker_name_error = "<br>";
            foreach my $error ( sort @mismatch_marker_names) {
                $marker_name_error .= $error."<br>";
            }
            push @error_messages, "These marker names in your file are not in the selected protocol. $marker_name_error";
            $result = { error => "These marker names in your file are not in the selected protocol. $marker_name_error"};
            return;
        }
    }

    if (scalar(@protocol_match_errors) > 0){
        my $protocol_warning;
        foreach my $match_error (@protocol_match_errors) {
            $protocol_warning .= $match_error."<br>";
        }
        push @warning_messages, $protocol_warning;
        if (!$params->{accept_warnings}){
            $result = { warning => $protocol_warning };
            return;
        }
    }

    return \@protocol_match_errors;
}

=head2 store_ssr_genotypes($parser, $store_args)

Reads an SSR file and saves the genotypes in it. SSR data is always stored against a protocol that
already exists, so the marker names are taken from that protocol rather than from the file, and the
samples are always accessions.

Returns what was stored, or nothing if the file could not be used.

=cut

sub store_ssr_genotypes {
    my $parser = shift;
    my $store_args = shift;

    my $parsed_data = $parser->parse();
    print STDERR "SSR PARSED DATA =".Dumper($parsed_data)."\n";
    my $parse_errors;
    if (!$parsed_data) {
        my $return_error = '';
        if (!$parser->has_parse_errors() ){
            $return_error = "Could not get parsing errors";
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."<br>";
            }
        }
        push @error_messages, $return_error;
        $result = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
        return;
    }

    my $observation_unit_uniquenames = $parsed_data->{observation_unit_uniquenames};
    my $genotype_info = $parsed_data->{genotypes_info};

    my @protocol_id_list;
    push @protocol_id_list, $params->{protocol_id};
    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$chado_schema,
        people_schema=>$people_schema,
        protocol_id_list=>\@protocol_id_list,
    });
    my $search_result = $genotypes_search->get_pcr_genotype_info();
    my $protocol_marker_names = $search_result->{'marker_names'};
    my $previous_protocol_marker_names = decode_json $protocol_marker_names;

    my %protocolprop_info;
    $protocolprop_info{'sample_observation_unit_type_name'} = 'accession';
    $protocolprop_info{'marker_names'} = $previous_protocol_marker_names;

    $store_args->{genotype_info} = $genotype_info;
    $store_args->{observation_unit_uniquenames} = $observation_unit_uniquenames;
    $store_args->{protocol_info} = \%protocolprop_info;
    $store_args->{observation_unit_type_name} = 'accession';
    $store_args->{genotyping_data_type} = 'ssr';

    my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new($store_args);
    my $verified_errors = $store_genotypes->validate();

    if (scalar(@{$verified_errors->{error_messages}}) > 0){
        my $error_string;
        foreach my $error (@{$verified_errors->{error_messages}}) {
            $error_string .= $error."<br>";
        }
        push @error_messages, $error_string;
        $result = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks}, missing_markers => $verified_errors->{missing_markers} };
        return;
    }

    if (scalar(@{$verified_errors->{warning_messages}}) > 0){
        my $warning_string;
        foreach my $error_string (@{$verified_errors->{'warning_messages'}}) {
            $warning_string .= $error_string."<br>";
        }
        push @warning_messages, $warning_string;
        if (!$params->{accept_warnings}){
            $result = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
            return;
        }
    }

    $store_genotypes->store_metadata();

    return $store_genotypes->store_identifiers();
}

=head2 refresh_matviews()

Rebuilds the cached search tables so that the genotypes that were just stored can be searched for.

=cut

sub refresh_matviews {
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$dbname, } );
    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'fullview', 'concurrent', $basepath);

    # Rebuild and refresh the materialized_markerview table
    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl $basepath/bin/refresh_materialized_markerview.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass");
}

=head2 sql_copy_tempfile()

Returns the file the genotypes are written to on their way into the database. They are stored with
a bulk copy rather than one insert at a time, which is what makes loading a whole VCF possible.

=cut

sub sql_copy_tempfile {
    return tempfile_in('genotype_data_upload_SQL_COPY', 'fileXXXX');
}

=head2 tempfile_in($subdirectory, $template)

Returns a new temporary file in a subdirectory of the site tempfiles directory, creating the
subdirectory if this is the first upload to need it.

=cut

sub tempfile_in {
    my $subdirectory = shift;
    my $template = shift;

    my $dir = "$basepath/$tempfiles_subdir/$subdirectory";
    if (! -d $dir) {
        make_path($dir);
    }
    my (undef, $tempfile) = tempfile("$dir/$template");

    return $tempfile;
}

=head2 finish()

Reports what happened back to the submitting job and exits.

A file that raised warnings has not been dealt with yet, even though nothing actually went wrong
with it, so the job is left failed until the uploader either fixes the file or says to go ahead
anyway. Only errors are treated as failures once they have.

=cut

sub finish {
    foreach (@success_messages) {
        print STDOUT "SUCCESS: $_\n";
    }
    foreach (@warning_messages) {
        print STDERR "WARNING: $_\n";
    }
    foreach (@error_messages) {
        print STDERR "ERROR: $_\n";
    }

    my $failed = scalar(@error_messages) > 0 || (scalar(@warning_messages) > 0 && !$params->{accept_warnings});

    try {
        my $job = CXGN::Job->new({
            sp_job_id => $sp_job_id,
            schema => $chado_schema,
            people_schema => $people_schema
        });

        if (!$job->additional_args()) {
            $job->additional_args({});
        }

        if ($result) {
            $job->additional_args->{result} = $result;
        }
        if (scalar(@success_messages) > 0) {
            $job->additional_args->{success_messages} = join("<br>", @success_messages);
        }
        if (scalar(@warning_messages) > 0) {
            $job->additional_args->{warning_messages} = join("<br>", @warning_messages);
        }
        if (scalar(@error_messages) > 0) {
            $job->additional_args->{error_messages} = join("<br>", @error_messages);
        }

        $job->update_status($failed ? "failed" : "finished");
    } catch {
        print STDERR "Could not report the results of this upload to job $sp_job_id: $_\n";
    };

    exit(scalar(@error_messages) > 0 ? 1 : 0);
}

1;
