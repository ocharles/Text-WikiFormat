#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../lib';
}

use Test::More tests => 4;

use_ok( 'Text::WikiFormat' );

my $wikitext =<<WIKI;


	* unordered

Final paragraph.

WIKI

my $htmltext = eval { Text::WikiFormat::format($wikitext) };

is( $@, '',
	'format() should throw no warnings for text starting with newlines' );

like( $htmltext, qr!<li>unordered</li>!, 
	'ensure that lists followed by paragraphs are included correctly' ); 

package Baz;
use Text::WikiFormat as => 'wf';

::can_ok( 'Baz', 'wf' );
