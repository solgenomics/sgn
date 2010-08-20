#!/usr/bin/perl

use strict;
use warnings;

use CXGN::Chado::Cvterm;
use CXGN::Scrap::AjaxPage;
use XML::Twig;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
print $doc->header();

my ( $cv_accession, $action, $indent ) = $doc->get_encoded_arguments("cv_accession", "action", "indent");

my $dbh = CXGN::DB::Connection->new();
$cv_accession =~ tr/a-z/A-Z/;

# Browser Searching
if($action eq "specific") {
    my $cv_term = CXGN::Chado::Cvterm->new_with_accession( $dbh, $cv_accession );
    my $obsolete = "false";
    if( $cv_term->get_cvterm_id() ne "" && $cv_term->term_is_obsolete() eq "true" ) {
	$obsolete = "true";
	print "obsolete";
    }

    if( $cv_term->get_cvterm_id() ne "" && $obsolete ne "true" ) {
	# Populate root list
	my @roots_list = ();
	my @roots = CXGN::Chado::Cvterm::get_roots($dbh, $cv_term->get_db_name() );
	foreach my $new_root ( @roots ) { 
	    push( @roots_list, $new_root );
	}
	my $rootNumber = scalar( @roots_list );
	
	# Paths will be stored as an array of arrays
	my @paths = ();

	# Explicitly initialize the first array, the rest will be dynamic
	my @init = ();
	push( @init, [$cv_term, undef] );
	unshift( @paths, \@init );

	# Monitor variables
	my $complete = "false";
	# Will become true if and only if every path traces back to a root
	my $doneCounter = 0;
	# Monitors how many paths are done -- when all are done, complete becomes true

	# If searching for a root, the path is already done
        FINDIFROOT: for( my $i = 0; $i < scalar( @roots_list ); $i++ ) {
	    if( $init[0]->[0]->get_accession() eq $roots_list[$i]->get_accession() ) {
		unshift( @init, "done" );
		$paths[0] = \@init;
		$doneCounter++;
		$complete = "true";
		last FINDIFROOT;
	    }
	}

	# Find paths
	while( $complete ne "true" ) {
	    # Identify latest term in each path
	    my $pathNumber = scalar( @paths );
	    for( my $i = 0; $i < $pathNumber; $i++ ) {
		my $pathArrayRef = $paths[$i];
		my @workingPath = @$pathArrayRef;

		my $nextTerm = "done";
		if( ref( $workingPath[0] ) eq "ARRAY" ) {
		    $nextTerm = $workingPath[0]->[0];
		}

		# Read only paths that are not done, this saves time
		if( $nextTerm ne "done" ) {
		    my @parents = $nextTerm->get_parents();
		    my $parentNumber = scalar( @parents );
		    
		    if( $parentNumber > 1 ) {
			# Take out original path, then push copies of original path with new parents into paths list
			my $index = $i;
			my $originalPath = splice( @paths, $index, 1 );
			
		        ROOTCHECKER: for( my $j = 0; $j < $parentNumber; $j++ ) {
			    my @nextPath = @$originalPath;
			    
			    unshift( @nextPath, $parents[$j] );
			    for( my $k = 0; $k < scalar( @roots_list ); $k++ ) {
				if( $nextPath[0]->[0]->get_accession() eq $roots_list[$k]->get_accession() ) {
				    $nextPath[0] = [ $roots_list[$k], undef ];
				    unshift( @nextPath, "done" );
				    push( @paths, \@nextPath );
				    $doneCounter++;
				    last ROOTCHECKER;
				}
			    }
			    push( @paths, \@nextPath );
			}
		    }

		    else {
			# Simple: put the parent in the array and see if it's a root or not
			unshift( @workingPath, $parents[0] );

		        ROOTCHECK: for( my $j = 0; $j < scalar( @roots_list ); $j++ ) {
			    if( $workingPath[0]->[0]->get_accession() eq $roots_list[$j]->get_accession() ) {
				$workingPath[0] = [ $roots_list[$j], undef ];
				unshift( @workingPath, "done" );
				$doneCounter++;
				last ROOTCHECK;
			    }
			}
			$paths[$i] = \@workingPath;
		    }
		}
	    }

	    my $test = scalar( @paths );
	    if( $doneCounter == $test ) {
		$complete = "true";
	    }
	}

	# Generate XML tree
	my $xmlRoot = XML::Twig::Elt->new('specific');
	my $treeRootTag = "term";
	my %termIndentHash = ();

	for( my $i = 0; $i < scalar( @paths ); $i++ ) {
	    my $pathRef = $paths[$i];
	    my @path = @$pathRef;
	    
	    for( my $j = 1; $j < scalar( @path ); $j++ ) {
		my $treeRootContent = $paths[$i]->[$j]->[0]->get_db_name().":".$paths[$i]->[$j]->[0]->get_accession();
		my $fullName = $treeRootContent;
		$treeRootContent .= ' -- '.$paths[$i]->[$j]->[0]->get_cvterm_name();

		my $elementID = $j."--".$fullName;
		
		my $next = XML::Twig::Elt->new( $treeRootTag, $treeRootContent );
		$next->set_att( id => $fullName );
		$next->set_att( divID => $elementID );
		$next->set_att( indent => $j );

		my $childNumber = $paths[$i]->[$j]->[0]->count_children();
		$next->set_att( children => $childNumber );

		if( scalar( $xmlRoot->descendants() ) > 0 ) {
		    my $element = $xmlRoot;
		    while( $element = $element->next_elt( '#ELT' ) ) {
			if( $j > 1 ) {
			    my $previousRootContent = $paths[$i]->[$j-1]->[0]->get_db_name().":";
			    $previousRootContent .= $paths[$i]->[$j-1]->[0]->get_accession();

			    my $text = $element->text;
			    my $startIndex = index( $text, ":" ) + 1;
			    $text = substr( $text, $startIndex - 3, $startIndex + 7 );
			    
			    my $idText = substr( $element->trimmed_text, 0, 10 );
			    my $idIndent = $element->att( 'indent' );

			    if( $text eq $previousRootContent ) {
				my $newElement = "true";

				if( exists $termIndentHash{$idText} ) {
				    if( !grep( $idIndent, @{$termIndentHash{$idText}} ) ) {
					push @{ $termIndentHash{$idText}}, $idIndent;
				    }
				}

				if( $newElement ne "false" ) {
				    if( $next->att( 'indent' ) - $element->att( 'indent' ) == 1 ) {
					eval{$next->paste( 'last_child', $element )};
					$termIndentHash{$idText} = [$idIndent];
				    }
				}
			    }
			}
		    }
		} else {
		    $next->paste( $xmlRoot );
		    $termIndentHash{$next->trimmed_text} = ["1"];
		}
	    }
	}

        # Format and print XML tree
	my $text = $xmlRoot->sprint;

	$text =~ s|>|>\n|g;                    # Put newlines after tag boundaries
	$text =~ s|<|\n<|g;                    # Put newlines before tag boundaries
	$text =~ s|>\n([A-Z])|>$1|g;           # Remove newlines when they come before an accession

	my $newLineIndex = 0;                  # Remove blank lines by removing extra newlines; go through string multiple
	while( $newLineIndex != -1 ) {         # times if necessary
	    $text =~ s|\n\n|\n|g;
	    $newLineIndex = index( $text, "\n\n" );
	}

	$text =~ s|(<term[A-Za-z0-9 _\,\<\>\+\=\/\'\"\:\t-]*)\n(</term>)|$1$2|g;
	      # Condense the final term of each path, and its end tag, onto one line for easy identification

	print $text;
    }
}

# Browser Scanning
else {
    # Assemble term list
    my @term_list = ();
    my $cv_term = undef;
    
    if ($action eq "children") {
	# Get all children of a term
	$cv_term = CXGN::Chado::Cvterm->new_with_accession($dbh, $cv_accession);
	@term_list = $cv_term->get_children();
    }
    
    else { 
	# This gets roots for a specific database
	my @new_roots = CXGN::Chado::Cvterm::get_roots($dbh, $action);
	foreach my $new_root (@new_roots) { 
	    push @term_list, [ $new_root, undef ];
	}
    }

    $indent++;

    # Print out XML
    foreach my $t (@term_list) { 
	my $id = $t->[0]->get_db_name().":".$t->[0]->get_accession();
	my $divID = $indent."--".$id;
	my $childNumber = $t->[0]->count_children();

	my $term = "<term children='$childNumber' divID='$divID' id='$id' indent='$indent'> ";
	$term .= $t->[0]->get_db_name().":".$t->[0]->get_accession(). " -- ".$t->[0]->get_cvterm_name();
	$term .= "</term>";

	print "$term\n";
    }
}

print $doc->footer();
