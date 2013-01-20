#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

# borrowed from Try::Tiny tests
sub _eval {
	local $@;
	local $Test::Builder::Level = $Test::Builder::Level + 2;
	return ( scalar(eval { $_[0]->(); 1 }), $@ );
}

# borrowed from Try::Tiny tests
sub lives_ok (&$) {
	my ( $code, $desc ) = @_;
	local $Test::Builder::Level = $Test::Builder::Level + 1;

	my ( $ok, $error ) = _eval($code);

	ok($ok, $desc );

	diag "error: $@" unless $ok;
}

# borrowed from Try::Tiny tests
sub throws_ok (&$$) {
	my ( $code, $regex, $desc ) = @_;
	local $Test::Builder::Level = $Test::Builder::Level + 1;

	my ( $ok, $error ) = _eval($code);

	if ( $ok ) {
		fail($desc);
	} else {
		like($error || '', $regex, $desc );
	}
}

my($parser, $src);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

$src = '';
try sub {
    $parser->feed($src);
    pass('Correctly feeded with empty string');
},
catch_default sub {
    fail('Error when feeding with empty string: ' . $_);
};

$src = '
[section1]
key1 = value1';
try sub {
    $parser->feed($src);
    pass('Correctly feeded with not empty string');
},
catch_default sub {
    fail('Error when feeding with not empty string: ' . $_);
};

