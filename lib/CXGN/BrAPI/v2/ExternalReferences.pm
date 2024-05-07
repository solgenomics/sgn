package CXGN::BrAPI::v2::ExternalReferences;

use Moose;
use Data::Dumper;
use Try::Tiny;
use List::Util 'max';
use CXGN::BrAPI::Exceptions::ServerException;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'external_references' => (
    is => 'ro',
    isa => 'ArrayRef[HashRef[Str]]',
);

has 'id' => (
    isa => 'Maybe[ArrayRef|Str]',
    is => 'rw',
    required => 0,
);

has 'table_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'table_id_key' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);



sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $ids = $self->id();
    my $table = $self->table_name();
    my $table_id = $self->table_id_key();

    my $query = "select db.name, db.url, ref.accession, s.$table_id from $table as s
                join $table\_dbxref as o_dbxref using ($table_id)
                join dbxref as ref on (ref.dbxref_id=o_dbxref.dbxref_id)
                join db using (db_id)";

    # $ids may be a string or an Array Reference.  This code must handle both cases.
    if ($ids) {
        if ( ref($ids) eq "ARRAY" ) {
            if (scalar(@$ids) > 0){
                my $list_ids = join(",", @$ids);
                $query = $query . " where s.$table_id in ($list_ids)";
            }
        }
        else{ # $ids must be a Str (assumed to be a single ID)
            my $list_ids = $ids;
            $query = $query . " where s.$table_id in ($list_ids)";
        }
    }

    my $sth = $self->bcs_schema->storage()->dbh()->prepare($query);
    $sth->execute();

    my %result;
    while (my @r = $sth->fetchrow_array()) {
        my $reference_source = $r[0] || undef;
        my $url = $r[1];
        my $accession = $r[2];
        my $reference_id;

        if($reference_source eq 'DOI') {
            $reference_id = ($url) ? "$url$accession" : "doi:$accession";
        } else {
            $url = ($url) ? $url : "";
            $reference_id = ($accession) ? "$url$accession" : $url;
        }

        push @{$result{$r[3]}}, {
            # TODO change 'referenceID' to 'referenceId'. The field 'referenceID' was deprecated in v2.1 of the
            # brapi spec. Now 'referenceId' should be used.
            referenceId => $reference_id,
            referenceSource => $reference_source
        };
    }
    return \%result;
}

sub store {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $table = sprintf "%s_dbxref", $self->table_name();
    my $table_id = $self->table_id_key();
    my $id = $self->id();
    my $external_references = $self->external_references();
    # Clear old external references
    $self->_remove_external_references();

    foreach (@$external_references){

        my $ref_name = $_->{'referenceSource'};

        # 'referenceID' was deprecated in v2.1 of the brapi spec. Now 'referenceId'
        # should be used.  Both are now in use.
        my $ref_id = $_->{'referenceId'};
        if( ! $ref_id ){
            $ref_id = $_->{'referenceID'};
        }

        #DOI
        if($ref_name eq "DOI"){
            my $create_db = $schema->resultset("General::Db")->find_or_create(
            {
            name       => 'DOI',
            urlprefix =>  'http://',
            url        => 'doi.org',
            } );
            
            $ref_id =~ s/http:\/\/doi\.org//;
            $ref_id =~ s/https:\/\/doi\.org//;
            $ref_id =~ s/doi://;
            $ref_id =~ s/DOI://;

            my $create_dbxref = $schema->resultset("General::Dbxref")->find_or_create({
                db_id => $create_db->db_id(),
                accession => $ref_id
            });

            # Switch to model way to do it once project_dbxref is added to chado schema
            my $dbh = $self->bcs_schema->storage()->dbh();
            my $sql = "INSERT INTO $table (dbxref_id, $table_id) VALUES ( ?, ? ) ON CONFLICT DO NOTHING";
            my $sth = $dbh->prepare( $sql );
            $sth->execute($create_dbxref->dbxref_id(), $id);

            #my $create_stock_dbxref = $schema->resultset($table)->find_or_create({
            #    $table_id => $id,
            #    dbxref_id => $create_dbxref->dbxref_id()
            #});

        } else {
            my ($url,$object_id) = _check_brapi_url($ref_id);

            if($ref_name){

                my $create_db = $schema->resultset("General::Db")->find_or_create({
                    name => $ref_name,
                    url => $url
                });
            
                if($object_id){
                  my $create_dbxref = $schema->resultset("General::Dbxref")->find_or_create({
                      db_id => $create_db->db_id(),
                      accession => $object_id
                  });

                  # Switch to model way to do it once project_dbxref is added to chado schema
                  my $dbh = $self->bcs_schema->storage()->dbh();
                  my $sql = "INSERT INTO $table (dbxref_id, $table_id) VALUES ( ?, ? ) ON CONFLICT DO NOTHING";
                  my $sth = $dbh->prepare( $sql );
                  $sth->execute($create_dbxref->dbxref_id(), $id);

                  #my $create_stock_dbxref = $schema->resultset($table)->find_or_create({
                  #    $table_id => $id,
                  #    dbxref_id => $create_dbxref->dbxref_id()
                  #});
                }
            }
        }
    }

    if ($@) {
        return {error => "External References transaction error trying to write to db"};
    }

    return { success => "External References added successfully" };

}

sub _remove_external_references {
    my $self = shift;
    my $table = $self->table_name();
    my $table_id = $self->table_id_key();
    my $id = $self->id();

    # Clear $table_dbxref, we'll leave the dbxref because those can be shared
    my $delete_table_dbxref_query = "delete from $table\_dbxref where $table_id = $id";
    $self->bcs_schema->storage()->dbh()->prepare($delete_table_dbxref_query)->execute();
}



sub _check_brapi_url {
    my $url = shift;
    
    my $url_object_id = "";

    if ($url =~ /brapi\/v[1-2]\//){
        $url_object_id = $url;
        $url = $`;
        $url_object_id =~ s/$url//;
    } else{
        $url_object_id = $url;
        $url = "";
    }
    return ($url,$url_object_id);
}

1;