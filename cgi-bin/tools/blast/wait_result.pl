#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::VHost;

my $vhost_conf = CXGN::VHost->new();
#	my $documents_folder = $vhost_conf->get_conf('basepath') . $vhost_conf->get_conf('documents_subdir');
my $tmpdir = $vhost_conf->get_conf('basepath') . $vhost_conf->get_conf('tempfiles_subdir') . "/blastgraph/";

our $page = CXGN::Page->new("BLAST running", "Koni");

#'output_graphs' will be passed on to view_result.pl
my ($request_file, $not_finished, $invalid, $output_graph_option) 
	= $page->get_arguments("request", "notfinished","invalids", "output_graphs");

if ( ! -f "$tmpdir/${request_file}.req" ) {
  print STDERR "$request_file ($!)\n";
  request_not_found($page);
}

open REQUEST_FILE, "<$tmpdir/$request_file.req"
  or $page->error_page("Failed to open BLAST request file " . "\"$request_file\" ($!)");

my @output = ();
my $refresh = "";
while(<REQUEST_FILE>) {
  chomp;
  my ($name, $file) = split/\t/;

  if ( -f "$tmpdir/$file.html" ) {
    push @output, "<tr><td><a href=\"./view_result.pl?result_file=$file.html&output_graphs=$output_graph_option\">$name</a></td><td><font color=#009900>Finished</font></td></tr>";
  } elsif ( -f "$tmpdir/$file" ) {
    push @output, "<tr><td>$name</td><td><font color=\"#CCCC00\">Running</font></td></tr>";
    $refresh = "<meta http-equiv=\"Refresh\" content=\"30; URL=./wait_result.pl?request=$request_file&invalids=$invalid&output_graphs=$output_graph_option\">";
    $not_finished="yes";
  } else {
    push @output, "<tr><td>$name</td><td><font color=#CC0000>Queued</font></td></tr>";
    $refresh = "<meta http-equiv=\"Refresh\" content=\"30; URL=./wait_result.pl?request=$request_file&invalids=$invalid&output_graphs=$output_graph_option\">";
    $not_finished="yes";
  }
}

close REQUEST_FILE;

my $text = "";
if ($not_finished eq "yes") {

  $text = "<tr><td><p>Your BLAST request is still running. Use links below to view results. Reload this page to update status. This page will automatically reload every <b>30 seconds</b>.</p></td></tr>";
} else {
  $text = "<tr><td align=\"center\"><p>BLAST finished. Use links below to view results.</p></td></tr>";
}

my $invalid_text;
if ($invalid eq "yes") {
  $invalid_text ="<p>NOTE: Some combinations of BLAST programs and target databases were invalid (i.e. protein search on nucleotide database) and automatically skipped.";
} else {
  $invalid_text = "";
}

$page->header("", $refresh);

print <<EOF;

<h4><center>SGN BLAST SEARCH RESULTS</center></h4>

<table width="80%" cellpadding="2" cellspacing="2" border="0" align="center">
$text
<tr><td><table cellpadding="2" cellspacing="2" border="0" align="center">
  <tr><th>Job</th><th>Status</th></tr>
  <tr><td></td><td><img src="/documents/img/dot_clear.png" height="1" width="40"></td></tr>
  @output
  </table>
  $invalid_text
</td></tr>
</table>
<br />
EOF



$page->footer();

sub request_not_found {
  my ($page) = @_;

  $page->header();

  print <<EOF;

  <h4>SGN BLAST ERROR -- OLD REQUEST NOT FOUND</h4>

  <p>Your browser requested the status of a BLAST job which does not exist. Please <b>do not bookmark</b> your BLAST results, they are automatically deleted from the server after 2 days.</p>

EOF

  $page->footer();
  exit(0);
}
