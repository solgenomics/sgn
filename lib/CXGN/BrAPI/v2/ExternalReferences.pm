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

has 'base_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
    required => 0,
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

has 'base_id_key' => (
    isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'table_id_key' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'cv_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        # get cv_id for external references
        my $cv_id = $self->bcs_schema->resultset("Cv::Cv")->find(
            {
                name => 'brapi_external_reference'
            },
            { key => 'cv_c1' }
        )->get_column('cv_id');
        return $cv_id;
    }
);

has 'reference_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        # get cvterm id for reference_id
        my $reference_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
            {
                name        => 'reference_id',
                cv_id       => $self->cv_id,
                is_obsolete => 0
            },
            { key => 'cvterm_c1' }
        )->get_column('cvterm_id');
        return $reference_id;
    }
);

has 'reference_source_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        # get cvterm id for reference_id
        my $reference_source = $self->bcs_schema->resultset("Cv::Cvterm")->find(
            {
                name        => 'reference_source',
                cv_id       => $self->cv_id,
                is_obsolete => 0
            },
            { key => 'cvterm_c1' }
        )->get_column('cvterm_id');
        return $reference_source;
    }
);

has 'references_db' => (
    isa => 'Maybe[ArrayRef[HashRef[Str]]]',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %references;

        my $base_id = $self->base_id();
        my $base_id_key = $self->base_id_key();

        my $props = $self->bcs_schema()->resultset($self->table_name())->search(
            {
                $base_id_key => $base_id
            },
            {order_by => { -asc => 'rank' }}
        );

        while (my $prop = $props->next()){
            my $reference = $references{$prop->get_column('rank')};
            if ($prop->get_column('type_id') == $self->reference_id) {
                $reference->{'referenceID'} = $prop->get_column('value');
                $references{$prop->get_column('rank')}=$reference;
            }
            if ($prop->get_column('type_id') == $self->reference_source_id) {
                $reference->{'referenceSource'} = $prop->get_column('value');
                $references{$prop->get_column('rank')}=$reference;
            }

        }

        if (%references) {
            my $ref = \%references;
            my $maxkey = max keys %$ref;
            my @array = @{$ref}{0 .. $maxkey};
            return \@array;
        }
        return undef;
    }
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
    print STDERR Dumper \%result;
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
        my $name = $_->{'referenceSource'};
        my ($url,$object_id) = _check_brapi_url($_->{'referenceID'});
        print STDERR "$url,$object_id";
        my $create_db = $schema->resultset("General::Db")->find_or_create({
            name => $name,
            url => $url #'dbx.com/brapi/v2/germplasm',
        });

        if($object_id){
            my $create_dbxref = $schema->resultset("General::Dbxref")->find_or_create({
                db_id => $create_db->db_id(),
                accession => $object_id
            });

            my $create_stock_dbxref = $schema->resultset($table)->find_or_create({
                $table_id => $id, # stock_id
                dbxref_id => $create_dbxref->dbxref_id()
            });
        }
    }

    if ($@) {
        return {error => "External References transaction error trying to write to db"}
    }

    return { success => "External References added successfully" };

}



sub _check_brapi_url {
    my $url = shift;
    
    my $url_object_id;

    if($url =~ m/brapi\/v2/){

        my @parse = split /\//, $url;
        $url_object_id = $parse[@parse - 1];
        $url =~ s/$url_object_id//;
    }
    return ($url,$url_object_id);
}

1;