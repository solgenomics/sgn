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
    isa => 'Maybe[ArrayRef]',
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
print Dumper $ids;
    my $query = "select db.name, db.url, ref.accession, s.$table_id from $table as s
                join $table\_dbxref as o_dbxref using ($table_id)
                join dbxref as ref on (ref.dbxref_id=o_dbxref.dbxref_id)
                join db using (db_id)";
    if ($ids) { 
        my $list_ids = join ("," , @$ids);
        $query = $query . " where s.$table_id in ($list_ids)"; 
    }
    print Dumper $query;
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
    my $base_id = $self->base_id();
    my $base_id_key = $self->base_id_key();


    if (!defined($self->base_id)) {
        CXGN::BrAPI::Exceptions::ServerException->throw({message => "Error: External References base id not specified, cannot store"});
    }

    my @references = @{$self->external_references()};
    my $rank = 0;

    # get cv_id for external references
    my $cv_id = $self->cv_id;
    # get cvterm ids for reference_id & reference_source
    my $reference_id = $self->reference_id;
    my $reference_source = $self->reference_source_id;

    # delete previous references
    $self->delete();

    my $coderef = sub {

        foreach my $reference (@references) {
            my $id = $reference->{'referenceID'};
            my $source = $reference->{'referenceSource'};

            # write external reference info to prop table
            my $prop_id = $schema->resultset($self->table_name())->create(
                {
                    $base_id_key => $base_id,
                    type_id   => $reference_id,
                    value     => $id,
                    rank      => $rank
                }
            );

            my $prop_source = $schema->resultset($self->table_name())->create(
                {
                    $base_id_key => $base_id,
                    type_id   => $reference_source,
                    value     => $source,
                    rank      => $rank
                }
            );

            $rank++;
        }
    };

    my $transaction_error;

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        return {error => "External References transaction error trying to write to db"}
    }

    return { success => "External References added successfully" };

}

sub delete {
    my $self = shift;
    my $schema = $self->bcs_schema();

    $schema->resultset($self->table_name())->search(
        {
            $self->base_id_key => $self->base_id,
            type_id   => { -in =>
                [
                    $self->reference_id,
                    $self->reference_source_id,
                ]
            }
        }
    ) -> delete;
}

1;