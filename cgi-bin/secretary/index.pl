#!/usr/bin/perl
use strict;
use CXGN::Tools::File;
use CXGN::Page::Secretary;
use CXGN::VHost;

my $page=CXGN::Page::Secretary->new("Secretary","Chris");

$page->header('Secretary', 'Home');
my ($error404) = $page->get_arguments('error404');
if($error404) {
	print "<center><div class='errorbox' id='errorbox404'>";
	print "<div class='errorboxinset'>";
	print "<b style='color:#990000; font-size:16px'>Error 404</b><br />";
	print "The requested page could not be found... ";
	print "  <a href='#' class='internal' onclick='closebox(\"errorbox404\")'>close(x)</a>";
	print "</div></div></center>";
}

print<<HTML;
<br /><br />
<div style='clear:both; text-align:center; width:100%'>
<a href='index.pl' style='text-decoration:none'><span style='font-size: 52px; clear:both;'><span style='color:#ff3366;'>Secret</span><span style='color:green'>ary</span></span></a>
<br />
<span style="color:#777;">The <em>Arabidopsis</em> search engine</span>
<br /><br />
<form action='query.pl' method="GET" name='fq'>
<input type="textbox" name='query' size=60 id='query_focus'><br>
<span style='font-size:12px; color:#111111'>Enter Keywords or AGIs</span>
<input type="submit" value="Search"><br>
<span style='font-size:12px'>
Example searches:
 <a href='query.pl?query=AT2G17720.1'>AT2G17720.1</a>,
 <a href='query.pl?query=transcription%20AND%20zinc'>transcription AND zinc</a>,
 <a href='query.pl?query=AT5G02'>AT5G02</a>,
 <a href='query.pl?query=%22succinyl-CoA%20ligase%22'>"succinyl-CoA"</a></span>
</form>
<!--
<b>OR</b>
<br><br>
<span style='font-size:15px'>
<a href='dbquery.pl' style='text-decoration:none; color:#555555; font-size:22px'>
<span style='color:#ff3366'>Secret</span><span style='color:green'>ary</span> Database Query </a>
</span>
-->
<b>OR</b>
<br><br>Send file of <em>any</em> type (&le; 6MB) which contains AGI (ex. AT1G01010.1) numbers*<br>

<form enctype="multipart/form-data" action="query.pl" method="POST" name='fu'>
    <!-- MAX_FILE_SIZE must precede the file input field -->
    <!-- Name of input element determines name in \$_FILES array -->
    <input name="userfile" type="file" />
    <input type="submit" value="Send File" />
</form>
<span style='font-size:12px; color:#111111'>*Files summarily deleted from server after query processes</span><br>
</div>
HTML
$page->footer();
