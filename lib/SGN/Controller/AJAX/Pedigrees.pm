
package SGN::Controller::AJAX::Pedigrees;

use Moose;
use List::Util qw | any |;
use File::Slurp qw | read_file |;
use Data::Dumper;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddPedigrees;
use CXGN::List::Validate;
use SGN::Model::Cvterm;
use utf8;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub upload_pedigrees_verify : Path('/ajax/pedigrees/upload_verify') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_name;
    my $user_role;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload pedigrees!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user()){
            $c->stash->{rest} = {error=>'You must be logged in to upload pedigrees!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload pedigrees'};
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'pedigree_upload';
    my $upload = $c->req->upload('pedigrees_uploaded_file');
    my $upload_tempfile  = $upload->tempname;
    my $upload_original_name  = $upload->filename();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $md5;

    my $params = {
	tempfile => $upload_tempfile,
	subdirectory => $subdirectory,
	archive_path => $c->config->{archive_path},
	archive_filename => $upload_original_name,
	timestamp => $timestamp,
	user_id => $user_id,
	user_role => $user_role,
    };

    my $uploader = CXGN::UploadFile->new( $params );

    my %upload_metadata;
    my $archived_filename_with_path = $uploader->archive();

    if (!$archived_filename_with_path) {
	$c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
	return;
    }

    $md5 = $uploader->get_md5($archived_filename_with_path);
    unlink $upload_tempfile;

    my $parser = CXGN::Pedigree::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('PedigreesGeneric');
    my $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            $c->detach();
        } else {
            $parse_errors = $parser->get_parse_errors();
            my $error_messages = $parse_errors->{'error_messages'};
            foreach my $error_string (@$error_messages){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    my $pedigree_check = $parsed_data->{'pedigree_check'};
    my $pedigree_data = $parsed_data->{'pedigree_data'};

    my $pedigrees_hash = {};
    $pedigrees_hash->{'pedigrees'} = $pedigree_data;

    my $pedigree_string = encode_json $pedigrees_hash;
    my $pedigree_info = '';
    if ($pedigree_check) {
        foreach my $pedigree (@$pedigree_check){
            $pedigree_info .= $pedigree."<br>";
        }
        $c->stash->{rest} = {error => $pedigree_info, pedigree_data => $pedigree_string };
    } else {
        $c->stash->{rest} = {pedigree_data => $pedigree_string};
    }

}

sub upload_pedigrees_store : Path('/ajax/pedigrees/upload_store') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $pedigree_data = $c->req->param('pedigree_data');
    my $overwrite_pedigrees = $c->req->param('overwrite_pedigrees') ne 'false' ? $c->req->param('overwrite_pedigrees') : 0;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $pedigree_hash = decode_json $pedigree_data;
    my $file_pedigree_info = $pedigree_hash->{'pedigrees'};

    my $pedigrees = CXGN::Pedigree::AddPedigrees->new({ schema => $schema });

    my $generated_pedigrees = $pedigrees->generate_pedigrees($file_pedigree_info);

    my $add = CXGN::Pedigree::AddPedigrees->new({ schema => $schema, pedigrees => $generated_pedigrees });
    my $error;

    my $return = $add->add_pedigrees($overwrite_pedigrees);

    if (!$return){
        $error = "The pedigrees were not stored";
    }
    if ($return->{error}){
        $error = $return->{error};
    }

    if ($error){
        $c->stash->{rest} = { error => $error };
        $c->detach();
    }
    $c->stash->{rest} = { success => 1 };
}


=head2 get_full_pedigree

Usage:
    GET "/ajax/pedigrees/get_full?stock_id=<STOCK_ID>";

Responds with JSON array containing pedigree relationship objects for the
accession identified by STOCK_ID and all of its parents (recursively).

=cut

sub get_full_pedigree : Path('/ajax/pedigrees/get_full') : ActionClass('REST') { }
sub get_full_pedigree_GET {
    my $self = shift;
    my $c = shift;
    my $stock_id = $c->req->param('stock_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my @queue = ($stock_id);
    my $nodes = [];
    while (@queue){
        my $node = pop @queue;
        my $relationships = _get_relationships($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $node);
        if ($relationships->{parents}->{mother}){
            push @queue, $relationships->{parents}->{mother};
        }
        if ($relationships->{parents}->{father}){
            push @queue, $relationships->{parents}->{father};
        }
        push @{$nodes}, $relationships;
    }
    $c->stash->{rest} = $nodes;
}

=head2 get_relationships

Usage:
    POST "/ajax/pedigrees/get_relationships";
    BODY "stock_id=<STOCK_ID>[&stock_id=<STOCK_ID>...]"

Responds with JSON array containing pedigree relationship objects for the
accessions identified by the provided STOCK_IDs.

=cut

sub get_relationships : Path('/ajax/pedigrees/get_relationships') : ActionClass('REST') { }
sub get_relationships_POST {
    my $self = shift;
    my $c = shift;
    my $stock_ids = [];
    my $s_ids = $c->req->body_params->{stock_id};
    push @{$stock_ids}, (ref $s_ids eq 'ARRAY' ? @$s_ids : $s_ids);
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $nodes = [];
    while (@{$stock_ids}){
        push @{$nodes}, _get_relationships($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, (shift @{$stock_ids}));
    }
    $c->stash->{rest} = $nodes;
}

sub _get_relationships {
    my $schema = shift;
    my $mother_cvterm = shift;
    my $father_cvterm = shift;
    my $accession_cvterm = shift;
    my $stock_id = shift;
    my $name = $schema->resultset("Stock::Stock")->find({stock_id=>$stock_id})->uniquename();
    my $parents = _get_pedigree_parents($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $stock_id);
    my $children = _get_pedigree_children($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $stock_id);
    return {
        id => $stock_id,
        name=>$name,
        parents=> $parents,
        children=> $children
    };
}

sub _get_pedigree_parents {
    my $schema = shift;
    my $mother_cvterm = shift;
    my $father_cvterm = shift;
    my $accession_cvterm = shift;
    my $stock_id = shift;
    my $edges = $schema->resultset("Stock::StockRelationship")->search([
        {
            'me.object_id' => $stock_id,
            'me.type_id' => $father_cvterm,
            'subject.type_id'=> $accession_cvterm
        },
        {
            'me.object_id' => $stock_id,
            'me.type_id' => $mother_cvterm,
            'subject.type_id'=> $accession_cvterm
        }
    ],{join => 'subject'});
    my $parents = {};
    while (my $edge = $edges->next) {
        if ($edge->type_id==$mother_cvterm){
            $parents->{mother}=$edge->subject_id;
        } else {
            $parents->{father}=$edge->subject_id;
        }
    }
    return $parents;
}

sub _get_pedigree_children {
    my $schema = shift;
    my $mother_cvterm = shift;
    my $father_cvterm = shift;
    my $accession_cvterm = shift;
    my $stock_id = shift;
    my $edges = $schema->resultset("Stock::StockRelationship")->search([
        {
            'me.subject_id' => $stock_id,
            'me.type_id' => $father_cvterm,
            'object.type_id'=> $accession_cvterm
        },
        {
            'me.subject_id' => $stock_id,
            'me.type_id' => $mother_cvterm,
            'object.type_id'=> $accession_cvterm
        }
    ],{join => 'object'});
    my $children = {};
    $children->{mother_of}=[];
    $children->{father_of}=[];
    while (my $edge = $edges->next) {
        if ($edge->type_id==$mother_cvterm){
            push @{$children->{mother_of}}, $edge->object_id;
        } else {
            push @{$children->{father_of}}, $edge->object_id;
        }
    }
    return $children;
}

# sub _trait_overlay {
#     my $schema = shift;
#     my $node_list = shift;
# }


1;
