
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
use CXGN::File;
use CXGN::Job;
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
    my $user_first_name;
    my $user_last_name;
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
        $user_first_name = $p->get_first_name();
        $user_last_name = $p->get_last_name();
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this VCF genotype info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
        $user_first_name = $c->user()->get_object()->get_first_name();
        $user_last_name = $c->user()->get_object()->get_last_name();
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
    my $add_new_markers = $c->req->param('upload_genotype_add_new_markers');
    my $add_accessions;
    if ($add_new_accessions){
        $add_accessions = 1;
        $obs_type = 'accession';
    }
    my $add_markers;
    if ($add_new_markers) {
        $add_markers = 1;
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
    my $archived_vcf_file_id = $c->req->param('archived_vcf_file_id') || undef;
    my $upload_tassel_hdf5 = $c->req->upload('upload_genotype_tassel_hdf5_file_input');
    my $archived_tassel_file_id = $c->req->param('archived_tassel_file_id') || undef;
    my $upload_transposed_vcf = $c->req->upload('upload_genotype_transposed_vcf_file_input');
    my $upload_intertek_genotypes = $c->req->upload('upload_genotype_intertek_file_input');
    my $archived_intertek_file_id = $c->req->param('archived_intertek_file_id') || undef;
    my $upload_inteterk_marker_info = $c->req->upload('upload_genotype_intertek_snp_file_input');
    my $archived_intertek_marker_info_file_id = $c->req->param('archived_intertek_marker_info_file_id') || undef;
    my $upload_ssr_data = $c->req->upload('upload_genotype_ssr_file_input');
    my $archived_ssr_file_id = $c->req->param('archived_ssr_file_id') || undef;
    my $upload_kasp_genotypes = $c->req->upload('upload_genotype_data_kasp_file_input');
    my $archived_kasp_file_id = $c->req->param('archived_kasp_file_id') || undef;
    my $upload_kasp_marker_info = $c->req->upload('upload_genotype_kasp_marker_info_file_input');
    my $archived_kasp_marker_info_file_id = $c->req->param('archived_kasp_marker_info_file_id') || undef;
    my $has_vcf      = defined($upload_vcf)               || defined($archived_vcf_file_id);
    my $has_tassel   = defined($upload_tassel_hdf5)        || defined($archived_tassel_file_id);
    my $has_intertek = defined($upload_intertek_genotypes) || defined($archived_intertek_file_id);
    my $has_intertek_marker = defined($upload_inteterk_marker_info) || defined($archived_intertek_marker_info_file_id);
    my $has_kasp     = defined($upload_kasp_genotypes)     || defined($archived_kasp_file_id);

    # The upload manager archives a file before calling here, so a file that is already in the
    # archive is one it is going to follow the job for itself. The upload dialog posts the file
    # directly and reports the outcome to the user, so it waits for the job to finish.
    my $from_upload_manager = ($archived_vcf_file_id || $archived_tassel_file_id || $archived_intertek_file_id || $archived_ssr_file_id || $archived_kasp_file_id) ? 1 : 0;

    if ($has_kasp && !defined $assay_type) {
        $assay_type = 'KASP';
    }

    if ($has_vcf && $has_intertek) {
        $c->stash->{rest} = { error => 'Do not try to upload both VCF and Intertek at the same time!' };
        $c->detach();
    }
    if ($has_vcf && $has_tassel) {
        $c->stash->{rest} = { error => 'Do not try to upload both VCF and Tassel HDF5 at the same time!' };
        $c->detach();
    }
    if ($has_intertek && $has_tassel) {
        $c->stash->{rest} = { error => 'Do not try to upload both Intertek and Tassel HDF5 at the same time!' };
        $c->detach();
    }
    if ($has_intertek != $has_intertek_marker) {
        $c->stash->{rest} = { error => 'To upload Intertek genotype data please provide both the Grid Genotypes File and the Marker Info File.' };
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $upload_original_name;
    my $upload_tempfile;
    my $subdirectory;
    my $parser_plugin;
    my $archived_filename_with_path;
    my $archived_main_file_id;
    my $archived_marker_info_file;
    my $tassel_hdf5_file;
    my $genotype_file_type;
    if ($upload_vcf || $archived_vcf_file_id) {
        $genotype_file_type = 'genotype_data_vcf';
        if ($upload_vcf) {
            $upload_original_name = $upload_vcf->filename();
            $upload_tempfile = $upload_vcf->tempname;
            $subdirectory = "genotype_vcf_upload";
            $parser_plugin = 'VCF';

        if ($transpose_vcf_for_loading) {
            #archive a copy of the original (non-transposed) VCF file as uploaded, so that
            #the website can later retrieve the original file instead of the transposed
            #version that gets archived (and used for loading) below. It is archived using
            #the same archive_filename/timestamp as the transposed file, so that it can be
            #found later by swapping the genotype_vcf_upload directory for genotype_vcf_archive.
            my $original_uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => "genotype_vcf_archive",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => 'genotyping_data',
                metadata_schema => $metadata_schema
            });
            my ($archived_original_vcf_id, $archived_original_vcf) = $original_uploader->archive();
            if (!$archived_original_vcf) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }

            my $dir = $c->tempfiles_subdir('/genotype_data_upload_transpose_VCF');
            my $temp_file_transposed = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_data_upload_transpose_VCF/fileXXXX');

                open (my $Fout, "> :encoding(UTF-8)", $temp_file_transposed) || die "Can't open file $temp_file_transposed\n";
                open (my $F, "< :encoding(UTF-8)", $upload_tempfile) or die "Can't open file $upload_tempfile \n";
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
                            if ($oldlastcol > 0) {
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

            my $vcf_uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => $genotype_file_type,
                metadata_schema => $metadata_schema
            });
            ($archived_main_file_id, $archived_filename_with_path) = $vcf_uploader->archive();
            my $md5 = $vcf_uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
        } else {
            my $archived_vcf = CXGN::File->new({
                file_id => $archived_vcf_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_filename_with_path = $archived_vcf->get_path();
            $archived_main_file_id = $archived_vcf_file_id;
            $parser_plugin = 'VCF';
        }
    }
    if ($upload_transposed_vcf) {
        $upload_original_name = $upload_transposed_vcf->filename();
        $upload_tempfile = $upload_transposed_vcf->tempname;
        $subdirectory = "genotype_transposed_vcf_upload";
        $parser_plugin = 'transposedVCF';
        $genotype_file_type = 'genotype_data_vcf';

        my $tvcf_uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role,
            file_type => $genotype_file_type,
            metadata_schema => $metadata_schema
        });
        ($archived_main_file_id, $archived_filename_with_path) = $tvcf_uploader->archive();
        my $md5 = $tvcf_uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
            $c->detach();
        }
        unlink $upload_tempfile;
    }
    if ($upload_tassel_hdf5 || $archived_tassel_file_id) {
        $genotype_file_type = 'genotype_data_tassel';
        my $archived_tassel_hdf5_file;
        if ($upload_tassel_hdf5) {
            $upload_original_name = $upload_tassel_hdf5->filename();
            $upload_tempfile = $upload_tassel_hdf5->tempname;
            $subdirectory = "genotype_tassel_hdf5_upload";

            my $tassel_uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => $genotype_file_type,
                metadata_schema => $metadata_schema
            });
            my $tassel_file_id;
            ($tassel_file_id, $archived_tassel_hdf5_file) = $tassel_uploader->archive();
            my $md5 = $tassel_uploader->get_md5($archived_tassel_hdf5_file);
            if (!$archived_tassel_hdf5_file) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            $archived_main_file_id = $tassel_file_id;
            unlink $upload_tempfile;
        } else {
            my $archived_tassel = CXGN::File->new({
                file_id => $archived_tassel_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_tassel_hdf5_file = $archived_tassel->get_path();
            $archived_main_file_id = $archived_tassel_file_id;
        }

        # Exporting the HDF5 file to VCF and transposing it is by far the slowest part of a Tassel
        # upload, so it is left to the background script along with the parsing and storing that
        # follow it. What is recorded here is the archived HDF5 file it starts from.
        $tassel_hdf5_file = $archived_tassel_hdf5_file;
        $archived_filename_with_path = $archived_tassel_hdf5_file;
        $subdirectory = "genotype_transposed_vcf_upload";
        $parser_plugin = 'transposedVCF';
    }

    if ($upload_intertek_genotypes || $archived_intertek_file_id) {
        $genotype_file_type = 'genotype_data_intertek';
        $subdirectory = "genotype_intertek_upload";
        $parser_plugin = 'IntertekCSV';

        if ($obs_type eq 'accession') {
            $include_lab_numbers = 1;
        }

        if ($upload_intertek_genotypes) {
            $upload_original_name = $upload_intertek_genotypes->filename();
            $upload_tempfile = $upload_intertek_genotypes->tempname;

            my $intertek_uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => $genotype_file_type,
                metadata_schema => $metadata_schema
            });
            ($archived_main_file_id, $archived_filename_with_path) = $intertek_uploader->archive();
            my $md5 = $intertek_uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
        } else {
            my $archived_intertek = CXGN::File->new({
                file_id => $archived_intertek_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_filename_with_path = $archived_intertek->get_path();
            $archived_main_file_id = $archived_intertek_file_id;
        }

        if ($upload_inteterk_marker_info) {
            my $upload_inteterk_marker_info_original_name = $upload_inteterk_marker_info->filename();
            my $upload_inteterk_marker_info_tempfile = $upload_inteterk_marker_info->tempname();

            my $intertek_marker_uploader = CXGN::UploadFile->new({
                tempfile => $upload_inteterk_marker_info_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_inteterk_marker_info_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => 'genotype_data_intertek_marker_info',
                metadata_schema => $metadata_schema
            });
            my ($intertek_marker_file_id, $intertek_marker_path) = $intertek_marker_uploader->archive();
            my $md5 = $intertek_marker_uploader->get_md5($intertek_marker_path);
            if (!$intertek_marker_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_inteterk_marker_info_original_name in archive." };
                $c->detach();
            }
            $archived_marker_info_file = $intertek_marker_path;
            unlink $upload_inteterk_marker_info_tempfile;
        } elsif ($archived_intertek_marker_info_file_id) {
            my $archived_intertek_marker = CXGN::File->new({
                file_id => $archived_intertek_marker_info_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_marker_info_file = $archived_intertek_marker->get_path();
        }
    }

    if ($upload_ssr_data || $archived_ssr_file_id) {
        $genotype_file_type = 'genotype_data_ssr';
        $subdirectory = "ssr_data_upload";
        $parser_plugin = 'SSRExcel';

        if ($upload_ssr_data) {
            $upload_original_name = $upload_ssr_data->filename();
            $upload_tempfile = $upload_ssr_data->tempname;

            my $ssr_uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => $genotype_file_type,
                metadata_schema => $metadata_schema
            });
            ($archived_main_file_id, $archived_filename_with_path) = $ssr_uploader->archive();
            my $md5 = $ssr_uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
        } else {
            my $archived_ssr = CXGN::File->new({
                file_id => $archived_ssr_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_filename_with_path = $archived_ssr->get_path();
            $archived_main_file_id = $archived_ssr_file_id;
        }
    }

    if ($upload_kasp_genotypes || $archived_kasp_file_id) {
        $genotype_file_type = 'genotype_data_kasp';
        $subdirectory = "genotype_kasp_upload";
        $parser_plugin = 'KASP';

        if ($upload_kasp_genotypes) {
            $upload_original_name = $upload_kasp_genotypes->filename();
            $upload_tempfile = $upload_kasp_genotypes->tempname;

            my $kasp_uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => $genotype_file_type,
                metadata_schema => $metadata_schema
            });
            ($archived_main_file_id, $archived_filename_with_path) = $kasp_uploader->archive();
            my $md5 = $kasp_uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
        } else {
            my $archived_kasp = CXGN::File->new({
                file_id => $archived_kasp_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_filename_with_path = $archived_kasp->get_path();
            $archived_main_file_id = $archived_kasp_file_id;
        }

        if ($upload_kasp_marker_info) {
            my $upload_kasp_marker_info_original_name = $upload_kasp_marker_info->filename();
            my $upload_kasp_marker_info_tempfile = $upload_kasp_marker_info->tempname();

            my $kasp_marker_uploader = CXGN::UploadFile->new({
                tempfile => $upload_kasp_marker_info_tempfile,
                subdirectory => $subdirectory,
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_kasp_marker_info_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                file_type => 'genotype_data_kasp_marker_info',
                metadata_schema => $metadata_schema
            });
            my ($kasp_marker_file_id, $kasp_marker_path) = $kasp_marker_uploader->archive();
            my $md5 = $kasp_marker_uploader->get_md5($kasp_marker_path);
            if (!$kasp_marker_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_kasp_marker_info_original_name in archive." };
                $c->detach();
            }
            $archived_marker_info_file = $kasp_marker_path;
            unlink $upload_kasp_marker_info_tempfile;
        } elsif ($archived_kasp_marker_info_file_id) {
            my $archived_kasp_marker = CXGN::File->new({
                file_id => $archived_kasp_marker_info_file_id,
                metadata_schema => $metadata_schema,
                archive_path => $c->config->{archive_path}
            });
            $archived_marker_info_file = $archived_kasp_marker->get_path();
        }
    }


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

    my $organism_id;
    if ($organism_species) {
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
        $organism_id = $found_organisms[0];
    } else {
	print STDERR "organism species not defined\n";
    }

    # Nothing recognizable was uploaded. Submitting a job for it would only produce a background
    # failure that is harder to read than saying so here.
    if (!$genotype_file_type || !$archived_filename_with_path || !$parser_plugin) {
        $c->stash->{rest} = { error => 'You must upload a genotype data file!' };
        $c->detach();
    }

    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $basepath = $c->config->{basepath};
    my $archive_path = $c->config->{archive_path};
    my $tempfiles_subdir = $c->config->{tempfiles_subdir};

    # Everything that describes the upload goes on the job rather than on the command line. Most of
    # it is text the uploader typed, which does not belong in a shell string, and the design of a
    # protocol would not fit on one anyway.
    my $upload_params = {
        parser_plugin => $parser_plugin,
        genotype_file_type => $genotype_file_type,
        archived_filename => $archived_filename_with_path,
        archived_marker_info_file => $archived_marker_info_file,
        tassel_hdf5_file => $tassel_hdf5_file,
        rootpath => $c->config->{rootpath},
        user_id => $user_id,
        obs_type => $obs_type,
        organism_id => $organism_id,
        organism_species => $organism_species,
        add_accessions => $add_accessions,
        add_markers => $add_markers,
        include_igd_numbers => $include_igd_numbers,
        include_lab_numbers => $include_lab_numbers,
        accept_warnings => $accept_warnings,
        project_id => $project_id,
        protocol_id => $protocol_id,
        genotyping_facility => $genotyping_facility,
        breeding_program_id => $breeding_program_id,
        year => $year,
        location_id => $location_id,
        project_name => $project_name,
        description => $description,
        protocol_name => $protocol_name,
        protocol_description => $protocol_description,
        reference_genome_name => $reference_genome_name,
        assay_type => $assay_type
    };

    # __SP_JOB_ID__ is filled in by CXGN::Job when the job is submitted, so that the script can
    # report its messages back to this job, and can read the upload it is to run off it.
    my $cmd = "perl \"$basepath/bin/upload_genotype_data.pl\" -H \"$dbhost\" -D \"$dbname\" -U \"$dbuser\" -P \"$dbpass\" -w \"$basepath\" -ap \"$archive_path\" -tf \"$tempfiles_subdir\" -j __SP_JOB_ID__";

    my $upload_job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $user_id,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        basepath => $basepath,
        cmd => $cmd,
        name => basename($archived_filename_with_path)." genotype data upload",
        job_type => 'upload',
        submit_page => ($c->req->referer ? $c->req->referer->as_string : undef),
        additional_args => {
            final_upload => 1,
            file_type => $genotype_file_type,
            user_name => "$user_first_name $user_last_name",
            file_id => $archived_main_file_id,
            upload_params => $upload_params
        }
    });

    my $submit_error;
    try {
        $upload_job->submit();
    } catch {
        $submit_error = $_;
    };
    if ($submit_error) {
        $c->stash->{rest} = { error => "Could not submit the genotype data upload: $submit_error" };
        $c->detach();
    }

    if ($from_upload_manager) {
        $c->stash->{rest} = { success => 1, job_id => $upload_job->sp_job_id() };
        $c->detach();
    }

    $upload_job->wait();

    # The script reports its results by writing them to the job, so they have to be read back from
    # the database rather than from the object that submitted it. The answer the dialog gets is
    # recorded whole, so that a file that was waited on reads exactly the same as it used to.
    my $finished_job = CXGN::Job->new({
        sp_job_id => $upload_job->sp_job_id(),
        schema => $schema,
        people_schema => $people_schema
    });
    my $job_args = $finished_job->additional_args() || {};
    print STDERR Dumper $job_args->{result};
    print STDERR Dumper $job_args->{success_messages};
    print STDERR Dumper $job_args->{warning_messages};
    print STDERR Dumper $job_args->{error_messages};

    if (!$job_args->{result}) {
        # The job left the queue without recording an outcome, which happens if the script died
        # before it could report anything.
        $c->stash->{rest} = { error => "The genotype data upload did not report a result. Check the status of upload job ".$upload_job->sp_job_id()."." };
        $c->detach();
    }

    $c->stash->{rest} = $job_args->{result};
}

1;
