use strict;
use CXGN::Page;
my $page=CXGN::Page->new("Sol Genomics Network","Tyler");
$page->header();
print <<END_HEREDOC;

<br />
<center>

<table class="boxbgcolor2" width="100%" summary="">
<tr>
<td width="25%">&nbsp;</td>
<td width="50%" class="left">
	  
<div class="boxcontent">
    
<map name="marker_search" id="marker_search">
<area shape="rect" href="/search/markers/markersearch.pl" coords="327,45,391,72" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=all&amp;techniques=rflp" coords="26,137,142,164" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=UNKNOWN&amp;techniques=all" coords="324,137,398,164" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=all&amp;techniques=pcr" coords="580,137,688,164" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;submit=search&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=RFLP&amp;techniques=all" coords="28,304,73,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;submit=search&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=TM&amp;techniques=all" coords="91,304,116,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;submit=search&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=COS&amp;techniques=all" coords="48,304,186,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;submit=search&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=P&amp;techniques=all" coords="219,304,230,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=EST-BY-CLONE&amp;techniques=all" coords="280,304,314,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=RAPD&amp;techniques=all" coords="449,304,498,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=AFLP&amp;techniques=all" coords="523,304,567,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=CAPS&amp;techniques=all" coords="586,304,634,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=SSR&amp;techniques=all" coords="666,304,702,331" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=GENOMIC&amp;techniques=all" coords="245,456,317,483" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=CAPS&amp;techniques=rflp" coords="343,456,429,511" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=COSII&amp;techniques=all" coords="441,456,495,483" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=KFG&amp;techniques=all" coords="533,456,569,483" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=DCAPS&amp;techniques=all" coords="602,456,663,483" alt="" />
<area shape="rect" href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=UNIGENE&amp;techniques=all" coords="671,456,737,483" alt="" />
</map>

<img src="/documents/img/marker_diagram.png" usemap="#marker_search" border="0" alt="" />
To search other markers use our <a href="/search/markers/markersearch.pl">marker search</a>.

</div>
</td>
<td width="25%">&nbsp;</td>
</tr>
</table>
</center>


END_HEREDOC


$page->footer();
