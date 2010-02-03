#!/usr/bin/perl

use strict;
use warnings;

use CXGN::Chado::Cvterm;
use CXGN::Page;

my $page = CXGN::Page->new('SGN Ontology Browser', 'Jessica Reuter');
$page->header( "SGN Ontology Browser", "SGN Ontology Browser" );

load_ontology();

$page->footer();

###############################################################################
##############################  SUBROUTINE  ###################################
####################### Perl Wrapper of JavaScript ############################
###############################################################################

sub load_ontology {
    print "Please scan through the available SGN ontologies to find terms.<br/>";
    print "To search for a specific term, please enter the qualified name (database and accession) below.";
    print " When finished, click \"Get Term\".<br/><br/>";

    print "<i>There may be short delays while tree nodes are being processed or searches are being conducted.";
    print " Please wait (do not click nodes multiple times), and the requested content will load momentarily.";
    print "</i><br/><br/><br/>";

    print <<EOJS;
    <form name="ontologies" onSubmit='return false;'>
	Enter term here: <input type='text' id='termSelect'>
	<input type='button' onclick='specific( "termSelect" )' value='Get Term'/>
	<div id='notice'></div><br/>

	<input type='button' onclick='roots( "GO", this );node( this )' value='+' id='go' style="font-family:mono"/> 
	GO (Gene Ontology)<div id='GO'></div><br/>

	<input type='button' onclick='roots( "PO", this );node( this )' value='+' id='po' style="font-family:mono"/> 
	PO (Plant Ontology)<div id='PO'></div><br/>

	<input type='button' onclick='roots( "SO", this );node( this )' value='+' id='so' style="font-family:mono"/> 
	SO (Sequence Ontology)<div id='SO'></div><br/>

	<input type='button' onclick='roots( "SP", this );node( this )' value='+' id='sp' style="font-family:mono"/> 
	SP (Solanaceae Phenotype Ontology)<div id='SP'></div><br/>
	
	<input type='button' onclick='roots( "PATO", this );node( this )' value='+' id='pato' style="font-family:mono"/> 
	PATO (Phenotype and Trait Ontology)<div id='PATO'></div><br/>
	
    </form>

    <script language="javascript" type="text/javascript">
        // Show the roots of a particular ontology
        function roots( rootType, button ) {
	    var rootRequest;
	    
	    try {
		rootRequest = new XMLHttpRequest();
	    } catch (e) {
		try {
		    rootRequest = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
		    try {
			rootRequest = new ActiveXObject("Microsoft.XMLHTTP");
		    } catch (e) {
			alert("The ontology browser could not run!");
			return false;
		    }
		}
	    }

	    rootRequest.onreadystatechange = function() {
		if(rootRequest.readyState == 4) {
		    var display = document.getElementById( rootType );
		    if( button.value == "\\u2014" ) {
			var text = String(rootRequest.responseText);
			text = addHTML( text, "root" );
			text = makeIndent( text, "root" );
			display.innerHTML = text;
		    } else {
			display.innerHTML = "";
		    }
		}
	    }

	    var queryString = "?cv_accession=GO:0000001&action=" + 
		escape( rootType ) + "&indent=0";
	    // Technically when finding roots, the ID is not important, but a
	    // valid GO ID is included in the query string so argument encoding
	    // works. (the term just happens to be mitochondrion inheritance)

	    rootRequest.open("GET", 
			 "/chado/ontology_browser_ajax.pl" + queryString, 
			 true);
	    rootRequest.send(null); 
	}

        // Show the children of a term
	function children( accession, button, indent, theDiv ) {
	    var childRequest;
	    
	    try {
		childRequest = new XMLHttpRequest();
	    } catch (e) {
		try {
		    childRequest = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
		    try {
			childRequest = new ActiveXObject("Microsoft.XMLHTTP");
		    } catch (e) {
			alert("The ontology browser could not run!");
			return false;
		    }
		}
	    }

	    childRequest.onreadystatechange = function() {
		if(childRequest.readyState == 4) {
		    var display = document.getElementById( theDiv );
		    if( button.value == "\\u2014" ) {
			var text = String(childRequest.responseText);
			text = addHTML( text, "children" );
			text = makeIndent( text, "children" );
			display.innerHTML = text;
		    } else {
			display.innerHTML = "";
		    }
		}
	    }
	    var queryString = "?cv_accession=" + accession + "&action=children" + "&indent=" + indent;

	    childRequest.open("GET", 
			 "/chado/ontology_browser_ajax.pl" + queryString, 
			 true);
	    childRequest.send(null); 
	}

        // Show trace for specific terms
	function specific( accessor ) {
	    var term = document.getElementById( accessor ).value;
	    var database = term.substring( 0, 2 );
	    var specificRequest;
		
	    try {
		specificRequest = new XMLHttpRequest();
	    } catch (e) {
		try {
		    specificRequest = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
		    try {
			specificRequest = new ActiveXObject("Microsoft.XMLHTTP");
		    } catch (e) {
			alert("The ontology browser could not run!");
			return false;
		    }
		}
	    }

	    specificRequest.onreadystatechange = function() {
		if(specificRequest.readyState == 4) {
		    var text = specificRequest.responseText;

		    // If the term exists in the database, show its path
		    if( text.indexOf( "</term>" ) != -1 ) {
			var display = document.getElementById( String(database).toUpperCase() );
			text = text.replace( /\"/g, "'" );
			text = addHTML( text, "specific" );
			text = makeIndent( text, "specific" );
			display.innerHTML = text;
		    }

		    // If an error occurs, the term is obsolete, or it does not exist, notify the user
		    else {
			text = text.replace( /\\n/g, "" );
			if( text.indexOf( "obsolete" ) == -1 ) {
			    if( text.indexOf( "<scrap></scrap>" ) != -1 ) {
				alert( "This term does not exist in the SGN ontologies." );
			    } else {
				alert( "The ontology browser has encountered an unexpected error.\\n" +
				       "Please try your query again." );
				document.getElementById('notice').innerHTML=text;
			    }
			}

			else {
			    alert( "The term you searched for is obsolete.\\n" + 
				   "Please browse the ontology to find a suitable replacement." );
			}
		    }
		}
	    }

	    var queryString = "?cv_accession=" + term + "&action=specific&indent=0";

	    specificRequest.open("GET", 
				 "/chado/ontology_browser_ajax.pl" + queryString, 
				 true);
	    specificRequest.send(null);
     	}

        // Handle expansion and collapse state of buttons while scanning
        function node( button ) {
	    var value = button.value;
	    if( value == "+" ) {
		button.value = "\\u2014";
	    } else {
		button.value = "+";
	    }
	}

        // Add HTML code to the text
	function addHTML( text, htmlType ) {
	    var htmlText = "";

	    // If finding a specific path for an empty div or divs
	    if( htmlType == "specific" ) {
		var pattern = /<term.*/g;
		var resultArray;
		var result;
		var resultHTML;
		var preliminaryHTML = text;

		// Add buttons and initial div tags to the text
		while((resultArray = pattern.exec(text)) != null ) {
		    // For each term, go through its attributes and extract them for use
		    result = resultArray[0];
		   
		    // Get the number of children of the term
		    var childPattern = /children='.*' d/;
		    var childResultArray = childPattern.exec(result);
		    var childResult = childResultArray[0];
		    var child = childResult.substring( childResult.indexOf("'") + 1, childResult.lastIndexOf("'") );

		    // Get the div id related to the term
		    var divPattern = /divID='.*' id/;
		    var divResultArray = divPattern.exec(result);
		    var divResult = divResultArray[0];
		    var div = divResult.substring( divResult.indexOf("'") + 1, divResult.lastIndexOf("'") );

		    // Get the id of the term
		    var idPattern = /id='.*' in/;
		    var idResultArray = idPattern.exec(result);
		    var idResult = idResultArray[0];
		    var id = idResult.substring( idResult.indexOf("'") + 1, idResult.lastIndexOf("'") );

		    // Get the indent level of the term
		    var indentPattern = /indent='.*'/;
		    var indentResultArray = indentPattern.exec(result);
		    var indentResult = indentResultArray[0];
		    var indent = indentResult.substring( indentResult.indexOf("'") + 1, indentResult.lastIndexOf("'") );

		    // Select proper button for the term
		    var properButton;
		    if( child != 0 ) {
			var variables = "'children( " + '"' + id + '"' + ", this, " + indent + ", " + 
			    '"' + div + '"' + " );node( this )'";
			properButton = "<input type='button' " + 
			    "onclick=" + variables + "value='+' style=\'font-family:mono\' /> ";
		    } else {
			properButton = "<input type='button' value='*' " + 
			    "style='font-family:mono' disabled='disabled' /> ";
		    }

		    // Add beginning of div to the term
		    var divStart = "<div id='" + div + "'>";

		    // Construct and add the result to the new HTML text
		    var originalText = preliminaryHTML.substring( preliminaryHTML.indexOf( "<specific>" ),
								  preliminaryHTML.indexOf( "</specific>" ) + 11 ); 
		    resultHTML = preliminaryHTML.replace( result, properButton + result + "<br/>" + divStart );
		    preliminaryHTML = resultHTML;
		}
		htmlText = preliminaryHTML;
		
		// Add end tags that make divs nested
		var tagPattern = /<term.*term><br.*\'>/g;
		var tagResultArray;
		var tagResult;

		while( (tagResultArray = tagPattern.exec(preliminaryHTML)) != null ) {
		    var unchangedTag = tagResultArray[0];
		    tagResult = tagResultArray[0];
		    
		    var internalPattern = /<div id.*>/;
		    var internalResultArray = internalPattern.exec(tagResult);
		    var internalResult = internalResultArray[0];
		    var divNumber = parseInt( internalResult.substring( internalResult.indexOf( "'" ) + 1,
									internalResult.indexOf( "-" ) ) );
		   
		    if( divNumber > 1 ) { 
			for( var i = 1; i < divNumber; i++ ) {
			    tagResult = tagResult + "</div>";
			    if( i == divNumber - 1 ) {
				tagResult = tagResult + "<div/>";
			    }
			}
		    } else {
			tagResult = tagResult + "</div><div/>";
		    }

		    htmlText = htmlText.replace( unchangedTag, tagResult );
		}

		var divEnd = htmlText.lastIndexOf( "</div>" ) + 6;
		var divBegin = htmlText.lastIndexOf( "'><" ) + 2;
		var lastDivString = htmlText.substring( divBegin, divEnd );

		if( divNumber != 1 ) {
		    htmlText = htmlText.replace( lastDivString, "</div>" + lastDivString );
		}
	    }

	    // If browsing with no specific path, HTML is formatted for a flat list in an empty div
	    else {
		var pattern = /<term.*term>/g;
		var resultArray;
		var result;
		var resultHTML;

		while((resultArray = pattern.exec(text)) != null ) {
		    // For each term, go through its attributes and extract them for use
		    result = resultArray[0];

		    // Get the number of children of the term
		    var childPattern = /children='.*' d/;
		    var childResultArray = childPattern.exec(result);
		    var childResult = childResultArray[0];
		    var child = childResult.substring( childResult.indexOf("'") + 1, childResult.lastIndexOf("'") );

		    // Get the div id related to the term
		    var divPattern = /divID='.*' id/;
		    var divResultArray = divPattern.exec(result);
		    var divResult = divResultArray[0];
		    var div = divResult.substring( divResult.indexOf("'") + 1, divResult.lastIndexOf("'") );

		    // Get the id of the term
		    var idPattern = /id='.*' in/;
		    var idResultArray = idPattern.exec(result);
		    var idResult = idResultArray[0];
		    var id = idResult.substring( idResult.indexOf("'") + 1, idResult.lastIndexOf("'") );

		    // Get the indent level of the term
		    var indentPattern = /indent='.*'/;
		    var indentResultArray = indentPattern.exec(result);
		    var indentResult = indentResultArray[0];
		    var indent = indentResult.substring( indentResult.indexOf("'") + 1, indentResult.lastIndexOf("'") );

		    // Select proper button for the term
		    var properButton;
		    if( child != 0 ) {
			var variables = "'children( " + '"' + id + '"' + ", this, " + indent + ", " + 
			    '"' + div + '"'  + " );node( this )'";
			properButton = "<input type='button' " + 
			    "onclick=" + variables + " value='+' style=\'font-family:mono\' /> ";
		    } else {
			properButton = "<input type='button' value='*'" + 
			    " style='font-family:mono' disabled='disabled' /> ";
		    }

		    // Construct div
		    var constructedDiv = "<div id='" + div + "'></div>";
		    
		    // Construct and append the result to the new HTML text
		    resultHTML = properButton + result + "<br/>" + constructedDiv;
		    htmlText = htmlText + resultHTML;
		}
	    }
	    return htmlText;
	}

        // Handle indentation
	function makeIndent( text, queryType ) {
	    var indentPlace = indentPlace = text.indexOf( "indent" ) + 8;
	    var buttonIndex = text.indexOf( "<input" );
	    var textLength = text.length;

	    // If searching for a specific path, indents are dynamic, dependent on each particular term
	    if( queryType == "specific" ) {
		while( indentPlace < textLength ) {
		    var indent = text.substring( indentPlace, text.indexOf( "\'", indentPlace ) );

		    var beforeButton = text.substring( 0, buttonIndex );
		    var afterButton = text.substring( buttonIndex );

		    var indentString = "";
		    for( var counter = 1; counter <= indent; counter++ ) {
			indentString = indentString + "----";
		    }
		    indentString = "<tab style='font-family:mono; color:white'>" + indentString + "</tab>";

		    indent = parseInt( indent );
		    
		    text = beforeButton + indentString + afterButton;
		    buttonIndex = text.indexOf( "<input", buttonIndex + indentString.length + 1 );
		    indentPlace = text.indexOf( "indent='", buttonIndex ) + 8;
		    if( buttonIndex == -1 ) {
			break;
		    }

		    textLength = text.length;
		}
		return text;
	    }

	    // If browsing with no specific path, indent is static in a flat list
	    else {
		var indent = text.substring( indentPlace, text.indexOf( "\'", indentPlace ) );

		var indentString = "";
		for( var counter = 1; counter <= indent; counter++ ) {
		    indentString = indentString + "----";
		}
		indentString = "<tab style='font-family:mono; color:white'>" + indentString + "</tab>";
		indentString = indentString + "<input";

		return text.replace( /\<input/g, indentString );
	    }
	}
    </script>
EOJS
}
