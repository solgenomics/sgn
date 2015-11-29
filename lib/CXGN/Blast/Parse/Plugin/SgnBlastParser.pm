
package CXGN::Blast::Parse::Plugin::SgnBlastParser;

use Moose;
use File::Slurp qw | read_file |;

sub name { 
    return "SGN";
}

sub priority { 
    return 10;
}

sub prereqs {
  return <<EOJS;

<div class="modal fade" id="xref_menu_popup" role="dialog">
  <div class="modal-dialog">

    <!-- Modal content-->
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal">&times;</button>
        <h4 class="modal-title">Match Information</h4>
      </div>
      <div class="modal-body">
        <dl>
            <dd>
              <div style="margin: 0.5em 0"><a class="match_details" href="" target="_blank">View matched sequence</a></div>
            </dd>
            <dd class="subject_sequence_xrefs">
            </dd>
        </dl>
      </div>
    </div>
  
  </div>
</div>


<script>

  function resolve_blast_ident( id, id_region, match_detail_url, identifier_url ) {
    var popup = jQuery( "#xref_menu_popup" );
    
    jQuery('.modal-title').html( id );
    
    if( identifier_url == null ) {
       jQuery('.sequence_name').html( id );
    } else {
       jQuery('.sequence_name').html( '<a href="' + identifier_url + '" target="_blank">' + id + '</a>' );
    }

    popup.find('a.match_details').attr( 'href', match_detail_url );

    // look up xrefs for overall subject sequence
    var subj = popup.find('.subject_sequence_xrefs');
    subj.html( '<img src="/img/throbber.gif" /> searching ...' );
    subj.load( '/api/v1/feature_xrefs?q='+id );
    
    popup.modal("show");

    return false;
  }
  
</script>


EOJS
}

sub parse { 
  my $self = shift;
  my $c = shift;
  my $file = shift;
  my $bdb = shift;
  
  my $db_id = $bdb->blast_db_id();

  my $query = "";
  my $subject = "";
  my $id = 0.0;
  my $aln = 0;
  my $qstart = 0;
  my $qend = 0;
  my $sstart = 0;
  my $send = 0;
  my $evalue = 0.0;
  my $score = 0;
  my $desc = "";

  my $one_hsp = 0;
  my $start_aln = 0;
  my $append_desc = 0;

  my @res_html;
  my @aln_html;

  open (my $blast_fh, "<", $file);

  push(@res_html, "<table id=\"blast_table\" class=\"table\">");
  push(@res_html, "<tr><th>SubjectId</th><th>id%</th><th>Aln</th><th>evalue</th><th>Score</th><th>Description</th></tr>");

  while (my $line = <$blast_fh>) {
    chomp($line);

    if ($line =~ /Query\=\s*(\S+)/) {
      $query = $1;
      unshift(@res_html, "<center><h3>$query</h3>");
    }

    if ($append_desc) {
      if ($line =~ /\w+/) {
        my $new_desc_line = $line;
        $new_desc_line =~ s/\s+/ /g;
        $desc .= $new_desc_line;
      }
      else {
        $append_desc = 0;
      }
    }

    if ($line =~ /^>/) {
      $start_aln = 1;
      $append_desc = 1;
      
      if ($subject) {
        push(@res_html, "<tr><td><a class=\"blast_match_ident\" href=\"show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" onclick=\"return resolve_blast_ident( '$subject', '$subject:$sstart..$send', 'show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send', null )\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");
        # push(@res_html, "<tr><td>$query</td><td>$subject</td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");
        # push(@res_html, "<tr><td>$query</td><td><a href=\"/tools/blast/show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" target=\"_blank\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");
      }
      $subject = "";
      $id = 0.0;
      $aln = 0;
      $qstart = 0;
      $qend = 0;
      $sstart = 0;
      $send = 0;
      $evalue = 0.0;
      $score = 0;
      $desc = "";
      $one_hsp = 0;

      if ($line =~ /^>(\S+)\s*(.*)/) {
        $subject = $1;
        $desc = $2;
      }
    }


    if ($line =~ /Score\s*=/ && $one_hsp == 1) {
      # push(@res_html, "<tr><td>$query</td><td>$subject</td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");
      push(@res_html, "<tr><td><a class=\"blast_match_ident\" href=\"show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" onclick=\"return resolve_blast_ident( '$subject', '$subject:$sstart..$send', 'show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send', null )\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");

      $id = 0.0;
      $aln = 0;
      $qstart = 0;
      $qend = 0;
      $sstart = 0;
      $send = 0;
      $evalue = 0.0;
      $score = 0;
    }
    
    if ($line =~ /Score\s*=\s*([\d\.]+)/) {
      $score = $1;
      $one_hsp = 1;
      $append_desc = 0;
    }


    if ($line =~ /Expect\s*=\s*([\d\.\-e]+)/) {
      $evalue = $1;
    }

    if ($line =~ /Identities\s*=\s*(\d+)\/(\d+)/) {
      my $aln_matched = $1;
      my $aln_total = $2;
      $aln = "$aln_matched/$aln_total";
      $id = sprintf("%.2f", $aln_matched*100/$aln_total);
    }

    if (($line =~ /^Query:\s+(\d+)/) && ($qstart == 0)) {
      $qstart = $1;
    }
    if (($line =~ /^Sbjct:\s+(\d+)/) && ($sstart == 0)) {
      $sstart = $1;
    }

    if (($line =~ /^Query:/) && ($line =~ /(\d+)\s*$/)) {
      $qend = $1;
    }
    if (($line =~ /^Sbjct:/) && ($line =~ /(\d+)\s*$/)) {
      $send = $1;
    }

    if ($start_aln) {
      push(@aln_html, $line);
    }


  }
  # push(@res_html, "<tr><td>$query</td><td>$subject</td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");
  push(@res_html, "<tr><td><a class=\"blast_match_ident\" href=\"show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" onclick=\"return resolve_blast_ident( '$subject', '$subject:$sstart..$send', 'show_match_seq.pl?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send', null )\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");
  push(@res_html, "</table></center>");
  
  push(@res_html, "<br><pre>");
  push(@res_html, @aln_html);
  push(@res_html, "</pre></div><br>");
  #
  # # print STDERR join("\n", @res_html);
  
  # return ("<p>SGN output</p>");
  return (join("\n", @res_html));
}

1;
