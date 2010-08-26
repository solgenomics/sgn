#!/usr/bin/perl

=head1 NAME

tree_browser/index.pl - the script controlling the tree browser tool 

=head1 DESCRIPTION

soon

=head1 DEPENDENCIES

soon

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>


=cut

use strict;

use CGI qw/ -compile :standard /;

use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use Tie::UrlEncoder;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html info_section_html/;

use CXGN::Tools::Identifiers qw | identifier_url identifier_namespace |;
use CXGN::Tools::Gene;
use CXGN::Tools::Param qw/ hash2param hash2hiddenpost /;

use CXGN::Phylo::Parser;
use CXGN::Phylo::Tree_browser;
use CXGN::Phylo::File;

use CXGN::Phylo::Alignment;
use CXGN::Phylo::Alignment::Member;

use CXGN::VHost;
use Bio::SeqIO;

use HTML::Entities;

#use Storable;

#print STDERR "Done loading modules...\n";

our %urlencode;

my $request = shift;

# generate a page object and get parameters

#
my $page = CXGN::Page->new( "SGN Tree Browser", "Lukas" );

my (
    $action,                $tree_string,
    $file,                  $shared_file,
    $hilite,                $ops,
    $term,                  $title,
    $tree_style,            $show_blen,
    $preset,                $height,
    $reroot,                $show_orthologs,
    $show_species,          $collapse_single_species_subtrees,
    $show_standard_species, $align_temp_show,
    $newick_temp_show,      $example_show,
    $use_html_path,         $show_skip_form,
    $align_format,          $align_seq_data,
    $align_temp_file,       $align_type,
    $hide_alignment,        $tree_from_align,
    $show_sigpep,           $show_domains,
    $stored_genes,          $family_nr,
    $i_value
  )
  = $page->get_encoded_arguments(
    "action",                "tree_string",
    "file",                  "shared_file",
    "hilite",                "ops",
    "term",                  "title",
    "tree_style",            "show_blen",
    "preset",                "height",
    "reroot",                "show_orthologs",
    "show_species",          "collapse_single_species_subtrees",
    "show_standard_species", "align_temp_show",
    "newick_temp_show",      "example_show",
    "use_html_path",         "show_skip_form",
    "align_format",          "align_seq_data",
    "align_temp_file",       "align_type",
    "hide_alignment",        "tree_from_align",
    "show_sigpep",           "show_domains",
    "stored_genes",          "family_nr",
    "i_value"
  );
my $tree_string_param = $tree_string;    #keep track of provided param

$height = 50 if ( $height =~ /^\d+$/ && $height < 50 );

#Stuff to fill into query form, with optional bypass if it's coming from somewhere else on SGN# :
# our	()=
# 	$page->get_encoded_arguments
# 	();

#print STDERR "Done getting parameters...\n";

##Alignment File Handling Stuff ########################################
# my ()
# 	= $page->get_arguments(

# 		);
my $vhost_conf = CXGN::VHost->new();

$show_domains = 1 unless ( $show_domains =~ /^(1|0)$/ && $show_domains == 0 );

our %PARAM = (
    "action"      => $action,
    "file"        => $file,
    "shared_file" => $shared_file,
    "hilite"      => $hilite,
    "ops"         => $ops,
    "term"        => $term,
    "title"       => $title,
    "tree_style"  => $tree_style,
    "show_blen"   => $show_blen,
    "preset"      => $preset,
    "height"      => $height,
    "reroot"      => $reroot,

    "align_format"                     => $align_format,
    "align_temp_file"                  => $align_temp_file,
    "align_type"                       => $align_type,
    "hide_alignment"                   => $hide_alignment,
    "tree_from_align"                  => $tree_from_align,
    "show_sigpep"                      => $show_sigpep,
    "show_domains"                     => $show_domains,
    "stored_genes"                     => $stored_genes,
    "show_orthologs"                   => $show_orthologs,
    "show_species"                     => $show_species,
    "collapse_single_species_subtrees" => $collapse_single_species_subtrees,
);

our $HTML_ROOT_PATH = $vhost_conf->get_conf('basepath');
our $DOC_PATH = $vhost_conf->get_conf('tempfiles_subdir') . '/align_viewer';
our $PATH     = $HTML_ROOT_PATH . $DOC_PATH;

our $CMD_QUICKTREE = "/data/prod/bin/quicktree";
our $CMD_SREFORMAT = "/data/prod/bin/sreformat";
$CMD_QUICKTREE = "quicktree" unless ( -x $CMD_QUICKTREE );
$CMD_SREFORMAT = "sreformat" unless ( -x $CMD_SREFORMAT );

unless ( !$align_temp_show || $align_temp_show =~ /\// ) {
    $align_temp_show = $PATH . "/" . $align_temp_show;
}
unless ( !$newick_temp_show || $newick_temp_show =~ /\// ) {
    $newick_temp_show = $PATH . "/" . $newick_temp_show;
}
if ($use_html_path) {
    $align_temp_show  = $HTML_ROOT_PATH . $align_temp_show;
    $newick_temp_show = $HTML_ROOT_PATH . $newick_temp_show;
}

#print STDERR "Done with setting up some variables...\n";

#Family Shortcuts
#Copy newick/alignment to temp files based on family information:
if (   !( -f ( $PATH . "/" . $align_temp_file ) && -f ( $PATH . "/" . $file ) )
    && $family_nr
    && $i_value )
{
    my $family_basedir = "/data/prod/public/family/$i_value";
    unless ( -d $family_basedir ) {
        input_err_page( $page,
            "No current family build corresponds to an i_value of $i_value" );
    }
    unless ( -f "$family_basedir/pep_align/$family_nr.pep.aligned.fasta" ) {
        input_err_page( $page, "Alignment was not calculated for this family" );
    }
    unless ( -f "$family_basedir/newick/$family_nr.newick" ) {
        $tree_from_align = 1;
    }
    else {

        #Make new temporary alignment and newick files
        my $tmp_fh = File::Temp->new(
            DIR    => $PATH,
            UNLINK => 0
        );
        $file = $tmp_fh->filename();
        $tmp_fh->close();

        system "cp $family_basedir/newick/$family_nr.newick $file";
    }

    my $tmp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0
    );
    $align_temp_file = $tmp_fh->filename();
    $tmp_fh->close();
    my @out =
`cp $family_basedir/pep_align/$family_nr.pep.aligned.fasta $align_temp_file 2>/dev/stdout`;
}

# 'show_skip_form' is a url parameter of unknown function, but it seems to have to do
# something with the combined tree/alignment view
#
if ($show_skip_form) {

    #Copy files to real temp directory
    my $temp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0
    );
    open( FH, $newick_temp_show );
    my $content = "";
    $content .= $_ while <FH>;
    close(FH);
    print $temp_fh $content;
    $file = $temp_fh->filename;

    $temp_fh = File::Temp->new( DIR => $PATH, UNLINK => 0 );

    open( FH, $align_temp_show );
    $content = "";
    $content .= $_ while <FH>;
    close(FH);
    print $temp_fh $content;
    $align_temp_file = $temp_fh->filename;
}

our $align_tmp_fh;
unless ( $align_temp_file =~ /\// ) {
    $align_temp_file = $PATH . "/" . $align_temp_file;
}

# my $align_upload = $page->get_upload("align_upload");
# my $align_upload_fh;
# if (defined $align_upload) {
# 	$align_upload_fh = $align_upload->fh();
#         while (<$align_upload_fh>) {
#             $align_seq_data .=$_;
# 	}
# }
if ( $align_seq_data ne '' ) {
    $align_tmp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0,
    );

    $align_temp_file = $align_tmp_fh->filename;
    $align_seq_data =~ s/\&gt\;/\>/g;
    $align_seq_data =~ s/\&lt\;/\</g;
    $align_seq_data =~ s/\&\#124;/\|/g;
    print $align_tmp_fh "$align_seq_data";
    close $align_tmp_fh;

    # Convert the input file into fasta if it is clustal
    #
    if ( $align_format eq 'clustalw' ) {
        my $align_temp_file_fasta = $align_temp_file . ".fasta";
        convert_clustal_fasta( $align_temp_file, $align_temp_file_fasta );

        # continue with the converted file...
        #
        $align_temp_file = $align_temp_file_fasta;
    }
}
if ( -f $align_temp_file ) {
    my ( $align_seq_count, $align_max_lengthh ) =
      fasta_check( $align_temp_file, $page )
      if $align_temp_file;
}
if ( $align_format eq "clustalw" && $align_temp_file && !$align_seq_data ) {
    my $align_temp_file_fasta = $align_temp_file . ".fasta";
    convert_clustal_fasta( $align_temp_file, $align_temp_file_fasta );
    $align_temp_file = $align_temp_file_fasta;
    $align_format    = "aligned_fasta";
}

#print STDERR "Done checking some file stuff\n";

#### Construct Alignment ##############################################
my $alignment = CXGN::Phylo::Alignment->new(
    name   => "Untitled",
    width  => 800,
    height => 2000,
    type   => $align_type
);
my $instream;
my $len;
my %fasta_hash = ();
$instream = Bio::SeqIO->new( -file => $align_temp_file, -format => 'fasta' );
while ( my $in = $instream->next_seq() ) {
    my $seq = $in->seq();
    my $id  = $in->id();
    chomp $seq;
    $len = length $seq;
    $fasta_hash{$id} = $seq;
    my $member = CXGN::Phylo::Alignment::Member->new(
        start_value => 1,
        end_value   => $len,
        id          => $id,
        seq         => $seq,
        type        => $align_type
    );
    eval { $alignment->add_member($member); };
    $@ and input_err_page( $page, $@ );

}

#print STDERR "Done defining alignment...\n";

if ($tree_from_align) {
    input_err_page( $page, "No alignment file" ) unless ( -f $align_temp_file );
    my @sre = `$CMD_SREFORMAT stockholm $align_temp_file`;

    # input_err_page($page, "sreformat command:  $CMD_SREFORMAT");
    input_err_page( $page,
        "Utility \"sreformat\" didn't work, or no alignment" )
      unless (@sre);
    my $sre_temp_fh = File::Temp->new( DIR => $PATH, UNLINK => 1 );
    print $sre_temp_fh $_ foreach (@sre);
    my $sre_temp = $sre_temp_fh->filename;
    my @newick   = `$CMD_QUICKTREE -kimura $sre_temp`;
    input_err_page( $page,
        "Program \"quicktree\" didn't work, or no alignment" )
      unless (@newick);
    $tree_string = "";
    $tree_string .= $_ foreach (@newick);
    $sre_temp_fh->close();
}

# create a new Tree_browser object which will handle most of the stuff
#
my $browser = CXGN::Phylo::Tree_browser->new();

#print STDERR "Done creating tree browser object..\n";
##Maybe do this:
$browser->set_temp_dir($PATH);

my $temp_dir = $browser->get_temp_dir();

# check to see if we have a preset tree that we should show
#
if ($preset) {
    my $plants_file =
      CXGN::Phylo::File->new( $page->path_to("data/asterids.newick.txt") );

    my $plants_tree = $plants_file->get_tree();
    $tree_string = $plants_tree->get_root()->recursive_generate_newick();

    my $new_root = $plants_tree->get_node_by_name($preset);
    if ($new_root) {
        $ops = "s" . $new_root->get_node_key();
    }
}

#print STDERR "Done dealing with presets...\n";

# get an upload object to upload a file, copy the
# file to a temp location
#
use CatalystX::GlobalContext qw( $c );
my $upload = $c->req->upload($file);

my ( $temp_fh, $temp_file ) =
  File::Temp::tempfile( "tree-XXXXXX", DIR => $temp_dir );

# print STDERR "upload: [$upload] <br>";
if ( defined $upload ) {
    my $upload_fh = $upload->fh();
    while (<$upload_fh>) {

        #print STDERR $_;
        print $temp_fh $_;
    }
    close($temp_fh);
    close($upload_fh);

    #print STDERR "Uploading file $temp_file...\n ";

    my $tree_file = CXGN::Phylo::File->new($temp_file);
    my $tree_obj  = $tree_file->get_tree();
    if ($tree_obj) {
        $tree_string = $tree_obj->get_root()->recursive_generate_newick();
    }
    print STDERR "TREE STRING= $tree_string\n";
}

if ($shared_file) {
    if ( $shared_file =~ /\/\./ ) {
        $page->error_page( 'Invalid file location.',
            "Invalid file location: $shared_file" );
    }
    my $conf             = $vhost_conf;
    my $shared_data_path = $conf->get_conf('static_datasets_path');
    my $shared_data_url  = $conf->get_conf('static_datasets_url');
    $shared_file =~ /^$shared_data_url\/cosii\/[\w\-\/]+\.\d\.ml\.tre$/
      or $page->error_page( "Invalid file location",
        "Invalid file location: $shared_file" );
    $title = $shared_file;
    $shared_file =~ s/$shared_data_url//;
    my $filename  = $shared_data_path . $shared_file;
    my $tree_file = CXGN::Phylo::File->new($filename);
    my $tree_obj  = $tree_file->get_tree();

    if ($tree_obj) {
        $tree_string = $tree_obj->get_root()->recursive_generate_newick();
    }
}

#print STDERR "Done with shared file...\n";
# for now, the species tree is just hard-coded for species relevant to sgn:
my $species_tree_newick =
"(((((((((tomato[species=Solanum_lycopersicum]:1, potato[species=Solanum_tuberosum]:1):1, eggplant[species=Solanum_melongena]:1):1, pepper[species=Capsicum_annuum]:1):1, tobacco[species=Nicotiana_tabacum]:1):1, petunia[species=Petunia]:1):1, sweet_potato[species=Ipomoea_batatas]:1):1,(arabica_coffee[species=Coffea_arabica]:1,robusta_coffee[species=Coffea_canephora]:1):1):1, snapdragon[species=Antirrhinum]:1):1,arabidopsis[species=Arabidopsis_thaliana]:1)";

$species_tree_newick =
"((brachypodium[species=Brachypodium_distachyon]:1, (rice[species=Oryza_sativa]):1):1, "
  . $species_tree_newick . ":1)";

#print STDERR "species tree newick: \n", $species_tree_newick, "\n";

my $species_tree =
  CXGN::Phylo::Parse_newick->new($species_tree_newick)->parse()
  ;    #construct Parse_newick for string $newick

## these aren't needed for the hard coded species tree, but may be needed if/when we allow other trees (user supplied)
$species_tree->set_missing_species_from_names()
  ;    # if get_species() not defined get species from name
$species_tree->impose_branch_length_minimum();
$species_tree->collapse_tree();
my $species_name_map = CXGN::Phylo::Species_name_map->new();
$species_tree->set_species_standardizer($species_name_map);

# the user can either submit a tree string (using the tree_string html
# parameter, or a temp file name is supplied with the file parameter (for
# clicks that are generated after the initial parsing).
# If we have neither, show the input form.
#
if ($tree_string) {

    # clean the string...
    $tree_string =~ s/\n//g;
    $tree_string =~ s/\r//g;

    #print STDERR "TREESTRING: $tree_string\n";

    # because we used CXGN::Page::encoded_arguments we have to
    # do some translation back to normal ascii
    #
    while ( $tree_string =~ m/(.*)\&quot\;(.*?)\&quot\;(.*)/gi ) {

        #print "MATCHED: $2\n";
        my $encoded = URI::Escape::uri_escape( $2, ":" );
        $tree_string = $1 . $encoded . $3;
    }
    $browser->set_tree_string($tree_string);
    $file = $browser->create_temp_file();
}

if ($file) {
    $file = File::Basename::basename($file);
    $file = $PATH . "/" . $file unless ( $file =~ /\// );
    $browser->set_temp_file($file);
}

$browser->set_hilite($hilite);

my @operations = split / /, $ops;
foreach my $o (@operations) {
    $browser->toggle_node_operation($o);
}

#print("browser->get_tree_string: ", $browser->get_tree_string(), "\n");
if ( !$browser->get_tree_string() ) {

    show_form($page);
    $show_orthologs                   = 0;
    $show_species                     = 0;
    $collapse_single_species_subtrees = 0;

}
else {
    my $tree_string = $browser->get_tree_string();
    my $parser      = CXGN::Phylo::Parse_newick->new($tree_string);
    my $tree        = $parser->parse();

    if ( !$tree ) {
        my $error = $parser->get_error();
        $page->message_page(
            "SGN tree browser error",
"This does not seem to be a legal Newick formatted tree.<br />Error possibly near highlighted token:<br />$error"
        );
    }
    $tree->impose_branch_length_minimum()
      ;    # impose the default minimum branch length (0.0001),
     # because zero branch lengths can lead to leaves getting lost during rerooting.
    $tree->set_show_species_in_label(1);

    if ( @{ $alignment->{members} } ) {
        $tree->set_alignment($alignment);
    }

    $tree->set_line_color( 150, 150, 150 );
    if ( !$title ) {
        $title = "Untitled Tree";
    }
    $tree->set_name($title);
    $tree->set_show_species_in_label($show_species);
    $tree->set_show_standard_species($show_standard_species);

    #	$tree->set_line_color(0, 200, 0);
    $tree->set_missing_species_from_names();
    $tree->impose_branch_length_minimum();
    $tree->get_root()->recursive_implicit_names();    # needed?

    $tree->set_species_standardizer($species_name_map);
    $tree->update_label_names();

    # species tree is already set up (check this is always true)
    my $spec_bit_hash = $tree->get_species_bithash($species_tree);
    $species_tree->get_root()->recursive_implicit_species();
    $species_tree->get_root()
      ->recursive_set_implicit_species_bits($spec_bit_hash);

#reroot the gene tree
# reroot the tree at the point which minimizes the variance of the root-leaf distances
#print blue_section_html("tree style: $tree_style <br> \n");

    if ( $reroot and ( $reroot ne "Original" ) )
    {    # reroot the tree according to the selected method

        my @new_root_point;
        if ( $reroot eq "MinVariance" ) {
            @new_root_point = $tree->min_leaf_dist_variance_point();
        }
        elsif ( $reroot eq "Midpoint" ) {
            @new_root_point = $tree->find_point_closest_to_furthest_leaf();
        }
        elsif ( $reroot eq "MinDuplication" ) {
            @new_root_point = $tree->find_mindl_node($species_tree);
        }
        elsif ( $reroot eq "MaxMin" ) {
            @new_root_point = $tree->find_point_furthest_from_leaves();
        }
        $tree->reset_root_to_point_on_branch(@new_root_point);
    }

    $tree->get_root()->recursive_implicit_names();
    $tree->get_root()->recursive_implicit_species();
    $tree->update_label_names();

#	if (0) {
#		my $spec_bit_hash = $browser->get_tree()->get_species_bithash($species_tree);

#		$species_tree->get_root()->recursive_implicit_species();
#		#print STDERR "ccccc\n";
#		$species_tree->get_root()->recursive_set_implicit_species_bits($spec_bit_hash);

#		$browser->get_tree()->get_root()->rs
#		$browser->get_tree()->get_root()->recursive_set_implicit_species_bits($spec_bit_hash);
#		$browser->get_tree()->get_root()->recursive_implicit_names(); # this is needed, but why?

#		$browser->get_tree()->get_root()->recursive_set_speciation($species_tree);
#		$browser->get_tree()->get_root()->recursive_hilite_speciation_nodes($species_tree);
#	}

    #	$tree->get_root()->recursive_set_leaf_species_count();
    #	$tree->get_root()->recursive_set_leaf_count();
    if ($collapse_single_species_subtrees) {
        $tree->collapse_unique_species_subtrees()
          ;    # this seems to be causing problems
        $tree->get_root()->recursive_implicit_names()
          ;    # this is needed, but why?
        $tree->get_root()->recursive_implicit_species();
    }
    if ($show_orthologs) {

        $tree->get_root()->recursive_implicit_names()
          ;    # this is needed, but why?
        $tree->get_root()->recursive_implicit_species();

#	print STDERR "root implicit species: ", join(";", ($tree->get_root()->get_implicit_species())), "\n";
        $tree->get_root()->recursive_set_implicit_species_bits($spec_bit_hash);

        $tree->update_label_names();

        #### handle possible trifurcation at root
        my $root_spec =
          $tree->get_root()->speciation_at_this_node($species_tree);

        # print "root_spec: $root_spec \n";
        if ( $root_spec < 0 )
        {   # if trifurcation at root, reroot to one of the neighboring branches
                # if this will yield a speciation at root...
            my $cn = ( $tree->get_root()->get_children() )[ $root_spec + 3 ];
            my $bl = $cn->get_branch_length();
            $tree->reset_root_to_point_on_branch( $cn, 0.5 * $bl );
            $tree->get_root()->recursive_implicit_names();
            $tree->get_root()->recursive_implicit_species();
            $tree->get_root()
              ->recursive_set_implicit_species_bits($spec_bit_hash);
        }
        #### end of handling trifurcation at root

        $tree->get_root()->recursive_set_speciation($species_tree);
        $tree->get_root()->recursive_hilite_speciation_nodes($species_tree);
    }

    #	$tree->set_line_color(100, 100, 0);
    $tree->set_hilite_color( 100, 200, 200 );

    $tree->show_newick_attribute("species");

    #	$tree->set_hilite_color(150, 0, 200);

    $browser->set_tree($tree);

    #	$page->message_page("tree_style, reroot: [$tree_style], [$reroot]\n");

    # initialize the layout object
    #
    my $layout = CXGN::Phylo::Layout_left_to_right->new($tree);

    # initialize an approprate layout object
    #

    $layout->set_top_margin(20);
    $layout->set_bottom_margin(20);

    #    $layout->set_image_height(400);
    $layout->set_image_width(700);
    $tree->set_layout($layout);

    #Highlight domains, utilize stored genes if possible to eliminate
    #database querying time.  Eval used for whole operation, since
    #none of it is critical for the viewer
    eval {
        my $genes;
        if ($stored_genes) {
            my $filepath = $stored_genes;
            $filepath = $PATH . "/" . $stored_genes
              unless ( $stored_genes =~ /\// );
            $genes = retrieve $filepath if ( -f $filepath );

            unlink $filepath
              ;    #we will always store to a new file, so this one must go!
        }
        $genes = $alignment->highlight_domains($genes)
          if ( $show_domains && !$hide_alignment );
        my $storetemp = File::Temp->new( DIR => $PATH, UNLINK => 0 );
        my $storefile = $storetemp->filename;
        store( $genes, $storefile ) if ref $genes eq "HASH";
        $stored_genes = File::Basename::basename($storefile);
        $PARAM{stored_genes} = $stored_genes;
    };

    my @nodes = $tree->get_all_nodes();

    my %id2mem = ();
    foreach my $m ( @{ $alignment->{members} } ) {
        my $name = $m->get_id();
        $id2mem{$name} = $m;
    }

    my %models;

    foreach my $n (@nodes) {
        my $key  = $n->get_node_key();
        my $file = File::Basename::basename( $browser->get_temp_file() );
        $align_temp_file = "" if ( $align_temp_file =~ /\/$/ );
        my $align_temp_name = File::Basename::basename($align_temp_file);

#		my $link_tail = "&amp;hilite=$key\&amp;height=$height&amp;file=$file&amp;action=display&amp;term=$term&amp;title=$urlencode{$title}&amp;style=$style&amp;show_blen=$show_blen&amp;align_temp_file=$align_temp_name&align_type=$align_type&hide_alignment=$hide_alignment";
        $PARAM{align_temp_file} = $align_temp_name;
        $PARAM{file}            = $file;

# if the node is hidden, we generate a link that will unhide it if you click on it!
# (we remove the node from the node_operations list)
#
        my @ops = $browser->get_node_operations();

        for ( my $i = 0 ; $i < @ops ; $i++ ) {
            if ( $ops[$i] =~ /^h$key$/i ) {
                splice @ops, $i, 1;
            }
        }

        my $tooltip = $n->get_tooltip()
          or "Node " . $n->get_node_key() . ": " . $n->get_label()->get_name();

        #	my $tooltip = "Node " . $n->get_node_key();
        my $model = $n->get_attribute("model");
        if ($model) {
            $tooltip .= ", Model: " . ucfirst($model);
            $models{$model}++;
        }
        $n->set_tooltip($tooltip);

        my $link = "?"
          . hash2param(
            \%PARAM,
            {
                hilite => $key,
                ops    => ( join "+", @ops )
            }
          );

        # set the link...
        #
        $n->set_link($link);

        if ( $n->is_leaf() ) {

            if ( !$n->get_label()->get_link() ) {
                my $name = $n->get_label()->get_name();
                my $link = identifier_url($name);

                #print STDERR "Name: ".$n->get_name()." LINK: ".$link."\n";
                if ($link) {
                    $n->get_label()->set_link($link);
                }
                if (
                    identifier_namespace($name) =~ /(sgn_u)|(tair_gene_model)/ )
                {
                    my ( $gene, $annot );
                    eval {

                        #print STDERR "Before Gene->new...\n";
                        $gene = CXGN::Tools::Gene->new($name);

                        #	print STDERR "After Gene->new...\n";
                        $annot = $gene->getAnnotation();
                        $annot = HTML::Entities::encode($annot);
                    };
                    unless ($@) {
                        $n->get_label()->set_tooltip($annot) if $annot;
                    }

                }
            }

          # adjust the label colors if there is a link. internal links are blue,
          # while external links are purple.
          #
            if ( $n->get_label()->get_link() ) {
                $n->get_label()->set_line_color( 0, 0, 255 );
            }
            if ( $n->get_label()->get_link() =~ /^\s*http/ ) {
                $n->get_label()->set_line_color( 200, 0, 200 );
            }
        }

        #$n->print();
    }    # end of foreach my $n (@nodes) loop

    # if a search was performed, hilite the results
    #
    my @search_nodes =
      $browser->get_tree()->search_label_name("$term")
      ;    # search_node_name("$term");
    foreach my $n (@search_nodes) {
        $n->get_label()->set_hilite(1);    #
        $n->get_label()->set_hilite_color( 255, 200, 85 );
    }

    #exit();
    # play back the tree operations
    #
    #print <<EOH;
    #before play_back_operations.
    #$ops
    #EOH

    $browser->play_back_operations();

# hilite the node if the node is still in the tree (may have disappeared due to subtree etc)
#
    if ( $hilite && $tree->get_node($hilite) ) {
        $tree->get_node($hilite)->set_hilited(1);
    }
    $tree->set_hilite_color( 140, 60, 60 );

    # initialize an appropriate renderer and render the image
    #
    my $renderer = undef;

    # deal with the tree_style
    #
    if ( !$tree_style ) { $tree_style = "straight"; }
    if ( $tree_style eq "round" ) {
        $renderer = CXGN::Phylo::PNG_round_tree_renderer->new($tree);
    }
    elsif ( $tree_style eq "angle" ) {
        $renderer = CXGN::Phylo::PNG_angle_tree_renderer->new($tree);
    }
    else { $renderer = CXGN::Phylo::PNG_tree_renderer->new($tree); }

    $renderer->set_show_branch_length($show_blen);

    my @model_colors = (
        [ 100, 40,  100 ],
        [ 50,  140, 50 ],
        [ 40,  40,  170 ],
        [ 150, 90,  10 ],
        [ 100, 100, 40 ]
    );
    foreach my $model ( sort { $models{$b} <=> $models{$a} } keys %models ) {
        my $color_array = shift @model_colors;
        $renderer->hilite_model( $model, $color_array ) if $color_array;
    }

    $renderer->hide_alignment() if ($hide_alignment);
    $tree->set_renderer($renderer);

    #    $tree->layout();

    $browser->recursive_manage_labels( $browser->get_tree()->get_root() );
    $tree->get_root()->recursive_propagate_properties();

    my $DEFAULT_HEIGHT = 400;
    if ( !$height ) {
        $height = "stretch";
    }
    my $image_height = $DEFAULT_HEIGHT;
    if ( $height =~ /stretch/i ) {
        $tree->get_renderer()->set_font( GD::Font->Small() );
        $image_height = $tree->get_unhidden_leaf_count() * 12;
        if ( $image_height > $DEFAULT_HEIGHT ) {
            $height = $image_height;
        }
        else {
            $height = $DEFAULT_HEIGHT;
        }
    }
    $layout->set_image_height($height);

    my $unique = "_" . time() . $$;

    my $new_align_temp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0,
    );
    my $new_align_temp     = $new_align_temp_fh->filename;
    my $new_hilite_temp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0,
    );
    my $new_hilite_temp = $new_hilite_temp_fh->filename;

    my $s = 0;

    foreach my $n ( $tree->get_leaf_list ) {

        #alignment member stuff:
        $s++;
        my ( @mem_color, @hilite_color, @label_color, @label_hilite_color );
        if ( $s % 2 == 1 )
        {    # alignments shown with alternating darker and lighter colors...
            @mem_color          = ( 60,  60, 140 );
            @hilite_color       = ( 140, 60, 60 );
            @label_color        = ( 80,  80, 120 );
            @label_hilite_color = ( 120, 80, 80 );
        }
        else {
            @mem_color          = ( 20,  20, 110 );
            @hilite_color       = ( 110, 20, 20 );
            @label_color        = ( 20,  20, 60 );
            @label_hilite_color = ( 60,  20, 20 );
        }

        my $key = $n->get_name();
        my $m   = $id2mem{$key};
        next unless $m;
        $n->set_alignment_member($m);
        if ( $n->get_hilited ) {
            $m->set_color(@hilite_color);
            print $new_hilite_temp_fh ">$key\n" . $fasta_hash{$key} . "\n";
            $n->get_label()->set_text_color(@label_hilite_color)
              unless $hide_alignment;
        }
        else {
            $m->set_color(@mem_color);
            $n->get_label()->set_text_color(@label_color)
              unless $hide_alignment;
        }
        print $new_align_temp_fh ">$key\n" . $fasta_hash{$key} . "\n";
    }

    my $start_value = 1;
    my $end_value   = $alignment->get_end_value();

    # add the process id to the file name of the image to create
    # a unique filename, so that the image is re-loaded every time
    # it is clicked (required by Explorer).
    #

    $tree->render_png( ( $browser->get_temp_file() ) . "$unique.png" );

    my $filename = File::Basename::basename($file);
    my $temp_url = "/documents/tempfiles/align_viewer/${filename}$unique.png";

    # display the page
    #
    $page->header();
    my $align_filename = File::Basename::basename($align_temp_file);
    print page_title_html(
"<a href=\"?align_temp_show=$align_filename&newick_temp_show=$filename\">Tree browser:</a> "
          . $tree->get_name() );

    #

    #     print blue_section_html('debugging output',<<EOH);
    # render_png to this file:  $browser->get_temp_file()."$unique.png"
    # action: $action, <br />
    # tree string: $tree_string, <br />
    # file $file,  <br />
    # shared file: $shared_file, <br />
    # 	hilite: $hilite, <br />
    # operations: $ops, <br />
    # term: $term, <br />
    # title: $title, <br />
    # 	tree_style: $tree_style, <br />
    # show_blen: $show_blen, <br />
    # preset: $preset, <br />
    # height: $height <br />

    # EOH

    #
    print $renderer->get_html_image_map( "tree_image_map", $new_align_temp,
        $new_hilite_temp, $align_type );

    my $file_for_link = File::Basename::basename( $browser->get_temp_file() );

    my $node_operations = join( " ", $browser->get_node_operations() );
    my $new_rotated_node_operations =
      join( " ", $node_operations, ( "r" . $browser->get_hilite() ) );
    my $new_hidden_node_operations =
      join( " ", $node_operations, ( "h" . $browser->get_hilite() ) );
    my $new_set_root_node_operations =
      join( " ", $node_operations, ( "s" . $browser->get_hilite() ) );
    my $new_reset_root_operations =
      join( " ", $node_operations, ( "t" . $browser->get_hilite() ) );

    my $active_if_hilite_button = "";
    my $not_show_blen           = !$show_blen;
    my $not_show_orthologs      = !$show_orthologs;
    my $not_collapse_single_species_subtrees =
      !$collapse_single_species_subtrees;
    my $not_show_species = !$show_species;

    #	my $not_root_min_var = !$root_min_var;
    if ( !$hilite ) {
        $active_if_hilite_button = "disabled";
    }
    my $not_hide_alignment = !$hide_alignment;

    my $active_if_changed_button = "disabled";
    if ( $hilite || $ops ) {
        $active_if_changed_button = "";
    }
    chomp($tree_style);

    #print STDERR "Tree_style: $tree_style\n";
    my ( $round_selected, $angle_selected, $straight_selected ) =
      ( "", "", "" );
    if ( $tree_style =~ /round/i ) {
        $round_selected    = "selected=\"selected\"";
        $angle_selected    = "";
        $straight_selected = "";
    }
    if ( $tree_style =~ /angle/i ) {
        $round_selected    = "";
        $angle_selected    = "selected=\"selected\"";
        $straight_selected = "";
    }
    if ( $tree_style =~ /straight/i ) {
        $round_selected    = "";
        $angle_selected    = "";
        $straight_selected = "selected=\"selected\"";
    }

    my (
        $original_selected, $midpoint_selected, $minvar_selected,
        $mindl_selected,    $maxmin_selected
    ) = ( "", "", "", "", "" );
    if ( $reroot =~ /Midpoint/i ) {
        $midpoint_selected = "selected=\"selected\"";
    }
    elsif ( $reroot =~ /MinVariance/i ) {
        $minvar_selected = "selected=\"selected\"";
    }
    elsif ( $reroot =~ /MinDuplication/i ) {
        $mindl_selected = "selected=\"selected\"";
    }
    elsif ( $reroot =~ /MaxMin/i ) {
        $maxmin_selected = "selected=\"selected\"";
    }
    else {
        $original_selected = "selected=\"selected\"";
    }

    my $smaller_height = int( $height * 0.7 );
    my $larger_height  = int( $height * 1.3 );

    my $not_show_domains = 0;
    $not_show_domains = 1 unless $show_domains;

    my $blen_text = "Show Branch Length";
    $blen_text = "Hide Branch Length" if $show_blen;
    my $align_text = "Hide Alignment";
    $align_text = "Show Alignment" if $hide_alignment;
    my $domain_text = "Hide Domains";
    $domain_text = "Show Domains" unless $show_domains;
    my $show_species_text = "Hide species";
    $show_species_text = "Show species" unless $show_species;

    #	my $root_min_var_text = "Reroot (Min Var)";
    #	$root_min_var_text = "Original Root" if $root_min_var;
    my $ortho_text = ($show_orthologs) ? "Hide Orthologs" : "Show Orthologs";
    my $collapse_single_species_text =
      ($collapse_single_species_subtrees)
      ? "Uncollapse 1-species subtrees"
      : "Collapse 1-species subtrees";

    unless ( $tree->get_alignment() ) {
        $align_text  = "";
        $domain_text = "";
    }
    $domain_text = "" if $hide_alignment;

    my $param_reset = hash2param( \%PARAM, { ops => "", hilite => "" } );
    my $param_rotate = hash2param(
        \%PARAM,
        {
            action => "rotate",
            ops    => $new_rotated_node_operations
        }
    );

    my $param_hide = hash2param(
        \%PARAM,
        {
            action => "hide",
            ops    => $new_hidden_node_operations
        }
    );

    my $param_prune_to_subtree = hash2param(
        \%PARAM,
        {
            height => "stretch",
            ops    => $new_set_root_node_operations
        }
    );

    my $param_set_as_root = hash2param(
        \%PARAM,
        {
            action => "reset_root",
            ops    => $new_reset_root_operations
        }
    );

    my $param_unselect = hash2param( \%PARAM, { hilite => "" } );
    my $param_align_toggle =
      hash2param( \%PARAM, { hide_alignment => $not_hide_alignment } );
    my $param_domain_toggle =
      hash2param( \%PARAM, { show_domains => $not_show_domains } );
    my $param_blen_toggle =
      hash2param( \%PARAM, { show_blen => $not_show_blen } );
    my $xxxxxx = $show_orthologs;
    my $param_orthologs_toggle =
      hash2param( \%PARAM, { show_orthologs => $not_show_orthologs } );
    my $param_collapse_toggle = hash2param(
        \%PARAM,
        {
            collapse_single_species_subtrees =>
              $not_collapse_single_species_subtrees
        }
    );

#	$page->message_page("xxxxxx, show ortho, std spec: ", "[$xxxxxx], [$show_orthologs], [$show_standard_species]<br>");
    my $param_show_species_toggle =
      hash2param( \%PARAM, { show_species => $not_show_species } );

    #	my $param_reroot = hash2param(\%PARAM, { reroot => $reroot });

    my ( $param_smaller, $param_larger, $param_autosize ) =
      map { hash2param( \%PARAM, { height => $_ } ) }
      ( $smaller_height, $larger_height, "stretch" );

    my $param_input_tree_style = hash2hiddenpost( \%PARAM, {}, ["tree_style"] );
    my $param_input_reroot     = hash2hiddenpost( \%PARAM, {}, ["reroot"] );

    my $param_input_term = hash2hiddenpost( \%PARAM, {}, ["term"] );

    my $original_link =
"<a href=\"?$param_reset\">&lt;&lt; See Original Tree</a>&nbsp;&nbsp;&nbsp;";
    $original_link = ""
      if ( $upload || $tree_string_param || !$node_operations );

#	my $root_min_var_link = "<a href=\"?$param_root_min_var_toggle\"> $root_min_var_text</a>&nbsp;&nbsp;&nbsp;";
#	$root_min_var_link = "" if ($node_operations);
    my $w1 = "30%";
    my $w2 = "35%";
    my $w3 = "40%";

#my $htmlstring = "<table width=\"100%\"  border=\"5\" cellpadding=\"5\" cellspacing=\"5\" style=\"font-size:1.0em\" bgcolor=\"\" >  <tr bgcolor=\"\"> <td> XXX</td></tr></table>";

# my $htmlstring = "<table width=\"100%\" style=\"font-size:1.0em\" bgcolor=\"\" >  <tr bgcolor=\"\"> <td></td></tr></table>";

    my $treestyle_str = "	 <td width = \"33%\" bgcolor=\"\">
			<form id=\"tree_style_form\" style=\"margin-bottom:0; margin-top:0;font-size:1.0em\">
	     	<table width=\"100%\">

			<tr bgcolor=\"\">

			<td style=\"font-size:1.1em\"  bgcolor =\"\" width = $w1 >Tree Style:&nbsp; </td>

		   	<td bgcolor = \"\" width = $w2 >
		   	<select name=\"tree_style\" onchange=\"
						document.getElementById('tree_style_form').submit();
						return false;
		   				\">
	       	<option value=\"round\" $round_selected>curve</option>
	       	<option value=\"angle\" $angle_selected>straight</option>
	       	<option value=\"straight\" $straight_selected>corner</option>
	       	</select>
			</td>

               <!-- is this needed? seems to work just when you select new style in menu. maybe some browsers behave differently?-->
			<td bgcolor = \"white\"  width = $w3>
		       <input type=\"submit\" value=\"Change\" />
		      	$param_input_tree_style 
			   </td>

		   	</tr>
		   </table>
	       </form>
		  </td>";

    my $reroot_str = "	 <td bgcolor=\"\">
			<form id=\"reroot_form\" style=\"margin-bottom:0; margin-top:0;font-size:1.0em\">
	     	<table width=\"100%\">

			<tr bgcolor=\"\">

			<td style=\"font-size:1.1em\"  bgcolor =\"\" width = $w1 >Reroot:&nbsp; </td>

		   	<td bgcolor = \"\" width = $w2 >
		   	<select name=\"reroot\" onchange=\" document.getElementById('reroot_form').submit(); return false;	\">
	       	<option value =\"Original\" $original_selected>original</option>
	       	<option value=\"Midpoint\" $midpoint_selected>midpoint</option>
	       	<option value=\"MinVariance\" $minvar_selected>minvar</option>
               <option value=\"MinDuplication\" $mindl_selected>mindupl</option>
               <option value=\"MaxMin\" $maxmin_selected>maxmin</option>
	       	</select>
			</td>

               <!-- is this needed? seems to work just when you select new style in menu. maybe some browsers behave differently?-->
			<td bgcolor = \"white\"  width = $w3>
		       <input type=\"submit\" value=\"Change\" />
		      	$param_input_reroot 
			   </td>

		   	</tr>
		   </table>
	       </form>
		  </td>";

    my $highlight_str = "<td width = \"28%\">
			<form style=\"margin-bottom:0; margin-top:0\">
	       <table>
		   <tr>
		   <td>
	       <input name=\"term\" size=\"10\" value=\"$term\" />
		   </td>
		   <td>
	       <input type=\"submit\" value=\"Highlight\" />	$param_input_term 
		  </td>
		   </tr>
		
		   </table>
	       </form>
</td>";

  #my $align_domain_str =    "<tr><td colspan=\"2\" style=\"text-align:center\">
  #		  		<a href=\"?$param_align_toggle\">$align_text</a>
  #				&nbsp;&nbsp;&nbsp;
  #				<a href=\"?$param_domain_toggle\">$domain_text</a>
  #		   </td>
  #		   </tr>";
    my $show_species_str =
"<td  style=\"text-align:center;\"> <a href=\"?$param_show_species_toggle\">$show_species_text</a> </td>";

    my $show_blen = "<td style=\"text-align:center\">
	<a href=\"?$param_blen_toggle\"
             onMouseover=\"oldwindowstatus = window.status; window.status=$show_blen; return true\" 
             onMouseout=\"window.status=oldwindowstatus; return true\">
           $blen_text</a><br /></td>";
    my $show_ortho =
"<td  style=\"text-align:center;\"> <a href=\"?$param_orthologs_toggle\">$ortho_text</a> </td>";
    my $collapse_single_species =
"<td  style=\"text-align:center;\"> <a href=\"?$param_collapse_toggle\">$collapse_single_species_text</a> </td>";

   #"<td> <input name=\"term\" size=\"10\" value=\"$term\" />  </td>
   #<td> <input type=\"submit\" value=\"Highlight\" />	$param_input_term </td>";
    my $imagesize_str =
"<td style=\"text-align:center;vertical-align:bottom;\">	<span style=\"font-size:1.1em\">Image Size:&nbsp;
			</span>
			<a style=\"font-size:0.90em\" href=\"?$param_smaller\">Smaller</a>&nbsp;
			<a style=\"font-size:1.18em\" href=\"?$param_larger\">Larger</a>&nbsp;
			<a href=\"?$param_autosize\">AUTO</a>
			</td>";
    my $align_domain_str = "<td colspan=\"2\" style=\"text-align:center\">
		  		<a href=\"?$param_align_toggle\">$align_text</a>
				&nbsp;&nbsp;&nbsp;
				<a href=\"?$param_domain_toggle\">$domain_text</a>  </td>";
    print <<HTML;
<table width="100%"  border="2" cellpadding="1" cellspacing="1" style="font-size:1.0em" bgcolor="" >
<table width="100%"   style="font-size:1.0em" bgcolor="" >
<tr>
$treestyle_str
$highlight_str
$imagesize_str
</tr>
<tr>
$reroot_str
$show_ortho
$collapse_single_species
</tr>
<tr>
$show_blen
$show_species_str
$align_domain_str
</tr>
</table>
HTML

    my $node_control = <<HTML;
<tr>
	<td style="padding:10px">
			<div style="text-align: center">
			<table style="border:1px solid #922; cell-padding:5px; padding:5px;font-size:1.0em;background-color:#eee">
			<tr>
			<td>
			<a href="?$param_unselect">X</a>
			</td>
			<td style="">
			<span style="font-weight:bold; color:#411">Node $hilite</span>&nbsp;&nbsp;&nbsp;
			</td>
			<td>
		 	<a href="?$param_hide">Hide</a>
			&nbsp;&nbsp;
			</td>
			<td>
		   	<a href="?$param_rotate">Rotate</a>
			&nbsp;&nbsp;
			</td>
			<td>
	    	<a href="?$param_prune_to_subtree">Subtree</a>
			&nbsp;&nbsp;
			</td>
			<td>
			<a href="?$param_set_as_root">Set&nbsp;as&nbsp;Root</a>
			&nbsp;&nbsp;
			</td>

			</tr>
			</table>
			</div>
  </td>
</tr>
HTML
    if ($hilite) {
        print $node_control;
    }

    print <<HTML;
</table>
<br />
<img src="$temp_url" usemap="#tree_image_map" border="" alt="" />
<a name="bottom">&nbsp;</a>
HTML

    # print STDERR "term: $term.   param_input_term: $param_input_term \n";

    if ($show_orthologs) {
        if (0) {
            $species_tree->get_root()->recursive_implicit_species();

            #print STDERR "ccccc\n";
            $species_tree->get_root()
              ->recursive_set_implicit_species_bits($spec_bit_hash);
            $browser->get_tree()->get_root()->recursive_implicit_species();

            #print STDERR "ddddd\n";
            $browser->get_tree()->get_root()
              ->recursive_set_implicit_species_bits($spec_bit_hash);
            $browser->get_tree()->get_root()->recursive_implicit_names()
              ;    # this is needed, but why?
            $browser->get_tree()->get_root()
              ->recursive_set_speciation($species_tree);
            $browser->get_tree()->get_root()
              ->recursive_hilite_speciation_nodes($species_tree);
        }

        $browser->get_tree()->set_line_color( 0, 200, 0 );
        $browser->get_tree()->set_hilite_color( 100, 200, 200 );

        #	my $species_name_map = CXGN::Phylo::Species_name_map->new();
        my @leaves = $browser->get_tree->get_leaves();
        $browser->get_tree()->set_show_standard_species($show_species);
        my $ostring = "";

  #	foreach (@leaves) {
  #			next unless((scalar @search_nodes == 0) or $_->get_label()->get_hilite());
  #			$ostring .= "orthologs of ".$_->get_name() . ":    &nbsp;&nbsp;   ";
  #			my @orthologs = $_->collect_orthologs_of_leaf();
  #			$ostring .= join("; ", @orthologs) . "<br>";
  #		}

        my $ortho_hilite_only = 0;
        if (1) {
            $ostring .= "<table>";
            my $first_cell_text = "Orthologs of&nbsp&nbsp";
            @leaves = sort { $a->get_name() cmp $b->get_name() } @leaves;
            foreach (@leaves) {

 # next line to only show orthologs of highlighted nodes, if any are highlighted
                next
                  unless ( !$ortho_hilite_only
                    or ( scalar @search_nodes == 0 )
                    or $_->get_label()->get_hilite() );
                my $the_name = $_->get_name();
                if ( $the_name =~ /([^{|]+)/ ) {
                    $the_name = $1;
                }    # i.e. trim off everything from the first pipe or { on
                $ostring .=
                    "<tr><td>$first_cell_text</td><td>"
                  . $the_name
                  . ":&nbsp&nbsp&nbsp&nbsp</td> ";
                $first_cell_text = "";
                my @orthologs = sort( $_->collect_orthologs_of_leaf() );
                $ostring .= "<td>" . join( ",&nbsp ", @orthologs ) . "</td>";
                $ostring .= "</tr>";
            }
            $ostring .= "</table>";
        }
        else {       # matrix format

            #		for printing ortholog pair information as a matrix
            $ostring .= "<table>";
            my $omh           = $browser->get_tree()->ortho_matrix_hash();
            my @sorted_leaves = sort keys %$omh;

            #$ostring .= "<td width=\"20%\"></td>";
            #foreach (@sorted_leaves) {
            #$ostring .=  "<td>$_</td>";
            #}
            my $i = 0;
            foreach (@sorted_leaves) {
                my $ortho_array_ref = $omh->{$_};

                #	my $str = sprintf("%5i %50s   ", $i, $_);
                $ostring .= "<tr>";

                #	$ostring .= "<td>$i</td>";
                #	$ostring .= "<td width=\"3%\">$_</td>";
                $ostring .= "<td>$_</td>";

                #	$str =~ s/ /\&nbsp/g;
                #	$ostring .= $str;
                foreach (@$ortho_array_ref) {

       #	$ostring .= sprintf(" %1i", $_); #join(" ", @$ortho_array_ref), "<br>";
                    $ostring .= "<td>$_</td>";
                }
                $ostring .= "</tr>";
                $i++;
            }
            $ostring .= "</table>";
        }

        $browser->get_tree()->show_newick_attribute("speciation");    # needed?
        $browser->get_tree()->show_newick_attribute("species");       # needed?
        my $newick_string = $browser->get_tree()->generate_newick();

        print info_section_html(
            title         => 'Ortholog pairs',
            contents      => $ostring,
            collapsible   => 'true',
            empty_message => ""
        );

    }

    if ( $hilite && ( $height > ( $DEFAULT_HEIGHT + 200 ) ) ) {
        $node_control =~ s/href="(.*?)"/href="$1#bottom"/ig;
        print $node_control;
    }

    $page->footer();

    #print STDERR "Done with the page.\n";
}

sub show_form {
    my $page = shift;

    #print STDERR "Debug marker 701\n";

    $page->header();

    print page_title_html("Tree browser");

    my $submit_preset = "";
    my $align_preset  = "";
    if ( -f $align_temp_show ) {
        open my $af, '<', $align_temp_show or die "$! opening '$align_temp_show'";
        while (<$af>) {
            $align_preset .= $_;
        }
    }

    my $newick_preset = "";
    if ( -f $newick_temp_show ) {
        open my $nf, '<', $newick_temp_show or die "$! opening '$newick_temp_show'";
        while (<$nf>) {
            $newick_preset .= $_;
        }
    }

    my $title_preset = "";
    #print STDERR "Debug marker 702\n";

    if ($example_show) {
        $title_preset = "Arabidopsis Family Example";
        if( open my $af, '<', "$HTML_ROOT_PATH/cgi-bin/tools/tree_browser/data/example_align_preset.txt" ) {
            while (<$af>) {
                $align_preset .= $_;
            }
            $submit_preset ||= "View Tree and Alignment";
        }
        else { $align_preset = "Example File Not Found" }
        if( open my $nf, '<', "$HTML_ROOT_PATH/cgi-bin/tools/tree_browser/data/example_newick_preset.txt" ) {
            while (<$nf>) {
                $newick_preset .= $_;
            }
        }
        else {
            $newick_preset = "Example File Not Found";
        }
    }
    print table({ style => 'margin: 0 auto'},
                Tr( td( 'Enter a tree in',
                        a( {href=> 'http://evolution.genetics.washington.edu/phylip/newicktree.html'},
                           'newick',
                         ),
                        a( {href=> '?example_show=1'},
                           'Show Me an Example',
                         ),
                      ),
                  ),
                Tr(
                   td( start_form(),
                       hidden( 'action', 'display'),
                       dl( 
                          dt('Title'),
                          dd(textfield( -id   => 'title_box',
                                        -size => 30,
                                        -name => 'title',
                                        -value => $title_preset,
                                      ),
                            ),
                          dt('Newick'),
                          dd(textarea( -name => 'tree_string',
                                       -id   => 'tree_string_box',
                                       -rows => 4,
                                       -columns => 80,
                                       -value => $newick_preset,
                                     ),
                            ),
                          dt('Optional Alignment'),
                          dd( {class => 'boxbgcolor5'},
                              div( 'Type:',
                                   radio_group(  -name => 'align_type',
                                                 -labels => { nt => 'Nucleotide',
                                                              pep => 'Peptide',
                                                            },
                                                 -values => [qw[ nt pep ]],
                                                 -default => 'pep',
                                              ),
                                 ),
                              div( 'Format:',
                                   radio_group( -name => 'format',
                                                -values => [qw[clustalw fasta]],
                                                -labels => { clustalw => 'CLUSTAL alignment',
                                                             fasta => 'Fasta (Gapped)',
                                                           },
                                                -default => 'fasta',
                                              ),
                                 ),
                              div( 'Input Sequences:' ),
                              div( textarea(
                                            -onBlur => <<EOJS,
document.getElementById('tree_submit').value = document.getElementById('align_seq_data_box').value ? 'View Tree and Alignment' : 'View Tree';
return false;
EOJS
                                            -name    => 'align_seq_data',
                                            -id      => 'align_seq_data_box',
                                            -rows    => 6,
                                            -columns => 76,
                                            -value   => $align_preset,
                                           ),
                                 ),
                            ),
                         ),
                       CGI::reset( -value => 'Clear form',
                                   -onClick => <<EOJS,
document.getElementById('align_seq_data_box').value =
document.getElementById('tree_string_box').value =
document.getElementById('title_box').value = '';
return false;
EOJS
                                 ),
                       submit(
                              -id => 'tree_submit',
                              -value => $submit_preset || "View Tree",
                             ),
                       end_form(),
                     ),
                  ),
#                 Tr(
#                    td( {colspan => 2},
#                        span({ style=> 'font-weight: bold'},
#                             'Upload nexus file',
#                            ),
#                        '*currently supports trees only',
#                        start_form( -enctype => 'multiport/form-data' ),
#                        filefield( -name => 'upload_file', -value => 'Upload Nexus file' ),
#                        hidden('action','upload'),
#                        submit('Upload Nexus file'),
#                        end_form(),

#                        start_form(),
#                        span({style=> 'font-weight: bold'},'View simplified phylogenetic tree of plants'),
#                        submit(),
#                        hidden('preset','plants'),
#                        end_form(),
#                      ),
#                   ),
               );

    $page->footer();
}

#Alignment-Related Subroutines ###############################################

sub fasta_check {
    my ( $file, $page, $n ) = @_;
    my ($filename) = $file =~ /([^\/]+)$/;
    my $count      = 0;
    my $maxlen     = 0;
    my $instream = Bio::SeqIO->new( -file => $file, -format => 'fasta' );
    my $entry = $instream->next_seq();
    unless ( $entry && $entry->id && $entry->seq ) {
        input_err_page( $page, "FASTA needs IDs and Sequences [$filename]" );
    }
    $count++;
    $maxlen = length( $entry->seq );
    $entry  = $instream->next_seq;

    #	print STDERR "Checking sequence number $count in $file...\n";
    unless ( $entry && $entry->id && $entry->seq ) {
        input_err_page( $page, "FASTA must have at least two valid sequences" );
    }
    $count++;
    $maxlen = length( $entry->seq ) if length( $entry->seq ) > $maxlen;
    while ( $entry = $instream->next_seq() ) {
        unless ( $entry->id && $entry->seq ) {
            input_err_page( $page, "Every entry must have ID AND sequence" );
        }
        $maxlen = length( $entry->seq ) if length( $entry->seq ) > $maxlen;
        $count++;
    }
    return ( $count, $maxlen );
}

sub convert_clustal_fasta {
    my $clustal_file = shift;
    my $fasta_file   = shift;

    my $in = Bio::AlignIO->new(
        -file   => $clustal_file,
        -format => 'clustalw'
    );
    my $cl_out = Bio::AlignIO->new(
        -file   => ">$fasta_file",
        -format => 'fasta',
    );

    while ( my $aln = $in->next_aln() ) {
        $aln->set_displayname_flat();
        $cl_out->write_aln($aln);
    }
    $cl_out->close();
    $in->close();
}

#############

# spaces-> &nbsp; and /n-><br>
sub htmlize {
    my $string = shift;
    $string =~ s/ /&nbsp;/g;
    $string =~ s/\n/<br>/g;
    return $string;
}

# \n -> new row
# >=2 whitespace characters -> go to next cell to right
sub html_tableize {
    my $instring = shift;
    $instring =~ s/^\s*//;    # remove leading whitespace.
    $instring =~ s/\s*$//;    # remove trailing whitespace
    my $outstring = "<table width=\"100%\" border=1><tr><td>";
    $outstring .= $instring;
    $outstring =~ s/\n/<\/td><\/tr><tr><td>/g;    # /n -> new row
    $outstring =~
      s/\s{2,}/<\/td><td>/g;    # >= 2 of any whitespace char -> new cell
    $outstring .= "<\/td><\/tr><\/table>";

    # print $outstring;
    return $outstring;
}

sub input_err_page {
    my $input_err_page = shift;
    my $err_message    = shift;
    $input_err_page->header();
    print page_title_html("Combined Tree/Alignment Error");
    print "$err_message<br><br><a href=\"index.pl\">Start over</a><br>";
    $input_err_page->footer();
    exit;
}

## this one will have col headings ortholog group, leaf names, leaf species, agrees with species tree (distance)
#sub oglist_string{
#	my @oglist = @_;
#	my $spacer = "  ";
#	my $oglstring .= "Ortholog group" . $spacer . "Names" . $spacer . "Species" . $spacer . "Matches species tree?" . $spacer . "Distance" . "\n";
#	my $ognumber = 1;
#my @ogletters = qw(a b c d e f g h i j k l m n o p q r s t u v w x y z);

#	if (scalar @oglist == 0) {
#		$oglstring .= "No ortholog groups found.\n";
#	} else {
#		foreach my $o (@oglist) {
#			if ($o->get_tree()->get_leaf_count()>1) {
#				$oglstring .= $ognumber . $spacer;
#				my $name_string =  join(", ",(map ($_->get_name(), $o->get_tree()->get_leaf_list()))) . $spacer;
#			#	print("name_string: ", $name_string, "\n");
#				$oglstring .= join(", ",(map ($_->get_name(), $o->get_tree()->get_leaf_list()))) . $spacer;

#				$oglstring .= join(", ",(map ($_->get_species(), $o->get_tree()->get_leaf_list()))) . $spacer;
#				if (defined $o->get_conforms_to_species_tree()) {
#					if ($o->get_conforms_to_species_tree()) {
#						$oglstring .= "Yes" . $spacer . "0" . "\n";
#					} else {
#						$oglstring .= "No" . $spacer .  $o->get_distance_to_species_tree() . "\n";
#					}
#				} else {
#					$oglstring .= "[no species tree]" . $spacer .  "[no species tree]" . "\n";
#				}
#			} else {									# Isolated leaf
#				$oglstring .= "Isolated leaf" . $spacer . "Isolated leaf" . "\n";
#			}

#			if (!$o->get_conforms_to_species_tree()) {
#				my @cnins = $o->get_conforming_node_implicit_names();
#				my $cognumber = 0;
#				foreach my $s (@cnins) {
#					$oglstring .= $ognumber.$ogletters[$cognumber].$spacer;
#					my $qRFd = $o->get_conforming_node($s)->get_attribute("qRF_distance");
#					$s =~ s/\t/, /g;				# tab ->, as glue between names
#					$oglstring .= $s.$spacer;
#					$oglstring .= ".".$spacer.".".$spacer. $qRFd.$spacer."\n";
#					$cognumber++;
#				}
#			}
#			$ognumber++;
#		}
#	}
#	return $oglstring;
#}

# this one will have col headings ortholog group, leaf names, leaf species, agrees with species tree (distance)
sub oglist_html_table {
    my $browser     = shift;
    my $tree        = $browser->get_tree();
    my @oglist      = @_;
    my $cell_spacer = "</td><td>";
    my $row_end     = "</td></tr>";
    my $oglstring   = "<table width=\"100%\" border=\"0\" ><tr><td>";
    $oglstring .=
        "Ortholog group"
      . $cell_spacer . "Names"
      . $cell_spacer
      . "Species"
      . $cell_spacer
      . "Matches species tree?"
      . $cell_spacer
      . "Distance"
      . $row_end;

    my $ognumber = 1;
    if ( scalar @oglist == 0 ) {
        $oglstring .= "<tr><td>No ortholog groups found.$row_end";
    }
    else {
        foreach my $o (@oglist) {

#	print STDOUT "ZZZ tree copy root qrfd: [", $o->get_tree()->get_root()->get_attribute("qRF_distance"), "] [", $o->get_tree()->get_root()->get_attribute("subtree_leaves_match"), "]<br>\n";

            $o->get_ortholog_tree()->get_root()->recursive_implicit_species();
            my $og_row_string =
              $o->table_row_string();    # this can have multiple rows...
                                         #Use a non-greedy quantifier here!!
            while ( $og_row_string =~ m/<tr><td>([a-z]*)_(.*?)$cell_spacer/ ) {
                $og_row_string =~
s{<tr><td([a-z]*)_(.*?)$cell_spacer}{<tr><td>$ognumber$1$cell_spacer$2$cell_spacer}
                  ;                      #just 1 subst.

                my $implname = $2;       #this is ", " separated
                $implname =~ s/,\s*/\t/g;    # make it space separated
                my $ogletter = $1;
                my ( $key, $node ) =
                  $tree->node_from_implicit_name_string($implname);

                my @ops  = $browser->get_node_operations();
                my $link = "?"
                  . hash2param(
                    \%PARAM,
                    {
                        hilite => $key,
                        ops    => ( join "+", @ops )
                    }
                  );
                my $lnkstr = "<a href=\"$link\">";
                $og_row_string =~
s{<tr><td>($ognumber$ogletter)?$cell_spacer}{<tr><td>$lnkstr$1$cell_spacer}
                  ;    #put in the links

            }
            $oglstring .= $og_row_string;
            $ognumber++;
        }
    }
    $oglstring .= "</table>";
    return $oglstring;
}
