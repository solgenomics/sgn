#!/usr/bin/env perl

use strict;
use warnings;
use English;
use Carp;
#$Carp::Verbose = 1;
use FindBin;
use Getopt::Std;
use Data::Dumper;
use File::Spec;
use File::Temp qw/tempfile/;

use SGN::Schema;
use CXGN::Blast;
use CXGN::DB::InsertDBH;

sub usage {
    my $sgn_schema = shift;
    my $message = shift || '';
    $message = "Error: $message\n" if $message;

#    my $file_bases = join '', sort map '    '.$_->file_base."\n", CXGN::BlastDB->retrieve_all($sgn_schema, $opt{d});

    die <<EOU;
    $message
      Usage:
	$FindBin::Script [ options ] -d <path>

  Go over all the BLAST databases we keep in stock and update them if
  needed.  When run with just the -g option, goes over all the BLAST
  dbs listed in the sgn.blast_db table and updates them if needed,
  putting them under the top-level BLAST db path given with the -d
  option.

  Options:

  -H <dbhost>

  -D <dbname>

  -p <password> (if not supplied, will prompt)

  -U <dbuser>   (if -p option is supplied)

  -d <path>     required.  path where all blast DB files are expected to go.

  -t <path>     path to put tempfiles.  must be writable.  Defaults to /tmp.

  -x   dry run, just print what you would update

  -f <db name>  force-update the DB with the given file base (e.g. 'genbank/nr')

  -a force update all dbs in blast dir - override needs_update and run makeblastdb on all blast datasets found in filebase

   Current list of file_bases:

EOU
}


our %opt;
getopts('axt:d:f:H:D:p:U:h',\%opt) or die "Invalid arguments";

$opt{t} ||= File::Spec->tmpdir;

print STDERR "Connecting to database... $opt{H} $opt{D}\n";

my $dbh;

if (!$opt{p}) {
    $dbh = CXGN::DB::InsertDBH->new( { dbhost => $opt{H}, dbname => $opt{D} });
}
else {
    $dbh = CXGN::DB::Connection->new( { dbhost => $opt{H}, dbname => $opt{D}, dbpass => $opt{p}, dbuser => $opt{U} });
}

print STDERR "Creating schema object...\n";
my $sgn_schema = SGN::Schema->connect( sub{ $dbh->get_actual_dbh() });

if ($opt{h}) { usage($sgn_schema); exit(); }

#if a alternate blast dbs path was given, set it in the BlastDB
#object
$opt{d} or usage($sgn_schema, '-d option is required');
-d $opt{d} or usage($sgn_schema, "directory $opt{d} not found");

my $bdbs = CXGN::Blast->new( sgn_schema => $sgn_schema, dbpath => $opt{d} );

my @dbs = $opt{f} ? CXGN::Blast->search( $sgn_schema, $opt{d}, file_base => $opt{f} )
    : CXGN::Blast->retrieve_all($sgn_schema, $opt{d});
unless(@dbs) {
    print $opt{f} ? "No database found with file_base='$opt{f}'.\n"
	: "No dbs found in database.\n";
}

my $count;
my @errs;

foreach my $db (@dbs) {

    print STDERR "Processing database ".$db->title(). "\n".  $db->file_base . "\n" ;
    #check if the blast db needs an update
    unless($opt{f} || $db->needs_update || $opt{a}) {
	print $db->file_base." is up to date.\n";
	next;
    }

    print STDERR "checking source url..\n";
    ##Not usig source_url anymore. Source files need to be in the blast db dir
    #skip the DB if it does not have a source url defined
    #unless($db->source_url) {
	  #   warn $db->file_base." needs to be updated, but has no source_url.  Skipped.\n";
	  #   next;
    #}
    ###########
    ###do not use source_url. Need to make sure all db fasta files are in the blast basedir
    #my $source_url = $db->source_url ;
    #$source_url =~ s/^ftp:\/\/ftp.sgn.cornell.edu/http:\/\/solgenomics.net\/ftp/;
    ###########
    my $file_path =  $opt{d} . $db->file_base;

    if( $opt{x} ) {
	     print "Would update ".$db->file_base." from file  ".$file_path."\n";
	      next;
    } else {
	     print "Updating ".$db->file_base." from file...\n";
    }

    eval {

	print STDERR "Checking permissions...\n";

	# check whether we have permissions to do the format
	if( my $perm_error = $db->check_format_permissions() ) {
	    die "Cannot format ".$db->file_base.":\n$perm_error";
	}

	#download the sequences from the source url to a tempfile
	print STDERR "Reading source file (".$file_path.")...\n";

  #### no longer used. Check if some blast dbs need to be copied manually to the blast basedir
  #use source_url only if file not found in file_path
  #my (undef,$sourcefile) = tempfile('blastdb-source-XXXXXXXX',
	#				  DIR => $opt{t},
	#				  UNLINK => 1,
	 #   );

#	my $wget_opts = { cache => 0 };
#	$wget_opts->{gunzip} = 1 if $source_url =~ /\.gz$/i;
#	wget_filter( $source_url => $sourcefile, $wget_opts );

	#formatdb it into the correct place
	print STDERR "Formatting database...";
	$db->format_from_file($file_path);

	#unlink $sourcefile or warn "$! unlinking tempfile '$sourcefile'";

	print $db->file_base." done.\n";
    }; if( $EVAL_ERROR ) {
        print STDERR "Update failed for ".$db->file_base.":\n$EVAL_ERROR";
        push(@errs , "Update failed for ".$db->file_base.":\n$EVAL_ERROR\n");
       }
      $count++;
  }

  print STDERR "Updated $count blast dbs\n";
  print STDERR  join(", ", @errs);


$dbh->disconnect();
