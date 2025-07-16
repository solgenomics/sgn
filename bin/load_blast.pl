#!/usr/bin/perl

=head1 NAME

load_blast.pl - loading blast tables into cxgn databases

=head1 SYNOPSIS

load_blast.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS

=head2 ARGUMENTS

=over 5

=item -H

host name (required) e.g. "localhost"

=item -D

database name (required) e.g. "cxgn_cassava"

=item -i

path to infile (required)

=back

=head2 FLAGS

=over 5

=item -t

Test run. Rolling back at the end.

=back 

=head1 DESCRIPTION

This script populates blast tables (sgn.blast_db, sgn.blast_db_group and the linking table). Each column in the spreadsheet represents a single blast fasta file. Connections to the blast_group are also made. 

The input file is xlsx format, and should have the following columns (column order is not important):

 file_base      # starts where blast_path ends in sgn_local.conf
 title
 type           # either nucleotide or protein
 source_url
 lookup_url
 update_freq
 info_url
 index_seqs
 blast_db_group
 web_interface_visible
 description
 jbrowse_src

Only file_base, title, type and blast_db_group are required. web_interface_visible is 'T' by default.

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>, Nov 2022

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use JSON::Any;
use JSON::PP;
use Carp qw /croak/ ;
use Try::Tiny;
use Pod::Usage;
use Spreadsheet::XLSX;
use Bio::Chado::Schema;
use CXGN::People::Person;
use CXGN::People::Schema;
use SGN::Schema;
use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;
use Text::Iconv;

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:i:tD:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;

print STDERR "Input file: $file\n";
print STDERR "DB host: $dbhost\n";
print STDERR "DB name: $dbname\n";
print STDERR "Rollback: $opt_t\n";

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file)\n");
}

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );

my $sgn_schema = SGN::Schema->connect( sub { $dbh->get_actual_dbh() } );

my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn,sgn_people');

my $converter = Text::Iconv->new("utf-8", "windows-1251");

my $excel = Spreadsheet::XLSX->new($opt_i, $converter);

my $coderef = sub {

    foreach my $sheet (@{$excel->{Worksheet}}) {
	
	printf("Sheet: %s\n", $sheet->{Name});
	
	$sheet->{MaxRow} ||= $sheet->{MinRow};

	print STDERR "MIN ROW = ".$sheet->{MinRow}."\n";

	# parse header
	#
	my @required_headers = qw | file_base title type blast_db_group |;
	
	my %ch;
	my @header;
	
	foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow}) { 
	    @header = @{$sheet->{Cells}->[0]};

	    for(my $i =0; $i< @header; $i++) {
		print STDERR $header[$i]->{Val}."\n";
		$ch{$header[$i]->{Val} } = $i;
	    }
	}

	print STDERR "HEADERS: ".Dumper(\%ch);
	print STDERR "REQUIRED: ".Dumper(\@required_headers);
	
	my @missing_headers;
	foreach my $h (@required_headers) {
	    if (!exists($ch{$h})) {
		push @missing_headers, $h;
	    }
	}

	if (@missing_headers) {
	    print STDERR "Required headers include: ". join(", ", @required_headers)."\n";
	    print STDERR "Missing: ".join(", ", @missing_headers)."\n";

	    die "Check file format for header requirements.";
	}
	    
	foreach my $row (1 .. $sheet->{MaxRow}) {

	    $sheet->{MaxCol} ||= $sheet->{MinCol};

	    my @fields = map { $_ ->{Val} } @{$sheet->{Cells}->[$row]};

	    my %data;
	    for(my $n =0; $n< @header; $n++) {
		if ($fields[$n]) {
		    $data{$header[$n]->{Val}} = $fields[$n];
		}
	    }

	    print STDERR "DATA: ".Dumper(\%data);
	    
	    if (!$data{file_base} || !$data{title} || !$data{type} || !$data{blast_db_group}) {
		print STDERR "Not enough information provided in row ".join(", ", @fields).". Skipping.\n";
		next();
	    }

	    my $group_row = $sgn_schema->resultset("BlastDbGroup")->find_or_create( { name => $data{blast_db_group}, ordinal => 20 });

	    my $blast_db_group_id;
	    
#	    if (!$group_row) {

#		$group_row = $sgn_schema->resultset("BlastDbGroup")->find_or_create(#
		   # {
	#		name => $data{blast_db_group},
#			ordinal => 20,
#		    });
#	    }
	    $blast_db_group_id = $group_row->blast_db_group_id();
		
	    
	    my $row = $sgn_schema->resultset("BlastDb")->find( { title => $data{title} } );

	    my $data = {
		file_base => $data{file_base},
		title => $data{title},
		type => $data{type},
		source_url => $data{source_url},
		lookup_url => $data{lookup_url},
		update_freq => $data{update_freq},
		info_url => $data{info_url},
		index_seqs => $data{index_seqs},
		blast_db_group_id => $blast_db_group_id,
		web_interface_visible => $data{web_interface_visible} || 'T',
		description => $data{description},
	    };

	    
	    if ($row) {
		print STDERR "upading blast dataset $data{title}...\n";

		$row->update($data);
		
	    }

	    else {
		$row = $sgn_schema->resultset("BlastDb")->find_or_create($data);
	    }

	    my $grow = $sgn_schema->resultset("BlastDbBlastDbGroup")->find_or_create(
		{
		    blast_db_id=> $row->blast_db_id(),
		    blast_db_group_id => $blast_db_group_id,
		});
	}	
    }
};

try {
    $schema->txn_do($coderef);
    if (!$opt_t) {
	print "Transaction succeeded! Commiting user data! \n\n";
    }
    else {
	die "Not storing, rolling back\n";
    }
    
} catch {
    # Transaction failed
    die "An error occured! Rolling back!" . $_ . "\n";
};

$dbh->disconnect();
