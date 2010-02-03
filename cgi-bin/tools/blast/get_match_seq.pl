

use strict;
use Bio::Seq;
use CXGN::Page;
use CXGN::BlastDB;
use CXGN::MasonFactory;

 my $p = CXGN::Page->new();


my ($db_id, $seq_id, $start, $end) = $p->get_encoded_arguments("db_id", "seq_id", "start", "end");

my $errors = "";

if (!$db_id) { 
    show_form($p);
    return;
}

if ($db_id && !$seq_id) { 
    $errors = "The sequence id is required.";
    show_form($p);
    return;
}

if ($start<1) { $start =1; }

if ($start > $end) { 
    $p->message_page("get_match_seq.pl error: The start coordinate has to be smaller than the end coordinante.");
}

my $bdb = CXGN::BlastDB->from_id($db_id);

my $seq = $bdb->get_sequence($seq_id);

if (!$seq) { 
    $p->message_page("The sequence $seq_id does not exist in this dataset");
}

my $fasta = "";

my $sub_seq = "";

my $sequence = $seq->seq();

if (length($sequence) == 0) { 
    $p->message_page("The sequence $seq_id has zero length.");
}

if ($end > $seq->length()) { 
    $end = $seq->length();
}

if ($end > 1) { 
    $sub_seq = $seq->subseq($start, $end);
}
else { 
    $end = $seq->length();
    $sub_seq = $seq->subseq($start, $end);
    
}

$fasta = ">$seq_id  $start - $end\n$sub_seq\n";

my $seq_obj = Bio::Seq->new();
$seq_obj->id("$seq_id");
$seq_obj->desc("extracted: $start-$end");
$seq_obj->seq($sub_seq);
my $m = CXGN::MasonFactory->new();
$m->exec("/tools/sequence.mas", title=>"Sequence $seq_id [from residue $start to residue $end]", seq=>$seq_obj);


sub show_form { 

    my $page = shift;

    $page->header();

    print <<HTML;

    <h1>Extract Sequence</h1>
	$errors
    <form>
    <table cellpadding="5" cellspacing="5" alt=""><tr>
    <td><b>Dataset</b></td><td> <select name="db_id">
	<option value="93">Tomato WGS Sequence</option>
	<option value="56">Tomato BAC contigs</option>
	</select></td></tr>

	<td><b>Id</b></td><td> <input type="text" name="seq_id" size="10"/><br /></td></tr>
	<tr><td><b>Start</b></td><td> <input type="text" name="start" size="10" /></td></tr>
	<tr><td><b>End</b></td><td> <input type="text" name="end" size="10" /><br /></td></tr></table>

	<input type="submit"  />
	</form>
	
	
HTML


$page->footer();

}
