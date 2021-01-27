use strict;

package SGN::Controller::AJAX::SequenceMetadata;

use Moose;
use JSON;
use File::Basename;

use CXGN::UploadFile;
use CXGN::Genotype::SequenceMetadata;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

#
# Get a list of the maps from the database and their associated organisms
# PATH: GET /ajax/sequence_metadata/reference_genomes
# 
sub get_reference_genomes : Path('/ajax/sequence_metadata/reference_genomes') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Get map and organism info
    my $q = "SELECT map.map_id, map.short_name, map.long_name, map.map_type, map.units, p1o.abbreviation AS parent1_abbreviation, p1o.genus AS parent1_genus, p1o.species AS parent1_species, p2o.abbreviation AS parent2_abbreviation, p2o.genus AS parent2_genus, p2o.species AS parent2_species FROM sgn.map LEFT JOIN public.stock AS p1s ON (p1s.stock_id = map.parent1_stock_id) LEFT JOIN public.organism AS p1o ON (p1o.organism_id = p1s.organism_id) LEFT JOIN public.stock AS p2s ON (p2s.stock_id = map.parent2_stock_id) LEFT JOIN public.organism AS p2o ON (p2o.organism_id = p2s.organism_id);";
    my $h = $dbh->prepare($q);
    $h->execute();

    my @results = ();
    while ( my ($map_id, $short_name, $long_name, $map_type, $units, $p1_abb, $p1_genus, $p1_species, $p2_abb, $p2_genus, $p2_species) = $h->fetchrow_array()  ) {
        my %result = (
            map_id => $map_id,
            short_name => $short_name,
            long_name => $long_name,
            map_type => $map_type,
            units => $units,
            parent1_abbreviation => $p1_abb,
            parent1_genus => $p1_genus,
            parent1_species => $p1_species,
            parent2_abbreviation => $p2_abb,
            parent2_genus => $p2_genus,
            parent2_species => $p2_species
        );
        push(@results, \%result);
    }

    $c->stash->{rest} = {
        maps => \@results
    };
}

#
# Process the gff file upload and perform file verification
# PATH: POST /ajax/sequence_metadata/file_upload_verify
# PARAMS:
#   - file = upload file
#
sub sequence_metadata_upload_verify : Path('/ajax/sequence_metadata/file_upload_verify') : ActionClass('REST') { }
sub sequence_metadata_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my @params = $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    use Data::Dumper;
    print STDERR "FILE UPLOAD VERIFY:\n";
    print STDERR Dumper \@params;

    # Check Logged In Status
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to do this!'};
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();
    if ( $user_role ne 'submitter' && $user_role ne 'curator' ) {
        $c->stash->{rest} = {error => 'You do not have permission in the database to do this! Please contact us.'};
        $c->detach();
    }

    # Archive upload file
    my $upload = $c->req->upload('file');
    if ( !defined $upload || $upload eq '' ) {
        $c->stash->{rest} = {error => 'You must provide the upload file!'};
        $c->detach();
    }
    else {
        my $upload_original_name = $upload->filename();
        my $upload_tempfile = $upload->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        my $subdirectory = "sequence_metadata_upload";

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filepath = $uploader->archive();
        my $processed_filepath = $archived_filepath . ".processed";

        # Run the verification
        my $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema);
        my $verification_results = $smd->verify($archived_filepath, $processed_filepath);
        $verification_results->{'processed_filepath'} = $processed_filepath;

        # Verification Error
        if ( defined $verification_results->{'error'} ) {
            $c->stash->{rest} = {error => $verification_results->{'error'}};
            $c->detach();
        }

        # Verification Results
        $c->stash->{rest} = {
            success => $verification_results
        };
    }
}


#
# Process the sequence metadata protocol info and store the previously uploaded gff file
# PATH: POST /ajax/sequence_metadata/store
# PARAMS:
#   - processed_filepath = path to previously uploaded and processed file
#   - use_existing_protocol = true (use existing protocol) / false (create new protocol)
#   - existing_protocol_id = nd_protocol_id of existing protocol to use
#   - new_protocol_name = name of new protocol
#   - new_protocol_description = description of new protocol
#   - new_protocol_sequence_metadata_type = cvterm id of sequence metadata type
#   - new_protocol_reference_genome = map id of reference genome
#   - new_protocol_score_description = description of score field
#   - new_protocol_attribute_count = max number of attributes to read (some may be missing if an attribute was removed)
#   - new_protocol_attribute_key_{n} = key name of nth attribute
#   - new_protocol_attribute_description_{n} = description of nth attribute
#
sub sequence_metadata_store : Path('/ajax/sequence_metadata/store') : ActionClass('REST') { }
sub sequence_metadata_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my @params = $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $sgn_schema = $c->dbic_schema("SGN::Schema");
    my $dbh = $schema->storage->dbh();

    use Data::Dumper;
    print STDERR "Store:\n";
    print STDERR Dumper \@params;

    # Check Logged In Status
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to do this!'};
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $user_role = $c->user->get_object->get_user_type();
    if ( $user_role ne 'submitter' && $user_role ne 'curator' ) {
        $c->stash->{rest} = {error => 'You do not have permission in the database to do this! Please contact us.'};
        $c->detach();
    }

    # Information required for the load script
    my $processed_filepath = $c->req->param('processed_filepath');
    my $protocol_id = undef;
    my $type_id = undef;

    # Check for processed filepath
    if ( !defined $processed_filepath || $processed_filepath eq '' ) {
        $c->stash->{rest} = {error => 'The path to the previously processed and verified file must be defined!'};
        $c->detach();
    }
    
    # Create new protocol, if requested
    if ( $c->req->param('use_existing_protocol') eq 'false' ) {
        print STDERR "CREATING NEW PROTOCOL:\n";
        
        my $protocol_name = $c->req->param('new_protocol_name');
        my $protocol_description = $c->req->param('new_protocol_description');
        my $protocol_sequence_metadata_type_id = $c->req->param('new_protocol_sequence_metadata_type');
        my $protocol_reference_genome_map_id = $c->req->param('new_protocol_reference_genome');
        my $protocol_score_description = $c->req->param('new_protocol_score_description');
        my $protocol_attribute_count = $c->req->param('new_protocol_attribute_count');
        if ( !defined $protocol_name || $protocol_name eq '' ) {
            $c->stash->{rest} = {error => 'The new protocol name must be defined!'};
            $c->detach();
        }
        if ( !defined $protocol_description || $protocol_description eq '' ) {
            $c->stash->{rest} = {error => 'The new protocol description must be defined!'};
            $c->detach();
        }
        if ( !defined $protocol_sequence_metadata_type_id || $protocol_sequence_metadata_type_id eq '' ) {
            $c->stash->{rest} = {error => 'The new protocol sequence metadata type must be defined!'};
            $c->detach();
        }
        if ( !defined $protocol_reference_genome_map_id || $protocol_reference_genome_map_id eq '' ) {
            $c->stash->{rest} = {error => 'The new protocol reference genome must be defined!'};
            $c->detach();
        }

        my $sequence_metadata_type_cvterm = $schema->resultset('Cv::Cvterm')->find({ cvterm_id => $protocol_sequence_metadata_type_id });
        if ( !defined $sequence_metadata_type_cvterm ) {
            $c->stash->{rest} = {error => 'Could not find matching CVTerm for sequence metadata type!'};
            $c->detach();
        }
        my $reference_genome_map = $sgn_schema->resultset('Map')->find({ map_id => $protocol_reference_genome_map_id });
        if ( !defined $reference_genome_map ) {
            $c->stash->{rest} = {error => 'Could not find matching Map for reference genome!'};
            $c->detach();
        }

        my %sequence_metadata_protocol_props = (
            sequence_metadata_type_id => $protocol_sequence_metadata_type_id,
            sequence_metadata_type => $sequence_metadata_type_cvterm->name(),
            reference_genome_map_id => $protocol_reference_genome_map_id,
            reference_genome => $reference_genome_map->get_column('short_name')
        );
        if ( defined $protocol_score_description && $protocol_score_description ne '' ) {
            $sequence_metadata_protocol_props{'score_description'} = $protocol_score_description;
        }
        my %attributes = ();
        if ( defined $protocol_attribute_count && $protocol_attribute_count ne '' ) {
            for ( my $i = 1; $i <= $protocol_attribute_count; $i++ ){
                my $attribute_key = $c->req->param('new_protocol_attribute_key_' . $i);
                my $attribute_description = $c->req->param('new_protocol_attribute_description_' . $i);
                if ( defined $attribute_key && $attribute_key ne '' && $attribute_key ne 'undefined' ) {
                    if ( defined $attribute_description && $attribute_description ne '' && $attribute_description ne 'undefined' ) {
                        $attributes{$attribute_key} = $attribute_description;
                    }
                }
            }
        }
        $sequence_metadata_protocol_props{'attribute_descriptions'} = \%attributes;
        
        my $sequence_metadata_protocol_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sequence_metadata_protocol', 'protocol_type')->cvterm_id();
        my $sequence_metadata_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sequence_metadata_protocol_properties', 'protocol_property')->cvterm_id();
        my $protocol = $schema->resultset('NaturalDiversity::NdProtocol')->create({
            name => $protocol_name,
            type_id => $sequence_metadata_protocol_type_id,
            nd_protocolprops => [{type_id => $sequence_metadata_protocol_prop_cvterm_id, value => encode_json \%sequence_metadata_protocol_props}]
        });
        $protocol_id = $protocol->nd_protocol_id();
        
        my $sql = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
        my $sth = $dbh->prepare($sql);
        $sth->execute($protocol_description, $protocol_id);

        $type_id = $protocol_sequence_metadata_type_id;
    }

    $c->stash->{rest} = {
        success => "Yes",
        error => ()
    };
}
