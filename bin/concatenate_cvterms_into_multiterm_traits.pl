#!/usr/bin/env perl

=head1
concatenate_cvterms_into_multi_term_traits.pl

=head1 SYNOPSIS

    this script is very specific to cassbase ontologies, but could possibly be generalized through more sophisticated recursion.

    perl concatenate_cvterms_into_multiterm_traits.pl -H localhost -D fixture2 -l 'chebi_compounds|CHEBI:00000[OR]ec_terms|EC:0000000,cass_tissues|CASSTISS:0000000,cass time of day|CASSTIME:0000001,cass number of weeks|CASSTIME:0000005,cass_units|CASSUNIT:0000000' -d CASSFT -c cassava_trait

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -l  comma separated list of parent cvterms. the first term can take [OR] separated parent cvterms. all children of the parent term (is_a relationship) will be concatenated together and saved.
 -d  the db name that the new cvterms will be stored under. Must be a new db name in this implementation.
 -c  the cv name that the new cvterms will be stored under.

=head2 DESCRIPTION


=head2 AUTHOR

Nicolas Morales (nm529@cornell.edu)

April 2014

=head2

The CASS project requires traits to be composed of many separate terms. This script concatenates cvterms into multi-term traits. A list of parent cvterms is given using the -l parameter. The script then finds all child terms that are of 'is_a' relationship to the parent terms given. All the children terms are then linearly combined in the order that the parent terms are in. The cvterms are separated by || in the concatenated string. 

The new concatenated strings are stored as cvterms, with cv = $opt_c and db = $opt_d



TODO during pheno spreadsheet upload make trait validation split the term on || and then nvalidate the individual terms.

Example: specifying -l CHEBI:00000,cass_tissue|CASSTISS:000000,cass time of day|CASSTIME:0000001 will create many new concatenated terms, one of which would be the concatenation of 'ADP|CHEBI:16761', 'cass leaf|CASSTISS:0000001', and 'cass end of night|CASSTIME:0000002' into 'ADP|CHEBI:16761||cass leaf|CASSTISS:0000001||cass end of night|CASSTIME:0000002'

=cut

use strict;
use warnings;

use lib 'lib';
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;
use Data::Dumper;
use SGN::Model::Cvterm;
use Try::Tiny;

our ($opt_H, $opt_D, $opt_l, $opt_d, $opt_c);
getopts('H:D:l:d:c:');



if (!$opt_D || !$opt_H || !$opt_l || !$opt_d || !$opt_c ) {
  die("Exiting: options missing\nRequires: -D -H -l -d -c");
}

my $dbh = CXGN::DB::InsertDBH
  ->new({
	 dbname => $opt_D,
	 dbhost => $opt_H,
	 dbargs => {AutoCommit => 1,
		    RaiseError => 1},
	});

my $schema = Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my $db = $schema->resultset("General::Db")->create({name=>$opt_d});
my $db_id = $db->db_id();
my $cv = $schema->resultset("Cv::Cv")->find_or_create({name=>$opt_c});
my $cv_id = $cv->cv_id();

my $accession = 0;

my @parent_trait_names = split /,/, $opt_l;

my $first_element = splice @parent_trait_names, 0, 1;
my @first_parent_names = split /\[OR\]/, $first_element;
foreach my $i (@first_parent_names) {
    my @children_array;

    my $children = get_children($schema, $i);
    push (@children_array, $children);

    foreach my $j (@parent_trait_names) {
        my $children;
        if ($j eq 'cass_tissues|CASSTISS:0000000') {
            my @sub_nodes = ('cass leaf|CASSTISS:0000001', 'cass stem|CASSTISS:0000002', 'cass root|CASSTISS:0000003');
            foreach my $t (@sub_nodes) {
                my $sub_children = get_children($schema, $t);
                push @$children, @$sub_children;
            }
        } else {
            $children = get_children($schema, $j);
        }
        push (@children_array, $children);
    }

    print Dumper \@children_array;

    my $count = 0;
    my @concatenated_terms;
    my $first_term = $children_array[0];
    foreach my $a (@$first_term) {
        my $a_concat_term = $a;
        my $second_term = $children_array[1];
        foreach my $b (@$second_term) {
            my $b_concat_term = $a_concat_term.'||'.$b;
            my $third_term = $children_array[2];
            foreach my $c (@$third_term) {
                my $c_concat_term = $b_concat_term.'||'.$c;
                my $fourth_term = $children_array[3];
                foreach my $d (@$fourth_term) {
                    my $d_concat_term = $c_concat_term.'||'.$d;
                    my $fifth_term = $children_array[4];
                    foreach my $e (@$fifth_term) {
                        my $e_concat_term = $d_concat_term.'||'.$e;
                        push @concatenated_terms, $e_concat_term;
                    }
                }
            }
        }
    }



    #print Dumper \@concatenated_terms;
    print scalar(@{$children_array[0]}) * scalar(@{$children_array[1]}) * scalar(@{$children_array[2]}) * scalar(@{$children_array[3]}) * scalar(@{$children_array[4]})."\n";
    print scalar(@concatenated_terms)."\n";

    foreach (@concatenated_terms) {
        my $accession_string = sprintf("%07d",$accession);
        my $dbxref = $schema->resultset("General::Dbxref")->create({db_id=>$db_id, accession=>$accession_string});
        my $dbxref_id = $dbxref->dbxref_id();
        my $cvterm = $schema->resultset("Cv::Cvterm")->create({cv_id=>$cv_id, name=>$_, dbxref_id=>$dbxref_id});
        $accession++;
        $count++;
    }

    print STDERR "Added $count new terms.\n";
}

print STDERR "Complete.\n";


sub get_children {
    my $schema = shift;
    my $term = shift;
    print $term."\n";
    my $parent_node_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $term)->cvterm_id();
    my $rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a', 'relationship')->cvterm_id();

    my $children_ref = $schema->resultset("Cv::CvtermRelationship")->search({type_id => $rel_cvterm_id, object_id => $parent_node_cvterm_id})->search_related('subject');
    my @children;
    while (my $child = $children_ref->next() ) {
        my $dbxref_info = $child->search_related('dbxref');
        my $accession = $dbxref_info->first()->accession();
        my $db_info = $dbxref_info->search_related('db');
        my $db_name = $db_info->first()->name();
        push @children, $child->name."|".$db_name.":".$accession;
    }
    return \@children;
}
