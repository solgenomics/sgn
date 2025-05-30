
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingProtocol - a REST controller class to provide genotyping protocol search

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::GenotypingProtocol;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::MarkersSearch;
use JSON;
use CXGN::Tools::Run;
use CXGN::Genotype::ProtocolProp;
use CXGN::BreedersToolbox::Projects;
use CXGN::Genotype::ParseUpload;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

sub genotyping_protocol_delete : Path('/ajax/genotyping_protocol/delete') : ActionClass('REST') { }

sub genotyping_protocol_delete_GET : Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;

    #print STDERR Dumper $c->req->params();
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to delete genotype info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to delete genotype info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to delete genotypes! Please contact us.' };
        $c->detach();
    }

    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $basepath = $c->config->{basepath};
    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};

    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my $q = "SELECT nd_experiment_id, genotype_id
        FROM genotype
        JOIN nd_experiment_genotype USING(genotype_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        WHERE nd_protocol_id = $protocol_id AND nd_experiment.type_id = $geno_cvterm_id;
    ";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();

    my %genotype_ids_and_nd_experiment_ids_to_delete;
    while (my ($nd_experiment_id, $genotype_id) = $h->fetchrow_array()) {
        push @{$genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}}, $genotype_id;
        push @{$genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}, $nd_experiment_id;
    }

    # Cascade will delete from genotypeprop
    if ($genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}->[0]) {
        my $genotype_id_sql = join (",", @{$genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}});

        my $del_geno_q = "DELETE from genotype WHERE genotype_id IN ($genotype_id_sql);";
        my $h_del_geno = $bcs_schema->storage->dbh()->prepare($del_geno_q);
        $h_del_geno->execute();
    }

    # Cascade will delete from nd_protocolprop
    my $del_geno_prot_q = "DELETE from nd_protocol WHERE nd_protocol_id=?;";
    my $h_del_geno_prot = $bcs_schema->storage->dbh()->prepare($del_geno_prot_q);
    $h_del_geno_prot->execute($protocol_id);

    # Delete nd_experiment_md_files entries linking genotypes to archived genotyping upload file
    # e.g. original VCF

    if ($genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}->[0]) {
        my $nd_experiment_id_sql = join (",", @{$genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}});
        my $q_nd_exp_files_delete = "DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id IN ($nd_experiment_id_sql);";
        my $h3 = $bcs_schema->storage->dbh()->prepare($q_nd_exp_files_delete);
        $h3->execute();


        # Delete from nd_experiment asynchronously because it takes long
        my $dir = $c->tempfiles_subdir('/genotype_data_delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = "$basepath/".$c->tempfile( TEMPLATE => 'genotype_data_delete_nd_experiment_ids/fileXXXX');
        open (my $fh, "> :encoding(UTF-8)", $temp_file_nd_experiment_id ) || die ("\nERROR: the file $temp_file_nd_experiment_id could not be found\n" );
        foreach (@{$genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}) {
            print $fh "$_\n";
        }
        close($fh);
        my $async_delete = CXGN::Tools::Run->new();
        $async_delete->run_async("perl $basepath/bin/delete_nd_experiment_entries.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -i $temp_file_nd_experiment_id");
    }
    # Rebuild and refresh the materialized_markerview table
    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl $basepath/bin/refresh_materialized_markerview.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass");

    $c->stash->{rest} = { success => 1 };
}


sub genotyping_protocol_details : Path('/ajax/genotyping_protocol/details') : ActionClass('REST') { }

sub genotyping_protocol_details_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $session_id = $c->req->param("sgn_session_id");
    my $protocol_id = $c->req->param("protocol_id");
    my @categories = $c->req->param("categories[]");
    my $details = {};
    foreach my $category (@categories) {
      $details->{$category} = $c->req->param("details[$category]");
    }

    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to edit genotyping protocol'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to edit genotyping protocol'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'submitter' && $user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to edit genotyping protocol! Please contact us.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my @protocol_list = ($protocol_id);
    my $protocol_info = CXGN::Genotype::Protocol::list($schema, \@protocol_list, , , , , );
    my $project_id = $protocol_info->[0]->{'project_id'};
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    my $program_ref = $program_object->get_breeding_programs_by_trial($project_id);

    my $program_array = @$program_ref[0];
    my $breeding_program_name = @$program_array[1];
    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    if (! ( (exists($has_roles{$breeding_program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
      $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $breeding_program_name to change the details of this protocol." };
      $c->detach();
    }

    my $new_protocol_name;
    my $new_reference_genome_name;
    my $new_species_name;
    if ($details->{name}) {
        $new_protocol_name = $details->{name};
        my $existing_protocol_name = $schema->resultset("NaturalDiversity::NdProtocol")->find({
            name => $new_protocol_name
        });
        if ($existing_protocol_name) {
            print STDERR "Can't use this new protocol name: Protocol name already exists\n";
            $c->stash->{rest} = {error => "New protocol name not saved: Protocol name already exists"};
            $c->detach();
        }
    }

    if ($details->{reference_genome_name}) {
        $new_reference_genome_name = $details->{reference_genome_name};
    }

    if ($details->{species_name}) {
        $new_species_name = $details->{species_name};

        my $organism_q = "SELECT organism_id FROM organism WHERE species = ?";
        my @found_organisms;
        my $h = $schema->storage->dbh()->prepare($organism_q);
        $h->execute($new_species_name);
        while (my ($organism_id) = $h->fetchrow_array()){
            push @found_organisms, $organism_id;
        }
        if (scalar(@found_organisms) == 0){
            $c->stash->{rest} = { error => 'The species name you provided is not in the database! Please contact us.' };
            $c->detach();
        }
        if (scalar(@found_organisms) > 1){
            $c->stash->{rest} = { error => 'The species name you provided is not unique in the database! Please contact us.' };
            $c->detach();
        }

    }

    my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $protocolprop_rs = $schema->resultset('NaturalDiversity::NdProtocolprop')->find({'nd_protocol_id' => $protocol_id, 'type_id' => $protocol_vcf_details_cvterm_id});
    my $protocolprop_id = $protocolprop_rs->nd_protocolprop_id();

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });

    my $protocolprop = CXGN::Genotype::ProtocolProp->new({
        bcs_schema => $schema,
        parent_id => $protocol_id,
        prop_id => $protocolprop_id
    });

    if ($new_reference_genome_name) {
        $protocolprop->reference_genome_name($new_reference_genome_name);
    }
    if ($new_species_name) {
        $protocolprop->species_name($new_species_name);
    }

    eval {
        if ($details->{name}) {
            $protocol->set_name($details->{name});
        }
         if ($details->{description}) {
            $protocol->set_description($details->{description});
        }
        if ($new_reference_genome_name || $new_species_name) {
            $protocolprop->store();
        }
    };

    if ($@) {
        $c->stash->{rest} = { error => "An error occurred setting the new protocol details: $@" };
    }
    else {
        $c->stash->{rest} = { success => 1 };
    }

}


sub genotyping_protocol_upload_mla : Path('/ajax/genotyping_protocol/add_major_loci_alleles') : ActionClass('REST') { }

sub genotyping_protocol_upload_mla_POST : Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $upload = $c->req->upload('upload_mla_file');
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my (@errors, %response);

    if (!$c->user()) {
        print STDERR "User not logged in... not uploading mla.\n";
        push @errors, "You need to be logged in to upload major loci alleles.";
        $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => 'mla_upload',
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

    ## Store uploaded temporary file in archive
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @errors, "Could not save file $upload_original_name in archive";
        $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
        return;
    }
    unlink $upload_tempfile;

    # Validate the upload file
    my $parser = CXGN::Genotype::ParseUpload->new({
        chado_schema => $schema,
        filename => $archived_filename_with_path,
        observation_unit_type_name => 'marker',
        nd_protocol_id => $protocol_id,
        major_locus_trait_ontology_root => $c->config->{major_locus_trait_ontology_root}
    });
    $parser->load_plugin('MajorLociAlleles');
    my $parsed_data = $parser->parse();
    my $parse_errors = $parser->get_parse_errors();

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            return;
        } else {
            $parse_errors = $parser->get_parse_errors();
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."\n";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        return;
    }

    # Store the allele information
    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id,
        sp_person_id => $user_id
    });
    $protocol->set_alleles($parsed_data);

    $c->stash->{rest} = { success => 1 };
    return;
}

sub genotyping_protocol_get_mla : Path('/ajax/genotyping_protocol/get_major_loci_alleles') : ActionClass('REST') { }

sub genotyping_protocol_get_mla_GET : Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;
    my $marker_name = $c->req->param("marker_name");
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Get the allele information
    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });
    my $alleles = $protocol->get_alleles($marker_name);

    $c->stash->{rest} = $alleles || {};
    return;
}

sub locus_marker_autocomplete : Path('/ajax/genotyping_protocol/locus_marker_autocomplete') : ActionClass('REST') { }

sub locus_marker_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $protocol_id = $c->req->param('protocol_id');
    $protocol_id =~ s/(^\s+|\s+)$//g;
    $protocol_id =~ s/\s+/ /g;

    my $term = $c->req->param('term');
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "SELECT DISTINCT marker_name
        FROM phenome.locus_geno_marker
        WHERE nd_protocol_id = ?
        AND marker_name ILIKE ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($protocol_id, '%'.$term.'%');
    while (my ($marker) = $sth->fetchrow_array ) {
        push @response_list, $marker;
    }

    $c->stash->{rest} = \@response_list;
}


1;
