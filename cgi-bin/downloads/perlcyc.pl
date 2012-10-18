
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | info_section_html |;
my $p = CXGN::Page->new();

$p->header("PerlCyc.pm", "PerlCyc.pm");

print info_section_html (title=>"Description", contents=> <<HTML );


PerlCyc is a Perl interface for <a href="http://bioinformatics.ai.sri.com/ptools/">Pathway Tools software</a>. It allows internal Pathay Tools Lisp functions to be accessed through Perl. <br /><br />

For a description of what the individual functions do, please
       refer to the Pathway Tools documentation at http://bioinformat-
       ics.ai.sri.com/ptools .
<br /><br />
       In general, the Lisp function name has to be converted to something
       compatible with Perl: Dashes have to be replaced by underlines, and
       question marks with underline p (_p).
<br /><br />
       Note that the optional parameters of all functions
       are not supported in perlcyc, except for all_pathways() which can
       use the optional arguments :all T to get the base pathways only (no
       super-pathways).

HTML

    print info_section_html (title=>"Installation", contents=> <<HTML );

Installation is standard as for any Perl module. If you downloaded the
       compressed tar file, uncompress and untar the file with the following
       commands:
<pre>
        gzip < perlcyc.tar.gz | tar xvf -
</pre>
       This will create a directory called perlcyc in your current directory.
       To install the program, type
<pre>
        make
        make install
</pre>
       The program should now be available in all your Perl programs. "make
       install" may require root access or access through sudo. For the latter
       case, type
<pre>
        sudo make install
</pre>
       You will be prompted for your password.

HTML

    print info_section_html (title=>"Limitations", contents=><<HTML);

Perlcyc does not implement the GFP objects in Perl, rather it just
       sends snippets of code to Pathway-Tools through a socket connection.
       Only one such connection can be openend at any given time. Because the
       objects are not implemented in Perl, only object references are supported.

HTML

    print info_section_html (title=>"Supported functions", contents=><<HTML);


Object functions:

<pre>
       new
       Parameters: The knowledge base name. Required!
</pre>
       GFP functions: More information on these functions can be found at:
       http://www.ai.sri.com/~gfp/spec/paper/node63.html
<pre>
        get_slot_values
        get_slot_value
        get_class_all_instances
        instance_all_instance_of_p
        member_slot_value_p
        fequal
        current_kb
        put_slot_values
        put_slot_value
        add_slot_value
        replace_slot_value
        remove_slot_value
        coercible_to_frame_p
        class_all_type_of_p
        get_instance_direct_types
        get_instance_all_types
        get_frame_slots
        put_instance_types
        save_kb
        revert_kb
</pre>
       Pathway-tools functions: More information on these functions can be
       found at: http://bioinformatics.ai.sri.com/ptools/ptools-fns.html
<pre>
        select_organism
        all_pathways
        all_orgs
        all_rxns
        genes_of_reaction
        substrates_of_reaction
        enzymes_of_reaction
        reaction_reactants_and_products
        get_predecessors
        get_successors
        genes_of_pathway
        enzymes_of_pathway
        compounds_of_pathway
        substrates_of_pathway
        transcription_factor_p
        all_cofactors
        all_modulators
        monomers_of_protein
        components_of_protein
        genes_of_protein
        reactions_of_enzyme
        enzyme_p
        transport_p
        containers_of
        modified_forms
        modified_containers
        top_containers
        reactions_of_protein
        regulon_of_protein
        transcription_units_of_protein
        regulator_proteins_of_transcription_unit
        enzymes_of_gene
        all_products_of_gene
        reactions_of_gene
        pathways_of_gene
        chromosome_of_gene
        transcription_unit_of_gene
        transcription_unit_promoter
        transcription_unit_genes
        transcription_unit_binding_sites
        transcription_unit_transcription_factors
        transcription_unit_terminators
        all_transported_chemicals
        reactions_of_compound
        full_enzyme_name
        enzyme_activity_name
        find_indexed_frame
        create-instance
        create-class
        create-frame

        pwys-of-organism-in-meta
        enzymes-of-organism-in-meta
        lower-taxa-or-species-p org-frame
        get-class-all-subs
</pre>
       added 5/2008 per Suzanne\'s request:
<pre>
        genes-regulating-gene
        genes-regulated-by-gene
        terminators-affecting-gene
        transcription-unit-mrna-binding-sites
        transcription-unit-activators
        transcription-unit-inhibitors
        containing-tus
        direct-activators
        direct-inhibitors
</pre>
       not supported:
<pre>
        get_frames_matching_value (why not?)
</pre>
       Internal functions:
<pre>
        parselisp
        send_query
        retrieve_results
        wrap_query
        call_func
        debug
        debug_on
        debug_off
</pre>
       Deprecated functions
<pre>
        parse_lisp_list
</pre>

HTML

    print info_section_html(title=>"Requirements", contents=> <<HTML );

       To use the Perl module, you also need the socket_server.lisp program.
       In Pathway Tools version 8.0 or later, the server program can be
       started with the command line option "-api". On earlier versions, the
       server daemon needs to be loaded manually, as follows: start Pathway-
       Tools with the -lisp option, at the prompt, type: (load
       "/path/to/socket_server.lisp"), then start the socket_server by typing
       (start_external_access_daemon :verbose? t). The server is now ready to
       accept connections and queries.

HTML

print    info_section_html (title=>"Download", contents=> <<HTML );

Download [<a href="ftp://ftp.sgn.cornell.edu/programs/perlcyc/">FTP</a>]

HTML

    print info_section_html(title=>"Documentation", contents=> <<HTML );

<pre>
       perlcyc is a Perl interface for Pathway Tools software.

       "use perlcyc;"

       "my \$cyc = perlcyc -> new("ARA");" "my \@pathways = \$cyc -> all_path-
       ways();"

VERSION
       Version 1.21 (May 2008).

VERSION HISTORY

       Version History

       0.1  March, 2002
            [Lukas Mueller] initial version

       0.3  April 22, 2002
            [Danny Yoo] Added better list parsing

       0.9  [Lukas Mueller]
            Added more functions

       1.0  August 28, 2002 [Lukas Mueller]
            Added pod documentation and eliminated some bugs.

       1.1  June 6, 2003
            [Thomas Yan] Fixed some minor bugs.

       1.2  December 7, 2006 [Lukas Mueller]
            Added three functions: create-frame, create-class, and cre-
            ate-instance.

       1.21 May 7, 2008 [Lukas Mueller]
            Added three functions that are new in PT v. 12:
             pwys-of-organism-in-meta
             enzymes-of-organism-in-meta
             lower-taxa-or-species-p org-frame

             other new functions:
             get-class-all-subs

             genes-regulating-gene
             genes-regulated-by-gene
             terminators-affecting-gene
             transcription-unit-mrna-binding-sites
             transcription-unit-activators
             transcription-unit-inhibitors
             containing-tus
             direct-activators
             direct-inhibitors


       
</pre>

HTML

    print info_section_html (title=>"Examples", contents=> <<HTML );

       Change product type for all genes that are in a pathway to "Enzyme"

<pre>
        use perlcyc;

        my \$cyc = perlcyc -> new ("ARA");
        my \@pathways = \$cyc -> all_pathways();

        foreach my $p (\@pathways) {
          my \@genes = \$cyc -> genes_of_pathway(\$p);
          foreach my \$g (\@genes) {
            \$cyc -> put_slot_value (\$g, "Product-Types", "Enzyme");
          }
        }
</pre>
       Load a file containing two columns with accession and a comment into
       the comment field of the corresponding accession:
<pre>
        use perlcyc;
        use strict;

        my \$file = shift;

        my \$added=0;
        my \$recs =0;

        open (F, "<\$file") || die "Can't open file\\n";

        print STDERR "Connecting to AraCyc...\\n";
        my \$cyc = perlcyc -> new("ARA");

        print STDERR "Getting Gene Information...\\n";
        my \@genes = \$cyc -> get_class_all_instances("|Genes|");

        my %genes;

        print STDERR "Getting common names...\\n";
        foreach my \$g (\@genes) {
          my \$cname = \$cyc -> get_slot_value(\$g, "common-name");
          \$genes{\$cname}=\$g;
        }

        print STDERR "Processing file...\\n";
        while (&lt;F&gt;) {
          my (\$locus, \$location, \@rest) = split /\\t/;
          \$recs++;
          if (exists \$genes{\$locus}) {
              my \$product = \$cyc -> get_slot_value(\$genes{\$locus}, "product");
                if (\$product) {
                \$cyc -> add_slot_value(\$product, "comment", "\"\\nTargetP location: \$location\\n\"");
                 #print STDERR "Added to description of frame \$product\n";
                \$added++;
              }
            }
        }

        close (F);

        print STDERR "Done. Added \$added descriptions. Total lines in file: \$recs. \\n";
</pre>
       Add a locus link to the TAIR locus page for each gene in the database
<pre>
        use strict;
        use perlcyc;

        my \$added =0;
        my \$genesprocessed=0;

        print "Connecting to AraCyc...\\n";
        my \$cyc = perlcyc -> new ("ARA");

        print "Getting Gene Information...\\n";
        my \@genes = \$cyc -> get_class_all_instances ("|Genes|");

        print "Adding TAIR links...\\n";
        foreach my \$g (\@genes) {
          \$genesprocessed++;
          my \$common_name = \$cyc -> get_slot_value(\$g, "common-name");
          if (\$common_name &amp;&amp; (\$common_name ne "NIL")) {
            \$cyc -> put_slot_value (\$g, "dblinks", "(TAIR \"\$common_name\")");
            \$added++;
          }
          if ((!\$genesprocessed ==0) &amp;&amp; (\$genesprocessed % 1000 == 0)) { print "\$genesprocessed ";}
        }

        print "Done. Processed \$genesprocessed genes and added \$added links. Thanks!\\n";
        \$cyc -> close();
</pre>

HTML

    print info_section_html(title=>"Troubleshooting", contents=> <<HTML );

       If your program terminates with the following error message: "connect:
       No such file or directory at perlcyc.pm line 166."  then the
       lisp_server.lisp module in Pathway Tools is not running.  Refer to
       http://aracyc.stanford.edu for more information on how to run the
       server program.

       Please send bug reports and comments to LAM87\@cornell.edu

HTML

    print info_section_html(title=>"License", contents=> <<HTML );

<pre>
       According to the MIT License:<br />
       http://www.open-source.org/licenses/mit-license.php
       <br /><br />
       Copyright (c) 2002-2008 by Lukas Mueller, TAIR, BTI
       <br /><br />
       Permission is hereby granted, free of charge, to any person obtaining a
       copy of this software and associated documentation files (the "Soft-
       ware"), to deal in the Software without restriction, including without
       limitation the rights to use, copy, modify, merge, publish, distribute,
       sublicense, and/or sell copies of the Software, and to permit persons
       to whom the Software is furnished to do so, subject to the following
       conditions:
       <br /><br />
       The above copyright notice and this permission notice shall be included
       in all copies or substantial portions of the Software.
       <br /><br />
       THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
       OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MER-
       CHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
       NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
       CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
       TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFT-
       WARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
       <br /><br />

ACKNOWLEDGEMENTS
       Many thanks to Suzanne Paley, Danny Yoo and Thomas Yan.


</pre>

HTML


    $p->footer();
