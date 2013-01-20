#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $src);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

ok($parser->feed ('t/basic.ini', { src_type => 'filename' }), 'feed t/basic.ini');

try sub {
    $parser->is_parsed ();
    fail('Source isn\'t parsed, exception should be raised');
},
catch_when 'Ini::Parser::Error' => sub {
    if ($_ =~ /Data not parsed/) {
        pass('Source isn\'t parsed, correct exception is raised');
    }
    else {
        fail('Source isn\'t parsed, unknown exception is raised: ' . $_);
    }
},
catch_default sub {
    fail('Source isn\'t parsed, unknown exception is raised: ' . $_);
};

ok($parser->parse(), 'parse');

try sub {
    $parser->is_parsed ();
    pass('Source is parsed, no exception should be raised');
},
catch_default sub {
    fail('Source is parsed, unknown exception is raised: ' . $_);
};

is_deeply([$parser->sections()], [ 'section with space', 'section!with:exclamation and colon and space', 'section1', 'section2', 'section3', 'section4' ], 'all sections in file');

is_deeply({$parser->to_hash()}, {
    section1 => {
        key1 => 'value1',
        key2 => "value2\nvalue3",
    },
    section2 => { },
    section3 => { key3 => '', },
    section4 => {
        key4 => 'value4',
        key5 => 'value5',
        key6 => 'value6',
        key7 => 'value7',
        key8 => 'value8',
        key9 => 'value9',
    },
    'section with space' => { key10 => 'value10' },
    'section!with:exclamation and colon and space' => {
        key11 => 'value11',
        'key12 with=some chars' => 'value12',
    },
}, 'to_hash');

