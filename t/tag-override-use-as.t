#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;
use Test::More tests => 2;
use Text::WikiFormat as => 'wikiformat';

my $wikitext =<<WIKI;

    * This should be a list.

    1. This should be an ordered list.

* This is like the default unordered list
* But not indented

    ! This is like the default unordered list
    ! But marked differently

WIKI

my $indent = $Text::WikiFormat::indent;

my %format_tags = ( lists => { unordered => qr/$indent\s*!\s*/ } );
 
my $htmltext = wikiformat( $wikitext, \%format_tags, {} );
like( $htmltext, qr!<li>But marked differently</li>!m,
	'redefining a list type works with use as' );

%format_tags = (
	lists => { 
		ordered         => qr/^\s*([\dA-Za-z]+)\.\s*/, 
		unordered       => qr/\s*\*\s*/
	}
); 

$htmltext = wikiformat( $wikitext, \%format_tags, {} );
like( $htmltext, qr!<li>But not indented</li>!m,
	'redefining a list type to require no indent works with use as' );
