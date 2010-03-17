
use strict;

use CXGN::Genefamily;
use CXGN::Page;
use Tie::UrlEncoder;

our %urlencode;

my  $DIR =  '/home/mueller/dutch_tomato_assembly/tomato_ara_rice_comparison/';
my $page = CXGN::Page->new();

my ($genefamily_id, $member_id) = $page->get_encoded_arguments("genefamily_id", "member_id");

my $gf;
if ($genefamily_id) { 
    $gf = CXGN::Genefamily->new(name=>$genefamily_id, files_dir=>$DIR);
    my $seq_data = $gf->get_alignment();

    $page->header();
  
    
    print "<table><tr><td>Family: $genefamily_id</td>\n";
    print <<HTML;

    <td><form method="post" action="/tools/align_viewer/">
	<input type="hidden" name="seq_data" value="$seq_data" />
	<input type="submit" value="view" />
	<input type="hidden" name="format" value="fasta" />
	</td></tr></table>

</form>

HTML
	
$page->footer();
    
    
}

if ($member_id) { 
    open (my $F, "<$DIR/dump.out.tomato_rar_rice_pep_self_e-10.m8.I11s2") || die "can't open family file";
    my $family_nr = 0;
    my $found = 0;
    while(<$F>) { 
	$family_nr++;
	if ($_=~/\b$member_id\b/i) { 
	    $found=1;
	    last();
	}
    }
    
    $page->header();

    if ($found) { 
	print qq | $member_id is in family <a href="?genefamily_id=$family_nr">$family_nr</a>. |;
    }
    else { 
	print qq | $member_id was not found. |;
    }

    $page->footer();


    
}
	    
	    
if (!$member_id && !$genefamily_id) { 
    
    $page->header();
    
    print <<HTML;

    <h1>Search Gene families</h1>
	<form>
	Genefamily id <input name="genefamily_id" />(a number)<br /> 
	-OR-<br />
	Member id <input name="member_id" /> (e.g. At1g01060)<br />
	<input type="submit" />
	</form>

HTML

$page->footer();

}

