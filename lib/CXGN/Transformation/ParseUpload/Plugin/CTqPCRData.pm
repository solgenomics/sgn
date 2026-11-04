package CXGN::Transformation::ParseUpload::Plugin::CTqPCRData;

use SGN::I18N ();
use CatalystX::GlobalContext '$c';

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use Scalar::Util qw(looks_like_number);
use CXGN::Stock::RelatedStocks;

sub _validate_with_plugin {
    my $self = shift;
    my SGN::I18N $ui__validate_with_plugin_i18n = SGN::I18N::translate($c);

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $vector_stock_id = $self->get_vector_stock_id();
    my $genes = $self->get_vector_construct_genes();
    my %valid_genes;
    foreach my $gene (@$genes) {
        $valid_genes{$gene} = 1;
    }
    my $endogenous_control = $self->get_endogenous_control();
    $valid_genes{$endogenous_control} = 1;

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new (
        i18n => $ui__validate_with_plugin_i18n,
        file => $filename,
        required_columns => [ 'accession_name', 'replicate_number', 'gene', 'Cq' ],
        column_aliases => {
            'accession_name' => ['accession name'],
            'replicate_number' => ['replicate number'],
            'Cq' => ['Ct', 'CQ', 'CT'],
        }
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

    # return if parsing error
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
        $errors{'error_messages'} = [
            (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.the_following_columns_are_not_recognized_value1_please_check_the_spr', 'The following columns are not recognized: %{value1}. Please check the spreadsheet format for the allowed columns.', {value1 => ("" . (join(', ', @$additional_columns)))}))];
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $seen_accession_names = $parsed_values->{'accession_name'};
    my $seen_genes = $parsed_values->{'gene'};
    my $seen_Cq_values = $parsed_values->{'Cq'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames', $seen_accession_names)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.the_following_accessions_are_not_in_the_database_or_are_not_in_the_d', 'The following accessions are not in the database, or are not in the database as uniquenames: %{value1}', {value1 => ("" . (join(',',@accessions_missing)))}));
    }

    my $related_transformants = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id =>$vector_stock_id});
    my $transformants = $related_transformants->get_vector_related_accession_list();
    my @all_transformants = @$transformants;
    foreach my $accession (@$seen_accession_names) {
        if ($accession ~~ @all_transformants) {
            next;
        } else {
            push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.this_accession_doesn_t_contain_expected_vector_construct_accession', 'This accession doesn\'t contain expected vector construct: %{accession}', {accession => ("" . ("$accession"))}));
        }
    }

    foreach my $gene_name (@$seen_genes) {
        if (!exists $valid_genes{$gene_name}) {
            push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.gene_not_in_this_vector_construct_gene_name', 'Gene not in this vector construct: %{gene_name}.', {gene_name => ("" . ("$gene_name"))}));
        }
    }

    foreach my $Cq_value (@$seen_Cq_values) {
        if ((!looks_like_number($Cq_value)) && ($Cq_value ne 'ND')) {
            push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.cq_value_is_not_a_number_or_nd_cq_value', 'Cq value is not a number or \'ND\': %{Cq_value}.', {Cq_value => ("" . ("$Cq_value"))}));
        }
    }




    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_parsed_data($parsed);
    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};
    my $endogenous_control = $self->get_endogenous_control();
    my %Cq_qPCR_data;

    foreach my $row (@$parsed_data) {
        my $row_number = $row->{'_row'};
        my $accession_name = $row->{'accession_name'};
        my $replicate_number = $row->{'replicate_number'};
        my $gene_name = $row->{'gene'};
        my $Cq_value = $row->{'Cq'};
        if ($gene_name eq $endogenous_control) {
            $Cq_qPCR_data{$accession_name}{$replicate_number}{'endogenous_control'}{$gene_name} = $Cq_value;
        } else {
            $Cq_qPCR_data{$accession_name}{$replicate_number}{'target'}{$gene_name} = $Cq_value;
        }
    }

    $self->_set_parsed_data(\%Cq_qPCR_data);

    return 1;
}


1;
