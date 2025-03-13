use strict;

package SGN::Controller::AJAX::SequenceMetadata;

use Moose;
use JSON;
use File::Basename;

use CXGN::UploadFile;
use SGN::Model::Cvterm;
use CXGN::Genotype::SequenceMetadata;
use CXGN::Genotype::Protocol;
use CXGN::Marker::SearchMatView;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


#
# Get all of the features associated with sequence metadata
# PATH: GET /ajax/sequence_metadata/features
# RETURNS:
#   - features: an array of features associated with sequence metadata
#       - feature_id: database id of feature
#       - feature_name: name of feature
#       - type_id: cvterm id of feature type
#       - type_name: cvterm name of feature type
#       - organism_id: database id of organism associated with the feature
#       - organism_name: genus and species name of organism
#
sub get_features : Path('/ajax/sequence_metadata/features') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Get features used by sequence metadata
    my $q = "SELECT feature.feature_id, feature.name AS feature_name, feature.type_id, cvterm.name AS type_name, 
                feature.organism_id, organism.genus AS organism_genus, REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '') AS organism_species
            FROM public.feature
            LEFT JOIN public.organism ON (organism.organism_id = feature.organism_id)
            LEFT JOIN public.cvterm ON (cvterm.cvterm_id = feature.type_id)
            WHERE feature_id IN (SELECT DISTINCT(feature_id) FROM public.featureprop_json)
            ORDER BY feature.name ASC;";
    my $h = $dbh->prepare($q);
    $h->execute();

    # Parse features into response
    my @results = ();
    while ( my ($feature_id, $feature_name, $type_id, $type_name, $organism_id, $organism_genus, $organism_species) = $h->fetchrow_array() ) {
        my %result = (
            feature_id => $feature_id, 
            feature_name => $feature_name,
            type_id => $type_id, 
            type_name => $type_name,
            organism_id => $organism_id,
            organism_name => $organism_genus . " " . $organism_species
        );
        push(@results, \%result);
    }

    # Return results
    $c->stash->{rest} = {
        features => \@results
    };
}


#
# Get all of the sequence metadata data types
# PATH: GET /ajax/sequence_metadata/types
# RETURNS:
#   - types: an array of sequence metadata data types
#       - type_id: cvterm id of type
#       - type_name: cvterm name of type
#       - type_definition: cvterm definition of type
#
sub get_types : Path('/ajax/sequence_metadata/types') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Get types used by sequence metadata
    my $q = "SELECT cvterm_id, name, definition
FROM public.cvterm
WHERE cv_id = (SELECT cv_id FROM public.cv WHERE name = 'sequence_metadata_types');";
    my $h = $dbh->prepare($q);
    $h->execute();

    # Parse types into response
    my @results = ();
    while ( my ($id, $name, $definition) = $h->fetchrow_array() ) {
        my %result = (
            type_id => $id, 
            type_name => $name,
            type_definition => $definition
        );
        push(@results, \%result);
    }

    # Return results
    $c->stash->{rest} = {
        types => \@results
    };
}


#
# Get all of the sequence metadata protocols
# PATH: GET /ajax/sequence_metadata/protocols
# RETURNS:
#   - protocols: an array of sequence metadata protocols
#       - nd_protocol_id: database id of the protocol
#       - nd_protocol_name: name of protocol
#       - nd_protocol_description: description of protocol
#       - nd_protocol_properties: additional properties of protocol
#
sub get_protocols : Path('/ajax/sequence_metadata/protocols') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Get protocols used by sequence metadata
    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocolprop.value AS properties
FROM public.nd_protocol
LEFT JOIN public.nd_protocolprop ON (nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id)
LEFT JOIN public.cvterm ON (nd_protocolprop.type_id = cvterm.cvterm_id)
WHERE nd_protocol.type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'sequence_metadata_protocol' AND cv_id = (SELECT cv_id FROM public.cv WHERE name = 'protocol_type'))
AND cvterm.name = 'sequence_metadata_protocol_properties'
ORDER BY name;";
    my $h = $dbh->prepare($q);
    $h->execute();

    # Parse protocols into response
    my @results = ();
    while ( my ($id, $name, $description, $props_json) = $h->fetchrow_array() ) {
        my $props = decode_json $props_json;
        my %result = (
            nd_protocol_id => $id, 
            nd_protocol_name => $name,
            nd_protocol_description => $description,
            nd_protocol_properties => $props
        );
        push(@results, \%result);
    }

    # Return results
    $c->stash->{rest} = {
        protocols => \@results
    };
}



#
# Process the gff file upload and perform file verification
# PATH: POST /ajax/sequence_metadata/file_upload_verify
# PARAMS:
#   - file = (required) upload file
#   - species = (required) name of the species to use when matching chromosome names to features (must match the feature organism name)
#   - use_existing_protocol = (required) 'true'/'false' if file is using an existing protocol (or creating a new one)
#   - existing_protocol_id = (required if use_existing_protocol is 'true') nd_protocol_id of existing protocol
#   - new_protocol_attribute_count = (required if use_existing_protocol is 'false') the number of attributes to be added to the new protocol
#   - new_protocol_attribute_key_{i} = (required if use_existing_protocol is 'false') the name of each attribute to be added to the new protocol
# RETURNS:
#   - error = error message
#   - results = verification results
#       - processed_filepath = server filepath to processed file
#       - processed = 1 if file successfully uploaded and processed / 0 if not
#       - verified = 1 if file sucessfully verified / 0 if not
#       - missing_features = list of seqid's not in the database as features
#       - missing_attributes = list of attributes in the protocol that are not in the uploaded file
#       - undefined_attributes = list attributes in the uploaded file not defined by the protocol
#
sub sequence_metadata_upload_verify : Path('/ajax/sequence_metadata/file_upload_verify') : ActionClass('REST') { }
sub sequence_metadata_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my @params = $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Check Logged In Status
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to do this!'};
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();
    #if ( $user_role ne 'submitter' && $user_role ne 'curator' ) {
    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "loci")) { 
        $c->stash->{rest} = {error => 'You do not have permission in the database to do this! Please contact us.'};
        $c->detach();
    }

    # Check for uploaded file
    my $upload = $c->req->upload('file');
    if ( !defined $upload || $upload eq '' ) {
        $c->stash->{rest} = {error => 'You must provide the upload file!'};
        $c->detach();
    }

    # Set file paths
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = "sequence_metadata_upload";

    # Upload and Archive file
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

    # Get protocol attributes to verify...
    my @attributes = ();
    my $use_existing_protocol = $c->req->param('use_existing_protocol');
    if ( !defined $use_existing_protocol || $use_existing_protocol eq '' ) {
        $c->stash->{rest} = {error => 'use_existing_protocol not provided!'};
        $c->detach();
    }

    # Set species via existing protocol or new protocol species param
    my $species = "";

    # Using an existing protocol...
    if ( $use_existing_protocol eq 'true' ) {

        # Get exisiting protocol id
        my $protocol_id = $c->req->param('existing_protocol_id');
        if ( !defined $protocol_id || $protocol_id eq '' ) {
            $c->stash->{rest} = {error => 'protocol_id not provided!'};
            $c->detach();
        }

        # Get attributes from protocol props
        my $smd_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sequence_metadata_protocol_properties', 'protocol_property')->cvterm_id();
        my $protocol_props = decode_json $schema->resultset('NaturalDiversity::NdProtocolprop')->search({nd_protocol_id=>$protocol_id, type_id=>$smd_protocol_prop_cvterm_id})->first->value;
        my $attribute_descriptions = $protocol_props->{attribute_descriptions};
        @attributes = keys %$attribute_descriptions;

        # Get species from the features of the protocol
        my $q = "SELECT DISTINCT(CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), ''))) AS species
                FROM public.feature 
                LEFT JOIN public.organism USING (organism_id)
                WHERE feature_id IN (
                    SELECT feature_id FROM featureprop_json WHERE nd_protocol_id = ?
                );";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($protocol_id);
        ($species) = $h->fetchrow_array();
        
    }

    # Adding new protocol...
    else {

        # Get new protocol attributes
        my $protocol_attribute_count = $c->req->param('new_protocol_attribute_count');
        if ( !defined $protocol_attribute_count || $protocol_attribute_count eq '' ) {
            $c->stash->{rest} = {error => 'protocol_attribute_count not provided!'};
            $c->detach();
        }
        for ( my $i = 1; $i <= $protocol_attribute_count; $i++ ){
            my $attribute_key = $c->req->param('new_protocol_attribute_key_' . $i);
            if ( defined $attribute_key && $attribute_key ne '' && $attribute_key ne 'undefined' ) {
                push(@attributes, $attribute_key);
            }
        }

        # Get new protocol species
        $species = $c->req->param('species');
        if ( !defined $species || $species eq '' ) {
            $c->stash->{rest} = {error => 'species name not provided!'};
            $c->detach();
        }

    }

    # Run the verification
    my $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema);
    my $verification_results = $smd->verify($archived_filepath, $processed_filepath, $species, \@attributes);
    $verification_results->{'processed_filepath'} = $processed_filepath;

    # Verification Error
    if ( defined $verification_results->{'error'} ) {
        $c->stash->{rest} = {error => $verification_results->{'error'}};
        $c->detach();
    }

    # Verification Results
    $c->stash->{rest} = { results => $verification_results };
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
#   - new_protocol_reference_genome = name of reference genome
#   - new_protocol_species = name of species
#   - new_protocol_score_description = description of score field
#   - new_protocol_attribute_count = max number of attributes to read (some may be missing if an attribute was removed)
#   - new_protocol_attribute_key_{n} = key name of nth attribute
#   - new_protocol_attribute_description_{n} = description of nth attribute
#   - new_protocol_link_count = max number of links to read (some may be missing if a link was removed)
#   - new_protocol_link_title_{n} = title of nth external link
#   - new_protocol_link_url_{n} = URL template of nth external link
# RETURNS:
#   - error: error message
#   - results: store results
#       - stored: 0 if storing failed, 1 if it succeeds
#       - nd_protocol_id: the id of the (new or existing) nd_protocol
#       - chunks: the number of chunks stored
#
sub sequence_metadata_store : Path('/ajax/sequence_metadata/store') : ActionClass('REST') { }
sub sequence_metadata_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my @params = $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $sgn_schema = $c->dbic_schema("SGN::Schema");
    my $dbh = $schema->storage->dbh();

    # Check Logged In Status
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to do this!'};
        $c->detach();
    }
    my $user_role = $c->user->get_object->get_user_type();
    #if ( $user_role ne 'submitter' && $user_role ne 'curator' ) {
    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "loci")) { 
        $c->stash->{rest} = {error => 'You do not have permission in the database to do this! Please contact us.'};
        $c->detach();
    }

    # Information required for the load script
    my $processed_filepath = $c->req->param('processed_filepath');
    my $protocol_id = undef;
    my $type_id = undef;
    my $species = undef;

    # Check for processed filepath
    if ( !defined $processed_filepath || $processed_filepath eq '' ) {
        $c->stash->{rest} = {error => 'The path to the previously processed and verified file must be defined!'};
        $c->detach();
    }

    # SMD Object for creating new protocol and storing data
    my $smd;
    
    # Create new protocol, if requested
    if ( $c->req->param('use_existing_protocol') eq 'false' ) {
        my $protocol_name = $c->req->param('new_protocol_name');
        my $protocol_description = $c->req->param('new_protocol_description');
        my $protocol_sequence_metadata_type_id = $c->req->param('new_protocol_sequence_metadata_type');
        my $protocol_reference_genome = $c->req->param('new_protocol_reference_genome');
        my $protocol_species = $c->req->param('new_protocol_species');
        my $protocol_score_description = $c->req->param('new_protocol_score_description');
        my $protocol_attribute_count = $c->req->param('new_protocol_attribute_count');
        my $protocol_link_count = $c->req->param('new_protocol_link_count');
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
        if ( !defined $protocol_reference_genome || $protocol_reference_genome eq '' ) {
            $c->stash->{rest} = {error => 'The new protocol reference genome must be defined!'};
            $c->detach();
        }
        if ( !defined $protocol_species || $protocol_species eq '' ) {
            $c->stash->{rest} = {error => 'The new protocol species must be defined!'};
            $c->detach();
        }

        # Check validity of sequence metadata type id (exists as cvterm)
        my $sequence_metadata_type_cvterm = $schema->resultset('Cv::Cvterm')->find({ cvterm_id => $protocol_sequence_metadata_type_id });
        if ( !defined $sequence_metadata_type_cvterm ) {
            $c->stash->{rest} = {error => 'Could not find matching CVTerm for sequence metadata type!'};
            $c->detach();
        }

        # Parse attributes
        my %attributes = ();
        if ( defined $protocol_attribute_count && $protocol_attribute_count ne '' ) {
            for ( my $i = 1; $i <= $protocol_attribute_count; $i++ ){
                my $attribute_key = $c->req->param('new_protocol_attribute_key_' . $i);
                my $attribute_description = $c->req->param('new_protocol_attribute_description_' . $i);
                if ( defined $attribute_key && $attribute_key ne '' && $attribute_key ne 'undefined' ) {
                    $attributes{$attribute_key} = $attribute_description;
                }
            }
        }

        # Parse links
        my %links = ();
        if ( defined $protocol_link_count && $protocol_link_count ne '' ) {
            for ( my $i = 1; $i <= $protocol_link_count; $i++ ) {
                my $link_title = $c->req->param('new_protocol_link_title_' . $i);
                my $link_url = $c->req->param('new_protocol_link_url_' . $i);
                if ( defined $link_title && $link_title ne '' && $link_title ne 'undefined' && 
                        defined $link_url && $link_url ne '' && $link_url ne 'undefined' ) {
                    $links{$link_title} = $link_url;
                }
            }
        }

        # Create the Sequence Metadata protocol
        $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema, type_id => $protocol_sequence_metadata_type_id);
        my %protocol_args = (
            protocol_name => $protocol_name,
            protocol_description => $protocol_description,
            reference_genome => $protocol_reference_genome,
            score_description => $protocol_score_description,
            attributes => \%attributes,
            links => \%links
        );
        my $protocol_results = $smd->create_protocol(\%protocol_args);
        if ( $protocol_results->{'error'} ) {
            $c->stash->{rest} = {error => 'Could not create sequence metadata protocol: ' . $protocol_results->{'error'}};
            $c->detach();
        }
        $protocol_id = $protocol_results->{'nd_protocol_id'};

        $type_id = $protocol_sequence_metadata_type_id;
        $species = $protocol_species;
    }

    # Use existing protocol
    else {
        $protocol_id = $c->req->param('existing_protocol_id');
        $type_id = $c->req->param('existing_protocol_sequence_metadata_type');

        if ( !defined $protocol_id || $protocol_id eq '' ) {
            $c->stash->{rest} = {error => 'The existing protocol id must be defined!'};
            $c->detach();
        }
        if ( !defined $type_id || $type_id eq '' ) {
            $c->stash->{rest} = {error => 'The existing protocol sequence metadata type must be defined!'};
            $c->detach();
        }

        # Create SMD with existing protocol id
        $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema, type_id => $type_id, nd_protocol_id => $protocol_id);

        # Get species from the features of the protocol
        my $q = "SELECT DISTINCT(CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), ''))) AS species
                FROM public.feature 
                LEFT JOIN public.organism USING (organism_id)
                WHERE feature_id IN (
                    SELECT feature_id FROM featureprop_json WHERE nd_protocol_id = ?
                );";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($protocol_id);
        ($species) = $h->fetchrow_array();
    }


    # Run the store script
    my $store_results = $smd->store($processed_filepath, $species);
    $store_results->{'nd_protocol_id'} = $protocol_id;
    

    $c->stash->{rest} = { results => $store_results };
}


#
# Perform a query of sequence metadata for a specific feature and range
# PATH: GET /ajax/sequence_metadata/query
# PARAMS:
#   REQUIRED:
#   - feature_id = id of the associated feature
#   OR
#   - feature_name = name of the associated feature
#   - species_name = name of the organism associated with the feature
#   OPTIONAL:
#   - start = start position of the query range (default: 0)
#   - end = end position of the query range (default: feature max)
#   - reference_genome = (required if start or end are provided) = name of referene genome used by start and/or end positions
#   - type_id = cvterm_id(s) of sequence metadata type(s) (comma separated list of multiple type ids)
#   - nd_protocol_id = nd_protocol_id(s) of sequence metadata protocol(s) (comma separated list of multiple protocol ids)
#   - attribute = attribute(s) and their properties (protocol id, comparison, and value - | separated) (comma separated list of multiple attributes)
#       attribute format: 
#           {attribute name}|{protocol id}|{comparison}|{value}
#           where comparison = con, eq, lt, lte, gt, gte
#       examples:
#           attribute=score|12|lt|0
#           attribute=score|12|lt|0,trait|13|eq|yield
#   - format = define the output format
#       - GA4GH: (default) JSON output following Global Alliance for Genomics and Health API format
#       - JSON: JSON output using internal/breedbase format
#       - gff: gff3 format
#   - prepend_chr_to_feature_name = (optional) when set to 1, the feature names will have 'chr' prepended, if not already present
# RETURNS: an array of sequence metadata objects with the following keys:
#   - feature_id = id of associated feature
#   - feature_name = name of associated feature
#   - type_id = cvterm_id of sequence metadata type
#   - type_name = name of sequence metadata type
#   - protocol_id = id of associated nd_protocol
#   - protocol_name = name of associated nd_protocol
#   - start = start position of sequence metadata
#   - end = end position of sequence metadata
#   - score = primary score value of sequence metadata
#   - attributes = hash of secondary key/value attributes
#   - links = hash of external link titles and URLs
#
sub sequence_metadata_query : Path('/ajax/sequence_metadata/query') : ActionClass('REST') { }
sub sequence_metadata_query_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    
    my $feature_id = $c->req->param('feature_id');
    my $feature_name = $c->req->param('feature_name');
    my $species_name = $c->req->param('species_name');
    my $start = $c->req->param('start');
    my $end = $c->req->param('end');
    my $reference_genome = $c->req->param('reference_genome');
    my @type_ids = split(',', $c->req->param('type_id'));
    my @nd_protocol_ids = split(',', $c->req->param('nd_protocol_id'));
    my @attributes = split(',', $c->req->param('attribute'));
    my $format = $c->req->param('format');
    my $prepend_chr_to_feature_name = $c->req->param('prepend_chr_to_feature_name');

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();


    # Check required parameters
    if ( (!defined $feature_id || $feature_id eq '') && (!defined $feature_name && !defined $species_name) ) {
        $c->stash->{rest} = {error => 'Feature id OR Feature name and species name must be provided!'};
        $c->detach();
    }
    if ( (!defined $feature_name || $feature_name eq '' || !defined $species_name || $species_name eq '') && (!defined $feature_id) ) {
        $c->stash->{rest} = {error => 'Feature id OR Feature name and species name must be provided!'};
        $c->detach();
    }
    if ( (!defined $reference_genome || $reference_genome eq '') && (defined $start || defined $end) ) {
        $c->stash->{rest} = {error => 'Reference genome must be provided with start and/or end position!'};
        $c->detach();
    }


    # Parse attribute filters
    my @attributes_parsed = ();
    foreach my $attr (@attributes) {
        my @attr_parts = split(/\|/, $attr);
        my %a = (
            key => $attr_parts[0],
            nd_protocol_id => $attr_parts[1],
            comparison => $attr_parts[2],
            value => $attr_parts[3]
        );
        push(@attributes_parsed, \%a);
    }


    # Get feature id from name and species, if provided
    if ( defined $feature_name && defined $species_name ) {
        my $q = "SELECT feature_id
                    FROM public.feature 
                    LEFT JOIN public.organism USING (organism_id)
                    WHERE uniquename = ?
                    AND CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) = ?;";
        my $h = $dbh->prepare($q);
        $h->execute($feature_name, $species_name);
        ($feature_id) = $h->fetchrow_array();

        if ( !defined $feature_id || $feature_id eq '' ) {
            $c->stash->{rest} = {error => 'No matching feature found [' . $feature_name . ' / ' . $species_name . ']!'};
            $c->detach();
        }
    }


    # Perform query
    my $smd =  CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema);
    my $query = $smd->query({
        feature_id => $feature_id, 
        start => defined $start && $start ne '' ? $start : undef, 
        end => defined $end && $end ne '' ? $end : undef,
        reference_genome => defined $reference_genome && $reference_genome ne '' ? $reference_genome : undef,
        type_ids => @type_ids ? \@type_ids : undef,
        nd_protocol_ids => @nd_protocol_ids ? \@nd_protocol_ids : undef,
        attributes => @attributes_parsed ? \@attributes_parsed : undef
    });


    # Query Error
    if ( exists $query->{'error'} ) {
        $c->stash->{rest} = { error => $query->{'error'} };
        $c->detach();
    }

    # Query Results
    my $results = $query->{'results'};


    # Prepend chr to feature names, if requested
    if ( defined $prepend_chr_to_feature_name && $prepend_chr_to_feature_name eq '1' ) {
        foreach my $result (@$results) {
            if ( $result->{feature_name} !~ /^chr/ ) {
                $result->{feature_name} = 'chr' . $result->{feature_name};
            }
        }
    }


    # GA4GH JSON Format
    if ( $format eq 'GA4GH' ) {
        my @features = ();

        my $count = 0;
        foreach my $item (@$results) {
            my $id = $item->{featureprop_json_id} . '.' . $count;

            my %attributes = ();
            my $ra = $item->{attributes};
            $ra->{score} = $item->{score};
            foreach my $key (keys %$ra) {
                $attributes{$key} = [$ra->{$key}];
            }
            my %bb_metadata = (
                type_id => [$item->{type_id}],
                type_name => [$item->{type_name}],
                nd_protocol_id => [$item->{nd_protocol_id}],
                nd_protocol_name => [$item->{nd_protocol_name}]
            );
            $attributes{'bb_metadata'} = \%bb_metadata;

            my %feature = (
                id => $id,
                parent_id => $item->{feature_id},
                reference_name => $item->{feature_name},
                feature_set_id => $item->{nd_protocol_id},
                start => $item->{start},
                end => $item->{end},
                attributes => \%attributes
            );
            push(@features, \%feature);

            $count++;
        }

        $c->stash->{rest} = { features => \@features };
        $c->detach();
    }

    # GFF Response
    elsif ( $format eq 'gff' ) {
        $c->res->content_type("text/plain");
        $c->res->headers()->header(
            "Content-Disposition" => "filename=sequence_metadata.gff",
            "Access-Control-Allow-Origin" => "*"
        );
        
        my @contents = ();
        foreach my $item (@$results) {
            my @attributes_parsed = ();
            my $attributes = $item->{attributes};
            foreach my $key ( keys %{ $attributes } ) {
                my $value = ${$attributes}{$key};
                if ( $value =~ m/\s/ ) {
                    $value = "\"$value\"";
                }
                push(@attributes_parsed, $key . "=" . $value);
            }
            my @row = (
                $item->{feature_name},
                '.',
                '.',
                $item->{start},
                $item->{end},
                defined $item->{score} && $item->{score} ne '' ? $item->{score} : '.',
                '.',
                '.',
                join(";", @attributes_parsed)
            );
            push(@contents, join("\t", @row));
        }

        $c->res->body(join("\n", @contents));
        $c->detach();
    }

    # Internal/Breedbase JSON Format
    else {
        $c->stash->{rest} = { results => $results };
        $c->detach();
    }
   
}
