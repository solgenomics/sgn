package CXGN::Genotype::CreatePlateOrder;
=head1 NAME

CXGN::Genotype::CreatePlateOrder - an object to submit genotyping plates to facilities

=head1 USAGE

PLEASE BE AWARE THAT THE DEFAULT OPTIONS FOR genotypeprop_hash_select, protocolprop_top_key_select, protocolprop_marker_hash_select ARE PRONE TO EXCEEDING THE MEMORY LIMITS OF VM. CHECK THE MOOSE ATTRIBUTES BELOW TO SEE THE DEFAULTS, AND ADJUST YOUR MOOSE INSTANTIATION ACCORDINGLY

my $create_order = CXGN::Genotype::CreatePlateOrder->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    client_id=>$client_id,
    order_id=>$order_id,
    extract_dna=>$extract_dna,
    service_id_list=>$service_id_list,
    plate_id => $plate_id,
});
my $errors = $submit_samples->validate();
$submit_samples->send();


# RECOMMENDED
If you just want to send genotyping plates with different volume per well 

=head1 DESCRIPTION


=head1 AUTHORS

 Mirella Flores <mrf252@cornell.edu>
 Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::TissueSample::Search;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);


has 'client_id' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


has 'requeriments' => (
    isa => 'HashRef|Undef',
    is => 'rw',
    required => 0,
);

has 'service_id_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'ro',
    required => 1,
);

has 'plate_id' => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

has 'facility_id' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
);


# sub BUILD {
#     my $self = shift;
# }

=head2 validate()

Function for validating data before sending to facilities

my $submit_samples = CXGN::Genotype::CreatePlateOrder->new({
    bcs_schema=>$schema,
    etc...
});
my $get_errors = $submit_samples->validate();

=cut

sub validate {
    my $self = shift;
    # my $schema = $self->bcs_schema;
    # my $dbh = $schema->storage->dbh;
}

=head2 submit()

Function for submit genotyping plates to facilities

my $create_order = CXGN::Genotype::CreatePlateOrder->new({
    bcs_schema=>$schema,
    etc...
});
my $errors = $submit_samples->submit();

=cut

sub create {
    my $self = shift;
    my $c = shift;

    my $schema= $self->bcs_schema;

    my $plate_id = $self->plate_id;
    my $facility_id = $self->facility_id;
    my $client_id = $self->client_id;
    my $get_requeriments = $self->requeriments;
    my $service_id_list = $self->service_id_list;
    my $requeriments = $get_requeriments ? $get_requeriments : {};
    
    my $genotyping_trial;
    eval {
        $genotyping_trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $plate_id });
    };

    my $sample_type = $genotyping_trial->get_genotyping_plate_sample_type;

    my $plate_format = 'PLATE_96' if ($genotyping_trial->get_genotyping_plate_format eq 96);

    my $samples = _formated_samples($schema,$plate_id);

    my $plate;
    push @$plate, {
        clientPlateBarcode=> $genotyping_trial->get_name(),
        clientPlateId=> $plate_id,
        sampleSubmissionFormat=> $plate_format,
        samples=> $samples
    };

    my $order =  {
                clientId=>qq|$client_id|,
                numberOfSamples=>scalar @$samples,
                plates=>$plate,         
                requiredServiceInfo => $requeriments,
                sampleType=>$sample_type,
                serviceIds=>$service_id_list,
            };

    return $order;
}

sub _formated_samples {
    my $schema = shift;
    my $plate_id = shift;

    my $concent_unit = 'ng';
    my $volume_unit =  'ul';

    my $sample_search = CXGN::Stock::TissueSample::Search->new({
        bcs_schema=>$schema,
        plate_db_id_list => [$plate_id],
        order_by => '',
    });

    my ($results, $total_count) = $sample_search->search();
    my @samples;

    foreach my $result (@$results){
         if ($result->{germplasmName} ne 'BLANK'){
            push @samples, {
                        clientSampleBarCode=> $result->{sampleName},
                        clientSampleId=> qq|$result->{sampleDbId}|,
                        column=> $result->{col_number},
                        row=> $result->{row_number},
                        comments=> $result->{notes},
                        concentration=> {
                            units=> $concent_unit,
                            value=> $result->{concentration} eq 'NA' ? 0 : $result->{concentration} + 0,
                        },
                        tissueType=> $result->{tissue_type},
                        volume=> {
                            units=> $volume_unit,
                            value=> $result->{volume} eq 'NA' ? 0 : $result->{volume} + 0,
                        },
                        well=> $result->{well} ? $result->{well} : $result->{row_number} . $result->{col_number},
                        organismName=> $result->{genus} ? $result->{genus} : "",
                        speciesName=> $result->{species} ? $result->{species} : "",
                        taxonomyOntologyReference=> {},
                        tissueTypeOntologyReference=> {},
                    };
            }
    }

    return \@samples;
}

1;
