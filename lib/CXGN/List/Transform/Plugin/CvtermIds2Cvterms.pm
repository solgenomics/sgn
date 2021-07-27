package CXGN::List::Transform::Plugin::CvtermIds2Cvterms;

use Moose;
use Data::Dumper;

sub name {
    return "cvterm_ids_2_cvterms";
}

sub display_name {
    return "cvterm IDs to cvterms";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "cvterm_ids") and ($type2 eq "cvterms")) {
        return 1;
    }
    else {  return 0; }
}


sub transform {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @transform = ();

    my @missing = ();

    if (ref($list) eq "ARRAY" ) {
        foreach my $l (@$list) {
            my $rs = $schema->resultset("Cv::Cvterm")->search({ cvterm_id => $l });

            if ($rs->count() == 0) {
                push @missing, $l;
            } else {
                push @transform, $rs->first()->name();
            }
        }
    }
    return {
        transform => \@transform,
        missing => \@missing,
    };
}

1;
