
=head1 NAME

fix_tissue_samples_plot_associations.pl - a script to fix associations between tissue samples and plots, including plate wells

=head1 DESCRIPTION

perl bin/fix_tissue_sampels_plot_associations.pl -H <host> -D <dbname> file.tsv

where file.tsv is a tab delimited file with the following two columns:

tissue_sample - for the tissue sample uniquename

plot_name - for the plot name to be associated with the tissue_sample

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 DATE

June 2025

=cut

use strict;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::DB::Schemas;
use CXGN::Stock;
use SGN::Model::Cvterm;

our($opt_H, $opt_D, $opt_P);
getopts('H:D:xP:');

my $pw = $opt_P;

if (! $pw) { 
    print "Password for $opt_H / $opt_D: \n";
    $pw = (<STDIN>);
    chomp($pw);
}

my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw, { AutoCommit => 0, RaiseError=>1 });

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);

my $tissue_sample_of_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

my $s = CXGN::DB::Schemas->new({ dbh => $dbh });
my $schema = $s->bcs_schema();
my $file = shift;

open(my $F, "<", $file) || die "Can't open file $file\n";

while (<$F>) {
    chomp;

    my ($tissue_sample_name, $plot_name) = split /\t/;

    print STDERR "Dealing with $plot_name and $tissue_sample_name...\n";
    my $q = "SELECT plot.uniquename, plot.stock_id,  stock_relationship.stock_relationship_id, plot_type.name, tissue_sample.uniquename, tissue_sample.stock_id, tissue_sample_type.name FROM stock as plot join stock_relationship on(plot.stock_id = stock_relationship.object_id) join stock as tissue_sample on(stock_relationship.subject_id=tissue_sample.stock_id) join cvterm as plot_type on(plot.type_id=plot_type.cvterm_id) join cvterm as tissue_sample_type on(tissue_sample.type_id=tissue_sample_type.cvterm_id)  where plot_type.name='plot' and tissue_sample.uniquename=?";

    my $h = $dbh->prepare($q);

    $h->execute($tissue_sample_name);

    if (my ($already_associated_plot_name, $already_associated_plot_id, $stock_rel_id, $already_associated_plot_type, $associated_tissue_sample_name, $tissue_sample_id, $tissue_sample_type) = $h->fetchrow_array()) {
	
	if ($already_associated_plot_name) {
	    print STDERR "PLOT $already_associated_plot_name already assigned to tissue sample $tissue_sample_name. Skipping. \n";
	    next();
	}
	elsif ($tissue_sample_type ne 'tissue_sample') {
	    print STDERR "TISSUE SAMPLE $tissue_sample_name  IS NOT OF TYPE tissue_sample. Skipping.\n";
	}
	
    }
    else { 
	print STDERR "Associating $plot_name with $tissue_sample_name...\n";

	my $pq = "SELECT stock_id, cvterm.name FROM stock join cvterm on(stock.type_id=cvterm.cvterm_id) where uniquename = ?";
	my $h = $dbh->prepare($pq);
	$h->execute($plot_name);

	my ($plot_id, $type)  = $h->fetchrow_array();

	if ($type ne 'plot') {
	    print STDERR "$plot_name IS OF TYPE $type and not TYPE PLOT! Skipping.\n";
	    next();
	}

	my $pq = "SELECT stock_id, cvterm.name FROM stock join cvterm on(stock.type_id=cvterm.cvterm_id) where uniquename = ?";
	my $h = $dbh->prepare($pq);
	$h->execute($tissue_sample_name);

	my ($tissue_sample_id, $type) = $h->fetchrow_array();

	if ($type ne 'tissue_sample') {
	    print STDERR "$tissue_sample_name is not of type tissue_sample, instead it is $type. Skipping.\n";
	    next();
	}

	    
	my $iq = "INSERT INTO stock_relationship (object_id, subject_id, type_id) values (? , ?, ?)";

	my $ih = $dbh->prepare($iq);
	$ih->execute($plot_id, $tissue_sample_id, $tissue_sample_of_id);
	print STDERR "$iq with $plot_id, $tissue_sample_id, $tissue_sample_of_id\n";
	
    }
}

print STDERR "COMMITTING...\n";
$dbh->commit();


print STDERR "Done.\n";



