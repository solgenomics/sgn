use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('International Solanaceae Workshop');
print<<END_HEREDOC;

<center>

<table summary="" width="720" cellpadding="0" cellspacing="0"
border="0">
<tr>
<td><br />
<h3>International Solanaceae Genome Workshop 2005</h3>
25-29 September 2005 - Island of Ischia (Italy)
<p>The International Solanaceae Genome Workshop 2005 will be held
on the island of Ischia, located in the Gulf of Naples, one of the
most beautiful settings in the world, at the <a href="http://www.continentalterme.it/">
Hotel Continental Terme</a>. Special rates are being
arranged for meeting participants. More information is available at
<a href="http://www.solanaceae2005.org">the meeting's webpage</a>.</p>
<p>First meeting annoucement: [<a href=
"/static_content/solanaceae-project/meeting_2005/SOL2_meeting_announcement1.pdf">pdf</a>]<br /></p>
<center><img src="/static_content/solanaceae-project/meeting_2005/Ischia-1.gif" alt="" /><br />
<br />
<img src="/static_content/solanaceae-project/meeting_2005/Ischia-2.gif" alt="" /></center>
<br />
<br />
<br /></td>
</tr>
</table>

</center>
END_HEREDOC
$page->footer();