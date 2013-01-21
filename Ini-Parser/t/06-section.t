#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 22;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $section);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

ok($parser->feed ('t/basic.ini', { src_type => 'filename' }), 'feed t/basic.ini');
ok($parser->parse(), 'parse');

$section = $parser->section('section7');
ok($section, 'section exists');
isa_ok($section, 'Ini::Parser::Section', 'is correct type');

my @keys = $section->keys();
my @values = $section->values();
is_deeply(\@keys, ['key13'  .. 'key24' ], 'section::keys');
is_deeply(\@values,
    [qw/value13 value1 value1 value13 value13 value13 value13 value24 value24/, 'value1 value13 value24', 'value1 value13 value24', 'value24'],
    'section::values'
);

# test for correct order from keys and values
for (my $i = 0; $i < scalar @keys; ++$i) {
    is($section->get($keys[$i]), $values[$i], "Key and value form index $i corresponds to proper values from section data");
}

is_deeply({$section->to_hash()},
    {
        key13 => 'value13',
        key14 => 'value1',
        key15 => 'value1',
        key16 => 'value13',
        key17 => 'value13',
        key18 => 'value13',
        key19 => 'value13',
        key20 => 'value24',
        key21 => 'value24',
        key22 => 'value1 value13 value24',
        key23 => 'value1 value13 value24',
        key24 => 'value24',
    },
    'section::to_hash'
);

