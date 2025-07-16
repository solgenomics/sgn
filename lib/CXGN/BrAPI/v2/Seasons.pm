package CXGN::BrAPI::v2::Seasons;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::Search;
use CXGN::Trial::TrialLayout;
use CXGN::Trait;
use CXGN::Stock;
use CXGN::Phenotypes::SearchFactory;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::JSONResponse;
use JSON;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $year_filter = $params->{seasonDbId} || ($params->{year} || ());

    my @data;
    my $total_count = 0;
    my $year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'project year', 'project_property')->cvterm_id();
    my $project_years_rs = $self->bcs_schema()->resultset("Project::Project")->search_related('projectprops', {'projectprops.type_id'=>$year_cvterm_id});
    my %unique_years;
    while (my $p_year = $project_years_rs->next()) {
        $unique_years{$p_year->value} = $p_year->projectprop_id;
    }
    my @sorted_years;
    foreach (sort keys %unique_years){
        my ($year, $season) = split '\|', $_;
        if ( $year_filter && ! grep { $_ eq $year } @{$year_filter} ) { next;};

        push @sorted_years, [$year, $season, $_];
    }

    my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@sorted_years, $page_size, $page);
    foreach (@$data_window){
        my $year = $_->[0] ? $_->[0] : '';
        my $season = $_->[1] ? $_->[1] : '';
        my $projectprop_id = $_->[2] ? $_->[2] : '';
        push @data, {
            seasonDbId=>qq|$projectprop_id|,
            season=>$season,
            year=>$year
        };
    }
    my %result = (data=>\@data);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seasons list result constructed');
}

sub detail {
    my $self = shift;
    my $year_filter = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data;
    my $total_count = 0;
    my $year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'project year', 'project_property')->cvterm_id();
    my $project_years_rs = $self->bcs_schema()->resultset("Project::Project")->search_related('projectprops', {'projectprops.type_id'=>$year_cvterm_id});
    my %unique_years;
    while (my $p_year = $project_years_rs->next()) {
        $unique_years{$p_year->value} = $p_year->projectprop_id;
    }
    my @sorted_years;
    foreach (sort keys %unique_years){
        my ($year, $season) = split '\|', $_;
        if ($year_filter){
            if ($year eq $year_filter){
                push @sorted_years, [$year, $season, $_];
            }
        } else {
            push @sorted_years, [$year, $season, $_];
        }
    }

    my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@sorted_years, $page_size, $page);
    foreach (@$data_window){
        my $year = $_->[0] ? $_->[0] : '';
        my $season = $_->[1] ? $_->[1] : '';
        my $projectprop_id = $_->[2] ? $_->[2] : '';
        push @data, {
            seasonDbId=>qq|$projectprop_id|,
            seasonName=>$season,
            year=>int($year)
        };
    }

    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(@data, $pagination, \@data_files, $status, 'Seasons list result constructed');
}

1;
