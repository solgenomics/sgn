
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

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

    my @missing = ();
    foreach my $term (@$list) {
        my $delim = q{|};
        my $full_accession = substr $term, rindex( $term, $delim ) + length $delim;

        my ($db_name, $accession) = split ":", $full_accession;
        if ($accession) {
            $accession =~ s/\s+$//;
            $accession =~ s/^\s+//;
        }
        if ($db_name) {
            $db_name  =~ s/\s+$//;
            $db_name  =~ s/^\s+//;
        }

        my $db_rs = $schema->resultset("General::Db")->search( { 'me.name' => $db_name });
        if ($db_rs->count() == 0) {
            push @missing, $term;
        }
        else {
            my $rs = $schema->resultset("Cv::Cvterm")->search( {
            'dbxref.db_id' => $db_rs->first()->db_id(),
            'dbxref.accession'=>$accession }, {
                'join' => 'dbxref' }
            );

            #print STDERR "COUNT: ".$rs->count."\n";

            if ($rs->count == 0) {
                push @missing, $_;
            } else {
                my $rs_var = $rs->search_related('cvterm_relationship_subjects', {'type.name' => 'VARIABLE_OF'}, { 'join' => 'type'});
                if ($rs_var->count == 0) {
                    push @missing, $term;
                }
            }
        }
    }
    return { missing => \@missing };
}

1;
