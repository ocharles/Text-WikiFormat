#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;
use Test::More tests => 3;

use_ok( 'Text::WikiFormat' ) or exit;
my $wikitext =<<END_HERE;
	* start of list
	* second line
		* indented list
	* now back to the first
END_HERE

my $htmltext = Text::WikiFormat::format( $wikitext );
like( $htmltext, qr|second line<ul>.*?<li>indented|s,
	'nested lists should start correctly' );
like( $htmltext, qr|indented list.*?</li>.*?</ul>|s,
	'... and end correctly' );
