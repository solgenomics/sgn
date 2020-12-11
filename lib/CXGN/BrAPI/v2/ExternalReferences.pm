package CXGN::BrAPI::v2::ExternalReferences;

use Moose;
use Data::Dumper;
use Try::Tiny;
use List::Util 'max';

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'external_references' => (
    is => 'ro',
    isa => 'ArrayRef[HashRef[Str]]',
);

has 'dbxref_id' => (
    isa => 'Int',
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
    isa => 'ArrayRef[HashRef[Str]]',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %references;

        my $props = $self->bcs_schema()->resultset("Cv::Dbxrefprop")->search(
            {
                dbxref_id => $self->dbxref_id()
            },
            {order_by => { -asc => 'rank' }}
        );

        while (my $prop = $props->next()){
            my $reference = $references{$prop->get_column('rank')};
            if ($prop->get_column('type_id') == $self->reference_id) {
                $reference->{'referenceID'} = $prop->get_column('value');
            }
            if ($prop->get_column('type_id') == $self->reference_source_id) {
                $reference->{'referenceSource'} = $prop->get_column('value');
            }

            $references{$prop->get_column('rank')}=$reference;
        }

        my $ref = \%references;
        my $maxkey = max keys %$ref;
        my @array = @{$ref}{0 .. $maxkey};
        return \@array;
    }
);

sub store {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $dbxref_id = $self->dbxref_id();

    my @references = @{$self->external_references()};
    my $rank = 0;

    # get cv_id for external references
    my $cv_id = $self->cv_id;
    # get cvterm ids for reference_id & reference_source
    my $reference_id = $self->reference_id;
    my $reference_source = $self->reference_source_id;

    my $coderef = sub {

        foreach my $reference (@references) {
            my $id = $reference->{'referenceID'};
            my $source = $reference->{'referenceSource'};

            # write external reference info to dbxrefprop
            my $prop_id = $schema->resultset("Cv::Dbxrefprop")->create(
                {
                    dbxref_id => $dbxref_id,
                    type_id   => $reference_id,
                    value     => $id,
                    rank      => $rank
                }
            );

            my $prop_source = $schema->resultset("Cv::Dbxrefprop")->create(
                {
                    dbxref_id => $dbxref_id,
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

1;