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
    isa => 'ArrayRef[HashRef]',
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



# Shared input contract for unit and phenotype writers. Optional scalar/null
# fields and the legacy referenceID spelling are accepted without mutation.
# Callers may validate before constructing the storage object or archiving data.
sub validate_payload {
    my ($refs) = @_;
    return undef if !defined($refs);
    return {code=>400,error=>'externalReferences must be an array of objects.'} if ref($refs) ne 'ARRAY';
    for my $ref (@$refs) {
        return {code=>400,error=>'Each external reference must be an object.'} if ref($ref) ne 'HASH';
        for my $value (values %$ref) {
            return {code=>400,error=>'External reference fields must be scalar values.'} if ref($value);
        }
        my $source=$ref->{referenceSource};
        my $id=defined($ref->{referenceId}) && length($ref->{referenceId}) ? $ref->{referenceId} : $ref->{referenceID};
        return {code=>400,error=>'Each external reference needs nonempty referenceSource and referenceId values.'}
            if !defined($source) || !length($source) || !defined($id) || !length($id);
        return {code=>400,error=>'referenceId and legacy referenceID identify different references.'}
            if defined($ref->{referenceId}) && length($ref->{referenceId}) && defined($ref->{referenceID}) && length($ref->{referenceID}) && $ref->{referenceId} ne $ref->{referenceID};
    }
    return undef;
}

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

    my @bind;
    if (defined($ids)) {
        if (ref($ids) eq 'ARRAY') {
            return {} if !@$ids;
            $query .= " WHERE s.$table_id IN (".join(',', ('?') x @$ids).")";
            @bind = @$ids;
        } else {
            $query .= " WHERE s.$table_id = ?";
            @bind = ($ids);
        }
    }
    (my $table_base = $table) =~ s/^.*\.//;
    $query .= " ORDER BY o_dbxref.${table_base}_dbxref_id";
    my $sth = $schema->storage->dbh->prepare($query);
    $sth->execute(@bind);

    my %result;
    while (my @r = $sth->fetchrow_array()) {
        my $reference_source = $r[0];
        my $url = $r[1];
        my $accession = $r[2];
        my $reference_id;

        if($reference_source eq 'DOI') {
            $reference_id = (defined($url) && length($url)) ? "$url$accession" : "doi:$accession";
        } else {
            $url = defined($url) ? $url : "";
            $reference_id = (defined($accession) && length($accession)) ? "$url$accession" : $url;
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
    my $schema = $self->bcs_schema;
    my $refs = $self->external_references;
    my $invalid = validate_payload($refs);
    return $invalid if $invalid;
    return {success=>'External references unchanged.'} if !defined($refs);
    my $id=$self->id;
    return {code=>400,error=>'A scalar target identifier is required for external references.'} if !defined($id) || ref($id) || !length($id);
    my $table = sprintf '%s_dbxref', $self->table_name;
    my $table_id = $self->table_id_key;
    my $ok=eval {
        $schema->txn_do(sub {
            $self->_remove_external_references;
            for my $ref (@$refs) {
                my $name=$ref->{referenceSource};
                my $ref_id=defined($ref->{referenceId}) && length($ref->{referenceId}) ? $ref->{referenceId} : $ref->{referenceID};
                my ($url,$accession);
                if ($name eq 'DOI') {
                    $url='http://doi.org/';
                    $ref_id =~ s{^https?://doi\.org/}{}i;
                    $ref_id =~ s{^doi:}{}i;
                    $accession=$ref_id;
                } else { ($url,$accession)=_check_brapi_url($ref_id); }
                my $db=$schema->resultset('General::Db')->find_or_create({name=>$name,url=>$url});
                my $xref=$schema->resultset('General::Dbxref')->find_or_create({db_id=>$db->db_id,accession=>$accession});
                $schema->storage->dbh->prepare("INSERT INTO $table (dbxref_id, $table_id) VALUES (?, ?) ON CONFLICT DO NOTHING")->execute($xref->dbxref_id,$id);
            }
        });
        1;
    };
    return {code=>500,error=>'External references could not be saved.'} if !$ok;
    return {success=>'External References added successfully'};
}


sub _remove_external_references {
    my $self = shift;
    my $table = $self->table_name();
    my $table_id = $self->table_id_key();
    my $id = $self->id();

    # Clear $table_dbxref, we'll leave the dbxref because those can be shared
    my $delete_table_dbxref_query = "delete from $table\_dbxref where $table_id = ?";
    $self->bcs_schema->storage()->dbh()->prepare($delete_table_dbxref_query)->execute($id);
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
