#!/usr/bin/perl

use strict;
use CXGN::Page;
use CXGN::DB::Connection;

our $page = CXGN::Page -> new( "ID Converter", "Teri Solow");
my $db = CXGN::DB::Connection->new();

$page -> header("ID Converter");

# This form supports two types of conversion: from TIGR TC (tentative consensus) numbers to SGN unigene ID numbers and vice versa.
# Neither operation is a one-to-one mapping; either may produce multiple results for a given identifier.

print <<HTML1
<b>Bulk Convert TIGR TC &#8660; SGN Unigene ID</b>
<a href="http://www.tigr.org/">The Institute for Genomic Research</a> and SGN maintain independent unigene databases, entries in which
tend to have common member ESTs, although they tend not to correspond completely. This tool uses common members to convert back and forth
between the two identifier sets. If it returns information you know is incorrect, SGN's TIGR TC list may be out of date; please 
<a href="http://www.sgn.cornell.edu/tools/contact.pl">let us know</a>.
<div style="margin: 0px 50px 0px 50px;">
<form name="convform" action="convert.pl" method="post" enctype="multipart/form-data"><br />
Unigene ID example: SGN-U212574<br />
TIGR TC identifier example: TC115712<br />
<br />
<table summary="" cellpadding="5">
	<tr>
		<td valign="top" bgcolor="#EEEEEE" width="320">
			Enter a list of identifiers or upload a file containing identifers separated by whitespace (spaces, tabs, newlines):<br />
			<textarea name="ids" rows="5" cols="20"></textarea><br />
			<br /><br />
			And/or select file: <br />
			<input type="file" name="file" /><br />
			<br />
		</td>
		<td width="20">&nbsp;</td>
		<td valign="top" bgcolor="#EEEEEE" width="320">
			<input type="radio" name="id_type" value="tigrtc" checked="checked" /><b>Enter TIGR TC numbers</b><br />
			&nbsp;&nbsp;&nbsp;<input type="checkbox" name="show_current_tc" />current TC number<br />
			&nbsp;&nbsp;&nbsp;<input type="checkbox" name="show_sgn_build_info_tc" />unigene build information<br />
			&nbsp;&nbsp;&nbsp;<input type="checkbox" name="show_common_mbrs_tc checked" />common members
			<br /><br />
			<input type="radio" name="id_type" value="sgn-u" /><b>Enter SGN unigene identifiers</b><br />
			&nbsp;&nbsp;&nbsp;<input type="checkbox" name="show_sgn_build_info_sgn_u" />unigene build information<br />
			&nbsp;&nbsp;&nbsp;<input type="checkbox" name="show_common_mbrs_sgn_u checked" />common members
		</td>
	</tr>
</table>
<input type="hidden" name="debug" value="0" /><input type="reset" />&nbsp;&nbsp;<input type="submit" value="Submit" /><br />
</form>
</div>
HTML1
;
$page->footer();


