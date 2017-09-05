
package CXGN::List::Validate::Plugin::Traits;

use Moose;
use Data::Dumper;

sub name {
    return "traits";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my @missing;

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

# Expects $terms to be full trait names e.g. root weight|CO_334:0000012
# For postcomposed terms expects full trait names e.g. tissue metabolite unit time|COMP:0000015

    foreach my $term (@$list) {
        print STDERR $term."\n";

        my @parts = split (/\|/ , $term);
        my ($db_name, $accession) = split ":", pop @parts;
        
        $accession =~ s/\s+$//;
        $accession =~ s/^\s+//;
        $db_name =~ s/\s+$//;
        $db_name =~ s/^\s+//;

        my $db_rs = $schema->resultset("General::Db")->search( { 'me.name' => $db_name });
        if ($db_rs->count() == 0) {
            print STDERR "Problem found with term $term at db $db_name\n";
            push @missing, $term;
        } else {
            my $db = $db_rs->first();
            my $rs = $schema->resultset("Cv::Cvterm")->search( {
            'dbxref.db_id' => $db->db_id(),
            'dbxref.accession'=>$accession }, {
                'join' => 'dbxref' }
            );

            if ($rs->count == 0) {
                print STDERR "Problem found with term $term at cvterm rs from accession $accession point 2\n";
                push @missing, $term;
            } else {
                my $rs_var = $rs->search_related('cvterm_relationship_subjects', {'type.name' => 'VARIABLE_OF'}, { 'join' => 'type'});
                if ($rs_var->count == 0) {
                    print STDERR "Problem found with term $term at variable check point 3\n";
                    push @missing, $term;
                }
            }
        }

    }
    # print STDERR Dumper \@missing;
    return { missing => \@missing };
}

1;
