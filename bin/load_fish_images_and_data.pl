#!/usr/bin/env perl

# Standard stuff.
use strict;
use Data::Dumper;
use File::Basename;
use File::Glob;
use Getopt::Std;
use SGN::Image;

# Beth's stuff.
use CXGN::DB::Connection;


# Rob's stuff.
use CXGN::Genomic::Clone;
#use CXGN::Genomic::CloneNameParser;

# Just a little CSV parser.  (In defense of this package's style and existence,
# I wrote it on my third or fourth week here as an exercise in learning Perl,
# and it has required no maintenance since it was written.  You're welcome to
# curse me for not having found some crap in CPAN that does what this does.)
package CSV;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(csv_line_to_list read_csv_record);

### CSV parser.
# There are three states in this parser, code where the state
# changes occur can be visited by searching for $state assignments.
use constant ex_quote => 0;
use constant in_quote => 1;
use constant quote_maybe_escape => 2;

# The following three functions are only used in csv_to_list.
sub parse_error {
  my ($position, $errmsg, $line) = @_; 
  my $errstr = "CSV parse error at position $position: $errmsg\n$line";
  my $fmtstr = "%" . ($position+1) . "s";
  $errstr = $errstr . sprintf ($fmtstr, "^");
  die ($errstr);
}

# Note: this is factored out to make it easier to find all places in
# the code where state is changed, but it doesn't actually do much.
# In this and in the next sub, we use prototypes to make the call
# sites cleaner, not to omit parentheses.
sub change_state (\$$) {
  my ($statevarref, $state) = @_;
  $$statevarref = $state;
}

sub collect_field (\@\$\$) {
  my ($accumulator_array_ref, $accumulator_scalar_ref, $stateref) = @_;
  push @$accumulator_array_ref, $$accumulator_scalar_ref;
  $$accumulator_scalar_ref = "";
  $$stateref = ex_quote;
}

# Return an array of scalars consisting of strings scraped out of a
# line that's been CSV encoded.
sub csv_line_to_list {
  my ($csv_line, $separator_char, $quote_char) = @_;
  # A string for accumulating tokens.
  my $accstr = "";
  # An array for accumulating strings.
  my @accarr = ();
  # For useful error messages, the position in the line.
  my $pos = -1;
  # Parser state.  There are only 3 possible states: in_quote,  ex_quote,
  # and quote_maybe_escape.  The quote character is used both to terminate 
  # quoted strings and to escape itself inside quoted strings.
  my $state = ex_quote;
  while ($csv_line =~ m/(.)/g) {
    my $char = $1;
    $pos++;
    # Note: parser states are numbers, and so == is the optimal
    # comparison operator.  If you change parser states to strings, you'll have
    # to change these to eq comparisons.
    if ($state == ex_quote) {
      if ($char eq $quote_char) {
	if ($accstr) { # we've accumulated some datum, and see a quote: bogus.
	  parse_error ($pos, "quote character in unquoted datum", $csv_line);
	} else { # we're seeing a quote right after a separator.
	  change_state ($state, in_quote);
	}
      } elsif ($char eq $separator_char) { # end of field
	collect_field (@accarr, $accstr, $state);
      } else {
	$accstr .= $char;
      }
    }
    elsif ($state == in_quote) {
      if ($char eq $quote_char) {
	change_state ($state, quote_maybe_escape);
      } else {
	$accstr .= $char;
      }
    }
    elsif ($state == quote_maybe_escape) {
      if ($char eq $quote_char) {
	$accstr .= $quote_char;
	change_state ($state, in_quote);
      } elsif ($char eq $separator_char) {
	collect_field (@accarr, $accstr, $state);
      } else { # anything other than a quote or separator after a quote is bogus
	parse_error ($pos, "garbage character after close quote", $csv_line);
      }
    }
    else {
      parse_error ($pos, "bug in csv parser, unknown state $state", $csv_line);
    }
  }
  # If in datum at end of line
  # FIXME: ",XXX\r\n"
  if (($accstr ne "") && ($accstr ne "\r")) {
    if ($state == in_quote) {
      parse_error ($pos, "end of line reached inside quoted datum", $csv_line);
    }
    push (@accarr, $accstr);
  }
  return @accarr;
}

sub read_csv_record {
  my ($filehandle, $separator_char, $quote_char) = @_;
  my $line = <$filehandle>;
  chomp $line;
  return csv_line_to_list ($line, $separator_char, $quote_char);
}

use Exporter;
package Schmenomic;
our @ISA = qw(Exporter);
our @EXPORT = qw(decompose_bac_name canonicalize_bac_name id_query_for_bac_name id_for_bac_name);
# The existing genomic API and its implementation are needlessly
# complex.
# As of 2006/4/12, there are 3 libraries of clones, with the
# following maxima for each of platenum, wellrow, and wellcol:
#
#  336 | P   |  24
#  148 | P   |  24
#  132 | P   |  24
sub decompose_bac_name {
  my ($bac_name) = @_;
  unless ($bac_name) {
    print STDERR "no BAC name supplied";
    return (undef);
  }
  if ($bac_name =~ m/^([[:alpha:]_]+)?(\d{1,3})([[:alpha:]]{1})(\d{1,2})/) {
    my ($shortname, $platenum, $wellrow, $wellcol) = ($1, $2, $3, $4);
    return ([$shortname, $platenum, $wellrow, $wellcol]);
  } else {
#    warn ()"Unparseable BAC name $bac_name.  If the BAC name is valid fix decompose_bac_name().\n");
    return (undef);
  }
}

sub canonicalize_bac_name {
  my ($bac_name) = @_;
  my $decomposed_bac_name = decompose_bac_name ($bac_name);
  unless ($decomposed_bac_name) {
    return (undef);
  }
  my ($shortname, $platenum, $wellrow, $wellcol) = @$decomposed_bac_name;
  my $ret = sprintf "%s%0.3d%s%0.2d", $shortname, $platenum, uc($wellrow), $wellcol;
  return ($ret);
}

sub id_query_for_bac_name {
  my ($bac_name, $optional_schema_name) = @_;
  my $canonical = canonicalize_bac_name ($bac_name);
  unless ($canonical) {
    return (undef);
  }
  my ($shortname, $platenum, $wellrow, $wellcol) = @{decompose_bac_name ($canonical)};
  unless ($shortname) {
    print STDERR "can't lookup BAC name $bac_name: no library shortname.\n";
    return (undef);
  }
  unless ($platenum) {
    print STDERR "can't lookup BAC name $bac_name: no plate number.\n";
    return (undef);
  }
  unless ($wellrow) {
    print STDERR "can't lookup BAC name $bac_name: no well row.\n";
    return (undef);
  }
  unless ($wellcol) {
    print STDERR "can't lookup BAC name $bac_name: no well column.\n";
    return (undef);
  }
  my $genomic;
  if ($optional_schema_name) {
    $genomic = $optional_schema_name;
  } else {
    $genomic = "genomic";
  }
  my $query = "SELECT clone_id
                 FROM $genomic.clone
                 JOIN $genomic.library USING (library_id)
                WHERE shortname ILIKE '$shortname'
                  AND platenum = $platenum
                  AND wellrow ILIKE '$wellrow%'
                  AND wellcol = $wellcol";
  return ($query);
}

sub id_for_bac_name {
  my ($dbh, $bac_name) = @_;;
  my $schema = $dbh->qualify_schema ("genomic");
  my $query = id_query_for_bac_name ($bac_name, $schema);
  unless ($query) {
    return (undef);
  }
  my $result = $dbh->selectall_arrayref ($query);
  return ($result->[0][0]);
}

package main;
## Globals.
#
# The body of the program below turns rows of a spreadsheet into hash tables
# whose keys are the chromosome number, the chromosome arm, the BAC ID,
# the experimenter's name for the experiment, and the distance from the
# centromere as a percentage of the arm length.  Unsurprisingly, these 5
# fields plus a couple of constants external to the spreadsheet are the
# significant columns in the fish_result table in the database.
#
# So here is the main query to be performed.  We'll run this for each
# row of the spreadsheet. Note that in order to hike this string up
# here before any argument processing, we've had to escape the two
# constants; we'll eval the string before using it.
our $result_insert_query =
  "INSERT INTO fish_result
          (chromo_num, chromo_arm,
           experiment_name, percent_from_centromere,
           clone_id, fish_experimenter_id, map_id)
          SELECT ?, ?, ?, ?, ?,
                 (SELECT fish_experimenter_id
                    FROM fish_experimenter
                   WHERE fish_experimenter_name = '%s'),
                 (SELECT map_id
                    FROM map
                   WHERE short_name = '%s')";
# The names of the fields we need to supply as bind parameters to the
# above query.  Make sure the order of field names match up.
our @result_insert_fields = ("chromo_num", "chromo_arm",
			       "experiment_name", "percent_from_centromere",
			       "clone_id");





# TODO
# A query for inserting a filename into the fish_file table.  FISH results
# are uniquely identified by the experimenter, their experiment name, and
# the clone_id so the linkage is pretty simple.
our $file_insert_query =
  "INSERT INTO fish_file (filename, fish_result_id)
          SELECT ?, (SELECT fish_result_id
                       FROM fish_result
               NATURAL JOIN fish_experimenter
                      WHERE fish_experimenter_name = '%s'
                        AND experiment_name = ?
                        AND clone_id = ?)";
#/TODO


# Next, because we don't really trust the submitters to maintain the same
# formatting of their spreadsheet (preserving column ordering, mostly), or
# to use the same file layouts from submission to submission, this program
# doesn't expect any specific spreadsheet structure or file layout, except
# that the spreadsheet must be tabular and the files associated with a row
# in the spreadsheet must be describable by a Unix glob.
#
# We use a format-stringy notation for both describing spreadsheet
# structure and constructing filenames for each spreadsheet row.  
# The mapping of format codes to programmer-friendly keys is as follows:
my %formats = (
	       "a" => "chromo_arm",
	       "b" => "bac",
	       "c" => "chromo_num",
	       "e" => "experiment_name",
	       "p" => "percent_from_centromere",
	      );

# The default ordering of columns in the spreadsheets we read.  Overridable
# with -f.
our $default_read_format = "%b%e%c%-%-%a%p";

# The default file name glob whose expansion names all files associated
# with a given row in the spreadsheet.  Overridable with -d.
our $default_file_glob = "Tomato_%c%a/BAC_%b/Photo_ID_%e/%e*";

# The name in table fish_experimenter of the FISH experimenter.  Overridable
# with -e.
our $default_experimenter_name = "fish_stack";
# The name in table maps of the FISH map.  Overridable with -m.
our $default_map_name = "Tomato FISH map";
# The number of files expected to be found for each row of spreadsheet
# data.  Overridable with -E
our $default_extfiles_per_experiment = 4;

## Process command line arguments.
our %opts;
getopts ("d:e:E:hlm:f:q:s:t", \%opts);

# Help message.
if ($opts{h}) {
    print_usage_and_quit(0);
}
# Make a DB connection.  We do this before processing further
# arguments so that any options that require querying the 
# database can assume $dbh is set.
our $dbh = CXGN::DB::Connection->new;
$dbh->ping or die ("bogus database handle.");
unless ($dbh) {
  die ("Can't connect to database.");
}
$dbh->dbh_param(PrintError=>0);

# Display the names of known FISH experimenters
if ($opts{l}) {
    print_fish_experimenters_and_quit(0);
}
# File glob format
our $file_glob = $default_file_glob;
if ($opts{d}) {
    $file_glob = $opts{d};
}
# Experimenter name
our $experimenter_name = $default_experimenter_name;
if ($opts{e}) {
    $experimenter_name = $opts{e};
}
# External files per experiment
our $extfiles_per_experiment = $default_extfiles_per_experiment;
if ($opts{E}) {
  $extfiles_per_experiment = $opts{E};
}
# Spreadsheet column "format" (it's actually parsed by a CSV routine;
# these are just the ordering of the columns)
our $read_format = $default_read_format;
if ($opts{f}) {
  $read_format = $opts{f};
}
# Map name.
our $map_name = $default_map_name;
if ($opts{m}) {
  $map_name = $opts{m};
}
# Parameters to the CSV parser.
our $quote = "\"";
if (defined($opts{q})) {
  $quote = $opts{q};
}
our $separator = ",";
if (defined($opts{s})) {
  $separator = $opts{s};
}
# Required arguments: a directory and some filenames
if (@ARGV < 2) {
  print "$0: too few arguments.\n";
  print_usage_and_quit (1);
}
our $directory = shift;
our @files = @ARGV;

# We're done processing arguments.  Now we construct a few structures
# that will be constant through the rest of the program.

# Construct a list whose elements are the names of the columns
# in the spreadsheet, or undef if we don't care about those columns.
my @fields = @{reckon_fields ($read_format)};

# Create a function that takes a hash representing a row in a spreadsheet
# and returns all files found for that row.
my $find_files = make_file_finder ($directory."/".$file_glob);

# Create a function that inserts the FISH data hash into the fish_result table.
my $result_inserter = make_inserter ($dbh, "fish_result", sprintf ($result_insert_query, $experimenter_name, $map_name));
# Create a function that inserts filenames into the fish_file table for





# TODO
# a given FISH data hash.
my $file_inserter = make_inserter ($dbh, "fish_file", sprintf ($file_insert_query, $experimenter_name));
#/TODO




# The main event.
eval {
  foreach my $file (@files) {
    printf "Processing data file $file...\n";
    open (my $fh, "<$file") || die ("$0: failed to open spreadsheet $file.");
    count("spreadsheet");
  RECORD:  while (my @record = CSV::read_csv_record ($fh, $separator, $quote)) {
      count("line");
      unless (@record >= @fields) { # Too few records
	#print STDERR @record+0, join("\t", @record);
	skip("Record has " . (@record) . " fields, not " . (@fields) . " fields.");
	next RECORD;
      }

      my %fish_params;
      for (my $i = 0; $i < @fields; $i++) {
	my $value = $record[$i];
	my $fieldname = $fields[$i];
	if ($fieldname) { # we don't care about undef fieldnames
	  # Trim the value, and stash it in %fish_params.
	  $value =~ s/(^\s|\s$)//g;
	  $fish_params{$fieldname} = $value;
	}
      }
      # Do some cleanup/error checking on the data.
      # cleanup_fish_data is expected to return a string
      # only if there's something wrong with the data.
      my $invalidity = cleanup_fish_data (\%fish_params);
      if ($invalidity) {
	skip ($invalidity);
	next RECORD;
      }

      # If we've got this far, we have all we need to start inserting.
      my @params = @fish_params{@result_insert_fields};
      # We'll make a savepoint before each spreadsheet row,
      # so that (1) if the row has already been inserted, then
      # we let the database generate the error, rollback that row
      # and proceed; (2) if the row inserts but has no
      # corresponding external files, then we rollback that row 
      # and proceed.
      my $saveptnm = name_savepoint();
      $dbh->pg_savepoint($saveptnm);
      eval {
	$result_inserter->(@params);
      };
      if ($@) { # The row didn't insert.
	# The only acceptable reason why this could occur is a violated UNIQUE
	# constraint (which we expect many of).
	# I started writing a module for mapping error codes to readable strings,
	# but keeping that sort of thing in sync with future database releases
	# is not worthwhile, at least given how little use is made of the
	# error code.  The error codes themselves are reputedly standardized
	# and therefore in principle stable.
	if ($dbh->state eq "23505") {
	  skip ("Failed to insert row for $experimenter_name, $fish_params{bac}, $fish_params{experiment_name} (already in database).");
	} else {
	  die ("Unexpected database insert error $@");
	}
    	$dbh->pg_rollback_to($saveptnm);
	next RECORD;
      } else { # Row inserted, now do the external files.
	# Find any files in this upload associated with this row.
	my @extfiles = @{$find_files->(\%fish_params)};
	# FIXME: provide some way of allowing the number
	# of extfiles to vary.  But only bother to do this
	# in case some submitter really needs this to be the case.
	unless (@extfiles == $extfiles_per_experiment) {
	  warn "Found ".@extfiles." files for $fish_params{bac} / $fish_params{experiment_name}.  Skipping.\n";
          $dbh->pg_rollback_to($saveptnm);
          next RECORD;
	}
	if (@extfiles) {
	    count ("row");
	    foreach my $filename (@extfiles) {
		# XXX: fixme: make this pattern settable by command-line argument.
		unless ($filename =~ m/(Thumbs.db|xls|xlsx)$/i) {
#		    $file_inserter->(File::Basename::basename($filename), File::Basename::basename($fish_params{experiment_name}), $fish_params{clone_id});
		    my $image = SGN::Image->new($dbh);
		    my ($fish_result_id) = $dbh->selectrow_array(
                        <<'',
                     SELECT fish_result_id
                       FROM fish_result
               NATURAL JOIN fish_experimenter
                      WHERE fish_experimenter_name = ?
                        AND experiment_name = ?
                        AND clone_id = ?

                        undef,
                        $experimenter_name,
                        File::Basename::basename($fish_params{experiment_name}),
                        $fish_params{clone_id}
                       );

		    #print STDERR "$fish_result_id\n";
		    my $return_value = $image->process_image("$filename", "fish",$fish_result_id,0);
		    unless ($return_value > 0) { die "failed to process image: $!\n"; } 
		    $image->set_description("$experimenter_name");
		    $image->set_sp_person_id(233);
		    $image->set_obsolete("f");
		    $image->store();
		    count ("extfile");
		}
	    }
	} else { # No external files found.
	  skip ("No files found for row $fish_params{experiment_name}.", 1);
	  $dbh->pg_rollback_to ($saveptnm);
	  next RECORD;
	}
      }
      # If we got here, the row and its files loaded.
#      $dbh->pg_release ($saveptnm);
    }
    close ($fh);
  }
  # Number of lines, minus the first line of each spreadsheet.
  my $total_lines = check("line");
  my $possible_files = $total_lines * 4;
  print "
LOAD REPORT FOR RUN:
========================================================
Processed ".check("spreadsheet")." spreadsheets.

\tRows\tFiles
Seen\t$total_lines\t$possible_files (expected)
Loaded\t".check("row")."\t".check("extfile")."
Skipped\t".check("skip")."

Expected to skip ".check("spreadsheet")." lines.

";
  print "Commit?\n(yes|no, default no)> ";
  if (<STDIN> =~ m/^y(es)?/i) {
    print "Committing...";
    $dbh->commit;
    print "okay.\n";
  } else {
    print "Rolling back...";
    $dbh->rollback;
    print "done.\n";
  }
};
if ($@) {
  print "Some sort of unhandled error in transaction.\n";
  print $@;
  $dbh->rollback;
  exit(1);
}
exit (0);

# Helper functions, etc.
sub print_fish_experimenters_and_quit {
    my ($exitcode) = @_;
    print "FISH Experimenters:\n";
    print "-------------------\n";
    my $schema = $dbh->qualify_schema('sgn');
    my $q = "SELECT fish_experimenter_name FROM $schema.fish_experimenter";
    my $result = $dbh->selectcol_arrayref($q);
    foreach my $experimenter (@$result) {
	print $experimenter."\n";
    }
    exit ($exitcode);
}

sub print_usage_and_quit {
    my ($exitcode) = @_;
    print "Usage: $0 [OPTIONS] DIR FILES

Load FISH data from FILES, which must be .csv files.  All files
associated with the experiment must be found under DIR.
Options:

-d FORMAT	When looking for files associated with a given experiment,
                look in a directory designated by DIR/<format glob>, with
                these format specifiers

		%a  --  Chromosome arm
		%b  --  BAC ID (DDDADD notation)
		%c  --  Chromosome number
		%e  --  Experimenter's experiment ID
		%p  --  Percentage distance from centromere
		%%  --  Literal percent sign

                The default format is '$default_file_glob'.
-e EXPERIMENTER Experimenter name (default '$default_experimenter_name').
-E COUNT        Expect COUNT external files per experiment (default $default_extfiles_per_experiment).
-f FORMAT       Parse the CSV file with each record's fields in order
		specified by FORMAT.  Valid format specifiers are:

		%a  --  Chromosome arm
		%b  --  BAC ID (DDDADD notation)
		%c  --  Chromosome number
		%e  --  Experimenter's experiment ID
		%p  --  Percentage distance from centromere
		%-  --  Some field we don't care about

                The default format is '$default_read_format'.
-h		Print this message.
-l		List known FISH experimenters.
-m MAP_NAME     Map name (default '$default_map_name').
-q QUOTE	Use QUOTE as the field quote character (default \")
-s SEPARATOR	Use SEPARATOR as the field separator (default ,)
";
  exit ($exitcode);
}

# Turn the read format into an ordered list of field names.
sub reckon_fields {
  my ($format) = @_;
  my @fields = ();
  my $counter = 0;
  foreach my $format_char (split "%(?!%)", $format) {
    if ($format_char eq "") { # empty string at beginning of format
      next;
    }
    if ($format_char eq "-") { # "ignore this field" char
      $fields[$counter++] = undef;
    } else {
      if (grep { $formats{$format_char} eq $_ } @fields) {
	die ("$0: $format_char appears more than once in $read_format");
      }
      $fields[$counter++] = $formats{$format_char};
    }
  }
  return (\@fields);
}

# I get the feeling that you won't like this part of the program.  I'm
# sorry about that.  Here's the idea: given a row in the input spreadsheet,
# we need to find those files that are related to the row.  We only have
# a vague idea about what they'll be sending us (a few images, and maybe a
# spreadsheet per row), and don't really trust submitters to use the same
# directory layout consistently, so it seemed reasonable to use globs
# to describe the set of files associated with a row in the spreadsheet.
# So, e.g., the default glob for the Stack group's uploads is this:
#
# Tomato_<chromo_num><chromo_arm>/BAC_<bac_id>/Photo_ID_<experiment_name>/<experiment_name>*";
#
# But since this is cumbersome to type, we offer a format-string notation
# for the operator, by which we can write the glob above as follows:
#
# Tomato_%c%a/BAC_%b/Photo_ID_%e/%e*
#
# Here is a routine that takes a format string and returns a
# function that takes a hash whose keys are the fields in the
# format structure and returns a reference to an array of the
# file names.  So the usage will be:
#
# my $find_files = make_file_finder ($globfmt);
# my %fish_hash = { chromo_num => 2, chromo_arm = 'P', ... }
# my $files = $find_files->(\%fish_hash);
#
# Now @$files will be the list of files associated with the experiment.
sub make_file_finder {
  my ($format) = @_;
  my $globfmt = "";
  my @keys = ();
  # Here we turn our format string into an sprintf format string,
  # while also collecting the order of the format codes, so that
  # we can turn a filled-in hash of FISH parameters into a list
  # of arguments to be formatted.
  while ($format =~ m/\G(.)/g) {
    my $char = $1;
    if ($char eq "%") {
      $format =~ m/\G(.)/gc;
      my $nextchar = $1;
      if ($nextchar eq "%" ) {
	$globfmt .= "%";
      } else {
	$globfmt .= "%s";
	push @keys, $formats{$nextchar};
      }
    } else {
      $globfmt .= $char;
    }
  }
  return sub {
    my ($hashref) = @_;
    my $glob = sprintf $globfmt, map { $$hashref{$_} || ""; } @keys;
    #print STDERR "find glob: $glob\n";
    my @files = File::Glob::bsd_glob($glob);
    return (\@files);
  }
}

# Given a dbh, a table name, and a query, prepare the query in the db that
# the dbh connects to, and return a function that executes the prepared query
# with whatever arguments are passed to it.  The point here is to provide
# a lightweight way to wrap statement handle execute() calls, e.g., to print
# out dbh properties at the time the statement handle is executed, etc.
# At present, we don't use the table name.
sub make_inserter {
  my ($dbh, $table, $query) = @_;
  my $st = $dbh->prepare($query);
  sub {
    eval {
      $st->execute(@_);
    };
    if ($@) {
      die ("$@ with arguments: " . (join ", ", @_));
    }
  }
}

# This is constructor that produces a new string every time it's
# called.  This ensures that we never reuse the same savepoint name
# twice.
{
  my $savepointnum = 1;
  sub name_savepoint {
    return ("savept".$savepointnum++);
  }
}

# Some dinky counters for doing checksums.
{
  my $spreadsheet_count = 0;
  my $line_count = 0;
  my $loaded_row_count = 0;
  my $skipped_rows = 0;
  my $extfile_count = 0;
  sub count {
    ($_) = @_;
    /^spreadsheet$/ && do { $spreadsheet_count++; };
    /^line$/        && do { $line_count++; };
    /^row$/         && do { $loaded_row_count++; };
    /^skip$/        && do { $skipped_rows++; };
    /^extfile$/     && do { $extfile_count++; };
  }
  sub check {
    ($_) = @_;
    /^spreadsheet$/ && do { return($spreadsheet_count); };
    /^line$/        && do { return($line_count); };
    /^row$/         && do { return($loaded_row_count); };
    /^skip$/        && do { return($skipped_rows); };
    /^extfile$/     && do { return($extfile_count); };
  }
}
sub skip {
  my ($msg, $serious) = @_;
  if ($serious) {
    print STDERR $msg." Skipping record.\n";
  }
  count ("skip");
}

# Tidy up the data in a row.  Return something only if the data is bogus.
sub cleanup_fish_data {
  my ($fish_row) = @_;

  foreach my $fieldname (keys (%$fish_row)) {
    # None of the ersatz case statement equivalents in the Camel book looked
    # less opaque to me than the straightforward if/elsif*/else construct.
    # Note that the fieldnames are set up by this program, and so can't
    # fall off this statement.
    if ($fieldname eq "bac") {
      my $bac = $fish_row->{bac};
      # We need to turn BAC names into clone_ids from the genomic db.
      my $clone;
      find_clone: for my $lib ("", "LE_HBA", "SL_MboI") {
	  $clone = CXGN::Genomic::Clone->retrieve_from_clone_name("$lib$bac");
	  if ($clone) {
	      last find_clone;
	  }
      }
#id_for_bac_name($dbh, "LE_HBA$bac");
      if ($clone) {
#	  print STDERR $clone->clone_name."\n";
	$fish_row->{clone_id} = $clone->clone_id();
      } else {
	return ("Ostensible BAC name '$bac' is either unparseable or not found in database.");
      }
    } elsif ($fieldname eq "experiment_name") {
      ; # There's nothing to validate for experiment_names at present.
    } elsif ($fieldname eq "chromo_num") {
      ; # We can't do much with chromo nums (we don't know what
        # species we're looking at).
    } elsif ($fieldname eq "chromo_arm") {
      # We canonicalize the chromo arm:
      if ($fish_row->{chromo_arm} =~ m/[ps]/i ) {
	$fish_row->{chromo_arm} = "P";
      } elsif ($fish_row->{chromo_arm} =~ m/[ql]/i ) {
	$fish_row->{chromo_arm} = "Q";
      } else {
	return ("$fish_row->{chromo_arm} doesn't look like a chromosome arm identifier.");
      }
    } elsif ($fieldname eq "percent_from_centromere") {
      # Percentage distance from the centromere.  If this is given
      # as an integer, normalize it. otherwise.
      my $percent_dist = $fish_row->{percent_from_centromere};
      if (($percent_dist >= 0.0) && ($percent_dist <= 100.0)) {
	$percent_dist = $percent_dist/100;
      }
      if (($percent_dist > 1.0) || ($percent_dist < 0.0)) {
	return ("$percent_dist doesn't look like a percentage.");
      }
      $fish_row->{percent_from_centromere} = $percent_dist;
    }
  }
  # If we got here, then we don't return anything for
  # the caller to report.
  return (undef);
}
