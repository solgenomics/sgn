
use strict;
use warnings;

use File::Temp qw/tempfile/;
use File::Basename;
use File::Spec;
use File::Slurp qw/slurp/;

use Bio::Seq;
use Bio::Restriction::Analysis;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | info_section_html  html_break_string |;
use CXGN::Cview::MapImage;
use CXGN::Cview::Chromosome::Vector;
use CXGN::Cview::Marker::VectorFeature;
use CXGN::Tools::WebImageCache;
use CXGN::Cview::VectorViewer;
use CatalystX::GlobalContext '$c';
###############################################################################

my $p = CXGN::Page->new("Vector drawing application", "VeDraw");
my ($action, $format, $name, $insert_sequence, $insert_coord, $show_re, $del_start ,$del_end, $native_file, $edit_commands) = $p->get_arguments("action", "format", "name" , "insert_sequence", "insert_coord", "show_re", "del_start", "del_end", "native_file", "edit_commands");

###############################################################################


my $native_commands;

#getting the file and url
our $tempfiles_subdir_rel = File::Spec->catdir($c->config->{'tempfiles_subdir'},'cview'); #path relative to website root dir
our $tempfiles_subdir_abs = File::Spec->catdir($c->config->{'basepath'},$tempfiles_subdir_rel); #absolute path

if ($native_file){

    my $native_file_dir  = File::Spec->catfile($tempfiles_subdir_abs, $native_file);
    my $native_file_url   = File::Spec->catfile($tempfiles_subdir_rel, $native_file);
    
    $native_commands = slurp ($native_file_dir);
}

if (!$action) { 
    display_form($p);
    exit();
}

my $upload;
my $data; 
my $size;
my $s;
my $seq;
my $length;
my @features;
my @commands = ();

my @input_errors = (); #to collect validation errors

my $image_width = 800;
my $image_height = 600;
my $vv = CXGN::Cview::VectorViewer->new($name? $name : "vector", $image_width, $image_height);

if ($action eq "upload") { 
		
    $upload = $p->get_upload();
    if (!$upload) { die "NO UPLOAD OBJ"; }
    else { 	
        my $size = $upload->slurp($data);
        my $fh = $upload->fh;

        if ($format eq "genbank") { 
	        $vv->parse_genbank($fh);
        }
        elsif ($format eq "native") { 
            my @lines = split /\n/, $data; 
	        $vv->parse_native(@lines);
        }

    }
}


elsif ($action eq "draw_native") { 
    my @lines = split /\n/ms, $edit_commands;
    $vv->parse_native(@lines);
}
###############################################################################
if ($action eq "insert") { 
   
    my @lines = split /\n/ms, $native_commands;
    $vv->parse_native(@lines);
    $seq = $vv->get_sequence;
    
     chomp($seq);
     my $preceding_seq =  substr($seq, 0, $insert_coord);
     my $following_seq =  substr($seq, $insert_coord +1, length($seq));
    
     $seq = $preceding_seq . $insert_sequence . $following_seq;
     
     $vv->set_sequence($seq);
     @commands = @{$vv->get_commands_ref};
     foreach my $c (@commands) { 
	 if ($c->[0] eq "SEQUENCE") { 
	     $c->[1]=$seq;
	 }
     }
     $vv->set_commands_ref( \@commands);
     #$vv->parse_native();

 }
###############################################################################
if ($action eq "delete")  { 
 my @lines = split /\n/ms, $native_commands;
    $vv->parse_native(@lines);
    $seq = $vv->get_sequence;
    
     chomp($seq);
 my $seq_before = substr ($seq, 0 , $del_start);
 my $seq_after = substr ($seq , $del_end , length($seq));
 $seq = $seq_before . $seq_after;
 $vv->set_sequence($seq);
     @commands = @{$vv->get_commands_ref};
     foreach my $c (@commands) { 
	 if ($c->[0] eq "SEQUENCE") { 
	     $c->[1]=$seq;
	 }
     }
     $vv->set_commands_ref( \@commands);
 
}
###############################################################################
if ($action ne "draw_native") { 

    $vv->restriction_analysis($show_re);
}
###############################################################################

my $image_html = $vv->generate_image();
my $commands_ref = $vv->get_commands_ref();
$seq = $vv->get_sequence();

################################################################################
#making temp file for the native format
my $native_format_tempdir = File::Spec->catdir($c->config->{'basepath'},
            		  $c->config->{'tempfiles_subdir'},
            		  "cview",
            		 );
my ($fh ,$native_tmp) = tempfile( DIR => $native_format_tempdir, TEMPLATE=>"vector_XXXXXX");

foreach my $c (@$commands_ref) { 
print $fh join ", ", @$c;
print $fh "\n";
}
  
my $base_temp = basename ($native_tmp);



  
################################################################################    
display_results($p, $image_html, $seq, $commands_ref, $show_re, $base_temp);
###############################################################################

sub display_form { 
    my $p = shift;
    
# display form
#
$p->header("Vector drawing application", "Vector drawing application");

print <<HTML;

<form enctype="multipart/form-data" method="post" >
Vector name <input type="text" name="name" value="" size="8" /><br /><br />
Upload a genbank file <input type="file" name="genbank_record" /><br /><br />
<b>Format:</b><br />
<input type="radio" name="format" value="genbank" checked="1" /> Genbank<br />
<input type="radio" name="format" value="native" /> Native<br /><br />
<b>Show restriction sites</b><br />
<input type="radio" name="show_re" value="all" /> all (not recommended)<br />
<input type="radio" name="show_re" value="unique" /> unique cutters<br />
<input type="radio" name="show_re" value="popular6bp" /> popular 6bp cutters<br />
<input type="radio" name="show_re" value="popular4bp" /> popular 4bp cutters<br />
<br /><br />
<input type="submit" value="upload" />
<input type="hidden" name="action" value="upload" />
</form>


HTML

$p->footer();

}

sub display_results { 
    
    my $p = shift;
    my $image_html = shift;
    my $seq = shift;
    my $commands = shift;
    my $show_re = shift;
    my $native_file =shift;
    $p->header("Vector Drawing", "Vector Drawing");

    print <<HTML;
    
      
<center>
      $image_html
</center>

HTML

my $html = qq{
    
<form method="post" >
<input type="hidden" name="format" value="native" />
<input type="hidden" name="action" value="draw_native" />
<center>
<textarea name="edit_commands" rows="20" cols="80">};
    
    $native_commands = "";
    foreach my $c (@$commands) { 
	$native_commands .= join ", ", @$c;
	$native_commands .= "\n";
    }
    
    $html .= $native_commands;
    $html .=  qq { </textarea><br /><input type="submit" /></center></form> };

    my $edit_native = info_section_html( title=> "Edit", contents=>$html, collapsible=>1, collapsed=>1);

    print $edit_native;


    my $insert_html = <<HTML;
<form method="post">
Insert Sequence <br /><br /><textarea name="insert_sequence" value="" rows = "4" cols="80" /></textarea><br />
Insert at position <input type="text" name="insert_coord" value="0" size="4" /><br />
<input type="hidden" name="action" value="insert" />

<input type="hidden" name="native_file" value="$native_file" />
<input type="hidden" name="show_re" value="$show_re" />
<input type="submit" />
</form>

HTML

print info_section_html( title=>"Insert sequence", contents=>$insert_html, collapsible=>1, collapsed=>1);

    my $delete_html = <<HTML;
<form method="post">
Delete Sequence<br /><br />
From position <input type="text" name="del_start" /> 
to position <input type="text" name="del_end" />
<input type="hidden" name="action" value="delete" />
<input type="hidden" name="native_file" value="$native_file" />
<input type="hidden" name="show_re" value="$show_re" />
<input type="submit" />
HTML

print info_section_html (title=>"Delete sequence", contents=>$delete_html, collapsible=>1, collapsed=>1);

    my $split_seq = html_break_string($seq, 100, "\n");
    my $sequence_html = qq { <pre><div id="sequence_display">$split_seq</div></pre> };

    print info_section_html( title=>"View sequence", contents=>$sequence_html, collapsible=>1, collapsed=>1);

    $p->footer();
    

}

