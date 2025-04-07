#!/usr/bin/perl

=head1

load_people.pl - loading user accounts into cxgn databases

=head1 SYNOPSIS

load_people.pl -H [dbhost] -D [dbname] -i [infile]

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

This script loads user account data into the sgn_people.sp_person and sgn_people.sp_login table. Each column in the spreadsheet represents a single user, and one row will be added to sp_login and one row to sp_person. 

The input file is xlsx format, and should have the following columns (column order is not important):

username 
first_name
last_name
email
organization
address
country
phone
research_keywords
research_interests
webpage
password

The first four columns listed are required. If no password is provided the system will create one.

The script outputs the username, first_name, last_name, email and assigned initial random password. This can be used to send the password to the user. 

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
use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;
use Text::Iconv;
use Crypt::RandPasswd;
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

my $people_schema = CXGN::People::Schema->connect( sub { $dbh->get_actual_dbh() } );

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
	my @required_headers = qw | first_name last_name username email |;
	
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
	    
	    if (!$data{username} || !$data{email} || !$data{first_name} || !$data{last_name}) {
		print STDERR "Not enough information provided in row ".join(", ", @fields).". Skipping.\n";
		next();
	    }
	    
	    my $row = $people_schema->resultset("SpPerson")->find( { username => $data{username} } );
	    if ($row) {
		print STDERR "Username $data{username} already exists in the database. Skipping this row.\n";
		next();
	    }

	    if ($data{email}) {	
		my $rs = $people_schema->resultset("SpPerson")
		    ->search( { '-or' => [ contact_email => $data{email}, private_email => $data{email}, pending_email => $data{email} ] } );
		
		if ($rs->count > 0) {
		    print STDERR "Email $data{email} already exists in the database in contact_email, pending_email, or private_email field. Skipping this row.\n";
		    next();
		}
	    }

	    # $row = $people_schema->resultset("SpPerson")->find( { pending_email => $data{email} });
	    # if ($row) {
	    # 	print STDERR "Email $data{email} already exists in the database in pending_email field. Skipping this row.\n";
	    # 	next();
	    # }
	    
	    my $password;

	    if ($data{password}) {
		$password = $data{password};
	    }
	    else {
		$password =Crypt::RandPasswd->word( 8 , 8 );
	    }
	    
	    if ($data{username}) {
		my $login = CXGN::People::Login->new($dbh);
				
		$login->set_username($data{username});
		$login->set_private_email($data{email});
		$login->set_pending_email($data{email});
		$login->set_organization($data{organization});
		$login->set_password($password);

		print  "$data{first_name}\t$data{last_name}\t$data{username}\t$data{email}\t$password\n";
		
		my $sp_person_id = $login->store();

		print STDERR "SP PERSON ID = ".$sp_person_id."\n";
		
		my $person = CXGN::People::Person->new($dbh, $sp_person_id);
		
		$person->set_first_name($data{first_name});
		$person->set_last_name($data{last_name});
		$person->set_contact_email($data{email});
		$person->set_address($data{address});
		$person->set_country($data{country});
		$person->set_phone_number($data{phone_number});
		$person->set_research_keywords($data{research_keywords});
		$person->set_research_interests($data{research_interests});
		$person->set_webpage($data{webpage});
		$person->store();
	    }   
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
