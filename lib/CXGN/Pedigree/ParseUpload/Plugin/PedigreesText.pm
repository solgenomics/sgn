package CXGN::Pedigree::ParseUpload::Plugin::PedigreesText;

use Moose::Role;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    return 1; #storing after validation plugin
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my %parsed_result;

    open(my $F, "< :encoding(UTF-8)", $filename) || die "Can't open file $filename";
    my $header = <$F>;
    my @pedigrees;
    my $line_num;
    while (<$F>) {
        my $female_parent;
        my $male_parent;
        chomp;
        $_ =~ s/\r//g;
        my ($progeny, $female, $male, $cross_type) = split /\t/;
        $progeny =~ s/^\s+|\s+$//g;
        $female =~ s/^\s+|\s+$//g;
        $male =~ s/^\s+|\s+$//g;

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

        my $pedigree_info = {
            cross_type => $cross_type,
            female_parent => $female_parent,
            name => $progeny
        };

        if ($male_parent) {
            $pedigree_info->{male_parent} = $male_parent;
        }


        my $pedigree = Bio::GeneticRelationships::Pedigree->new($pedigree_info);
        push @pedigrees, $pedigree;
        $line_num++;
    }

    $parsed_result{'pedigrees'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}



1;
