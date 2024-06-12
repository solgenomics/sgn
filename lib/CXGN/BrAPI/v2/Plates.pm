package CXGN::BrAPI::v2::Plates;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $plates_arrayref = $params->{plateDbId} || ($params->{plateDbIds} || ());
    my $program_id_list = $params->{programDbId} || ($params->{programDbIds} || ());
    my $program_list = $params->{programName} || ($params->{programNames} || ());
    my $trial_name_list = $params->{plateName} || ($params->{plateNames} || ());
    my $folder_id_list = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $folder_name_list = $params->{studyName} || ($params->{studyNames} || ());

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    my @trial_ids;
    if ($plates_arrayref){
        push @trial_ids, @{$plates_arrayref};
    }

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotyping_plate'],
        trial_id_list => \@trial_ids,
        program_list => $program_list,
        program_id_list => $program_id_list,
        trial_name_list => $trial_name_list,
        folder_id_list => $folder_id_list,
        folder_name_list => $folder_name_list,
        # location_list => $location_list,
        # location_id_list => $location_id_list,
        # year_list => $year_list,
        # trial_type_list => $trial_type_list,
        # trial_design_list => $trial_design_list,
        # trial_name_is_exact => $trial_name_is_exact,
        # accession_list => $accession_list,
        # accession_name_list => $accession_name_list,
        # trait_list => $trait_list,
    });

    my ($data, $total_count) = $trial_search->search();

    my @data;

    foreach (@$data){
        push @data, {
                additionalInfo => {},
                externalReferences => [],
                plateBarcode => undef,
                plateFormat => $_->{genotyping_plate_format},
                plateName => $_->{trial_name},
                programDbId => qq|$_->{breeding_program_id}|,
                sampleType => $_->{genotyping_plate_sample_type},
                studyDbId => qq|$_->{trial_id}|,
                trialDbId => qq|$_->{trial_id}|,
                plateDbId => qq|$_->{trial_id}|,
        }
    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Plates result constructed');
}

sub detail {
    my $self = shift;
    my $plate_id = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotyping_plate'],
        trial_id_list => [$plate_id]
    });

    my ($data, $total_count) = $trial_search->search();

    my @data;

    foreach (@$data){
        push @data, {
                additionalInfo => {},
                externalReferences => [],
                plateBarcode => undef,
                plateFormat => $_->{genotyping_plate_format},
                plateName => $_->{trial_name},
                programDbId => qq|$_->{breeding_program_id}|,
                sampleType => $_->{genotyping_plate_sample_type},
                studyDbId => qq|$_->{trial_id}|,
                trialDbId => qq|$_->{trial_id}|,
                plateDbId => qq|$_->{trial_id}|,
        }
    }

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(@data, $pagination, \@data_files, $status, 'Plates result constructed');
}



1;
