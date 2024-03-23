
package SGN::Controller::AJAX::Genefamily;

use Moose;
use SGN::Genefamily;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub browse_families_table :Path('/ajax/tools/genefamily/table') Args(0) {
    my $self = shift;
    my $c = shift;

    my $build = $c->req->param("build");

    my $genefamily_dir = $c->config->{genefamily_dir};
    my $genefamily_format = $c->config->{genefamily_format};

    my $gf = SGN::Genefamily->new( { files_dir => $genefamily_dir, genefamily_format => $genefamily_format, build => $build });

    my $data_ref = $gf -> table();
    
    $c->stash->{rest} = { data => $data_ref };

}

sub genefamily_details :Path('/tools/genefamily/details') Args(2) {
    my $self = shift;
    my $c = shift;
    my $build = shift;
    my $family = shift;

    my $gf = SGN::Genefamily->new(
        name      => $family,
        build   => $build,
        files_dir => $c->config()->{genefamily_dir},
	);

    my $seq_data ="";
    my $fasta_data = "";
    my $tree_data = "";
    my $annot_data = "";
    my $exp_data = "";

    my $align_link_disabled = "";
    my $fasta_link_disabled = "";
    my $tree_link_disabled = "";
    my $exp_link_disabled = "";

    my $errors = "";
    my $big_errors = 0;
    eval {
      $seq_data = $gf->get_alignment();
    };
    if ($@) {
      $errors .= "Alignment data not available. ";
      $big_errors++;
      $align_link_disabled="disabled";
    }
    eval {
      $fasta_data = $gf->get_fasta();

    };
    if ($@) {
      $errors .= "Sequence data not available. ";
      $big_errors++;
      $fasta_link_disabled = "disabled";
    }
    eval {
      $c->stash->{tree_data} = $gf->get_tree();
    };
    if ($@) {
      $errors .= "Tree data not available. ";
      $c->stash->{tree_link_disabled} = "disabled"
    }
    eval {
      $c->stash->{annot_data} = $gf->get_annotation();
    };
    if ($@) {
      $errors .= "Annotation data not available. ";
      $c->stash->{annot_data} = "(No annotation data available)";
    }
    eval {
      $errors .= "Expression data not available. ";
      $c->stash->{exp_data} = $gf->get_expression();
    };
    if ($@) {
      $c->stash->{exp_link_disabled} = "disabled";
    }

    if ($big_errors > 0) { 
      $errors = "This family does not seem to exist!\n";
    }

    $c->stash->{template} = '/tools/genefamily/details.mas';

}

1;
