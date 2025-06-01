
=head1 NAME

download_obo.pl - script to download obo file of an ontology

=head1 SYNOPSIS

perl download_obo.pl -i prefix -H host -D dbname

=head1 DESCRIPTION

Download an obo file from your database. The file will contain all terms listed under the provided ontology prefix (db.name).
The obo filename is $prefix_breedbase.obo.
After downloading the file it is recommended to test it in the Protege program to make sure it is a valid obo,
and loading back into the database with gmod_load_cvterms.pl  <see the solgenomics/chado_tools repo>


This script currently prints the following fields:

    [Term]
    id: $prefix:$accession
    name: $cvterm_name
    namespace: $namespace
    def: "$def" #if the cvterm 'definition' field is populated
    is_obsolete: true #if cvterm is_obsolete field is 'true'
    synonym: $synonym_name []  # one row for each synonym
    xref: $xref_cvterm [] # one row for each cvterm xref that is not for the cvterm is_for_definition
    is_a: $cvterm # one row for each is_a relationship object
    relationship: $typedef $cvterm # one row for each relationship type that is not is_a (e.g. variable_of, method_of, scale_of)

    --------------------------------------------

    Example:

    [Term]
    id: CO_334:0000009
    name: initial vigor assessment 1-7
    namespace: cassava_trait
    def: "Visual assessment of plant vigor during establishment scored one month after planting. 3 = Not vigorous, 5 = Medium vigor, 7 = highly vigorous." [CO:curators]
    synonym: "Can't fall when there is strong wind" EXACT []
    synonym: "IVig_IITAVisScg_1to7" EXACT []
    synonym: "vigor" EXACT []
    xref: TO:0000250
    is_a: CO_334:0001000 ! Variables
    is_a: CO_334:0002010 ! Farmer trait
    relationship: variable_of CO_334:0000386 ! Initial vigor
    relationship: variable_of CO_334:0010228 ! Visual Rating: Initial vigor_method
    relationship: variable_of CO_334:0100434 ! 7pt scale

    ------------------------------------------

If there are any cvterm.is_relationshiptype for this ontology they will be printed as
    [Typedef]
    id: $cvterm_name
    name: $cvterm_name


=head1 COMMAND-LINE OPTIONS

    -H host name
    -D database name
    -i prefix for the ontology (e.g. CO_334)
    -t Test run. Rolls back at the end.

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Try::Tiny;
use DateTime;

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use File::Slurp;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_i);

getopts('H:D:U:P:i:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $prefix = $opt_i;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
        dbname=>$dbname,
        dbargs => {AutoCommit => 0,
        RaiseError => 1}
    } );

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my $obo_file = $prefix . ".breedbase.obo";

#resultset of all cvterms
my $cvterm_rs = $schema->resultset("Cv::Cvterm")->search(
    { 'db.name' => $prefix },
    { join => [ 'cv', { dbxref => 'db' } ]  ,
    '+select' => ['cv.name', 'dbxref.accession'],
    '+as' => [ 'cv_name', 'dbxref_accession' ]
} );

my $date = DateTime->now();

my $obo_header = "format-version: 1.2
ontology: $prefix\n\n";

write_file( $obo_file,  {append => 0 }, $obo_header  ) ;
my $count=0;
while(my $cvterm = $cvterm_rs->next() ) {
    my $accession = $cvterm->dbxref->accession();
    print STDERR "Looking at Accession $accession\n";
    my $cvterm_name = $cvterm->name();
    my $namespace = $cvterm->cv->name();
    my $def = $cvterm->definition();
    #remove quotes from definition sting
    $def =~ s/"//g;
    my $is_obsolete = $cvterm->is_obsolete();
    my $is_relationshiptype = $cvterm->is_relationshiptype();
    my $is_obsolete = $cvterm->is_obsolete();

    my $term_details = "\n[Term]\nid: $prefix:$accession\nname: $cvterm_name\nnamespace: $namespace\n";
    $term_details .="def: \"$def\"\n" if $def;
    $term_details .="is_obsolete: true\n" if $is_obsolete;
    $count++;
    if ($is_relationshiptype) {
        $term_details = "
[Typedef]
id: $cvterm_name
name: $cvterm_name
"
    }
    write_file( $obo_file,  {append => 1 }, "$term_details" );

    my $syn_rs = $cvterm->cvtermsynonyms();
    my $xref_rs = $cvterm->cvterm_dbxrefs();
    my $relationships_rs = $cvterm->cvterm_relationship_subjects();

    while( my $synonym = $syn_rs->next() ) {
        my $syn_name  =  $synonym->synonym();
        print STDERR "synonym = $syn_name\n";
        my $type = $synonym->type;
        my $type_name ;

        defined $type ? $type_name = $type->name : "[]";

        #synonyms need to be quoted. Somtimes they are already quoted if loaded properly from the obo loader
        unless ($syn_name =~ /^\"/) { $syn_name = '"' . $syn_name . '"' ; }
        #xref list for synonyms
        unless ($syn_name =~ /$\]/) { $syn_name .= " []" ; }
        write_file( $obo_file,  {append => 1 }, "synonym: "  . $syn_name  . $type_name . "\n" );
    }
    while( my $xref = $xref_rs->next() ) {
        my $xref_acc  =  $xref->dbxref->accession();
        my $xref_prefix = $xref->dbxref->db->name();
        print STDERR "xref = $xref_prefix:$xref_acc\n";
        write_file( $obo_file,  {append => 1 }, "xref: "  . $xref_prefix . ":"  . $xref_acc . "\n" ) if ( $xref->is_for_definition == 0 );
    }

    while( my $rel = $relationships_rs->next() ) {
        my $object = $rel->object();
        my $type = $rel->type();
        my $object_name = $object->name();
        my $object_acc = $object->dbxref->accession();
        my $object_acc_prefix = $object->dbxref->db->name();

        my $type_name = $type->name();

        my $relationship_format = "is_a:";
        if ($type_name ne "is_a") {
            $relationship_format = "relationship: $type_name";
        }
        print STDERR "$relationship_format $object_acc_prefix:$object_acc\n";
        write_file( $obo_file,  {append => 1 }, "$relationship_format $object_acc_prefix:$object_acc " . "! ". $object_name . "\n" );
    }
}
print STDERR "wrote $count terms to file $obo_file\n";
