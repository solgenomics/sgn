
=head1 NAME

SGN::Controller::AJAX::GenotypesVCFUpload - a REST controller class to provide the
backend for uploading genotype VCF files

=head1 DESCRIPTION

Uploading Genotype VCF

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::GenotypesVCFUpload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::UploadFile;
use CXGN::Genotype::ParseUpload;
use CXGN::Genotype::StoreVCFGenotypes;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::GenotypingProject;
use File::Basename qw | basename dirname|;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );


sub upload_genotype_verify :  Path('/ajax/genotype/upload') : ActionClass('REST') { }
sub upload_genotype_verify_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $transpose_vcf_for_loading = 1;
    my @error_status;
    my @success_status;

    #print STDERR Dumper $c->req->params();
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this VCF genotype info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this VCF genotype info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'submitter' && $user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to upload VCF genotypes! Please contact us.' };
        $c->detach();
    }

    my $project_id = $c->req->param('upload_genotype_project_id') || undef;
    my $protocol_id = $c->req->param('upload_genotype_protocol_id') || undef;
#    print STDERR "PROJECT ID =".Dumper($project_id)."\n";
#    print STDERR "PROTOCOL ID =".Dumper($protocol_id)."\n";

    my $organism_species = $c->req->param('upload_genotypes_species_name_input');
    my $protocol_description = $c->req->param('upload_genotypes_protocol_description_input');
    my $project_name = $c->req->param('upload_genotype_vcf_project_name');
    my $location_id = $c->req->param('upload_genotype_location_select');
    my $year = $c->req->param('upload_genotype_year_select');
    my $breeding_program_id = $c->req->param('upload_genotype_breeding_program_select');
    my $obs_type = $c->req->param('upload_genotype_vcf_observation_type');
    my $genotyping_facility = $c->req->param('upload_genotype_vcf_facility_select');
    my $description = $c->req->param('upload_genotype_vcf_project_description');
    my $protocol_name = $c->req->param('upload_genotype_vcf_protocol_name');
    my $contains_igd = $c->req->param('upload_genotype_vcf_include_igd_numbers');
    my $reference_genome_name = $c->req->param('upload_genotype_vcf_reference_genome_name');
    my $assay_type = $c->req->param('assay_type_select');
    my $add_new_accessions = $c->req->param('upload_genotype_add_new_accessions');
    my $add_accessions;
    if ($add_new_accessions){
        $add_accessions = 1;
        $obs_type = 'accession';
    }
    my $include_igd_numbers;
    if ($contains_igd){
        $include_igd_numbers = 1;
    }
    my $include_lab_numbers;
    my $accept_warnings_input = $c->req->param('upload_genotype_accept_warnings');
    my $accept_warnings;
    if ($accept_warnings_input){
        $accept_warnings = 1;
    }

    if (defined $project_id && defined $protocol_id) {
        my $protocol_info = CXGN::Genotype::GenotypingProject->new({
            bcs_schema => $schema,
            project_id => $project_id
        });
        my $associated_protocol  = $protocol_info->get_associated_protocol();
        my @info;
        if ((defined $associated_protocol) && (scalar(@$associated_protocol)>1)) {
            $c->stash->{rest} = { error => "Each genotyping project should be associated with only one protocol" };
            $c->detach();
        } elsif (defined $associated_protocol && scalar(@$associated_protocol) == 1) {
            my $stored_protocol_id = $associated_protocol->[0]->[0];
            if ($stored_protocol_id != $protocol_id) {
                $c->stash->{rest} = { error => "The selected genotyping project is already associated with different protocol. Each project should be associated with only one protocol" };
                $c->detach();
            }
        }
    } elsif ((defined $project_id) && (defined $protocol_name)) {
        my $protocol_info = CXGN::Genotype::GenotypingProject->new({
            bcs_schema => $schema,
            project_id => $project_id
        });
        my $associated_protocol  = $protocol_info->get_associated_protocol();
        if ((defined $associated_protocol) && (scalar(@$associated_protocol) > 0)) {
            $c->stash->{rest} = { error => "The selected genotyping project is already associated with a protocol. Each project should be associated with only one protocol" };
            $c->detach();
        }
    }

    #archive uploaded file
    my $upload_vcf = $c->req->upload('upload_genotype_vcf_file_input');
    my $upload_tassel_hdf5 = $c->req->upload('upload_genotype_tassel_hdf5_file_input');
    my $upload_transposed_vcf = $c->req->upload('upload_genotype_transposed_vcf_file_input');
    my $upload_intertek_genotypes = $c->req->upload('upload_genotype_intertek_file_input');
    my $upload_inteterk_marker_info = $c->req->upload('upload_genotype_intertek_snp_file_input');
    my $upload_ssr_data = $c->req->upload('upload_genotype_ssr_file_input');
    my $upload_kasp_genotypes = $c->req->upload('upload_genotype_data_kasp_file_input');
    my $upload_kasp_marker_info = $c->req->upload('upload_genotype_kasp_marker_info_file_input');
    if (defined $upload_kasp_genotypes) {
        if (!defined $assay_type) {
            $assay_type = 'KASP';
        }
    }

    if (defined($upload_vcf) && defined($upload_intertek_genotypes)) {
        $c->stash->{rest} = { error => 'Do not try to upload both VCF and Intertek at the same time!' };
        $c->detach();
    }
    if (defined($upload_vcf) && defined($upload_tassel_hdf5)) {
        $c->stash->{rest} = { error => 'Do not try to upload both VCF and Tassel HDF5 at the same time!' };
        $c->detach();
    }
    if (defined($upload_intertek_genotypes) && defined($upload_tassel_hdf5)) {
        $c->stash->{rest} = { error => 'Do not try to upload both Intertek and Tassel HDF5 at the same time!' };
        $c->detach();
    }
    if ((defined($upload_intertek_genotypes) && !defined($upload_inteterk_marker_info)) || (!defined($upload_intertek_genotypes) && defined($upload_inteterk_marker_info))) {
        $c->stash->{rest} = { error => 'To upload Intertek genotype data please provide both the Grid Genotypes File and the Marker Info File.' };
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $upload_original_name;
    my $upload_tempfile;
    my $subdirectory;
    my $parser_plugin;
    if ($upload_vcf) {
        $upload_original_name = $upload_vcf->filename();
        $upload_tempfile = $upload_vcf->tempname;
        $subdirectory = "genotype_vcf_upload";
        $parser_plugin = 'VCF';

        if ($transpose_vcf_for_loading) {
            my $dir = $c->tempfiles_subdir('/genotype_data_upload_transpose_VCF');
            my $temp_file_transposed = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_data_upload_transpose_VCF/fileXXXX');

            open (my $Fout, "> :encoding(UTF-8)", $temp_file_transposed) || die "Can't open file $temp_file_transposed\n";
            open (my $F, "< :encoding(UTF-8)", $upload_tempfile) or die "Can't open file $upload_tempfile \n";
            my @outline;
            my $lastcol;
            while (<$F>) {
		$_ =~ s/\r//g;
                if ($_ =~ m/^\##/) {
                    print $Fout $_;
                } else {
                    chomp;
                    my @line = split /\t/;
                    my $oldlastcol = $lastcol;
                    $lastcol = $#line if $#line > $lastcol;
                    for (my $i=$oldlastcol; $i < $lastcol; $i++) {
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
            $upload_tempfile = $temp_file_transposed;
            $upload_original_name = basename($temp_file_transposed);
            $parser_plugin = 'transposedVCF';
        }
    }
    if ($upload_transposed_vcf) {
        $upload_original_name = $upload_transposed_vcf->filename();
        $upload_tempfile = $upload_transposed_vcf->tempname;
        $subdirectory = "genotype_transposed_vcf_upload";
        $parser_plugin = 'transposedVCF';
    }
    if ($upload_tassel_hdf5) {
        $upload_original_name = $upload_tassel_hdf5->filename();
        $upload_tempfile = $upload_tassel_hdf5->tempname;
        $subdirectory = "genotype_tassel_hdf5_upload";

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_tassel_hdf5_file = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_tassel_hdf5_file);
        if (!$archived_tassel_hdf5_file) {
            $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
            $c->detach();
        }
        unlink $upload_tempfile;

        my $output_dir = $c->tempfiles_subdir('/genotype_upload_tassel_hdf5');
        $upload_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_upload_tassel_hdf5/temp_vcf_XXXX').".vcf";
        my $cmd = "perl ".$c->config->{rootpath}."/tassel-5-standalone/run_pipeline.pl -Xmx12g -h5 ".$archived_tassel_hdf5_file." -export ".$upload_tempfile." -exportType VCF";
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $temp_file_transposed = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_upload_tassel_hdf5/fileXXXX');

        open (my $Fout, "> :encoding(UTF-8)", $temp_file_transposed) || die "Can't open file $temp_file_transposed\n";
        open (my $F, "< :encoding(UTF-8)", $upload_tempfile) or die "Can't open file $upload_tempfile \n";
        my @outline;
        my $lastcol;
        while (<$F>) {
	    $_ =~ s/\r//g;
            if ($_ =~ m/^\##/) {
                print $Fout $_;
            } else {
                chomp;
                my @line = split /\t/;
                my $oldlastcol = $lastcol;
                $lastcol = $#line if $#line > $lastcol;
                for (my $i=$oldlastcol; $i < $lastcol; $i++) {
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
        $upload_tempfile = $temp_file_transposed;
        $upload_original_name = basename($temp_file_transposed);

        $subdirectory = "genotype_transposed_vcf_upload";
        $parser_plugin = 'transposedVCF';
    }

    my $archived_marker_info_file;
    if ($upload_intertek_genotypes) {
        $upload_original_name = $upload_intertek_genotypes->filename();
        $upload_tempfile = $upload_intertek_genotypes->tempname;
        $subdirectory = "genotype_intertek_upload";
        $parser_plugin = 'IntertekCSV';

        if ($obs_type eq 'accession') {
            $include_lab_numbers = 1;
        }

        my $upload_inteterk_marker_info_original_name = $upload_inteterk_marker_info->filename();
        my $upload_inteterk_marker_info_tempfile = $upload_inteterk_marker_info->tempname();

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_inteterk_marker_info_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_inteterk_marker_info_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        $archived_marker_info_file = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_marker_info_file);
        if (!$archived_marker_info_file) {
            push @error_status, "Could not save file $upload_inteterk_marker_info_original_name in archive.";
            return (\@success_status, \@error_status);
        } else {
            push @success_status, "File $upload_inteterk_marker_info_original_name saved in archive.";
        }
        unlink $upload_inteterk_marker_info_tempfile;
    }

    if ($upload_ssr_data) {
        $upload_original_name = $upload_ssr_data->filename();
        $upload_tempfile = $upload_ssr_data->tempname;
        $subdirectory = "ssr_data_upload";
        $parser_plugin = 'SSRExcel';
    }

    if ($upload_kasp_genotypes) {
        $upload_original_name = $upload_kasp_genotypes->filename();
        $upload_tempfile = $upload_kasp_genotypes->tempname;
        $subdirectory = "genotype_kasp_upload";
        $parser_plugin = 'KASP';

        my $upload_kasp_marker_info_original_name = $upload_kasp_marker_info->filename();
        my $upload_kasp_marker_info_tempfile = $upload_kasp_marker_info->tempname();

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_kasp_marker_info_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_kasp_marker_info_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        $archived_marker_info_file = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_marker_info_file);
        if (!$archived_marker_info_file) {
            push @error_status, "Could not save file $upload_kasp_marker_info_original_name in archive.";
            return (\@success_status, \@error_status);
        } else {
            push @success_status, "File $upload_kasp_marker_info_original_name saved in archive.";
        }
        unlink $upload_kasp_marker_info_tempfile;
    }

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        return (\@success_status, \@error_status);
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    #if protocol_id provided, a new one will not be created
    if ($protocol_id){
        my $protocol = CXGN::Genotype::Protocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $protocol_id
        });
        $organism_species = $protocol->species_name;
        $obs_type = $protocol->sample_observation_unit_type_name;
        if ($obs_type eq 'accession') {
            $include_lab_numbers = 1;
        }
    }

    my $organism_q = "SELECT organism_id FROM organism WHERE species = ?";
    my @found_organisms;
    my $h = $schema->storage->dbh()->prepare($organism_q);
    $h->execute($organism_species);
    while (my ($organism_id) = $h->fetchrow_array()){
        push @found_organisms, $organism_id;
    }
    if (scalar(@found_organisms) == 0){
        $c->stash->{rest} = { error => 'The organism species you provided is not in the database! Please contact us.' };
        $c->detach();
    }
    if (scalar(@found_organisms) > 1){
        $c->stash->{rest} = { error => 'The organism species you provided is not unique in the database! Please contact us.' };
        $c->detach();
    }
    my $organism_id = $found_organisms[0];

    my $parser = CXGN::Genotype::ParseUpload->new({
        chado_schema => $schema,
        filename => $archived_filename_with_path,
        filename_marker_info => $archived_marker_info_file,
        observation_unit_type_name => $obs_type,
        organism_id => $organism_id,
        create_missing_observation_units_as_accessions => $add_accessions,
        igd_numbers_included => $include_igd_numbers,
        # lab_numbers_included => $include_lab_numbers
    });
    $parser->load_plugin($parser_plugin);

    my $dir = $c->tempfiles_subdir('/genotype_data_upload_SQL_COPY');
    my $temp_file_sql_copy = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_data_upload_SQL_COPY/fileXXXX');

    my $vcf_genotyping_type =  'vcf_snp_genotyping';#for now only SNP type are uploaded from VCF using the web interface
    my $genotyping_type;
    my $genotype_data_type;

    if ($vcf_genotyping_type =~ /vcf_phg_genotyping/) {
    $genotyping_type = 'phg genotyping';
    $genotype_data_type = 'PHG';

} else {
    $genotyping_type = 'snp genotyping';
    $genotype_data_type = 'SNP';
}

    my $store_args = {
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        observation_unit_type_name=>$obs_type,
        project_id=>$project_id,
        protocol_id=>$protocol_id,
        genotyping_facility=>$genotyping_facility, #projectprop
        breeding_program_id=>$breeding_program_id, #project_rel
        project_year=>$year, #projectprop
        project_location_id=>$location_id, #ndexperiment and projectprop
        project_name=>$project_name, #project_attr
        project_description=>$description, #project_attr
        protocol_name=>$protocol_name,
        protocol_description=>$protocol_description,
        organism_id=>$organism_id,
        igd_numbers_included=>$include_igd_numbers,
        lab_numbers_included=>$include_lab_numbers,
        user_id=>$user_id,
        archived_filename=>$archived_filename_with_path,
        archived_file_type=>'genotype_vcf', #can be 'genotype_vcf' or 'genotype_dosage' to disntiguish genotyprop between old dosage only format and more info vcf format
        temp_file_sql_copy=>$temp_file_sql_copy,
        vcf_genotyping_type => $vcf_genotyping_type,
        genotyping_type => $genotyping_type,
        genotyping_data_type=> $genotype_data_type,
    };

    my $return;
    #For VCF files, memory was an issue so we parse them with an iterator
    if ($parser_plugin eq 'VCF' || $parser_plugin eq 'transposedVCF') {
        my $parser_return = $parser->parse_with_iterator();

        if ($parser->get_parse_errors()) {
            my $return_error = '';
            my $parse_errors = $parser->get_parse_errors();
            print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."<br>";
            }
            $c->stash->{rest} = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
            $c->detach();
        }

        my $protocol = $parser->protocol_data();
        my $observation_unit_names_all = $parser->observation_unit_names();
        $store_args->{observation_unit_uniquenames} = $observation_unit_names_all;

        if ($parser_plugin eq 'VCF') {
            $store_args->{marker_by_marker_storage} = 1;
        }

        $protocol->{'reference_genome_name'} = $reference_genome_name;
        $protocol->{'species_name'} = $organism_species;
        $protocol->{'assay_type'} = $assay_type;
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
                $c->stash->{rest} = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks} };
                $c->detach();
            }

            if (scalar(@{$verified_errors->{warning_messages}}) > 0){
                my $warning_string;
                foreach my $error_string (@{$verified_errors->{'warning_messages'}}){
                    $warning_string .= $error_string."<br>";
                }
                if (!$accept_warnings){
                    $c->stash->{rest} = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
                    $c->detach();
                }
            }

            if ($protocol_id) {
                my @protocol_match_errors;
                my $new_marker_data = $protocol->{markers};
                my $stored_protocol = CXGN::Genotype::Protocol->new({
                    bcs_schema => $schema,
                    nd_protocol_id => $protocol_id
                });
                my $stored_markers = $stored_protocol->markers();

                my @all_stored_markers = keys %$stored_markers;
                my %compare_marker_names = map {$_ => 1} @all_stored_markers;
                my @mismatch_marker_names;
                while (my ($chrom, $new_marker_data_1) = each %$new_marker_data) {
                    while (my ($marker_name, $new_marker_details) = each %$new_marker_data_1) {
                        if (exists($compare_marker_names{$marker_name})) {
                            while (my ($key, $value) = each %$new_marker_details) {
                                if ($value ne ($stored_markers->{$marker_name}->{$key})) {
                                    push @protocol_match_errors, "Marker $marker_name in your file has $value for $key, but in the previously stored protocol shows ".$stored_markers->{$marker_name}->{$key};
                                }
                            }
                        } else {
                            push @mismatch_marker_names, $marker_name;
                        }
                    }
                }

                if (scalar(@mismatch_marker_names) > 0){
                    my $marker_name_error;
                    $marker_name_error .= "<br>";
                    foreach my $error ( sort @mismatch_marker_names) {
                        $marker_name_error .= $error."<br>";
                    }

                    $c->stash->{rest} = { error => "These marker names in your file are not in the selected protocol. $marker_name_error"};
                    $c->detach();
                }


                if (scalar(@protocol_match_errors) > 0){
                    my $protocol_warning;
                    foreach my $match_error (@protocol_match_errors) {
                        $protocol_warning .= $match_error."<br>";
                    }
                    if (!$accept_warnings){
                        $c->stash->{rest} = { warning => $protocol_warning };
                        $c->detach();
                    }
                }
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
        $return = $store_genotypes->store_genotypeprop_table();
    }
    #For smaller Intertek files, memory is not usually an issue so can parse them without iterator
    elsif (($parser_plugin eq 'IntertekCSV') || ($parser_plugin eq 'KASP')) {
        if (defined $protocol_id) {
            $parser->{nd_protocol_id} = $protocol_id;
        }
        my $parsed_data = $parser->parse();
        my $parse_errors;
        if (!$parsed_data) {
            my $return_error = '';
            if (!$parser->has_parse_errors() ){
                $return_error = "Could not get parsing errors";
                $c->stash->{rest} = {error_string => $return_error,};
            } else {
                $parse_errors = $parser->get_parse_errors();
                #print STDERR Dumper $parse_errors;
                foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                    $return_error=$return_error.$error_string."<br>";
                }
            }
            $c->stash->{rest} = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
            $c->detach();
        }
        #print STDERR Dumper $parsed_data;
        my $observation_unit_uniquenames = $parsed_data->{observation_unit_uniquenames};
        my $genotype_info = $parsed_data->{genotypes_info};
        my $protocol_info = $parsed_data->{protocol_info};
        my $marker_info_keys = $parsed_data->{marker_info_keys};
        $protocol_info->{'reference_genome_name'} = $reference_genome_name;
        $protocol_info->{'species_name'} = $organism_species;
        $protocol_info->{'marker_info_keys'} = $marker_info_keys;
        $protocol_info->{'assay_type'} = $assay_type;

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
            $c->stash->{rest} = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks} };
            $c->detach();
        }

        if (scalar(@{$verified_errors->{warning_messages}}) > 0){
            my $warning_string;
            foreach my $error_string (@{$verified_errors->{'warning_messages'}}) {
                $warning_string .= $error_string."<br>";
            }
            if (!$accept_warnings){
                $c->stash->{rest} = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
                $c->detach();
            }
        }

        if ($protocol_id) {
            my @protocol_match_errors;
            my $new_marker_data = $protocol_info->{markers};
            my $stored_protocol = CXGN::Genotype::Protocol->new({
                bcs_schema => $schema,
                nd_protocol_id => $protocol_id
            });
            my $stored_markers = $stored_protocol->markers();

            while (my ($marker_name, $marker_obj) = each %$stored_markers) {
                while (my ($chrom, $new_marker_data_1) = each %$new_marker_data) {
                    if ($new_marker_data_1->{$marker_name}) {
                        my $protocol_data_obj = $new_marker_data_1->{$marker_name};
                        while (my ($key, $value) = each %$marker_obj) {
                            if ($value ne $protocol_data_obj->{$key}) {
                                push @protocol_match_errors, "Marker $marker_name in the previously loaded protocol has $value for $key, but in your file now shows ".$protocol_data_obj->{$key};
                            }
                        }
                    }
                }
            }

            if (scalar(@protocol_match_errors) > 0){
                my $protocol_warning;
                foreach my $match_error (@protocol_match_errors) {
                    $protocol_warning .= $match_error."<br>";
                }
                if (!$accept_warnings){
                    $c->stash->{rest} = { warning => $protocol_warning };
                    $c->detach();
                }
            }
        }

        $store_genotypes->store_metadata();
        $store_genotypes->store_identifiers();
        $return = $store_genotypes->store_genotypeprop_table();

    } elsif ($parser_plugin eq 'SSRExcel') {
        my $parsed_data = $parser->parse();
        print STDERR "SSR PARSED DATA =".Dumper($parsed_data)."\n";
        my $parse_errors;
        if (!$parsed_data) {
            my $return_error = '';
            if (!$parser->has_parse_errors() ){
                $return_error = "Could not get parsing errors";
                $c->stash->{rest} = {error_string => $return_error,};
            } else {
                $parse_errors = $parser->get_parse_errors();
                #print STDERR Dumper $parse_errors;
                foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                    $return_error=$return_error.$error_string."<br>";
                }
            }
            $c->stash->{rest} = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
            $c->detach();
        }

        my $observation_unit_uniquenames = $parsed_data->{observation_unit_uniquenames};
        my $genotype_info = $parsed_data->{genotypes_info};

        my @protocol_id_list;
        push @protocol_id_list, $protocol_id;
        my $genotypes_search = CXGN::Genotype::Search->new({
        	bcs_schema=>$schema,
        	people_schema=>$people_schema,
        	protocol_id_list=>\@protocol_id_list,
        });
        my $result = $genotypes_search->get_pcr_genotype_info();
        my $protocol_marker_names = $result->{'marker_names'};
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
            $c->stash->{rest} = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks} };
            $c->detach();
        }

        if (scalar(@{$verified_errors->{warning_messages}}) > 0){
            my $warning_string;
            foreach my $error_string (@{$verified_errors->{'warning_messages'}}) {
                $warning_string .= $error_string."<br>";
            }
            if (!$accept_warnings){
                $c->stash->{rest} = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
                $c->detach();
            }
        }

        $store_genotypes->store_metadata();
        $return = $store_genotypes->store_identifiers();

    } else {
        print STDERR "Parser plugin $parser_plugin not recognized!\n";
        $c->stash->{rest} = { error => "Parser plugin $parser_plugin not recognized!" };
        $c->detach();
    }

    my $basepath = $c->config->{basepath};
    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$dbname, } );
    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'fullview', 'concurrent', $basepath);

    # Rebuild and refresh the materialized_markerview table
    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl $basepath/bin/refresh_materialized_markerview.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass");

    $c->stash->{rest} = $return;
}

1;
