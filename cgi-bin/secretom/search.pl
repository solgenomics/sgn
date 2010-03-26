
# quick hack to implement a secretom search...
# most of this concerns Arabidopsis so we don't have anything in the SGN database...



use strict;

use CXGN::Page;
use CXGN::Tools::Identifiers qw | link_identifier |;
my $page = CXGN::Page->new();
my ($query) = $page->get_encoded_arguments("query");

my $secretom_file_dir = '/data/prod/public/secretom/';

my $tabfile = 'Tair9RiceBrachyITAG1.tab';

$page->header();

print <<HTML;


<center>


<form>

    <img src='/documents/img/secretom/secretom_logo.jpg' border="0" width="50%" /><br /><br />

    Search<br /><br />
 <input type="text" name="query" value="$query" /><br /><br />

    <input type="submit" value="Search" size="20" />

</center>

</form>

HTML

    my @matches = ();


if ($query) { 

    my @column_headers = (
	"locus name",
	"annotation",
	"protein length",
	"mol weight",
	"signalp-nn (Dscore)",
	"signalp-nn (YES if Dscore >= 0.43, NO otherwise)",
	"signalp-nn pred sp len",
	"signalp-hmm sp score",
	"signalp-hmm sa score",
	"signalp-hmm prediction (SP,SA or NS)",
	"targetP result (C,M,S,_)"
	);

    
    @matches = `grep -i \"$query\" $secretom_file_dir/$tabfile`; # this should be ok because we use get_encoded_arguments...
    
    print "<br /><br />Your search \"<b>$query</b>\" return ".scalar(@matches)." matches. <br /><br />\n";
    
    if (@matches) { 




	print "Results: <br />\n";
	print qq | <table alt="Secretom Results"  > |;

	print format_table_row(@column_headers);
	foreach my $match (@matches) { 
	    my @fields = (split /\t/, $match)[0,1,4,5,6,7,8,9,10,11,12];
            my $link = link_identifier($fields[0]);
	    $fields[0] = $link if(defined $link);
	    print format_table_row(@fields);
	}
	print "</table>\n";

    }
}
	

   
$page->footer();

    
sub format_table_row { 
    my @row = @_;

    return "<tr><td class=\"boxbgcolor5\">".(join "</td><td  class=\"boxbgcolor5\">", @row)."</td></tr>\n";

}
