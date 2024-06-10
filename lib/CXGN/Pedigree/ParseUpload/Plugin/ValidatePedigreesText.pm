package CXGN::Pedigree::ParseUpload::Plugin::ValidatePedigreesText;

use Moose::Role;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use List::Util qw | any |;
use File::Slurp qw | read_file |;
use utf8;


sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    print STDERR "FILENAME =".Dumper($filename)."\n";
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my %errors;
    my %supported_cross_types;

    open(my $F, "< :encoding(UTF-8)", $filename) || die "Can't open archive file $filename";
    my %stocks;

    my $header = <$F>;
    $header =~ s/\r//g;
    chomp($header);
    my ($progeny_name, $female_parent_accession, $male_parent_accession, $type) =split /\t/, $header;

    my %header_errors;

    if ($progeny_name ne 'progeny name') {
	    $header_errors{'progeny name'} = "First column must have header 'progeny name' (not '$progeny_name'); ";
    }

    if ($female_parent_accession ne 'female parent accession') {
	    $header_errors{'female parent accession'} = "Second column must have header 'female parent accession' (not '$female_parent_accession'); ";
    }

    if ($male_parent_accession ne 'male parent accession') {
	    $header_errors{'male parent accession'} = "Third column must have header 'male parent accession' (not '$male_parent_accession'); ";
    }

    if ($type ne 'type') {
	    $header_errors{'type'} = "Fourth column must have header 'type' (not '$type');";
    }

    if (%header_errors) {
	    my $error = join "<br />", values %header_errors;
        push @error_messages, $error;
    }

    my %legal_cross_types = ( biparental => 1, open => 1, self => 1, sib => 1, polycross => 1, backcross => 1, reselected => 1, doubled_haploid => 1, dihaploid_induction => 1 );

    while (<$F>) {
        chomp;
        $_ =~ s/\r//g;
        my @acc = split /\t/;
        for(my $i=0; $i<3; $i++) {
            if ($acc[$i] =~ /\,/) {
                my @a = split /\s*\,\s*/, $acc[$i];  # a comma separated list for an open pollination can be given
                foreach (@a) {
                    if ($_){
                        $_ =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
                        $stocks{$_}++;
                    }
                };
            }
            else {
                if ($acc[$i]){
                    $acc[$i] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
                    $stocks{$acc[$i]}++;
                }
            }
        }

            # check if the cross types are recognized...
    	#
        if ($acc[3] && !exists($legal_cross_types{lc($acc[3])})) {
            $errors{"not legal cross type: $acc[3] (should be biparental, self, open, sib, backcross, reselected or polycross)"}=1;
        }
    }
    close($F);
    my @unique_stocks = keys(%stocks);
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions_or_populations_or_vector_constructs',\@unique_stocks)->{'missing'}};
    my $cross_validator = CXGN::List::Validate->new();
    my @stocks_missing = @{$cross_validator->validate($schema,'crosses',\@accessions_missing)->{'missing'}};
    if (scalar(@stocks_missing)>0){
        $errors{"The following parents or progenies are not in the database: ".(join ",", @stocks_missing)} = 1;
    }

    if (%errors) {
        push @error_messages, "There were problems loading the pedigree for the following accessions or populations: ".(join ",", keys(%errors)).". Please fix these errors and try again. (errors: ".(join ", ", values(%errors)).")" ;
    }

    print STDERR "ERROR MESSAGES =".Dumper(\@error_messages)."\n";

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }


    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my %parsed_result;


    open(my $F, "< :encoding(UTF-8)", $filename) || die "Can't open file $filename";
    my $header = <$F>;
    my @pedigrees;
    my $line_num = 2;
    while (<$F>) {
        my $female_parent;
        my $male_parent;
        chomp;
        $_ =~ s/\r//g;
        my ($progeny, $female, $male, $cross_type) = split /\t/;
        $progeny =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $female =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $male =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        if(($cross_type eq "self") || ($cross_type eq "reselected") || ($cross_type eq "dihaploid_induction") || ($cross_type eq "doubled_haploid") || ($cross_type eq "backcross")) {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
        }
        elsif(($cross_type eq 'biparental') || ($cross_type eq 'backcross') || ($cross_type eq "sib") || ($cross_type eq "polycross")){
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
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
        $line_num++;
    }

    $parsed_result{'pedigrees'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
