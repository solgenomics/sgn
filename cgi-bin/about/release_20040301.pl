use strict;
use CXGN::Page;
my $page=CXGN::Page->new('release_20040301.html','html2pl converter');
$page->header('About The Sol Genomics Network');
print<<END_HEREDOC;

  <center>
    

  <table summary="" width="720" cellpadding="0" cellspacing="0"
  border="0">
    <tr>
      <td>
        <h4>Release Notes March 1, 2004</h4><b>Summary</b>
<ol>
<li>New datasets -- eggplant, petunia and pepper ESTs and
        unigene builds.</li>
<li>International Solanaceae Project Page -- A new version
        of the whitepaper is available!</li>
<li>Updated toolbar and user interface</li>
<li>Physical map data updated</li>
<li>SGN people directory</li>
<li>SOL Forum mailing list</li>
<li>Bulk download facility</li>
<li>FTP site</li>
<li>Improved search interface</li>
</ol>

        <p><b>Detailed descriptions</b></p>
<ol>
<li><p>New datasets -- ESTs from Pepper, Petunia and
        Eggplant added, Potato build updated.</p>

        <p>We have added EST data from pepper, petunia and
        eggplant. The pepper data was kindly submitted by Prof.
        Doil Choi of the KRIBB institute (http://www.kribb.re.kr)
        in Korea; the petunia data was kindly provided by Prof
        David Clark of University of Florida and Cornell
        University; and the eggplant data was supplied by Prof.
        Steven Tanksley of Cornell University. In addition, the
        potato unigene build was re-run with new sequences kindly
        provided by Robin Buell of TIGR, USA. We would like to
        sincerely thank these researchers for making their data
        available through SGN.</p>
</li>
<li><p>International Solanaceae Project (SOL) page</p>

        <p>The International Solanaceae Project (SOL) page is
        available at http://sgn.cornell.edu/solanaceae-project/.
        SOL is an initiative that will create a coordinated network
        of knowledge about the Solanaceae family aimed at answering
        two of the most important questions about life and
        agriculture, namely (1) How can a common set of
        genes/proteins give rise to such a wide range of
        morphologically and ecologically distinct organisms that
        occupy our planet? and (2) How can a deeper understanding
        of the genetic basis of diversity be harnessed to better
        meet the needs of society in an environmentally-friendly
        way? In addition, the page contains information on the
        meeting in Dulles, Virginia last November and provides
        downloads for a number of documents, such as the SOL
        whitepaper draft, information and guidelines for the tomato
        sequencing project, and transcripts from the Dulles
        meeting. More information will be available soon, so check
        back frequently.</p>
</li>
<li><p>Updated toolbar and user interface</p>

        <p>We continue to make improvements to the user interface,
        hopefully without causing too many disruptive changes. We
        have improved the toolbar with a better layout of the
        menus, which are now pull-down menus for easier direct
        access to the most important pages from any page. In
        addition, there is now a quick search feature which
        searches the entire database contents with one simple
        search. We have re-arranged some of the pages and added
        more help files and a data overview page
        (http://sgn.cornell.edu/content/sgn_data.pl). The
        search page was also overhauled and now has a more
        functional layout. Please let us know what you think of
        these changes.</p>
</li>
<li><p>Physical Map Data</p>

        <p>We have integrated the results from almost 700 overgo
        markers linking the genetic map to the physical map. The
        results can be viewed graphically at
        http://sgn.cornell.edu/cview/map.pl?map_id=1&amp;physical=1.
        The purpose of this project was to develop a tomato
        physical map anchored to the genetic map and to identify
        the tomato BAC minimum tiling path for positional cloning
        and whole genome sequencing. 88,642 BAC clones from a
        Lycopersicon esculentum cv. Heinz 1706 BAC library with
        129,024 clones and roughly 15 genome equivalents generated
        Unambiguous fingerprints (Arizona Genome Institute). In
        order to anchor the fingerprinted BACs onto the tomato
        genetic map, overgo (overlapping oligonucleotide) probes
        were generated from a total of 1535 sequenced, mapped
        markers from the current high density tomato map. The map
        overview page is at
        http://sgn.cornell.edu/cview/index.pl
        .</p>
</li>
<li><p>SGN people directory</p>

        <p>SGN has now a directory of people who are actively
        involved in Solanaceae research. The data can be searched
        and browsed on-line at
        http://sgn.cornell.edu/search/direct_search.pl?search=Directory.
        If you are in the database, a password should have been
        sent to you that allows you to modify and complete the
        information in your entry. If you are not yet in the
        database, you can add yourself at
        http://sgn.cornell.edu/user/login. You will
        have to create an account first and then you can add your
        information.</p>
</li>
<li><p>SOL-Forum mailing list</p>

        <p>To better connect the solanaceae community, a new list
        has been made available that allows subscribed members to
        post messages to the list or ask questions to the
        community. You can subscribe to the list at
        http://caffeine.sgn.cornell.edu/mailman/listinfo/sol-forum.
        The scope of the list is solanaceae research and related
        topics. Please follow the guidelines of the list when
        posting to make this a useful tool for solanaceae
        researchers. Unsubscribing is possible at any moment.
        People who are not subscribe to the list cannot post
        messages, mainly because this prevents spammers from using
        the list.</p>
</li>
<li><p>Bulk download facility</p>

        <p>SGN now has a bulk download facility that allows you to
        download data using lists of clone names, unigene ids, and
        microarray identifiers. You can specify the information
        that you would like to download, including associated clone
        names, associated unigene ids, sequence data and much more.
        Before downloading the data to your disk in tab delimited
        or fasta formats, you can browse the data on line. The bulk
        download is linked from the toolbar on every page and is
        directly available at:
        http://sgn.cornell.edu/bulk/input.pl.</p>
</li>
<li><p>FTP site</p>

        <p>SGN now has an FTP site that allows you to download
        complete datasets. The ftp site is linked from the bulk
        download page (rightmost tab) and can also be accessed via
        ftp://ftp.sgn.cornell.edu using a web browser or ftp
        client. The FTP site is structured into folders that group
        datasets by type of data. Marker data, EST sequences,
        unigene sequences and much more can be downloaded. More
        data will be added to the FTP site in the coming months so
        check back frequently.</p>
</li>
<li><p>Improved searches</p>
The database search interface has been improved in the following ways:
<ul>
<li>the different searches are now separated by 'tabs' for
        better navigation</li>
<li>you can now search the unigenes using TIGR
        identifiers</li>
<li>a library search has been added that allows you to search
        by name, organism, source tissue, development stage,
        etc.</li>
</ul>
</li>
</ol>
      </td>
    </tr>
  </table>

</center>
END_HEREDOC
$page->footer();
