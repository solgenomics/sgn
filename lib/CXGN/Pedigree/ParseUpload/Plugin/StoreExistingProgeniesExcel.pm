package CXGN::Pedigree::ParseUpload::Plugin::StoreExistingProgeniesExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::RelatedStocks;


# Store re-parses and validates the file independently of the earlier verify
# request; it never trusts client-side verification state.
sub _validate_with_plugin {
    my $self = shift;
    require CXGN::File::Parse;
    my $file = CXGN::File::Parse->new(file => $self->get_filename,
        required_columns => ['cross_unique_id', 'progeny_name'],
        unique_only_columns => ['progeny_name']);
    my $parsed = $file->parse;
    if (@{$parsed->{errors} || []} || !@{$parsed->{data} || []}) {
        $self->_set_parse_errors({error_messages => $parsed->{errors} && @{$parsed->{errors}}
            ? $parsed->{errors} : ['No progeny data were supplied.']});
        return;
    }
    $self->_set_parsed_data($parsed);
    return 1;
}

sub _parse_with_plugin {
    my $self = shift;
    my %groups;
    for my $row (@{$self->_parsed_data->{data}}) {
        push @{$groups{$row->{cross_unique_id}}}, $row->{progeny_name};
    }
    $self->_set_parsed_data(\%groups);
    return 1;
}

1;
