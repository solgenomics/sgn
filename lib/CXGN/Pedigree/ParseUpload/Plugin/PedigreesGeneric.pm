package CXGN::Pedigree::ParseUpload::Plugin::PedigreesGeneric;


use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use Bio::GeneticRelationships::Individual;
use CXGN::Pedigree::AddPedigrees;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new (
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

    my @pedigrees;
    foreach my $row (@$parsed_data) {
        my $female_parent;
        my $male_parent;

        my $progeny = $row->{'progeny name'};
        $progeny =~ s/^\s+|\s+$//g;
        my $female = $row->{'female parent accession'};
        $female =~ s/^\s+|\s+$//g;
        my $male = $row->{'male parent accession'};
        $female =~ s/^\s+|\s+$//g;
        my $cross_type = $row->{'type'};
        $cross_type =~ s/^\s+|\s+$//g;
        my $line_number = $row->{'_row'};

        if (!$female && !$male) {
            push @error_messages, "No male parent and no female parent on line $line_number!";
        }
        if (!$progeny) {
            push @error_messages, "No progeny specified on line $line_number!";
        }
        if (!$female) {
            push @error_messages, "No female on line $line_number for $progeny!";
        }
        if (!$cross_type){
            push @error_messages, "No cross type on line $line_number! Must be one of these: biparental, open, self, sib, backcross, reselected, polycross.";
        }
        if ($cross_type ne 'biparental' && $cross_type ne 'open' && $cross_type ne 'self' && $cross_type ne 'sib' && $cross_type ne 'polycross' && $cross_type ne 'backcross' && $cross_type ne 'reselected' && $cross_type ne 'doubled_haploid' && $cross_type ne 'dihaploid_induction') {
            push @error_messages, "Invalid cross type on line $line_number! Must be one of these: biparental, open, self, backcross, sib, reselected, polycross.";
        }
        if ($female eq $male) {
            if ($cross_type ne 'self' && $cross_type ne 'sib' && $cross_type ne 'reselected' && $cross_type ne 'doubled_haploid' && $cross_type ne 'dihaploid_induction'){
                push @error_messages, "Female parent and male parent are the same on line $line_number, but cross type is not self, sib or reselected.";
            }
        }
        if (($female && !$male) && ($cross_type ne 'open')) {
            push @error_messages, "For $progeny on line number $line_number no male parent specified and cross_type is not open...";
        }

        if (($cross_type eq "self") || ($cross_type eq "reselected") || ($cross_type eq "dihaploid_induction") || ($cross_type eq "doubled_haploid") ) {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
        }
        elsif ($cross_type eq 'biparental') {
            if (!$male){
                push @error_messages, "For $progeny Cross Type is biparental, but no male parent given";
            } else {
                $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }
        }
        elsif($cross_type eq 'backcross') {
            if (!$male){
                push @error_messages, "For $progeny Cross Type is backcross, but no male parent given";
            } else {
                $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }
        }
        elsif($cross_type eq "sib") {
            if (!$male){
                push @error_messages, "For $progeny Cross Type is sib, but no male parent given";
            } else {
                $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }
        }
        elsif($cross_type eq "polycross") {
            if (!$male){
                push @error_messages, "For $progeny Cross Type is polycross, but no male parent given";
            } else {
                $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }
        }
        elsif($cross_type eq "open") {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = undef;
            if ($male){
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }
        }

        my $opts = {
            cross_type => $cross_type,
            female_parent => $female_parent,
            name => $progeny
        };

        if ($male_parent) {
            $opts->{male_parent} = $male_parent;
        }

        my $p = Bio::GeneticRelationships::Pedigree->new($opts);
        push @pedigrees, $p;

    }

    print STDERR "ERRORS =".Dumper(scalar @error_messages)."\n";
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $add = CXGN::Pedigree::AddPedigrees->new({ schema => $schema, pedigrees => \@pedigrees });
    my $error;

    my $pedigree_check = $add->validate_pedigrees();

    #print STDERR Dumper $pedigree_check;
    if (!$pedigree_check){
        $error = "There was a problem validating pedigrees. Pedigrees were not stored.";
    }
#    if ($pedigree_check->{error}){
#        $c->stash->{rest} = {error => $pedigree_check->{error}, archived_file_name => $file_name};
#    } else {
#        $c->stash->{rest} = {archived_file_name => $file_name};
#    }

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
