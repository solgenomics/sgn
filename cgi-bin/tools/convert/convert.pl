#!/usr/bin/perl
# convert.pl: converts TIGR TC (tentative consensus) numbers to SGN unigene ID numbers and vice versa
#
# Evan Herbst
# 9 / 10 / 04
#
# parameters: file, id_type, debug, show_current_tc, show_sgn_build_no{_tc, _sgn-u}, show_sgn_no_mbrs{_tc, _sgn-u}
# legal values for file are any legal filename
# legal values for id_type are "tigrtc" and "sgn-u"; this is the type that the user submitted
# legal values for debug are 0 or 1
# legal values for the "show_" options are "off" and "on"
#
# returns an array of array references, each of which contains a TC number, a "current TC number" which has the value "n/a" when appropriate,
# and an SGN unigene ID, in that order when TC numbers are submitted and in the opposite order when SGN-U IDs are submitted
#
# the user interface for this script is in input.pl

use strict;

#retrieve the list of params to this page and their values in formatted form (e.g."x=1&y=2") from an Apache Request obj; can't access them directly
#to print something, use $page->debug(string) on an SGN page object
my $conv_obj = convert->new();
$conv_obj->get_params();
$conv_obj->process_input();

#if input not OK, write an error message; otherwise call mySQL and display HTML

############################################################################################################
package convert;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Page;
use HTML::Entities;

#set up class fields
#no parameters
sub new {
    my $classname = shift;    #the name of this object type
    die 'too many args to new' if shift;
    my $obj = {
               page => CXGN::Page->new('TIGR TC Conversion','many people'),
               db_handle => CXGN::DB::Connection->new(),
              };
    return bless $obj, $classname;
}

#retrieve parameters to this script from an Apache::Request object
sub get_params {
    my $self = shift(@_);

#extract parameter values from the Request 
#	$self->{debug} = $self->{request_obj}->param("debug"); #if commented, ignore debug setting sent from input.pl
    my $page = $self->{page};

    my @arglist = qw( id_type
                      show_current_tc
                      show_sgn_build_info_tc
                      show_common_mbrs_tc
                      show_sgn_build_info_sgn_u
                      show_common_mbrs_sgn_u
                      file
                    );

    @{$self}{@arglist} = $page->get_arguments(@arglist);

    my ($rawinput) = $page->get_arguments('ids');
    #put in an ending newline if necessary
    $rawinput .= "\n" unless $rawinput =~ /\n$/;

    $self->debug( "id_type = "
          . $self->{id_type}
          . ", debug = "
          . $self->{debug}
          . ", file = "
          . $self->{file} );

#get an upload object to upload a file -- this and filling in the textbox are not mutually exclusive
    my $upload = $page->get_upload();
    if ( defined $upload ) {    #if there's a filename in the text box
        $self->debug( "uploading file: " . $self->{file} );
        my $fh = $upload->fh;
        $rawinput .= $_ while <$fh>;
    }

    #put in an ending newline if necessary
    $rawinput .= "\n" unless $rawinput =~ /\n$/;

    # encode_entities to defend against xss attacks, since we
    # sometimes print these ids
    $self->{rawInput} = encode_entities( $rawinput );
    $self->debug( "uploaded ids: $self->{rawInput}\n" );
}

#one parameter: a string to print if $self->{debug} is 1
sub debug {
    my $self = shift(@_);
    if ( $self->{debug} ) {
        $self->{content} .= "<p>" . shift(@_) . "</p>\n";
    }
}

#one parameter: text to be written to $self->{content}, which is used as HTML
sub write {
    my $self    = shift(@_);
    my $message = shift(@_);
    $self->{content} .= $message;
}

#check the input for errors; print an error message if necessary; otherwise display HTML output
sub process_input {
    my $self = shift(@_);
    if ( $self->input_ok() ) {
        $self->convert_ids();
        $self->write_output();
    }
    else    #{error} contains a descriptive string
    {
        $self->{page}->header();

        #run through possible errors
        if ( $self->{error} eq "no input" ) {
            $self->write(
"<p><b>No IDs were submitted.</b> Please enter IDs into the text field before submitting.</p>"
            );
        }
        elsif ( $self->{error} =~ m/unknown\s*input\s*(\S*)\s*(\S*)/ ) {
            $self->write(
"<p><b>Cannot interpret The ID \"$1\".</b></p>"
            );
        }
        print $self->{content};
        $self->{page}->footer();
    }
}

#make sure there are no problems with the user input; if there are, set an error flag
#no parameters
#return 1 for OK, 0 for not OK
sub input_ok {
    my $self = shift(@_);
    @{ $self->{ids} } =
      split( /[,;\s]+/, $self->{rawInput} )
      ;    #get the IDs in array form rather than string form
    $self->debug( "ids: " . join( ', ', @{ $self->{ids} } ) );
    if ( scalar( @{ $self->{ids} } ) < 1 )    #no IDs uploaded
    {
        $self->{error} = "no input";
        return 0;
    }
    else {

        #test all input for incorrect format
        if ( $self->{id_type} eq "tigrtc" ) {
            foreach my $id ( @{ $self->{ids} } ) {
                if ( $id !~
m/^\s*(tc|t|c|tc-|tc_|tigr-tc|tigr|tigrtc|tigr_tc|)\d{1,10}\s*$/i
                  )    #up to 10 digits, for scalability :)
                {
                    $self->{error} = "unknown input $id TIGRTC";
                    return 0;
                }
            }
        }
        else           #id_type = "sgn-u"
        {
            foreach my $id ( @{ $self->{ids} } ) {
                if ( $id !~ m/^\s*(sgn|sgn-u|u|sgn_u|s|)\d{1,10}\s*$/i
                  )    #up to 10 digits, for scalability :)
                {
                    $self->{error} = "unknown input $id SGN-U";
                    return 0;
                }
            }
        }
        return 1;
    }
}

#given an input ID type in $self->{id_type} and an ID list in $self->{ids}, submit a MySQL query, collect the output and stick it in $self->{sql_output}
#(need to create and remove a temporary table for our ID list to be able to do this)
#no parameters
sub convert_ids {
    my $self = shift(@_);

#create a temporary table for our list of IDs
#	my $temp_table_q = $self->{db_handle}->do("create temporary table tmp_data.submitted_ids (submitted_id int(10) primary key)");
#add entries to the table for our submitted IDs
#	my $temp_insert_q = $self->{db_handle}->prepare("insert into tmp_data.submitted_ids (submitted_id) values (?)");
#	$self->debug("ids: " . join(', ', @{$self->{ids}}));
#	foreach my $id (@{$self->{ids}})
#	{
#		$self->debug("current id is $id");
#		$id =~ s/^(\D*)(\d+)$/$2/; #remove non-digits from the beginning of the id
#		$self->debug("current id is now $id");
#	}
#	my @stati; #statement statuses for the next line to return
#	$self->debug("selfids: " . join(", ", @{$self->{ids}}));
#	my $numOK = $temp_insert_q->execute_array({ArrayTupleStatus => \@stati}, $self->{ids});
#	$self->debug("$numOK ids were added to the temp table");
#	$self->debug("statuses are " . join(',', @stati));
#$self->{db_handle}->commit() or $self->{page}->error_page($DBI::errstr); #commit changes to the (temporary) table

    my $ids_relation = sprintf "(%s)", join ") UNION (",
      map { $_ =~ s/^(\D*)(\d+)$/SELECT $2 AS submitted_id/; $_; }
      @{ $self->{ids} };

    #	print STDERR "ids_relation: $ids_relation\n";

    #convert within mysql
    my $conversion_q;
    my $queryTime = time();
    if ( $self->{id_type} eq "tigrtc" )    #TC #s to SGN-Us
    {
        $conversion_q = $self->{db_handle}->prepare( "
			SELECT ids.submitted_id, tct.current_tc_id, COUNT (est.est_id), um.unigene_id, groups.comment, ub.build_date
			FROM ($ids_relation) as ids
			LEFT JOIN tigrtc_tracking AS tct ON (tct.tc_id = ids.submitted_id OR tct.current_tc_id = ids.submitted_id) 
			LEFT JOIN tigrtc_membership AS tcm ON (tct.current_tc_id = tcm.tc_id) 
			LEFT JOIN est ON (tcm.read_id = est.read_id) 
			LEFT JOIN unigene_member AS um ON (um.est_id = est.est_id) 
			LEFT JOIN unigene ON (um.unigene_id = unigene.unigene_id) 
			LEFT JOIN unigene_build AS ub ON (unigene.unigene_build_id = ub.unigene_build_id) 
			LEFT JOIN groups ON (ub.organism_group_id = groups.group_id) 
			WHERE ub.status = 'C'
			GROUP BY ids.submitted_id, um.unigene_id, groups.comment, ub.build_date, tct.current_tc_id"
        ) or $self->{page}->error_page($DBI::errstr);
        $self->debug("prepared");
    }
    else    #SGN-Us to TC #s
    {
        $conversion_q = $self->{db_handle}->prepare( "
			select ids.submitted_id, groups.comment, ub.build_date, tcm.tc_id, count(est.est_id) 
			from ($ids_relation) as ids
			left join unigene on (ids.submitted_id = unigene.unigene_id)
			left join unigene_member as um on (unigene.unigene_id = um.unigene_id) 
			left join est on (um.est_id = est.est_id) 
			left join tigrtc_membership as tcm on (est.read_id = tcm.read_id) 
			left join unigene_build as ub on (unigene.unigene_build_id = ub.unigene_build_id) 
			left join groups on (ub.organism_group_id = groups.group_id) 
			where tcm.tc_id is not null 
			group by ids.submitted_id, tcm.tc_id, groups.comment, ub.build_date" )
          or $self->{page}->error_page($DBI::errstr);
        $self->debug("prepared");
    }
    $conversion_q->execute() or $self->{page}->error_page($DBI::errstr);
    $self->debug("executed");
    $queryTime = time() - $queryTime;

    #fill the sql_output field
    if ( $self->{id_type} eq "tigrtc" ) {
        while ( my $rowref = $conversion_q->fetchrow_arrayref() ) {
            $self->debug( "row: " . join( ", ", @{$rowref} ) );
            $rowref->[3] =
                "<a href=\"/search/unigene.pl?unigene_id="
              . $rowref->[3] . "\">"
              . $rowref->[3] . "</a>";
            push( @{ $self->{sql_output} }, [ @{$rowref} ] );
        }
    }
    else {
        while ( my $rowref = $conversion_q->fetchrow_arrayref() ) {
            $self->debug( "row: " . join( ", ", @{$rowref} ) );
            $rowref->[3] =
              "<a href=\"http://www.tigr.org/tigr-scripts/tgi/tc_report.pl?tc="
              . $rowref->[3]
              . "&amp;species=tomato\">"
              . $rowref->[3] . "</a>";
            push( @{ $self->{sql_output} }, [ @{$rowref} ] );
        }
    }

    #get a list of identifiers not matched
    my $unmatched_ids_q;
    if ( $self->{id_type} eq "tigrtc" )    #TC #s to SGN-Us
    {
        $unmatched_ids_q = $self->{db_handle}->prepare( "
			select ids.submitted_id
			from ($ids_relation) as ids
			left join tigrtc_tracking as tct on (ids.submitted_id = tct.tc_id or ids.submitted_id = tct.current_tc_id)
			where tct.tc_id is null or tct.current_tc_id is null
			group by ids.submitted_id" )
          or $self->{page}->error_page($DBI::errstr);
        $self->debug("unmatched query prepared");
    }
    else                                   #SGN-Us to TC #s
    {
        $unmatched_ids_q = $self->{db_handle}->prepare( "
			select ids.submitted_id
			from ($ids_relation) as ids
			left join unigene on (ids.submitted_id = unigene.unigene_id)
			where unigene.unigene_id is null
			group by ids.submitted_id" )
          or $self->{page}->error_page($DBI::errstr);
        $self->debug("unmatched query prepared");
    }
    $unmatched_ids_q->execute() or $self->{page}->($DBI::errstr);
    $self->debug("unmatched query executed");
    while ( my $rowref = $unmatched_ids_q->fetchrow_arrayref() ) {
        $self->debug( "unmatched: " . $rowref->[0] );
        push( @{ $self->{unmatched_ids} }, $rowref->[0] );
    }

#this is not a shared db-handle; can disconnect from it
#	$self->{db_handle}->do('drop table tmp_data.submitted_ids'); #mysql will NOT autodrop the temp table, since we are now using Apache::DBI behind the scenes to pool connections.
#	$self->{db_handle}->disconnect() or $self->{page}->error_page($DBI::errstr); #mysql will autodrop the temporary table for us

    #print a bit of a summary to the output string
    $self->write( "
<h4>Bulk download summary</h4>
<p>The query you submitted contained " . scalar( @{ $self->{ids} } ) . " lines.
<br />Your query resulted in "
          . ($self->{sql_output} ? scalar @{$self->{sql_output}} : 0)
          . " lines being read from the database in $queryTime seconds.
</p>
	" );
}

#output the raw data in our sql_output field as HTML and make it look nice
#no parameters
sub write_output {
    my $self = shift(@_);

    #add formatted SQL output to content

    $self->write(
        "<b>Notes:</b>
					  <p>The mapping between TIGR TC identifiers and SGN-U identifiers is not unique in either direction.</p>
					  <p>Identifiers not listed in the table below and not listed as not found do exist but don't map to any current "
          . ( $self->{id_type} eq "tigrtc" ? "SGN-U" : "TIGR TC" ) . " IDs.</p>"
    );

    my $column_info;
    if ( $self->{id_type} eq "tigrtc" ) {
        $column_info = [
            [ "TIGR TC",                  1 ],
            [ "Current TC",               $self->{show_current_tc} ],
            [ "Common Members",           $self->{show_common_mbrs_tc} ],
            [ "SGN Unigene ID (Current)", 1 ],
            [ "Build Series",             $self->{show_sgn_build_info_tc} ],
            [ "Build Date",               $self->{show_sgn_build_info_tc} ]
        ];
    }
    else {
        $column_info = [
            [ "SGN Unigene ID",    1 ],
            [ "Build Series",      $self->{show_sgn_build_info_sgn_u} ],
            [ "Build Date",        $self->{show_sgn_build_info_sgn_u} ],
            [ "TIGR TC (Current)", 1 ],
            [ "Common Members",    $self->{show_common_mbrs_sgn_u} ]
        ];
    }
    $self->write( "
	<center>
<table border=\"0\" cellspacing=\"5\" cellpadding=\"0\">
	<tr>
	" );
    for ( my $i = 0 ; $i < scalar( @{$column_info} ) ; $i++ ) {
        if ( $column_info->[$i]->[1] ) {
            $self->write( "<td align=\"center\" width=\"120\"><b>"
                  . $column_info->[$i]->[0]
                  . "</b></td>" );
        }
    }
    $self->write( "
	</tr>
	<tr>
		<td colspan=\"" . scalar( @{$column_info} ) . "\"><hr /></td>
	</tr>
	" );
    foreach my $row ( @{ $self->{sql_output} } ) {
        $self->write("<tr>");
        for ( my $i = 0 ; $i < scalar( @{$column_info} ) ; $i++ ) {
            if ( $column_info->[$i]->[1] ) {
                $self->write( "<td align=\"center\">" . $row->[$i] . "</td>" );
            }
        }
        $self->write("</tr>");
    }
    $self->write("</table></center>");

    if ( defined( @{ $self->{unmatched_ids} } ) ) {

        #output a list of IDs not found in the database
        $self->write("<p>The following IDs were not found:</p><p>");
        foreach my $um ( @{ $self->{unmatched_ids} } ) {
            $self->write( $um . "<br />" );
        }
        $self->write("</p>");
    }

    #write the content field to the document
    $self->{page}->header();
    print $self->{content};
    $self->{page}->footer();
}
