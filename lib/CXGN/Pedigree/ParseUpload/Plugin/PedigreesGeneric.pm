package CXGN::Pedigree::ParseUpload::Plugin::PedigreesGeneric;


use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => [ 'progeny name', 'female parent accession', 'male parent accession', 'type' ],
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    print STDERR "PARSED DATA =".Dumper($parsed_data)."\n";
    print STDERR "PARSED VALUES =".Dumper($parsed_values)."\n";
    print STDERR "PARSED ERRORS =".Dumper($parsed_errors)."\n";

    # return if parsing error
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my %supported_cross_types = ( biparental => 1, open => 1, self => 1, sib => 1, polycross => 1, backcross => 1, reselected => 1, doubled_haploid => 1, dihaploid_induction => 1 );
    my $seen_cross_types = $parsed_values->{'type'};
    my $seen_progenies = $parsed_values->{'progeny name'};
    my $seen_female_parents = $parsed_values->{'female parent accession'};
    my $seen_male_parents = $parsed_values->{'male parent accession'};
    my @all_stocks;
    push @all_stocks, @$seen_progenies;
    push @all_stocks, @$seen_female_parents;
    push @all_stocks, @$seen_male_parents;
    print STDERR "ALL STOCKS =".Dumper(\@all_stocks)."\n";


    foreach my $type (@$seen_cross_types) {
        if (!exists $supported_cross_types{$type}) {
            push @error_messages, "Cross type not supported: $type. Cross type should be biparental, self, open, sib, backcross, reselected or polycross";
        }
    }

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions_or_populations_or_vector_constructs',\@all_stocks)->{'missing'}};
    my $cross_validator = CXGN::List::Validate->new();
    my @stocks_missing = @{$cross_validator->validate($schema,'crosses',\@accessions_missing)->{'missing'}};
    if (scalar(@stocks_missing) > 0) {
        push @error_messages, "The following accessions are not in the database, or are not in the database as uniquenames: ".join(',',@stocks_missing);
    }


    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_parsed_data($parsed);
    print STDERR "PARSED =".Dumper($parsed)."\n";

    return 1;

}


sub _parse_with_plugin {
  my $self = shift;
  my $schema = $self->get_chado_schema();

  my $parsed = $self->_parsed_data();
  my $parsed_data = $parsed->{data};
  my $parsed_values = $parsed->{values};
  my $parsed_columns = $parsed->{columns};
  my %return_data;

  $self->_set_parsed_data(\%return_data);
  return 1;
}


1;
