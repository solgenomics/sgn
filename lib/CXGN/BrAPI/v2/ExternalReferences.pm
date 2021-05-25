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

    # if (!defined($id)) {
    #     CXGN::BrAPI::Exceptions::ServerException->throw({message => "Error: External References base id not specified, cannot be retrieve."});
    # }

    my $query = "select db.name, db.url, ref.accession, s.$table_id from $table as s
                join $table\_dbxref as o_dbxref using ($table_id)
                join dbxref as ref on (ref.dbxref_id=o_dbxref.dbxref_id)
                join db using (db_id)";
    if ($ids) { 
        my $list_ids = join ("," , @$ids);
        $query = $query . " where s.$table_id in ($list_ids)"; 
    }

    my $sth = $self->bcs_schema->storage()->dbh()->prepare($query);
    $sth->execute();

    my %result;
    while (my @r = $sth->fetchrow_array()) {
        push @{$result{$r[3]}} , \@r;
    }
    return \%result;
}

sub store {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $table = $self->table_name();
    my $table_id = $self->table_id_key();
    my $id = $self->id();
    my $external_references = $self->external_references();

    foreach (@$external_references){
        my $ref_name = $_->{'referenceSource'};
        my $ref_id = $_->{'referenceID'};

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

            my $create_stock_dbxref = $schema->resultset($table)->find_or_create({
                $table_id => $id,
                dbxref_id => $create_dbxref->dbxref_id()
            });

        } else {
            my ($url,$object_id) = _check_brapi_url($_->{'referenceID'});

            if($url){

                my $create_db = $schema->resultset("General::Db")->find_or_create({
                    name => $ref_name,
                    url => $url
                });
            
                my $create_dbxref = $schema->resultset("General::Dbxref")->find_or_create({
                    db_id => $create_db->db_id(),
                    accession => $object_id
                });

                my $create_stock_dbxref = $schema->resultset($table)->find_or_create({
                    $table_id => $id,
                    dbxref_id => $create_dbxref->dbxref_id()
                });
            }
        }
    }

    if ($@) {
        return {error => "External References transaction error trying to write to db"};
    }

    return { success => "External References added successfully" };

}



sub _check_brapi_url {
    my $url = shift;
    
    my $url_object_id = "";

    if ($url =~ /brapi\/v[1-2]\//){
        $url_object_id = $url;
        $url = $`;
        $url_object_id =~ s/$url//;
    }
    return ($url,$url_object_id);
}

1;