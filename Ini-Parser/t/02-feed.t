#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 17;

use Try::Tiny::SmartCatch 0.5 qw/:all/;

BEGIN { use_ok 'Ini::Parser'; }

my($parser, $src);
$parser = Ini::Parser->new ();
ok($parser, 'Parser created');
isa_ok($parser, 'Ini::Parser', 'Parser is correct');

# feed type auto recognize
# empty string
$src = '';
try sub {
    $parser->feed($src);
    pass('Correctly feeded with empty string');
},
catch_default sub {
    fail('Error when feeding with empty string: ' . $_);
};

# simple string
$src = '[section1]';
try sub {
    $parser->feed($src);
    fail('Simple string - should be recognize as non existent file');
},
catch_default sub {
    if ($_->msg() =~ /cannot open file/i) {
        pass('Simple string recognized as non existent file');
    }
    else {
        fail('Simple string isn\'t recognized as non existent file: ' . $_);
    }
};

# string - full section
$src = '[section1]
k1 = v1';
try sub {
    $parser->feed($src);
    pass('String - full section - should be recognize as string');
},
catch_default sub {
    fail('String isn\'t recognized correctly: ' . $_);
};

# existent filename
try sub {
    $parser->feed('t/basic.ini');
    pass('Filename - exists');
},
catch_default sub {
    fail('Can\'t load file t/basic.ini: ' . $_);
};

# file handler
try sub {
    my ($fh);
    open ($fh, '<', 't/basic.ini')
        or die('Cannot open file t/basic.ini: ' . $!);

    $parser->feed($fh);
    pass('File handler - exists');
},
catch_default sub {
    fail('Can\'t load file t/basic.ini: ' . $_);
};

# object - fine
try sub {
    $parser->feed(IniTest1->new());
    pass('Read from object');
},
catch_default sub {
    fail('Can\'t load data from object IniTest1: ' . $_);
};

# object - no read method
try sub {
    $parser->feed(IniTest2->new());
    fail('Read from object - method read doesn\'t exists');
},
catch_default sub {
    if ($_->msg() =~ /unrecognized source type/i) {
        pass('Read from object without read method failed (correctly)');
    }
    else {
        fail('Read from object without read method failed (uncorrectly): ' . $_);
    }
};


# feed type given
# empty string
$src = '';
try sub {
    $parser->feed($src, { src_type => 'string' });
    pass('Correctly feeded with empty string');
},
catch_default sub {
    fail('Error when feeding with empty string: ' . $_);
};

# simple string
$src = '[section1]';
try sub {
    $parser->feed($src, { src_type => 'string' });
    pass('Correctly feeded with simple string');
},
catch_default sub {
    fail('Error when feeding with simple string: ' . $_);
};

# string - full section
$src = '[section1]
k1 = v1';
try sub {
    $parser->feed($src, { src_type => 'string' });
    pass('String - full section - should be recognize as string');
},
catch_default sub {
    fail('String isn\'t recognized correctly: ' . $_);
};

# existent filename
try sub {
    $parser->feed('t/basic.ini', { src_type => 'filename' });
    pass('Filename - exists');
},
catch_default sub {
    fail('Can\'t load file t/basic.ini: ' . $_);
};

# file handler
try sub {
    my ($fh);
    open ($fh, '<', 't/basic.ini')
        or die('Cannot open file t/basic.ini: ' . $!);

    $parser->feed($fh, { src_type => 'handler' });
    pass('File handler - exists');
},
catch_default sub {
    fail('Can\'t load file t/basic.ini: ' . $_);
};

# object - fine
try sub {
    $parser->feed(IniTest1->new(), { src_type => 'object' });
    pass('Read from object');
},
catch_default sub {
    fail('Can\'t load data from object IniTest1: ' . $_);
};

# object - no read method
try sub {
    $parser->feed(IniTest2->new(), { src_type => 'object' });
    fail('Read from object - method read doesn\'t exists');
},
catch_when qr/Can't locate object method "read"/i => sub {
    pass('Read from object without read method failed (correctly)');
},
catch_default sub {
    fail('Read from object without read method failed (uncorrectly): ' . $_);
};

package IniTest1;
{
    sub new { return bless ({}, $_[0]) }
    sub read { return <<'EOI';
[section2]
a = 1
EOI
    }

}

package IniTest2;
{
    sub new { return bless ({}, $_[0]) }

}

