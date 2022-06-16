
=head1 NAME
 load_dbxref.pl - a script to link marker_names with cvterm for external database link, this script uses the nd_protocolprop table
     with a typdef_id

=head1 SYNOPSYS

load_locus_publications.pl -p [person_id] -H [hostname] -D [database name] -c dbxref -j protocol_id file

where file contains a column with marker names
if marker_name does not exist then do not insert
nd_protocolprop format { dbxref: dbxref_name, marker: {array of marker_names} }
To use an existing protocol (not create a new nd_protocol name entry), use -j protocol_id

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS

-H host name (required) e.g. "localhost"
-D database name (required) e.g. "cxgn_cassava"
-j protocol_id (Will associate genotype data to an existing nd_protocol_id)

=head1 AUTHOR

Clay Birkett <clb343@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Std;
use File::Slurp qw | slurp |;
use CXGN::DB::InsertDBH;

our %opts;
getopts('p:H:D:j:', \%opts);

my $file = shift;

my @lines = slurp($file);
chomp(@lines);

my $dbh = CXGN::DB::InsertDBH->new( { dbname => $opts{D},
				      dbhost => $opts{H},
				    });


my $sth;
my @row;
my $alias;
my $count;
my $count_add;
my $marker_id;
my %alias_list;
my %marker_list;
my %unique_list;

my $protocol_id = $opt_j;

#if protocol_id provided, a new one will not be created
if ($protocol_id){
    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });
    $organism_species = $protocol->species_name;
    $obs_type = $protocol->sample_observation_unit_type_name if !$obs_type;
}

##get list of current alias entries
##use (marker_id, alias) as unique key so we don't duplicate entries
my $key;
$count = 0;
$sth = $dbh->prepare("SELECT alias, marker_id, preferred from marker_alias");
$sth->execute();
while (@row = $sth->fetchrow_array()) {
    $count++;
    $alias = $row[0];
    if ($row[2]) {
	$marker_list{$alias} = $row[1];
    } else {
        $alias_list{$alias} = $row[1];
    }
    $key = $row[0] . $row[1];
    $unique_list{$key} = 1;
}
print "$count from marker_alias\n";

$count = 0;
$sth = $dbh->prepare("INSERT into marker_alias (marker_id, alias, preferred) values (?, ?, ?)");
foreach my $l (@lines) { 
    $count++;
    push (@marker_list, $alias);
}

    my ($marker_name, $alias) = split /\t/, $l;
    my @alias_list = split /\|/, $alias;
    if (exists($marker_list{$marker_name})) {
	$marker_id = $marker_list{$marker_name};
        foreach (@alias_list) {
	    $key = $_ . $marker_id;
            if (exists($unique_list{$key})) {
	    } else {
		$count_add++;
		$sth->execute($marker_id, $_, 0);
		$alias_list{$_} = $marker_id;
	    }
        }
    } else {
	$sth2 = $dbh->prepare("INSERT into marker (dummy_field) values (null) RETURNING marker_id");
	$sth2->execute();
	($marker_id) = $sth2->fetchrow_array();
	$sth2 = $dbh->prepare("INSERT into marker_alias (marker_id, alias, preferred) values (?, ?, ?)");
	$sth2->execute($marker_id, $marker_name, 1);
	print "added marker $marker_name $marker_id\n";
	foreach (@alias_list) {
            $key = $_ . $marker_id;
            if (exists($unique_list{$key})) {
            } else {
                $count_add++;
                $sth->execute($marker_id, $_, 0);
                $alias_list{$_} = $marker_id;
            }
	    print "added alias $_\n";
        }
        last;	
    }
}
print "$count total $count_add added\n";

$dbh->commit();
    
				





