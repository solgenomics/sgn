use CXGN::Page;

use strict;
use CXGN::DB::Connection;

library_info_main();

sub library_info_main {

     our $page = CXGN::Page->new( "SGN Library Info", "Lukas");

     my ($library) = $page -> get_arguments("library");
     my $db = CXGN::DB::Connection->new();
     
     my $query = "SELECT organism.organism_name, types.comment as type, library_name, library_shortname, development_stage, treatment_conditions, tissue, cultivar, accession,cloning_host, comments, authors, contact_information, cloning_kit, rs1, rs2, library.library_id
                  FROM library, organism, types
                  WHERE library.organism_id=organism.organism_id and library.type=types.type_id and library_shortname=?";
     my $sth = $db -> prepare($query);
     $sth -> execute($library);
     
     my $libraries ="";
     my $lib =$sth-> fetchrow_hashref();

     

     if (!exists($$lib{library_shortname})) {

	 $page -> header();

	 my $temp_value = "<h4>Library Detail Page</h4> Library \n";

    if ($library) {
	$temp_value = $temp_value."\"<b>$library</b>\" \n";
}

$temp_value = $temp_value."unknown. Sorry! Please try again.<br /><br /><br /><br /><br />\n";

	 print $temp_value;

	 $page -> footer();
	 return;
     }

     my $query2 = "SELECT count(*) from clone, seqread, est WHERE clone.clone_id=seqread.clone_id and seqread.read_id=est.read_id and clone.library_id=? and est.status=0 and est.flags=0";
     
     my $sth2 = $db->prepare($query2);
     $sth2->execute($lib->{library_id});
     my ($seq_count) = $sth2->fetchrow_array();
     
     my $query3 = "SELECT count(*) from clone WHERE clone.library_id=?";
     my $sth3 = $db -> prepare($query3);
     $sth3 -> execute($lib->{library_id}); 
     my ($clone_count) = $sth3 -> fetchrow_array();

     my $query4 = "SELECT avg(hqi_length), stddev(hqi_length) FROM clone, seqread, est, qc_report where clone.library_id=? and clone.clone_id=seqread.clone_id and seqread.read_id=est.read_id and est.est_id=qc_report.est_id and est.flags=0 and est.status=0 group by clone.library_id";
     my $sth4 = $db -> prepare($query4);
     $sth4 -> execute($lib->{library_id});
     my ($average_seqlen, $std_dev) = $sth4 -> fetchrow_array();
     $average_seqlen = sprintf "%4.1f", $average_seqlen;
     $std_dev = sprintf "%4.1f", $std_dev;
     
     $page -> header();

     print <<HTML;
     
     <h4>Library Detail Page for $library</h4>
     <table>
     <tr><td width="180">Short Name:</td><td>$$lib{library_shortname}</td></tr>
     <tr><td>Organism:</td><td>$$lib{organism_name}</td></tr>
     <tr><td>Library Name: </td><td>$$lib{library_name}</td></tr>
     <tr><td>Total Sequences: </td><td>$seq_count sequences from $clone_count clones</td></tr>
     <tr><td>Average Sequence Length:</td><td>$average_seqlen (Standard deviation $std_dev)</td></tr>
     <tr><td>Type:</td><td>$$lib{type}</td></tr>
     <tr><td>Tissue:</td><td>$$lib{tissue}</td></tr>
     <tr><td>Development Stage:</td><td>$$lib{development_stage}</td></tr>
     <tr><td valign="top">Treatment Conditions:</td><td>$$lib{treatment_conditions}</td></tr>
     <tr><td>Cloning Host:</td><td>$$lib{cloning_host}</td></tr>
     <tr><td>Cloning Kit: </td><td>$$lib{cloning_kit}</td></tr>
     <tr><td valign="top">Comments</td><td>$$lib{comments}</td></tr>
     <tr><td valign="top">Authors</td><td>$$lib{authors}</td></tr>
     <tr><td valign="top">Contact Information</td><td>$$lib{contact_information}</td></tr>
     </table>
     <br /><br /><br /><br /><br />

HTML

     $page -> footer();
 }
