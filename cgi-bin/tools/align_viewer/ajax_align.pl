#!/usr/bin/perl
use CXGN::Scrap::AjaxPage;
use CXGN::Phylo::Alignment;
use CXGN::Phylo::Alignment::Member;
use Bio::SeqIO;

my $page = CXGN::Scrap::AjaxPage->new();


my ($temp_file, $title, $type, $hide_seqs, $start_value, $end_value) 
	= $page->get_arguments(
  qw|temp_file title type hide_seqs start_value end_value|);

$page->throw("No temp_file specified") unless($temp_file);
$page->throw("No type specified") unless ($type);



my $vhost_conf = CXGN::VHost->new();

our $html_root_path = $vhost_conf->get_conf('basepath');
our $doc_path =  $vhost_conf->get_conf('tempfiles_subdir').'/align_viewer';
our $path = $html_root_path . $doc_path;
our $tmp_fh;

#You can send the temp_file as a filename and not a full path, good for security
unless($temp_file =~ /\//){
	$temp_file = $path . "/" . $temp_file;
}

my %hidden_seqs = ();
my @ids = split /\s+/, $hide_seqs;
foreach (@ids) {
  $hidden_seqs{$_} = 1;
}

my $align = CXGN::Phylo::Alignment->new(
					name=>$title, 
					width=>800, 
					height=>2000, 
					type=>$type
				       );
my $instream;
my $len;

$instream =  Bio::SeqIO->new(-file => $temp_file, -format => 'fasta');
while (my $in = $instream->next_seq()){
  my $seq = $in->seq();
  my ($id,$species) = $in->id() =~ m/(.+)-(.+)/;
 $id = $in->id();
  (!$species) and $species = ();

	my $hidden = 0;
  	$hidden = 1 if(exists $hidden_seqs{$id});  #skip the sequence if it is in the hide_seq

  chomp $seq;
  $len = length $seq;
  my $member = CXGN::Phylo::Alignment::Member->new(
						     start_value=>1, 
						     end_value=>$len, 
						     id=>$id,
						     seq=>$seq,
							 hidden=>$hidden,
						     species=>$species
						    );
	
	#temporary!	
	if($title eq "Alignment Example"){
		$member->add_region("Example Domain", 379, 422, [250, 120, 20]);
		$member->add_region("Another Example", 444, 486, [100, 190, 90]);
	}
	##

  eval {  $align->add_member($member);};
  $@ and $page->throw($@);
}

(!$start_value) and $start_value = 1;
$align->set_start_value($start_value);
(!$end_value) and $end_value = $len;
($len < $end_value) and $end_value = $len;
$align->set_end_value($end_value);

my $tmp_image = new File::Temp(
                               DIR => $path,
                               SUFFIX => '.png',
                               UNLINK => 0,
                              );

##Render image
$align -> render_png_file($tmp_image, 'c');
close $tmp_image;
$tmp_image =~ s/$html_root_path//;
my ($temp_file_name) = $temp_file =~ /([^\/]+)$/;
$align->set_fasta_temp_file($temp_file_name);


print $page->header();

print "<src>$tmp_image</src>";
print "<imap>";
print $align->get_image_map;
print "</imap>";
print $page->footer();


