package CXGN::BrAPI::v2::Methods;

use Moose;
use Data::Dumper;
use Try::Tiny;
use List::Util 'max';

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'method' => (
    is => 'ro',
    isa => 'HashRef[Any]',
);

has 'cvterm_id' => (
    isa => 'Int',
    is => 'rw',
    required => 0,
);

has 'cv_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $cv_id = $self->bcs_schema->resultset("Cv::Cv")->find(
            {
                name => 'trait_property'
            },
            { key => 'cv_c1' }
        )->get_column('cv_id');
        return $cv_id;
    }
);

has 'method_name_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $method_name_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
            {
                name        => 'trait_method_name',
                cv_id       => $self->cv_id,
                is_obsolete => 0
            },
            { key => 'cvterm_c1' }
        )->get_column('cvterm_id');
        return $method_name_id;
    }
);

has 'method_description_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $method_description_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
            {
                name        => 'trait_method_description',
                cv_id       => $self->cv_id,
                is_obsolete => 0
            },
            { key => 'cvterm_c1' }
        )->get_column('cvterm_id');
        return $method_description_id;
    }
);

has 'method_class_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $method_class_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
            {
                name        => 'trait_method_class',
                cv_id       => $self->cv_id,
                is_obsolete => 0
            },
            { key => 'cvterm_c1' }
        )->get_column('cvterm_id');
        return $method_class_id;
    }
);

has 'method_formula_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $method_formula_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
            {
                name        => 'trait_method_formula',
                cv_id       => $self->cv_id,
                is_obsolete => 0
            },
            { key => 'cvterm_c1' }
        )->get_column('cvterm_id');
        return $method_formula_id;
    }
);

has 'method_db' => (
    isa => 'HashRef[Str]',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %method;

        my $props = $self->bcs_schema()->resultset("Cv::Cvtermprop")->search(
            {
                cvterm_id => $self->cvterm_id()
            },
            {order_by => { -asc => 'rank' }}
        );

        my $ref = \%method;

        while (my $prop = $props->next()){
            if ($prop->get_column('type_id') == $self->method_name_id) {
                $ref->{'methodName'} = $prop->get_column('value');
            }
            if ($prop->get_column('type_id') == $self->method_description_id) {
                $ref->{'description'} = $prop->get_column('value');
            }
            if ($prop->get_column('type_id') == $self->method_class_id) {
                $ref->{'methodClass'} = $prop->get_column('value');
            }
            if ($prop->get_column('type_id') == $self->method_formula_id) {
                $ref->{'formula'} = $prop->get_column('value');
            }
        }

        return $ref;
    }
);

sub store {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $cvterm_id = $self->cvterm_id();
    my $method = $self->method();
    my $cv_id = $self->cv_id;

    if (!defined($cvterm_id)) {
        CXGN::BrAPI::Exceptions::ServerException->throw({message => "Error: Method cvterm_id not specified, cannot store"});
    }

    # Clear our old method
    $self->delete();

    my $method_name_id = $self->method_name_id;
    my $method_description_id = $self->method_description_id;
    my $method_class_id = $self->method_class_id;
    my $method_formula_id = $self->method_formula_id;

    my $coderef = sub {

        my $method_name = $method->{'methodName'};
        my $method_description = $method->{'description'};
        my $method_class = $method->{'methodClass'};
        my $method_formula = $method->{'formula'};

        my $prop_name = $schema->resultset("Cv::Cvtermprop")->create(
            {
                cvterm_id => $cvterm_id,
                type_id   => $method_name_id,
                value     => $method_name,
                rank      => 0
            }
        );

        if ($method_description) {
            my $prop_description = $schema->resultset("Cv::Cvtermprop")->create(
                {
                    cvterm_id => $cvterm_id,
                    type_id   => $method_description_id,
                    value     => $method_description,
                    rank      => 0
                }
            );
        }

        my $prop_class = $schema->resultset("Cv::Cvtermprop")->create(
            {
                cvterm_id => $cvterm_id,
                type_id   => $method_class_id,
                value     => $method_class,
                rank      => 0
            }
        );

        if ($method_formula) {
            my $prop_formula = $schema->resultset("Cv::Cvtermprop")->create(
                {
                    cvterm_id => $cvterm_id,
                    type_id   => $method_formula_id,
                    value     => $method_formula,
                    rank      => 0
                }
            );
        }

    };

    my $transaction_error;

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        return {error => "Method transaction error trying to write to db"}
    }

    return { success => "Method added successfully" };

}

sub delete {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $cvterm_id = $self->cvterm_id();

    $schema->resultset("Cv::Cvtermprop")->search(
        {   cvterm_id => $cvterm_id,
            type_id   => { -in =>
                [
                    $self->method_name_id,
                    $self->method_description_id,
                    $self->method_class_id,
                    $self->method_formula_id
                ]
            }
        }
    )->delete;
}

1;