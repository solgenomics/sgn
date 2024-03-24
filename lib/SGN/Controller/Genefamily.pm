
package SGN::Controller::Genefamily;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub genefamily_index :Path('/tools/genefamily') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/tools/genefamily/index.mas';
}


sub search : Path('/tools/genefamily/search') Args(0) {
    my $self = shift;
    my $c = shift;

    if ($c->user()) { 
	if (grep(/curator|genefamily_editor/, $c->user->get_object()->get_roles() )) { 
	    
	    $c->stash->{genefamily_id} = $c->req->param("genefamily_id") || '';
	    $c->stash->{build} = $c->req->param("build") || '';
	    $c->stash->{member_id} = $c->req->param("member_id") || '';
	    $c->stash->{action} = $c->req->param("action") || '';
	    
	    $c->stash->{template} = '/tools/genefamily/search.mas';
	}
	else {
	    $c->stash->{message} = "You do not have the necessary privileges to access this page.";
	    $c->stash->{template} = "/generic_message.mas";
	}

    }
    else {
	$c->stash->{message} = "You need to be logged in to access this page.";
	$c->stash->{template} = "/generic_message.mas";
    }
	
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

    if (!$family) {
	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message} = 'Need a family to display!';
	return;
    }

    $c->stash->{genefamily_id} = $family;
    
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
